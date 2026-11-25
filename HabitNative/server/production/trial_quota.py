"""Prototype: one completed free review per App Store app transaction.

Only keyed hashes and trial state are persisted. A successful trial marker has no
automatic expiry; it requires disclosure and a supported deletion process before
release. Pending reservations expire so an interrupted request is retryable.
"""
import hashlib
import hmac
import secrets
import sqlite3
import time

class TrialQuota:
    PENDING_SECONDS = 600
    def __init__(self, path, secret):
        if not isinstance(secret, bytes) or len(secret) < 32:
            raise ValueError('invalid trial secret')
        self.path, self.secret = str(path), secret
        with sqlite3.connect(self.path, timeout=10) as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS trial_usage (identity TEXT PRIMARY KEY, used INTEGER NOT NULL, pending TEXT, pending_at INTEGER);
                CREATE TABLE IF NOT EXISTS trial_resets (identity TEXT NOT NULL, generation TEXT NOT NULL, PRIMARY KEY(identity, generation));
            ''')
    def _identity(self, app_transaction_id):
        if not isinstance(app_transaction_id, str) or not app_transaction_id or len(app_transaction_id) > 255:
            raise ValueError('invalid app transaction identifier')
        return hmac.new(self.secret, ('trial:' + app_transaction_id).encode(), hashlib.sha256).hexdigest()
    def reserve(self, app_transaction_id, now=None):
        identity = self._identity(app_transaction_id)
        timestamp = int(time.time() if now is None else now)
        with sqlite3.connect(self.path, timeout=10, isolation_level=None) as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT used,pending,pending_at FROM trial_usage WHERE identity=?', (identity,)).fetchone()
            if row and (row[0] or (row[1] and row[2] is not None and timestamp - row[2] < self.PENDING_SECONDS)):
                db.execute('ROLLBACK'); return None
            token = secrets.token_urlsafe(32)
            db.execute('INSERT INTO trial_usage VALUES (?,0,?,?) ON CONFLICT(identity) DO UPDATE SET pending=excluded.pending,pending_at=excluded.pending_at', (identity, token, timestamp))
            db.execute('COMMIT'); return token
    def reset_after_data_clear(self, app_transaction_id, generation):
        """Reset a verified user's trial after clearing local data.

        The caller must authenticate the clear request and verify the app proof.
        Removing the reservation invalidates completion of any in-flight request.
        """
        identity = self._identity(app_transaction_id)
        if not isinstance(generation, str) or not generation or len(generation) > 64:
            raise ValueError('invalid reset generation')
        with sqlite3.connect(self.path, timeout=10, isolation_level=None) as db:
            db.execute('BEGIN IMMEDIATE')
            inserted = db.execute('INSERT OR IGNORE INTO trial_resets VALUES (?,?)', (identity, generation)).rowcount
            if inserted:
                db.execute('DELETE FROM trial_usage WHERE identity=?', (identity,))
            db.execute('COMMIT')

    def finish(self, app_transaction_id, token, success):
        identity = self._identity(app_transaction_id)
        with sqlite3.connect(self.path, timeout=10) as db:
            db.execute('UPDATE trial_usage SET used=?, pending=NULL, pending_at=NULL WHERE identity=? AND pending=? AND used=0',
                       (1 if success else 0, identity, token))
