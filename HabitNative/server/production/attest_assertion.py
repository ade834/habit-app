"""Unpublished App Attest assertion prototype. Enrollment is NOT implemented.

Only public keys independently verified by Apple's full attestation procedure may
be registered. Do not expose this module until enrollment and live-device testing
are complete. No report text or StoreKit proofs are stored.
"""
import hashlib
import io
import json
import sqlite3
import time
import cbor2
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from attest_extensions import validation_category


def _decode_one(data):
    stream = io.BytesIO(data)
    value = cbor2.CBORDecoder(stream).decode()
    if stream.read(1): raise ValueError('trailing CBOR data')
    return value


def client_data(challenge, key_id, body, subscription_proof, app_proof):
    """Canonical ASCII JSON shared with the app. Digests bind the actual request."""
    document = {'challenge': challenge, 'keyId': key_id,
                'bodySHA256': hashlib.sha256(body).hexdigest(),
                'subscriptionProofSHA256': hashlib.sha256(subscription_proof.encode('utf-8')).hexdigest(),
                'appProofSHA256': hashlib.sha256(app_proof.encode('utf-8')).hexdigest()}
    return json.dumps(document, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode('ascii')


class AssertionStore:
    def __init__(self, path, app_id, allowed_categories, allowed_versions):
        if not app_id or not allowed_categories or not allowed_versions:
            raise ValueError('explicit app ID, validation categories and versions are required')
        self.path = str(path)
        self.rp_id = hashlib.sha256(app_id.encode('utf-8')).digest()
        self.allowed_categories = frozenset(allowed_categories)
        self.allowed_versions = frozenset(allowed_versions)
        with sqlite3.connect(self.path, timeout=10) as db:
            db.execute('CREATE TABLE IF NOT EXISTS attest_keys (key_id TEXT PRIMARY KEY, public_key BLOB NOT NULL, counter INTEGER NOT NULL, app_tag TEXT NOT NULL)')
            db.execute('CREATE TABLE IF NOT EXISTS attest_challenges (digest TEXT PRIMARY KEY, purpose TEXT NOT NULL, expires INTEGER NOT NULL)')

    def store_verified_key(self, key_id, public_key_der, app_tag):
        """Caller must complete full Apple attestation verification first."""
        public_key = serialization.load_der_public_key(public_key_der)
        if not isinstance(public_key, ec.EllipticCurvePublicKey) or not isinstance(public_key.curve, ec.SECP256R1):
            raise ValueError('invalid attested public key')
        if not isinstance(key_id, str) or not 1 <= len(key_id) <= 256:
            raise ValueError('invalid key identifier')
        if not isinstance(app_tag, str) or len(app_tag) != 64 or any(c not in '0123456789abcdef' for c in app_tag):
            raise ValueError('invalid keyed app identifier')
        with sqlite3.connect(self.path, timeout=10) as db:
            db.execute('INSERT INTO attest_keys VALUES (?,?,0,?)', (key_id, public_key_der, app_tag))

    def verify_and_consume(self, key_id, assertion, challenge, body, app_tag, subscription_proof='', app_proof='', now=None):
        if not isinstance(assertion, bytes) or not 1 <= len(assertion) <= 8192:
            return False
        if not isinstance(challenge, str) or not 1 <= len(challenge) <= 128:
            return False
        try:
            challenge_digest = hashlib.sha256(challenge.encode('ascii')).hexdigest()
            decoded = _decode_one(assertion)
            if not isinstance(decoded, dict) or set(decoded) != {'signature', 'authenticatorData'}: return False
            signature, auth = decoded['signature'], decoded['authenticatorData']
            if not isinstance(signature, bytes) or not isinstance(auth, bytes) or len(auth) < 38 or len(auth) > 4096: return False
            # Apple's signed assertion authenticator data can carry flags that
            # differ from generic WebAuthn expectations. Verify the signed RP ID,
            # counter and parsed extensions rather than rejecting valid flags.
            if auth[:32] != self.rp_id: return False
            counter = int.from_bytes(auth[33:37], 'big')
            extensions = _decode_one(auth[37:])
            if not isinstance(extensions, dict): return False
            category = validation_category(extensions.get('apple_validation_category_01'))
            version = extensions.get('apple_bundle_version_01')
            if category not in self.allowed_categories or version not in self.allowed_versions: return False
            data = client_data(challenge, key_id, body, subscription_proof, app_proof)
            nonce = hashlib.sha256(auth + hashlib.sha256(data).digest()).digest()
            with sqlite3.connect(self.path, timeout=10, isolation_level=None) as db:
                db.execute('BEGIN IMMEDIATE')
                key = db.execute('SELECT public_key,counter,app_tag FROM attest_keys WHERE key_id=?', (key_id,)).fetchone()
                saved = db.execute('SELECT purpose,expires FROM attest_challenges WHERE digest=?', (challenge_digest,)).fetchone()
                timestamp = int(time.time() if now is None else now)
                if not key or key[2] != app_tag or not saved or saved[0] != 'assertion' or saved[1] <= timestamp or counter <= key[1]:
                    db.execute('ROLLBACK'); return False
                public_key = serialization.load_der_public_key(key[0])
                # App Attest signs the derived nonce with ECDSA-SHA256.
                # The ECDSA operation hashes the nonce; treating it as already
                # prehashed rejects signatures generated by real devices.
                public_key.verify(signature, nonce, ec.ECDSA(hashes.SHA256()))
                db.execute('UPDATE attest_keys SET counter=? WHERE key_id=?', (counter, key_id))
                db.execute('DELETE FROM attest_challenges WHERE digest=?', (challenge_digest,))
                db.execute('COMMIT'); return True
        except (ValueError, TypeError, UnicodeEncodeError, InvalidSignature, EOFError, cbor2.CBORDecodeError):
            return False
