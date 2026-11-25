"""Single-use, short-lived challenges for the unpublished App Attest prototype."""
import hashlib
import secrets
import sqlite3
import time

class AttestChallenges:
    TTL = 120
    def __init__(self, path):
        self.path = str(path)
        with sqlite3.connect(self.path, timeout=10) as db:
            db.execute('CREATE TABLE IF NOT EXISTS attest_challenges (digest TEXT PRIMARY KEY, purpose TEXT NOT NULL, expires INTEGER NOT NULL)')
    def issue(self, purpose, now=None):
        if purpose not in ('attestation', 'assertion'):
            raise ValueError('invalid challenge purpose')
        timestamp = int(time.time() if now is None else now)
        value = secrets.token_urlsafe(32)
        digest = hashlib.sha256(value.encode('ascii')).hexdigest()
        with sqlite3.connect(self.path, timeout=10, isolation_level=None) as db:
            db.execute('BEGIN IMMEDIATE')
            db.execute('DELETE FROM attest_challenges WHERE expires <= ?', (timestamp,))
            if db.execute('SELECT count(*) FROM attest_challenges').fetchone()[0] >= 10000:
                db.execute('ROLLBACK'); raise ValueError('challenge capacity reached')
            db.execute('INSERT INTO attest_challenges VALUES (?,?,?)', (digest, purpose, timestamp + self.TTL))
            db.execute('COMMIT')
        return value
    def consume(self, value, purpose, now=None):
        if not isinstance(value, str) or len(value) > 128 or purpose not in ('attestation', 'assertion'):
            return False
        try: digest = hashlib.sha256(value.encode('ascii')).hexdigest()
        except UnicodeEncodeError: return False
        timestamp = int(time.time() if now is None else now)
        with sqlite3.connect(self.path, timeout=10, isolation_level=None) as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT purpose,expires FROM attest_challenges WHERE digest=?', (digest,)).fetchone()
            if not row or row[0] != purpose or row[1] <= timestamp:
                db.execute('ROLLBACK'); return False
            db.execute('DELETE FROM attest_challenges WHERE digest=?', (digest,))
            db.execute('COMMIT'); return True
