"""Unpublished subscriber-only AI relay. Do not expose until release gates pass.

Free-trial authorization and device attestation are not implemented. Production
must not be switched to this entry point until those paths are designed and tested.
"""
import json
import os
import sys
import time
from datetime import datetime, timezone
from http.server import HTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import local_qwen_proxy as proxy
from appstoreserverlibrary.api_client import AppStoreServerAPIClient
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException
from subscription_quota import SubscriptionQuota
from subscription_verifier import SubscriptionVerifier

MAX_REQUEST_BYTES = 128 * 1024


def handler_type(entitlements, quota):
    class Handler(proxy.Handler):
        def send_json(self, status, obj):
            if self.path == '/api/review':
                print(json.dumps({'time': datetime.now(timezone.utc).isoformat(),
                    'endpoint': '/api/review', 'period': getattr(self, 'review_period', 'unknown'),
                    'characters': getattr(self, 'review_length', 0),
                    'duration_ms': round((time.monotonic() - getattr(self, 'review_started', time.monotonic())) * 1000),
                    'status': status}), flush=True)
            super().send_json(status, obj)

        def reserve_review_request(self):
            return quota.reserve(self.subscription_id)

        def do_OPTIONS(self):
            self.send_json(405, {'error': 'method_not_allowed'})

        def do_POST(self):
            self.review_started = time.monotonic()
            if self.path != '/api/review':
                self.send_json(404, {'error': 'not_found'})
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= MAX_REQUEST_BYTES:
                    self.send_json(413, {'error': 'invalid_payload_size'})
                    return
                proof = self.headers.get('X-StoreKit-Transaction', '')
                self.subscription_id = entitlements.verified_subscription_id(proof)
                if not self.subscription_id:
                    self.send_json(401, {'error': 'subscription_required'})
                    return
            except (ValueError, VerificationException):
                self.send_json(401, {'error': 'invalid_subscription'})
                return
            except Exception:
                self.send_json(503, {'error': 'subscription_verification_unavailable'})
                return
            super().do_POST()

    return Handler


class SafeHTTPServer(HTTPServer):
    def handle_error(self, request, client_address):
        print(json.dumps({'time': datetime.now(timezone.utc).isoformat(), 'event': 'connection_error'}), flush=True)


def main():
    # Explicit environment and credentials. Never fall back from production to sandbox.
    credentials = Path(os.environ['CREDENTIALS_DIRECTORY'])
    state = Path(os.environ['STATE_DIRECTORY'])
    environment = {'production': Environment.PRODUCTION, 'sandbox': Environment.SANDBOX}[os.environ['MAYBII_APPLE_ENV']]
    roots = [(credentials / 'apple_root_g3').read_bytes()]
    signing_key = (credentials / 'appstore_api_key').read_bytes()
    hmac_secret = (credentials / 'quota_hmac_key').read_bytes()
    apple_id = int(os.environ['MAYBII_APP_APPLE_ID']) if environment == Environment.PRODUCTION else None
    verifier = SignedDataVerifier(roots, True, environment, 'com.deshiru.habitnative', apple_id)
    client = AppStoreServerAPIClient(signing_key, os.environ['MAYBII_APPSTORE_KEY_ID'], os.environ['MAYBII_APPSTORE_ISSUER_ID'], 'com.deshiru.habitnative', environment)
    entitlements = SubscriptionVerifier(verifier, client)
    quota = SubscriptionQuota(state / 'subscription-quota.sqlite3', hmac_secret, limit=3)
    api_key = (credentials / 'qwen_api_key').read_text().strip()
    if not api_key or '\n' in api_key or '\r' in api_key:
        raise SystemExit('invalid API key')
    proxy.get_api_key = lambda: api_key
    SafeHTTPServer(('127.0.0.1', 8766), handler_type(entitlements, quota)).serve_forever()


if __name__ == '__main__':
    main()
