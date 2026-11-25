"""UNPUBLISHED registration composition for App Attest.

The production receipt verifier is NOT implemented. Callers must supply a
cryptographic Apple receipt verifier. Never expose registration without it.
"""
import hashlib
import hmac
import sqlite3
import time
from attest_attestation import verify_attestation

class AttestRegistration:
    def __init__(self, path, trial_verifier, receipt_verifier, hmac_secret, app_id, root_der, environment, allowed_categories, allowed_versions):
        if receipt_verifier is None or not callable(receipt_verifier):
            raise ValueError('Apple receipt verifier required')
        if not isinstance(hmac_secret, bytes) or len(hmac_secret) < 32:
            raise ValueError('HMAC secret required')
        self.path, self.trial_verifier, self.receipt_verifier = str(path), trial_verifier, receipt_verifier
        self.secret, self.app_id, self.root, self.environment = hmac_secret, app_id, root_der, environment
        self.categories, self.versions = allowed_categories, allowed_versions
        with sqlite3.connect(self.path, timeout=10) as db:
            db.execute('CREATE TABLE IF NOT EXISTS attest_keys (key_id TEXT PRIMARY KEY, public_key BLOB NOT NULL, counter INTEGER NOT NULL, app_tag TEXT NOT NULL)')
            db.execute('CREATE TABLE IF NOT EXISTS attest_challenges (digest TEXT PRIMARY KEY, purpose TEXT NOT NULL, expires INTEGER NOT NULL)')
            db.execute('CREATE TABLE IF NOT EXISTS attest_receipts (key_id TEXT PRIMARY KEY, receipt BLOB NOT NULL)')

    def register(self, key_id, challenge, app_proof, attestation, now=None):
        # Verify everything before the transaction, but consume the challenge and
        # register the key together so concurrent requests cannot reuse it.
        app_transaction_id = self.trial_verifier.verified_app_transaction_id(app_proof)
        if not app_transaction_id: return False
        public_key, receipt = verify_attestation(attestation, key_id, challenge, app_proof, self.app_id,
                                                  self.root, self.environment, self.categories, self.versions)
        timestamp = int(time.time() if now is None else now)
        app_tag = hmac.new(self.secret, ('app:' + app_transaction_id).encode('utf-8'), hashlib.sha256).hexdigest()
        digest = hashlib.sha256(challenge.encode('ascii')).hexdigest()

        def existing_matches(db):
            row = db.execute('SELECT k.public_key,k.app_tag,r.receipt FROM attest_keys k '
                             'JOIN attest_receipts r ON r.key_id=k.key_id WHERE k.key_id=?', (key_id,)).fetchone()
            if row is None: return None
            return (hmac.compare_digest(row[0], public_key) and hmac.compare_digest(row[1], app_tag)
                    and hmac.compare_digest(row[2], receipt))

        # A previously verified registration may be retried after its receipt
        # freshness window. The signed attestation was verified again above;
        # only an exact match to the already verified stored record succeeds.
        with sqlite3.connect(self.path, timeout=10) as db:
            existing = existing_matches(db)
        if existing is not None: return existing
        if not self.receipt_verifier(receipt, self.app_id, public_key, timestamp): return False
        with sqlite3.connect(self.path, timeout=10, isolation_level=None) as db:
            db.execute('BEGIN IMMEDIATE')
            # The server may have committed while the response was lost.
            # Replaying the same fully verified attestation is safe only if
            # key, receipt and account binding are exactly the stored values.
            matches = existing_matches(db)
            if matches is not None:
                db.execute('COMMIT' if matches else 'ROLLBACK')
                return matches
            row = db.execute('SELECT purpose,expires FROM attest_challenges WHERE digest=?', (digest,)).fetchone()
            if not row or row[0] != 'attestation' or row[1] <= timestamp:
                db.execute('ROLLBACK'); return False
            try:
                db.execute('INSERT INTO attest_keys VALUES (?,?,0,?)', (key_id, public_key, app_tag))
                db.execute('INSERT INTO attest_receipts VALUES (?,?)', (key_id, receipt))
            except sqlite3.IntegrityError:
                db.execute('ROLLBACK'); return False
            db.execute('DELETE FROM attest_challenges WHERE digest=?', (digest,))
            db.execute('COMMIT'); return True
