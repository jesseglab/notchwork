#!/usr/bin/env python3
"""Run real child processes against a recording local host, with isolated credentials."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json
import os
import signal
import subprocess
import sys
import tempfile
import threading
import time

cards = []
class Host(BaseHTTPRequestHandler):
    def do_POST(self):
        assert self.headers.get('Authorization') == 'Bearer synthetic-test-token'
        payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        cards.append(payload['activity'])
        body = b'{"ok":true,"message":"accepted"}'
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *_): pass

server = HTTPServer(('127.0.0.1', 0), Host)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    with tempfile.TemporaryDirectory(prefix='notchwork-run-') as directory:
        connection = Path(directory) / 'connection.json'
        connection.write_text(json.dumps({'endpoint': f'http://127.0.0.1:{server.server_port}', 'token': 'synthetic-test-token'}))
        cli = [str(Path(sys.argv[1]).resolve()), '--connection', str(connection), 'run', '--name', 'Test build', '--']
        for code in [0, 7]:
            cards.clear()
            result = subprocess.run(cli + ['/bin/sh', '-c', f'read value; printf "out:%s\\n" "$value"; printf "err\\n" >&2; sleep .3; exit {code}'], input='hello\n', text=True, capture_output=True, timeout=10)
            assert result.returncode == code, result
            assert result.stdout == 'out:hello\n' and result.stderr == 'err\n', result
            assert cards[0]['title'].endswith('running') and cards[-1]['title'].endswith('complete' if code == 0 else 'failed'), cards
            assert cards[-1]['priority'] == ('normal' if code == 0 else 'urgent')
            assert len({c['id'] for c in cards}) == 1
            assert not any('hello' in str(c) for c in cards), 'Child output was leaked'
            print(f'PASS: exit {code}, live status, stdin/stdout/stderr, and output privacy')
        cards.clear()
        process = subprocess.Popen(cli + ['/bin/sleep', '30'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            for _ in range(100):
                if cards: break
                time.sleep(.02)
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=10)
            assert process.returncode == 143, process.returncode
            assert cards[-1]['priority'] == 'urgent'
            print('PASS: termination forwards to the child and reports signal exit')
        finally:
            if process.poll() is None: process.kill(); process.wait()
        missing = Path(directory) / 'missing.json'
        result = subprocess.run([cli[0], '--connection', str(missing), 'run', '--', '/bin/sh', '-c', 'printf offline; exit 9'], capture_output=True, text=True, timeout=10)
        assert result.returncode == 9 and result.stdout == 'offline', result
        print('PASS: missing host does not block the command or change its exit status')
        result = subprocess.run(cli + ['/does/not/exist'], capture_output=True, text=True, timeout=10)
        assert result.returncode == 127, result
        print('PASS: missing executable returns 127')
finally:
    server.shutdown(); server.server_close(); thread.join(timeout=2)
