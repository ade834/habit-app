import CloudKit
import Foundation

/// Append-only private CloudKit transport. It is not connected to the app UI yet.
/// The caller commits every fetched page locally before persisting its change token.
actor SyncCloudTransport: SyncTransport {
    enum TransportError: Error {
        case signedOut, accountChanged, revisionCollision, unexpectedDeletion, invalidChangeToken
    }

    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    init(container: CKContainer, zoneName: String = "HabitPrivateRevisionsV1") {
        self.container = container
        self.database = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    func currentAccountID() async throws -> String {
        guard try await container.accountStatus() == .available else { throw TransportError.signedOut }
        return try await container.userRecordID().recordName
    }

    private func requireAccount(_ expected: String) async throws {
        guard try await currentAccountID() == expected else { throw TransportError.accountChanged }
    }

    func ensureZone(account: String) async throws {
        try await requireAccount(account)
        _ = try await database.save(CKRecordZone(zoneID: zoneID))
        try await requireAccount(account)
    }

    func upload(_ envelope: SyncEnvelope, account: String) async throws {
        try await requireAccount(account)
        let record = try SyncCloudRecordCodec.encode(envelope, zoneID: zoneID)
        do {
            _ = try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // A retry of an immutable revision is safe only if the existing content matches.
            guard let server = error.serverRecord,
                  try SyncCloudRecordCodec.decode(server) == envelope else { throw TransportError.revisionCollision }
        }
        try await requireAccount(account)
    }

    func fetchPage(account: String, after token: Data?) async throws -> SyncPage {
        try await requireAccount(account)
        let cloudToken: CKServerChangeToken?
        if let token {
            guard let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: token) else { throw TransportError.invalidChangeToken }
            cloudToken = decoded
        } else {
            cloudToken = nil
        }
        let result: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, any Error>], deletions: [CKDatabase.RecordZoneChange.Deletion], changeToken: CKServerChangeToken, moreComing: Bool)
        do {
            result = try await database.recordZoneChanges(inZoneWith: zoneID, since: cloudToken)
        } catch let error as CKError where error.code == .changeTokenExpired && cloudToken != nil {
            // Replaying immutable revisions is idempotent; never advance the old token
            // before the replacement page has been committed locally.
            return try await fetchPage(account: account, after: nil)
        }
        guard result.deletions.isEmpty else { throw TransportError.unexpectedDeletion }
        let entries = try result.modificationResultsByID.values.map { item in
            try SyncCloudRecordCodec.decode(item.get().record)
        }
        try await requireAccount(account)
        let savedToken = try NSKeyedArchiver.archivedData(withRootObject: result.changeToken, requiringSecureCoding: true)
        return SyncPage(revisions: entries, token: savedToken, moreComing: result.moreComing)
    }
}
