"""Loopback-only review service. Requires explicit production credentials.

This entry point is intentionally not installed or exposed by default. Apple
attestation receipt verification and CloudKit/IAP sandbox must be independently
verified on real devices before use.
"""
import os
import sys
import threading
from http.server import HTTPServer
from pathlib import Path
from socketserver import ThreadingMixIn
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from appstoreserverlibrary.api_client import AppStoreServerAPIClient
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
from attest_assertion import AssertionStore
from attest_attestation import verify_attestation  # validates dependency at startup
from attest_challenges import AttestChallenges
from attest_receipt import verify_receipt
from attest_registration import AttestRegistration
from review_authorization import ReviewAuthorization
from review_http import handler_type
from subscription_quota import SubscriptionQuota
from subscription_verifier import SubscriptionVerifier
from trial_quota import TrialQuota
from trial_verifier import TrialVerifier
import local_qwen_proxy as proxy


class BoundedHTTPServer(ThreadingMixIn, HTTPServer):
    """Keep a slow generation from blocking challenges, with bounded workers."""
    daemon_threads = True
    MAX_CONCURRENT_REQUESTS = 16

    def __init__(self, *args, **kwargs):
        self._slots = threading.BoundedSemaphore(self.MAX_CONCURRENT_REQUESTS)
        super().__init__(*args, **kwargs)

    def process_request(self, request, client_address):
        if not self._slots.acquire(blocking=False):
            try:
                request.sendall(b'HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\nContent-Length: 0\r\n\r\n')
            except OSError:
                pass
            finally:
                self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except BaseException:
            self._slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self._slots.release()

    def handle_error(self, request, client_address):
        # Request bodies, proofs and account identifiers must not enter logs.
        print('{"event":"connection_error"}', flush=True)


def main():
    credential = Path(os.environ['CREDENTIALS_DIRECTORY'])
    state = Path(os.environ['STATE_DIRECTORY'])
    environment = os.environ['MAYBII_APPLE_ENV']
    if environment not in ('production', 'sandbox'):
        raise ValueError('explicit Apple environment required')
    apple_environment = Environment.PRODUCTION if environment == 'production' else Environment.SANDBOX
    attest_environment = os.environ['MAYBII_ATTEST_ENV']
    if attest_environment not in ('development', 'production'):
        raise ValueError('explicit App Attest environment required')
    app_id = os.environ['MAYBII_APPLE_TEAM_ID'] + '.com.deshiru.habitnative'
    categories = {int(x) for x in os.environ['MAYBII_ATTEST_CATEGORIES'].split(',')}
    versions = set(os.environ['MAYBII_ATTEST_VERSIONS'].split(','))
    if not categories or not versions or '' in versions:
        raise ValueError('explicit attestation policy required')
    app_store_root = (credential / 'apple_root_g3').read_bytes()
    attest_root = (credential / 'apple_app_attest_root').read_bytes()
    # App Attest's key-attestation certificate and its CMS receipt have
    # different trust roots. The receipt uses Apple Root CA - G3, which is
    # also the root already loaded for App Store signed data.
    receipt_root = app_store_root
    secret = (credential / 'quota_hmac_key').read_bytes()
    signing_key = (credential / 'appstore_api_key').read_bytes()
    api_key = (credential / 'qwen_api_key').read_text().strip()
    if len(secret) < 32 or not api_key or '\n' in api_key or '\r' in api_key:
        raise ValueError('invalid credentials')
    apple_id = int(os.environ['MAYBII_APP_APPLE_ID']) if environment == 'production' else None
    verifier = SignedDataVerifier([app_store_root], True, apple_environment, 'com.deshiru.habitnative', apple_id)
    client = AppStoreServerAPIClient(signing_key, os.environ['MAYBII_APPSTORE_KEY_ID'],
        os.environ['MAYBII_APPSTORE_ISSUER_ID'], 'com.deshiru.habitnative', apple_environment)
    trials = TrialVerifier(verifier)
    attest_db = state / 'attest.sqlite3'
    challenges = AttestChallenges(attest_db)
    assertions = AssertionStore(attest_db, app_id, categories, versions)
    receipt_check = lambda receipt, identifier, key, now: verify_receipt(receipt, identifier, key, now, receipt_root)
    registration = AttestRegistration(attest_db, trials, receipt_check, secret, app_id, attest_root,
        attest_environment, categories, versions)
    # A subscription is the billing identity. Keep the agreed limit here, at
    # the only production entry point, rather than in an unused relay.
    authorization = ReviewAuthorization(trials, SubscriptionVerifier(verifier, client), assertions,
        SubscriptionQuota(state / 'subscription-quota.sqlite3', secret, limit=3),
        TrialQuota(state / 'trial.sqlite3', secret), secret)
    proxy.get_api_key = lambda: api_key
    port = int(os.environ.get('MAYBII_BIND_PORT', '8766'))
    if not 1024 <= port <= 65535:
        raise ValueError('invalid private listener port')
    BoundedHTTPServer(('127.0.0.1', port), handler_type(authorization, challenges, registration)).serve_forever()


if __name__ == '__main__':
    main()
