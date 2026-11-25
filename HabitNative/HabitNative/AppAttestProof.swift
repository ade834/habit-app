import CryptoKit
import DeviceCheck
import Foundation
import Security

/// Unpublished building block. Server enrollment, receipt validation and real-device
/// verification must be completed before this is attached to AI requests.
enum AppAttestProof {
    enum ProofError: Error {
        case unsupported, keyMissing, keyStorage, invalidChallenge, invalidRequest
    }

    struct Material {
        let keyID: String
        let data: Data
    }

    struct PendingEnrollment: Codable {
        let challenge: String
        let appProof: String
        var keyID: String?
        var attestation: Data?
    }

    private static let keychainQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.deshiru.habitnative.app-attest",
        kSecAttrAccount as String: "key-id"
    ]

    static var isSupported: Bool { DCAppAttestService.shared.isSupported }

    private static var pendingQuery: [String: Any] {
        var query = keychainQuery
        query[kSecAttrAccount as String] = "pending-key-id"
        return query
    }

    private static var pendingEnrollmentQuery: [String: Any] {
        var query = keychainQuery
        query[kSecAttrAccount as String] = "pending-enrollment"
        return query
    }

    private static func storedKeyID(query: [String: Any]) -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func saveKey(_ keyID: String, query: [String: Any]) throws {
        guard let data = keyID.data(using: .utf8), !data.isEmpty else { throw ProofError.keyStorage }
        let result = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if result == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw ProofError.keyStorage }
        } else if result != errSecSuccess { throw ProofError.keyStorage }
    }

    static func loadPendingEnrollment() throws -> PendingEnrollment? {
        guard let encoded = storedKeyID(query: pendingEnrollmentQuery) else { return nil }
        guard let data = Data(base64Encoded: encoded),
              let pending = try? JSONDecoder().decode(PendingEnrollment.self, from: data) else {
            try discardPendingEnrollment()
            return nil
        }
        return pending
    }

    static func savePendingEnrollment(_ value: PendingEnrollment) throws {
        let data = try JSONEncoder().encode(value)
        try saveKey(data.base64EncodedString(), query: pendingEnrollmentQuery)
    }

    static func discardPendingEnrollment() throws {
        for query in [pendingQuery, pendingEnrollmentQuery] {
            let result = SecItemDelete(query as CFDictionary)
            guard result == errSecSuccess || result == errSecItemNotFound else { throw ProofError.keyStorage }
        }
    }

    /// Call only after the server confirms that it verified and stored the key.
    static func saveEnrolledKey(_ keyID: String) throws {
        guard storedKeyID(query: pendingQuery) == keyID else { throw ProofError.keyStorage }
        try saveKey(keyID, query: keychainQuery)
        try discardPendingEnrollment()
    }

    static func createAttestation(challenge: String, appProof: String) async throws -> Material {
        guard isSupported else { throw ProofError.unsupported }
        guard !challenge.isEmpty, challenge.utf8.count <= 128, challenge.utf8.allSatisfy({ $0 < 128 }) else { throw ProofError.invalidChallenge }
        guard !appProof.isEmpty, appProof.utf8.count <= 16384 else { throw ProofError.invalidRequest }
        let service = DCAppAttestService.shared
        let keyID: String
        if let pending = storedKeyID(query: pendingQuery) {
            keyID = pending
        } else {
            keyID = try await service.generateKey()
            try saveKey(keyID, query: pendingQuery)
        }
        let proofDigest = SHA256.hash(data: Data(appProof.utf8)).map { String(format: "%02x", $0) }.joined()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let clientData = try encoder.encode(["challenge": challenge, "appProofSHA256": proofDigest])
        let hash = Data(SHA256.hash(data: clientData))
        let attestation = try await service.attestKey(keyID, clientDataHash: hash)
        return Material(keyID: keyID, data: attestation)
    }

    static func createAssertion(challenge: String, body: Data, subscriptionProof: String, appProof: String) async throws -> Material {
        guard isSupported else { throw ProofError.unsupported }
        guard let keyID = storedKeyID(query: keychainQuery) else { throw ProofError.keyMissing }
        guard !challenge.isEmpty, challenge.utf8.count <= 128, challenge.utf8.allSatisfy({ $0 < 128 }) else { throw ProofError.invalidChallenge }
        guard keyID.utf8.allSatisfy({ $0 < 128 }) else { throw ProofError.invalidRequest }
        func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        let data: [String: String] = [
            "challenge": challenge,
            "keyId": keyID,
            "bodySHA256": digest(body),
            "subscriptionProofSHA256": digest(Data(subscriptionProof.utf8)),
            "appProofSHA256": digest(Data(appProof.utf8))
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let clientData = try encoder.encode(data)
        let hash = Data(SHA256.hash(data: clientData))
        let assertion = try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: hash)
        return Material(keyID: keyID, data: assertion)
    }
}
