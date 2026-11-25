"""Apple ID token verification; no Apple private signing key needed for this step."""
import hashlib
import secrets
import time
import jwt

class AppleAuth:
    def __init__(self, access, audience, keys=None):
        self.access = access
        self.audience = audience
        self.keys = keys or jwt.PyJWKClient('https://appleid.apple.com/auth/keys', cache_jwk_set=True, lifespan=3600, timeout=5)
        with access.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS challenges (id TEXT PRIMARY KEY, nonce TEXT NOT NULL, expires INTEGER NOT NULL)')
    def challenge(self):
        challenge_id = secrets.token_urlsafe(32)
        nonce = hashlib.sha256(secrets.token_bytes(32)).hexdigest()
        with self.access.connect() as db:
            db.execute('DELETE FROM challenges WHERE expires < ?', (int(time.time()),))
            if db.execute('SELECT count(*) FROM challenges').fetchone()[0] >= 1000:
                raise ValueError('challenge_capacity')
            db.execute('INSERT INTO challenges VALUES (?,?,?)', (challenge_id, nonce, int(time.time()) + 300))
        return {'challenge_id': challenge_id, 'nonce': nonce}
    def exchange(self, challenge_id, identity_token):
        key = self.keys.get_signing_key_from_jwt(identity_token).key
        claims = jwt.decode(identity_token, key, algorithms=['RS256'], audience=self.audience,
                            issuer='https://appleid.apple.com',
                            options={'require': ['exp', 'iat', 'iss', 'aud', 'sub', 'nonce']})
        with self.access.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT nonce,expires FROM challenges WHERE id=?', (challenge_id,)).fetchone()
            if not row or row[1] < time.time() or not secrets.compare_digest(row[0], claims['nonce']):
                raise ValueError('invalid_challenge')
            db.execute('DELETE FROM challenges WHERE id=?', (challenge_id,))
        subject = claims['sub']
        if not isinstance(subject, str) or not subject or len(subject) > 255:
            raise ValueError('invalid_subject')
        return {'token': self.access.issue('apple:' + subject), 'expires_at': int(time.time()) + 604800}
