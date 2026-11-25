"""HTTP adapter for verified review authorization.

Dependency injection is intentional: production must supply configured Apple
verifiers and attestation registration. This module never substitutes mocks.
"""
import base64
import io
import json
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import local_qwen_proxy as proxy


def handler_type(authorization, challenges, registration):
    class Handler(proxy.Handler):
        reservation = None

        def reserve_review_request(self):
            return self.reservation is not None

        def send_json(self, status, obj):
            reservation, self.reservation = self.reservation, None
            if reservation is not None:
                # Commit success before sending; a broken client connection must
                # not turn a completed, billable generation into a new trial.
                authorization.finish(reservation, status == 200)
            super().send_json(status, obj)

        def do_POST(self):
            self.reservation = None
            try:
                if self.headers.get('Transfer-Encoding'):
                    self.send_json(400, {'error': 'unsupported_encoding'}); return
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 128 * 1024:
                    self.send_json(413, {'error': 'invalid_payload_size'}); return
                body = self.rfile.read(length)
                if len(body) != length:
                    self.send_json(400, {'error': 'incomplete_request'}); return
                document = json.loads(body)
                if not isinstance(document, dict):
                    self.send_json(400, {'error': 'invalid_request'}); return
                if self.path == '/api/attest/challenge':
                    value = challenges.issue(document.get('purpose'))
                    self.send_json(200, {'challenge': value}); return
                if self.path == '/api/attest/register':
                    ok = registration.register(document['key_id'], document['challenge'],
                        document['app_proof'], base64.b64decode(document['attestation'], validate=True))
                    self.send_json(200 if ok else 401, {'registered': bool(ok)}); return
                if self.path not in ('/api/review', '/api/review/reset-trial'):
                    self.send_json(404, {'error': 'not_found'}); return
                arguments = dict(app_proof=self.headers.get('X-App-Transaction', ''),
                    subscription_proof=self.headers.get('X-StoreKit-Transaction', ''),
                    key_id=self.headers.get('X-App-Attest-Key', ''),
                    assertion=base64.b64decode(self.headers.get('X-App-Attest-Assertion', ''), validate=True),
                    challenge=self.headers.get('X-App-Attest-Challenge', ''), body=body)
                if self.path == '/api/review/reset-trial':
                    ok = authorization.reset_trial(**arguments)
                    self.send_json(200 if ok else 401, {'reset': bool(ok)}); return
                # Reject malformed model requests before consuming a reservation.
                if (not isinstance(document.get('report'), str) or not document['report'].strip()
                        or document.get('period') not in ('week', 'month')
                        or document.get('language', 'zh-Hans') not in proxy.OUTPUT_LANGUAGES):
                    self.send_json(400, {'error': 'invalid_request'}); return
                self.reservation = authorization.reserve(**arguments)
                if self.reservation is None:
                    self.send_json(403, {'error': 'review_not_authorized'}); return
                original = self.rfile
                try:
                    self.rfile = io.BytesIO(body)
                    super().do_POST()
                finally:
                    self.rfile = original
                    if self.reservation is not None:
                        authorization.finish(self.reservation, False)
                        self.reservation = None
            except (ValueError, KeyError, TypeError, UnicodeError):
                self.send_json(400, {'error': 'invalid_request'})
            except Exception:
                self.send_json(503, {'error': 'verification_unavailable'})

        def do_OPTIONS(self):
            self.send_json(405, {'error': 'method_not_allowed'})
    return Handler
