#!/usr/bin/env python3
"""Confirm the CLI's shared Swift client refuses HTTP redirects on loopback."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json
import subprocess
import sys
import tempfile
import threading

paths = []
class Redirect(BaseHTTPRequestHandler):
    def do_POST(self):
        paths.append(self.path)
        if self.path == '/v1/activity':
            self.send_response(307)
            self.send_header('Location', '/must-not-follow')
            self.send_header('Content-Length', '0')
            self.end_headers()
        else:
            body = b'{"ok":true,"message":"redirect followed"}'
            self.send_response(200)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    def log_message(self, *_): pass

server = HTTPServer(('127.0.0.1', 0), Redirect)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    with tempfile.TemporaryDirectory(prefix='notchwork-redirect-') as directory:
        connection = Path(directory) / 'connection.json'
        connection.write_text(json.dumps({'endpoint': f'http://127.0.0.1:{server.server_port}', 'token': 'synthetic-test-token'}))
        result = subprocess.run([sys.argv[1], '--connection', str(connection), 'ping'], capture_output=True, timeout=10)
        assert result.returncode != 0, 'Redirect unexpectedly succeeded'
        assert paths == ['/v1/activity'], f'Client followed redirect: {paths}'
        print('PASS: Swift client refuses redirects without forwarding the token.')
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=2)
