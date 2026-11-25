"""Unpublished composition of app proof, device assertion and AI quotas.

No HTTP endpoints use this yet. Real Apple device/StoreKit testing and a review
of free-trial retention and reset semantics are required before it is enabled.
"""
from dataclasses import dataclass
import hashlib
import hmac
import json
import uuid


@dataclass(frozen=True)
class Reservation:
    kind: str
    app_transaction_id: str = ''
    token: str = ''


class ReviewAuthorization:
    def __init__(self, apps, subscriptions, assertions, paid_quota, trial_quota, secret):
        if not isinstance(secret, bytes) or len(secret) < 32:
            raise ValueError('invalid device binding secret')
        self.apps, self.subscriptions, self.assertions = apps, subscriptions, assertions
        self.paid_quota, self.trial_quota, self.secret = paid_quota, trial_quota, secret

    def reserve(self, *, app_proof, subscription_proof, key_id, assertion, challenge, body):
        if not isinstance(body, bytes) or len(body) > 128 * 1024:
            return None
        try:
            document = json.loads(body)
            period = document.get('period') if isinstance(document, dict) else None
        except (ValueError, UnicodeDecodeError):
            return None
        if period not in ('week', 'month'):
            return None
        app_id = self.apps.verified_app_transaction_id(app_proof)
        if not app_id:
            return None
        # A supplied paid proof must verify; it must never silently fall back to
        # free access when Apple verification fails or the subscription expires.
        subscription_id = None
        if subscription_proof:
            subscription_id = self.subscriptions.verified_subscription_id(subscription_proof, app_id)
            if not subscription_id:
                return None
        elif period != 'week':
            return None
        tag = hmac.new(self.secret, ('app:' + app_id).encode('utf-8'), hashlib.sha256).hexdigest()
        if not self.assertions.verify_and_consume(key_id, assertion, challenge, body, tag,
                                                  subscription_proof, app_proof):
            return None
        if subscription_id:
            return Reservation('paid') if self.paid_quota.reserve(subscription_id) else None
        token = self.trial_quota.reserve(app_id)
        return Reservation('trial', app_id, token) if token else None

    def reset_trial(self, *, app_proof, subscription_proof, key_id, assertion, challenge, body):
        # Bind resets to a distinct signed action, never to a review request.
        if not isinstance(body, bytes) or len(body) > 1024 or subscription_proof:
            return False
        try:
            document = json.loads(body)
            if not isinstance(document, dict) or set(document) != {'action', 'generation'} or document['action'] != 'clear-local-data':
                return False
            generation = document['generation']
            if not isinstance(generation, str) or str(uuid.UUID(generation)) != generation.lower():
                return False
            generation = generation.lower()
        except (ValueError, UnicodeDecodeError, AttributeError):
            return False
        app_id = self.apps.verified_app_transaction_id(app_proof)
        if not app_id:
            return False
        tag = hmac.new(self.secret, ('app:' + app_id).encode('utf-8'), hashlib.sha256).hexdigest()
        if not self.assertions.verify_and_consume(key_id, assertion, challenge, body, tag, '', app_proof):
            return False
        self.trial_quota.reset_after_data_clear(app_id, generation)
        return True

    def finish(self, reservation, success):
        if reservation.kind == 'trial':
            self.trial_quota.finish(reservation.app_transaction_id, reservation.token, bool(success))
