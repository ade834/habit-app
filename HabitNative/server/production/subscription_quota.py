"""Daily request quota per subscription. No review text or raw ID is stored."""
import hashlib
import hmac
import sqlite3
import time
from pathlib import Path

class VerifiedSubscriptionAccess:
    """No extra per-day product limit after entitlement verification.

    The app retains its existing per-report cooldowns. Request-rate controls
    remain at the HTTP proxy and do not change the subscription entitlement.
    """
    def reserve(self, subscription_id, now=None):
        return isinstance(subscription_id, str) and 0 < len(subscription_id) <= 255

def purge_expired(path, now=None):
    """Remove old quota rows without needing traffic or the identity secret.

    The database must already exist; a scheduler must invoke this separately.
    """
    day = int(((time.time() if now is None else now) + 8 * 3600) // 86400)
    uri = Path(path).resolve().as_uri() + '?mode=rw'
    with sqlite3.connect(uri, uri=True, timeout=10) as db:
        return db.execute('DELETE FROM subscription_quota WHERE day <= ?', (day - 30,)).rowcount

class SubscriptionQuota:
    def __init__(self, path, secret, limit=3):
        if not isinstance(secret, bytes) or len(secret) < 32 or not isinstance(limit, int) or limit < 1:
            raise ValueError('invalid quota configuration')
        self.path, self.secret, self.limit = str(path), secret, limit
        with sqlite3.connect(self.path, timeout=10) as db:
            db.execute('CREATE TABLE IF NOT EXISTS subscription_quota (identity TEXT NOT NULL, day INTEGER NOT NULL, count INTEGER NOT NULL, PRIMARY KEY(identity, day))')

    def reserve(self, subscription_id, now=None):
        if not isinstance(subscription_id, str) or not subscription_id or len(subscription_id) > 255:
            raise ValueError('invalid subscription identifier')
        identity = hmac.new(self.secret, subscription_id.encode('utf-8'), hashlib.sha256).hexdigest()
        day = int(((time.time() if now is None else now) + 8 * 3600) // 86400)
        with sqlite3.connect(self.path, timeout=10, isolation_level=None) as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT count FROM subscription_quota WHERE identity=? AND day=?', (identity, day)).fetchone()
            if row and row[0] >= self.limit:
                db.execute('ROLLBACK')
                return False
            db.execute('INSERT INTO subscription_quota VALUES (?, ?, 1) ON CONFLICT(identity, day) DO UPDATE SET count=count+1', (identity, day))
            db.execute('DELETE FROM subscription_quota WHERE day <= ?', (day - 30,))
            db.execute('COMMIT')
            return True

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Delete expired subscription quota rows from an existing database.')
    parser.add_argument('database')
    args = parser.parse_args()
    purge_expired(args.database)
