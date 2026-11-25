import Foundation
import StoreKit

/// Unpublished proof helpers. Server binding and trial privacy handling are not yet complete.
enum AppStoreProof {
    enum ProofError: Error { case unverified }

    static func appTransaction() async throws -> String {
        let result = try await AppTransaction.shared
        guard case .verified = result else { throw ProofError.unverified }
        return result.jwsRepresentation
    }

    static func activeSubscription() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  SubscriptionManager.allProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            return result.jwsRepresentation
        }
        return nil
    }
}
