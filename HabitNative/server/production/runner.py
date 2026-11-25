"""Authenticated loopback upstream behind nginx. No user content in access DB."""
import os
import json
import time
import jwt
from datetime import datetime, timezone
from pathlib import Path
from http.server import HTTPServer
import local_qwen_proxy as proxy
from access import Access
from apple_auth import AppleAuth

credential = Path(os.environ['CREDENTIALS_DIRECTORY']) / 'qwen_api_key'
key = credential.read_text().strip()
if not key or '\n' in key or '\r' in key:
    raise SystemExit('invalid API key')
proxy.get_api_key = lambda: key
access = Access(Path(os.environ['STATE_DIRECTORY']) / 'access.sqlite3')

apple = AppleAuth(access, "com.deshiru.habitnative")

class Handler(proxy.Handler):
    def send_json(self, status, obj):
        if self.path == '/api/review':
            print(json.dumps({
                'time': datetime.now(timezone.utc).isoformat(),
                'endpoint': '/api/review',
                'period': getattr(self, 'review_period', 'unknown'),
                'characters': getattr(self, 'review_length', 0),
                'duration_ms': round((time.monotonic() - getattr(self, 'review_started', time.monotonic())) * 1000),
                'status': status,
            }), flush=True)
        super().send_json(status, obj)

    def do_OPTIONS(self):
        self.send_json(405, {'error': 'method_not_allowed'})
    def do_POST(self):
        self.review_started = time.monotonic()
        if self.path in ('/auth/apple/challenge', '/auth/apple/session'):
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 16384:
                    self.send_json(413, {'error': 'invalid_payload_size'})
                    return
                body = json.loads(self.rfile.read(length))
                if self.path.endswith('/challenge'):
                    result = apple.challenge()
                else:
                    result = apple.exchange(body['challenge_id'], body['identity_token'])
                self.send_json(200, result)
            except (ValueError, KeyError, TypeError, jwt.PyJWTError):
                self.send_json(401, {'error': 'authentication_failed'})
            return
        if self.path != '/api/review':
            self.send_json(404, {'error': 'not_found'})
            return
        status = access.consume(self.headers.get('Authorization', ''))
        if status != 200:
            self.send_json(status, {'error': 'quota_exceeded' if status == 429 else 'unauthorized'})
            return
        super().do_POST()

class SafeHTTPServer(HTTPServer):
    def handle_error(self, request, client_address):
        # Tracebacks can include request-dependent data. Never print them here.
        print(json.dumps({'time': datetime.now(timezone.utc).isoformat(),
                          'event': 'connection_error'}), flush=True)


if __name__ == '__main__':
    SafeHTTPServer(('127.0.0.1', 8766), Handler).serve_forever()
