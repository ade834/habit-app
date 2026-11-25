import CloudKit
import Foundation

@main struct SyncCloudCodecTests {
    static func main() throws {
        let zone = CKRecordZone.ID(zoneName: "test", ownerName: CKCurrentUserDefaultName)
        let revision = SyncRevision(revisionID: "device-random-uuid-1", version: SyncVersion(counters: ["device": 1]), value: Data("private text".utf8))
        let envelope = SyncEnvelope(schemaVersion: 1, entityKey: "review:2026-10-31", revision: revision)
        let encoded = try SyncCloudRecordCodec.encode(envelope, zoneID: zone)
        precondition(!encoded.recordID.recordName.contains("private"))
        precondition(!encoded.recordID.recordName.contains("review"))
        precondition(encoded["encryptedPayload"] == nil)
        let decoded = try SyncCloudRecordCodec.decode(encoded)
        precondition(decoded == envelope)
        let other = CKRecord(recordType: SyncCloudRecordCodec.recordType, recordID: CKRecord.ID(recordName: "wrong", zoneID: zone))
        other.encryptedValues["encryptedPayload"] = try JSONEncoder().encode(envelope) as NSData
        do { _ = try SyncCloudRecordCodec.decode(other); fatalError("wrong ID accepted") }
        catch SyncCloudRecordCodec.Error.recordIdentityMismatch { }
        print("PASS: encrypted-field encoding, round-trip and identity validation")
    }
}
