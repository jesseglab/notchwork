import http.server
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'Examples'))
from notchwork_client import Client, NotchworkError, activity


class ReferenceClientTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.file = Path(self.folder.name) / 'connection.json'

    def tearDown(self):
        self.folder.cleanup()

    def connection(self, endpoint):
        self.file.write_text(json.dumps(dict(endpoint=endpoint, token='test-token')))
        return Client(self.file)

    def test_missing_runtime_is_actionable(self):
        with self.assertRaisesRegex(NotchworkError, 'Start Notchwork'):
            Client(self.file)

    def test_rejects_nonlocal_or_ambiguous_endpoints(self):
        for endpoint in ['https://127.0.0.1:1234', 'http://example.com:1234',
                         'http://127.0.0.1:1234/path', 'http://user@127.0.0.1:1234',
                         'http://127.0.0.1:1234?redirect=x', 'http://127.0.0.1:1234#x',
                         'http://127.0.0.1:0']:
            with self.subTest(endpoint=endpoint), self.assertRaises(NotchworkError):
                self.connection(endpoint)

    def test_rejects_token_header_injection(self):
        self.file.write_text(json.dumps(dict(endpoint='http://127.0.0.1:1234', token='x\r\nOther: yes')))
        with self.assertRaises(NotchworkError):
            Client(self.file)

    def test_request_contract_and_redirect_rejection(self):
        calls = []
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                calls.append((self.path, self.headers['Authorization'], json.loads(self.rfile.read(int(self.headers['Content-Length'])))))
                payload = json.dumps(dict(ok=True, apiVersion=2, message='test')).encode()
                self.send_response(302 if len(calls) == 2 else 200)
                self.send_header('Location', 'http://127.0.0.1:%s/leaked' % self.server.server_port)
                self.send_header('Content-Length', str(len(payload)))
                self.end_headers(); self.wfile.write(payload)
            def log_message(self, *args):
                pass
        server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        try:
            client = self.connection('http://127.0.0.1:%s' % server.server_port)
            self.assertEqual(client.ping()['apiVersion'], 2)
            with self.assertRaisesRegex(NotchworkError, '302'):
                client.ping()
            self.assertEqual(len(calls), 2, 'Redirect must not receive a request or token')
            self.assertEqual(calls[0], ('/v1/activity', 'Bearer test-token', {'operation':'ping'}))
        finally:
            server.shutdown(); server.server_close(); thread.join()

    def test_full_card_and_body_limit(self):
        card = activity('app.test', 'Test', 'Ready')
        self.assertEqual(card['priority'], 'low')
        self.assertEqual(card['ttl'], 60)
        client = self.connection('http://127.0.0.1:1')
        with self.assertRaisesRegex(NotchworkError, '16 MiB'):
            client.publish(dict(card, title='x' * 16_777_216))


if __name__ == '__main__':
    unittest.main()
