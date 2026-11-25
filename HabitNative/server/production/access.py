"""Server-only access control. Tokens are individually issued; never ship one in App."""
import hashlib
import secrets
import sqlite3
import time

class Access:
    def __init__(self, path):
        self.path = str(path)
        with self.connect() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS users (
                  id TEXT PRIMARY KEY, token_hash TEXT UNIQUE NOT NULL,
                  daily_limit INTEGER NOT NULL CHECK(daily_limit > 0),
                  enabled INTEGER NOT NULL DEFAULT 1, expires INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS usage (
                  user_id TEXT, day INTEGER, count INTEGER NOT NULL,
                  PRIMARY KEY(user_id, day));
            ''')
            columns = {row[1] for row in db.execute('PRAGMA table_info(users)')}
            if 'expires' not in columns:
                db.execute('ALTER TABLE users ADD COLUMN expires INTEGER NOT NULL DEFAULT 0')
    def connect(self):
        return sqlite3.connect(self.path, timeout=10)
    def issue(self, user_id, daily_limit=10):
        token = secrets.token_urlsafe(32)
        with self.connect() as db:
            existing = db.execute('SELECT enabled FROM users WHERE id=?', (user_id,)).fetchone()
            if existing and not existing[0]:
                raise ValueError('account_disabled')
            db.execute('INSERT INTO users VALUES (?,?,?,1,?) ON CONFLICT(id) DO UPDATE SET token_hash=excluded.token_hash, expires=excluded.expires',
                       (user_id, self.digest(token), daily_limit, int(time.time()) + 604800))
        return token
    @staticmethod
    def digest(token):
        return hashlib.sha256(token.encode()).hexdigest()

    def consume(self, authorization):
        if not authorization.startswith('Bearer ') or len(authorization) > 200:
            return 401
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT id,daily_limit FROM users WHERE token_hash=? AND enabled=1 AND expires>?',
                             (self.digest(authorization[7:]), int(time.time()))).fetchone()
            if not row:
                return 401
            user_id, limit = row
            # Calendar day in China Standard Time. Reserve before calling paid API.
            day = int((time.time() + 8 * 3600) // 86400)
            count = db.execute('SELECT count FROM usage WHERE user_id=? AND day=?', (user_id, day)).fetchone()
            if count and count[0] >= limit:
                return 429
            db.execute('INSERT INTO usage VALUES (?,?,1) ON CONFLICT(user_id,day) DO UPDATE SET count=count+1', (user_id, day))
            db.execute('DELETE FROM usage WHERE day < ?', (day - 35,))
        return 200
