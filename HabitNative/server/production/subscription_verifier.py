"""Verify the signed StoreKit transaction and current status without app login.

The verifier and Apple API client are created by the production entry point. The
caller must fail closed on exceptions and must never log signed transactions.
"""
from appstoreserverlibrary.models.Status import Status

PRODUCTS = frozenset(('com.habitnative.subscription.monthly', 'com.habitnative.subscription.yearly'))

class SubscriptionVerifier:
    def __init__(self, signed_verifier, api_client):
        self.verifier = signed_verifier
        self.client = api_client

    def verified_subscription_id(self, signed_transaction, expected_app_transaction_id=None):
        if not isinstance(signed_transaction, str) or not 1 <= len(signed_transaction) <= 16384:
            return None
        if not isinstance(expected_app_transaction_id, str) or not 1 <= len(expected_app_transaction_id) <= 255:
            return None
        original = self.verifier.verify_and_decode_signed_transaction(signed_transaction)
        if (original.productId not in PRODUCTS or not original.originalTransactionId or original.revocationDate is not None
                or original.appTransactionId != expected_app_transaction_id):
            return None
        status_response = self.client.get_all_subscription_statuses(original.originalTransactionId)
        for group in status_response.data or []:
            for item in group.lastTransactions or []:
                if item.status not in (Status.ACTIVE, Status.BILLING_GRACE_PERIOD) or not item.signedTransactionInfo:
                    continue
                current = self.verifier.verify_and_decode_signed_transaction(item.signedTransactionInfo)
                if (current.originalTransactionId == original.originalTransactionId and
                    current.productId in PRODUCTS and current.revocationDate is None):
                    return str(current.originalTransactionId)
        return None

    def is_entitled(self, signed_transaction, expected_app_transaction_id=None):
        return self.verified_subscription_id(signed_transaction, expected_app_transaction_id) is not None
