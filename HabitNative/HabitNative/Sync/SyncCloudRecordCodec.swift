import CloudKit
import CryptoKit
import Foundation

/// The key identifies a logical item inside the encrypted payload, never the record name.
nonisolated struct SyncEnvelope: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let entityKey: String
    let revision: SyncRevision
}

nonisolated enum SyncCloudRecordCodec {
    static let recordType = "HabitRevision"
    private static let payloadKey = "encryptedPayload"

    enum Error: Swift.Error {
        case missingPayload, unsupportedSchema, recordIdentityMismatch
    }

    static func recordID(for revisionID: String, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        let hash = SHA256.hash(data: Data(revisionID.utf8)).map { String(format: "%02x", $0) }.joined()
        return CKRecord.ID(recordName: hash, zoneID: zoneID)
    }

    static func encode(_ envelope: SyncEnvelope, zoneID: CKRecordZone.ID) throws -> CKRecord {
        guard envelope.schemaVersion == 1 else { throw Error.unsupportedSchema }
        let record = CKRecord(recordType: recordType, recordID: recordID(for: envelope.revision.revisionID, zoneID: zoneID))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        record.encryptedValues[payloadKey] = try encoder.encode(envelope) as NSData
        return record
    }

    static func decode(_ record: CKRecord) throws -> SyncEnvelope {
        guard record.recordType == recordType,
              let payload = record.encryptedValues[payloadKey] as? Data else { throw Error.missingPayload }
        let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: payload)
        guard envelope.schemaVersion == 1 else { throw Error.unsupportedSchema }
        guard record.recordID == recordID(for: envelope.revision.revisionID, zoneID: record.recordID.zoneID) else {
            throw Error.recordIdentityMismatch
        }
        return envelope
    }
}
