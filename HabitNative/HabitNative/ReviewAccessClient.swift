import Foundation
import DeviceCheck

/// Obtains request-bound App Attest proof for the review service. No Apple login.
enum ReviewAccessClient {
    private static let base = URL(string: "https://api.ddream.top")!
    private struct Challenge: Decodable { let challenge: String }
    private struct Registration: Decodable { let registered: Bool }
    private struct ResetResult: Decodable { let reset: Bool }
    private enum AccessError: Error { case invalidResponse, registrationFailed, httpStatus(Int) }
    private static var enrollmentInFlight: Task<Void, Error>?

    private static func send<T: Decodable>(_ path: String, body: Data, headers: [String: String] = [:]) async throws -> T {
        var request = URLRequest(url: base.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = body
        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AccessError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw AccessError.httpStatus(response.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func challenge(_ purpose: String) async throws -> String {
        let body = try JSONEncoder().encode(["purpose": purpose])
        let response: Challenge = try await send("/api/attest/challenge", body: body)
        return response.challenge
    }

    private static func enroll(appProof: String) async throws {
        if let existing = enrollmentInFlight { return try await existing.value }
        let task = Task { try await performEnrollment(appProof: appProof) }
        enrollmentInFlight = task
        defer { enrollmentInFlight = nil }
        try await task.value
    }

    private static func performEnrollment(appProof: String) async throws {
        var pending: AppAttestProof.PendingEnrollment
        if let saved = try AppAttestProof.loadPendingEnrollment() {
            pending = saved
        } else {
            pending = .init(challenge: try await challenge("attestation"), appProof: appProof, keyID: nil, attestation: nil)
            try AppAttestProof.savePendingEnrollment(pending)
        }
        if pending.keyID == nil && pending.attestation == nil {
            do {
                let material = try await AppAttestProof.createAttestation(challenge: pending.challenge, appProof: pending.appProof)
                pending.keyID = material.keyID
                pending.attestation = material.data
                try AppAttestProof.savePendingEnrollment(pending)
            } catch let error as DCError where error.code != .serverUnavailable {
                try AppAttestProof.discardPendingEnrollment()
                throw error
            }
        }
        guard let keyID = pending.keyID, let attestation = pending.attestation else {
            try AppAttestProof.discardPendingEnrollment()
            throw AccessError.invalidResponse
        }
        let body = try JSONEncoder().encode(["key_id": keyID, "challenge": pending.challenge,
                                              "app_proof": pending.appProof, "attestation": attestation.base64EncodedString()])
        do {
            let response: Registration = try await send("/api/attest/register", body: body)
            guard response.registered else {
                try AppAttestProof.discardPendingEnrollment()
                throw AccessError.registrationFailed
            }
            try AppAttestProof.saveEnrolledKey(keyID)
        } catch AccessError.httpStatus(let code) where code == 400 || code == 401 {
            try AppAttestProof.discardPendingEnrollment()
            throw AccessError.registrationFailed
        }
    }

    static func headers(for body: Data, includeSubscription: Bool = true) async throws -> [String: String] {
        let appProof = try await AppStoreProof.appTransaction()
        let subscription = includeSubscription ? (await AppStoreProof.activeSubscription() ?? "") : ""
        var nonce = try await challenge("assertion")
        var material: AppAttestProof.Material
        do {
            material = try await AppAttestProof.createAssertion(challenge: nonce, body: body, subscriptionProof: subscription, appProof: appProof)
        } catch AppAttestProof.ProofError.keyMissing {
            try await enroll(appProof: appProof)
            nonce = try await challenge("assertion")
            material = try await AppAttestProof.createAssertion(challenge: nonce, body: body, subscriptionProof: subscription, appProof: appProof)
        }
        return ["X-App-Transaction": appProof, "X-StoreKit-Transaction": subscription,
                "X-App-Attest-Key": material.keyID, "X-App-Attest-Assertion": material.data.base64EncodedString(),
                "X-App-Attest-Challenge": nonce]
    }

    /// Clear the exact generation only after the server confirms it. A later
    /// local clear is committed together with its new generation in SQLite.
    @MainActor
    static func completePendingTrialReset() async throws {
        let database = NativeDatabase()
        // Migrate pending markers from pre-transactional builds.
        let defaults = UserDefaults.standard
        let oldKey = "review.ai.trial-reset-pending.v1"
        if defaults.object(forKey: oldKey) != nil {
            try database.withConnection { db in
                try NativeDatabase.execute("INSERT OR IGNORE INTO native_metadata(key,value) VALUES ('ai_trial_reset_pending', ?)", bindings: [UUID().uuidString], in: db)
            }
            defaults.removeObject(forKey: oldKey)
        }
        while let generation = try database.pendingAITrialReset() {
            try await resetTrial(generation: generation)
            try database.acknowledgeAITrialReset(generation)
        }
    }

    static func resetTrial(generation: String) async throws {
        let body = try JSONEncoder().encode(["action": "clear-local-data", "generation": generation])
        let headers = try await headers(for: body, includeSubscription: false)
        let result: ResetResult = try await send("/api/review/reset-trial", body: body, headers: headers)
        guard result.reset else { throw AccessError.invalidResponse }
    }
}
