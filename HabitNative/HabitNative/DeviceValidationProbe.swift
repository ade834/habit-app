#if DEBUG
import CloudKit
import CryptoKit
import DeviceCheck
import Foundation
import StoreKit

/// Explicit developer-only launch probe. Never runs in a distribution build.
enum DeviceValidationProbe {
    static func runIfRequested() async {
        guard ProcessInfo.processInfo.environment["MAYBII_VALIDATE_DEVICE"] == "1" else { return }
        if ProcessInfo.processInfo.environment["MAYBII_DELETE_ATTEST_TEST"] == "1" {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("maybii-attest-validation.json")
            if FileManager.default.fileExists(atPath: url.path) { try? FileManager.default.removeItem(at: url) }
            print("MAYBII_VALIDATION attestationFixtureCleaned=\(!FileManager.default.fileExists(atPath: url.path))")
        }
        if ProcessInfo.processInfo.environment["MAYBII_DELETE_SUBSCRIPTION_TEST"] == "1" {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("maybii-subscription-validation.json")
            if FileManager.default.fileExists(atPath: url.path) { try? FileManager.default.removeItem(at: url) }
            print("MAYBII_VALIDATION subscriptionFixtureCleaned=\(!FileManager.default.fileExists(atPath: url.path))")
        }
        print("MAYBII_VALIDATION appAttestSupported=\(DCAppAttestService.shared.isSupported)")
        do {
            let status = try await CKContainer(identifier: "iCloud.com.deshiru.habitnative").accountStatus()
            print("MAYBII_VALIDATION cloudAccountStatus=\(status.rawValue)")
            if status == .available {
                let transport = SyncCloudTransport(container: CKContainer(identifier: "iCloud.com.deshiru.habitnative"))
                let account = try await transport.currentAccountID()
                try await transport.ensureZone(account: account)
                print("MAYBII_VALIDATION cloudPrivateZoneReady=true")
                if ProcessInfo.processInfo.environment["MAYBII_VALIDATE_CLOUD_ROUNDTRIP"] == "1" {
                    try await validateCloudRoundTrip()
                }
                if let action = ProcessInfo.processInfo.environment["MAYBII_SYNC_TEST_ACTION"],
                   let zone = ProcessInfo.processInfo.environment["MAYBII_SYNC_TEST_ZONE"] {
                    try await validateTwoDeviceTransport(action: action, zoneName: zone)
                }
            }
        } catch {
            let errorInfo = error as NSError
            let code = errorInfo.code
            print("MAYBII_VALIDATION cloudErrorDomain=\(errorInfo.domain)")
            print("MAYBII_VALIDATION cloudErrorCode=\(code)")
            if let retry = errorInfo.userInfo[CKErrorRetryAfterKey] as? NSNumber {
                print("MAYBII_VALIDATION cloudRetryAfterSeconds=\(retry.intValue)")
            }
        }
        do {
            let proof = try await AppStoreProof.appTransaction()
            print("MAYBII_VALIDATION verifiedAppTransaction=\(!proof.isEmpty)")
            if let environment = appTransactionEnvironment(proof) {
                print("MAYBII_VALIDATION appTransactionEnvironment=\(environment)")
            }
            if ProcessInfo.processInfo.environment["MAYBII_EXPORT_ATTEST_TEST"] == "1" {
                try await exportAttestationTest(appProof: proof)
            }
            if ProcessInfo.processInfo.environment["MAYBII_EXPORT_SUBSCRIPTION_TEST"] == "1" {
                guard let subscription = await AppStoreProof.activeSubscription() else { throw CloudProbeError.mismatch }
                let data = try JSONEncoder().encode(["app_proof": proof, "subscription_proof": subscription])
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("maybii-subscription-validation.json")
                try data.write(to: url, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                print("MAYBII_VALIDATION subscriptionFixtureReady=true")
            }
        } catch {
            let code = (error as NSError).code
            print("MAYBII_VALIDATION appTransactionErrorCode=\(code)")
        }
        do {
            let products = try await Product.products(for: Array(SubscriptionManager.allProductIDs))
            let ids = Set(products.map(\.id))
            print("MAYBII_VALIDATION sandboxMonthlyAvailable=\(ids.contains(SubscriptionManager.monthlyProductID))")
            print("MAYBII_VALIDATION sandboxYearlyAvailable=\(ids.contains(SubscriptionManager.yearlyProductID))")
        } catch {
            let code = (error as NSError).code
            print("MAYBII_VALIDATION sandboxProductsErrorCode=\(code)")
        }
        var hasVerifiedMonthly = false
        var hasVerifiedYearly = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true else { continue }
            if transaction.productID == SubscriptionManager.monthlyProductID {
                hasVerifiedMonthly = true
                print("MAYBII_VALIDATION monthlyTransactionEnvironment=\(transaction.environment.rawValue)")
            }
            if transaction.productID == SubscriptionManager.yearlyProductID {
                hasVerifiedYearly = true
                print("MAYBII_VALIDATION yearlyTransactionEnvironment=\(transaction.environment.rawValue)")
            }
        }
        print("MAYBII_VALIDATION verifiedMonthlyEntitlement=\(hasVerifiedMonthly)")
        print("MAYBII_VALIDATION verifiedYearlyEntitlement=\(hasVerifiedYearly)")
        var verifiedMonthlyHistory = 0
        var verifiedYearlyHistory = 0
        var latestExpiration: Date?
        var unverifiedTransactions = 0
        for await result in Transaction.all {
            switch result {
            case .verified(let transaction):
                if transaction.productID == SubscriptionManager.monthlyProductID { verifiedMonthlyHistory += 1 }
                if transaction.productID == SubscriptionManager.yearlyProductID { verifiedYearlyHistory += 1 }
                if [SubscriptionManager.monthlyProductID, SubscriptionManager.yearlyProductID].contains(transaction.productID),
                   let expiration = transaction.expirationDate, expiration > (latestExpiration ?? .distantPast) {
                    latestExpiration = expiration
                }
            case .unverified:
                unverifiedTransactions += 1
            }
        }
        print("MAYBII_VALIDATION verifiedMonthlyHistoryCount=\(verifiedMonthlyHistory)")
        print("MAYBII_VALIDATION verifiedYearlyHistoryCount=\(verifiedYearlyHistory)")
        print("MAYBII_VALIDATION latestSubscriptionExpired=\(latestExpiration.map { $0 <= Date() } ?? false)")
        print("MAYBII_VALIDATION unverifiedTransactionCount=\(unverifiedTransactions)")
        print("MAYBII_VALIDATION finished")
    }

    /// Uses an isolated, randomly named test zone containing no user content.
    /// Remove only the zone created by this run.
    private static func validateCloudRoundTrip() async throws {
        let database = CKContainer(identifier: "iCloud.com.deshiru.habitnative").privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "MAYBII-validation-" + UUID().uuidString, ownerName: CKCurrentUserDefaultName)
        var created = false
        do {
            _ = try await database.save(CKRecordZone(zoneID: zoneID))
            created = true
            print("MAYBII_VALIDATION cloudProbeZoneCreated=true")
            let record = CKRecord(recordType: "HabitRevision", recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
            let value = Data(UUID().uuidString.utf8)
            record.encryptedValues["encryptedPayload"] = value as NSData
            _ = try await database.save(record)
            print("MAYBII_VALIDATION cloudProbeRecordSaved=true")
            let downloaded = try await database.record(for: record.recordID)
            guard downloaded.encryptedValues["encryptedPayload"] as? Data == value else { throw CloudProbeError.mismatch }
            print("MAYBII_VALIDATION cloudProbeRecordRead=true")
            _ = try await database.deleteRecordZone(withID: zoneID)
            created = false
            print("MAYBII_VALIDATION cloudEncryptedRoundTrip=true")
        } catch {
            if created {
                do { _ = try await database.deleteRecordZone(withID: zoneID) }
                catch { print("MAYBII_VALIDATION cloudProbeCleanupFailed=true") }
                print("MAYBII_VALIDATION cloudProbeCleanupAttempted=true")
            }
            throw error
        }
    }

    private enum CloudProbeError: Error { case mismatch }

    private static func appTransactionEnvironment(_ proof: String) -> String? {
        let pieces = proof.split(separator: ".")
        guard pieces.count == 3 else { return nil }
        var encoded = String(pieces[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let environment = object["receiptType"] as? String,
              ["Xcode", "Sandbox", "Production"].contains(environment) else { return nil }
        return environment
    }

    private static func exportAttestationTest(appProof: String) async throws {
        guard let challenge = ProcessInfo.processInfo.environment["MAYBII_ATTEST_TEST_CHALLENGE"],
              let assertionChallenge = ProcessInfo.processInfo.environment["MAYBII_ASSERTION_TEST_CHALLENGE"],
              !challenge.isEmpty, !assertionChallenge.isEmpty else { throw CloudProbeError.mismatch }
        func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let keyID = try await DCAppAttestService.shared.generateKey()
        let enrollment = try encoder.encode(["challenge": challenge, "appProofSHA256": digest(Data(appProof.utf8))])
        let attestation = try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: enrollment)))
        let body = try encoder.encode(["period": "week", "language": "zh-Hans", "report": "合成测试：本周完成两次散步。"])
        let subscription: String
        if ProcessInfo.processInfo.environment["MAYBII_ATTEST_INCLUDE_SUBSCRIPTION"] == "1" {
            guard let proof = await AppStoreProof.activeSubscription() else { throw CloudProbeError.mismatch }
            subscription = proof
        } else { subscription = "" }
        let assertionInput = try encoder.encode(["challenge": assertionChallenge, "keyId": keyID,
            "bodySHA256": digest(body), "subscriptionProofSHA256": digest(Data(subscription.utf8)), "appProofSHA256": digest(Data(appProof.utf8))])
        let assertion = try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: assertionInput)))
        let output = try encoder.encode(["key_id": keyID, "challenge": challenge, "app_proof": appProof,
            "attestation": attestation.base64EncodedString(), "assertion": assertion.base64EncodedString(),
            "assertion_challenge": assertionChallenge, "body": body.base64EncodedString(), "subscription_proof": subscription])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("maybii-attest-validation.json")
        try output.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        print("MAYBII_VALIDATION attestationFixtureReady=true")
    }

    /// Explicit debug-only probe. It uses synthetic data in a uniquely named
    /// private zone and a disposable journal, never the user's app database.
    private static func validateTwoDeviceTransport(action: String, zoneName: String) async throws {
        let prefix = "MAYBII-two-device-"
        guard zoneName.hasPrefix(prefix), UUID(uuidString: String(zoneName.dropFirst(prefix.count))) != nil,
              ["ipad-write", "iphone-reply", "ipad-read", "cleanup"].contains(action) else { throw CloudProbeError.mismatch }
        let container = CKContainer(identifier: "iCloud.com.deshiru.habitnative")
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        if action == "cleanup" {
            _ = try await container.privateCloudDatabase.deleteRecordZone(withID: zoneID)
            print("MAYBII_VALIDATION twoDeviceZoneCleaned=true")
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("maybii-cloud-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SyncRevisionStore(url: directory.appendingPathComponent("journal.sqlite"))
        let transport = SyncCloudTransport(container: container, zoneName: zoneName)
        let coordinator = SyncCoordinator(store: store, transport: transport)
        let account = try await transport.currentAccountID()
        try await coordinator.fetchRemote(account: account)
        if action == "iphone-reply" || action == "ipad-read" {
            let entity = action == "iphone-reply" ? "test/ipad" : "test/iphone"
            let value = action == "iphone-reply" ? "ipad-to-iphone" : "iphone-to-ipad"
            let frontier = try store.frontier(account: account, entity: entity)
            guard frontier.count == 1, frontier[0].value == Data(value.utf8) else { throw CloudProbeError.mismatch }
            print("MAYBII_VALIDATION \(action == "iphone-reply" ? "ipadToIphone" : "iphoneToIpad")=true")
        }
        if action != "ipad-read" {
            let isIpad = action == "ipad-write"
            _ = try store.stage(account: account, entity: isIpad ? "test/ipad" : "test/iphone", device: isIpad ? "ipad" : "iphone",
                                value: Data((isIpad ? "ipad-to-iphone" : "iphone-to-ipad").utf8), observedFrontier: [])
            try await coordinator.uploadPending(account: account)
            print("MAYBII_VALIDATION \(isIpad ? "ipadTestUploaded" : "iphoneTestUploaded")=true")
        }
    }
}
#endif
