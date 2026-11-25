"""Verify App Store app-download proof for an account-free trial prototype."""
class TrialVerifier:
    def __init__(self, signed_verifier):
        self.verifier = signed_verifier

    def verified_app_transaction_id(self, signed_app_transaction):
        if not isinstance(signed_app_transaction, str) or not 1 <= len(signed_app_transaction) <= 16384:
            return None
        # Apple's verifier checks signature, bundle ID, App Apple ID and environment.
        app_transaction = self.verifier.verify_and_decode_app_transaction(signed_app_transaction)
        identifier = app_transaction.appTransactionId
        if not isinstance(identifier, str) or not 1 <= len(identifier) <= 255:
            return None
        return identifier
