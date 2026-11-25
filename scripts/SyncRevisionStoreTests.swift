import Foundation

@main struct SyncRevisionStoreTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("journal.sqlite")
        let a = try SyncRevisionStore(url: url)
        let first = try a.stage(account: "account-a", entity: "review", device: "a", value: Data("one".utf8))
        let remote = SyncEnvelope(schemaVersion: 1, entityKey: "review", revision: SyncRevision(revisionID: "remote", version: SyncVersion(counters: ["b": 1]), value: Data("two".utf8)))
        try a.ingest(account: "account-a", envelope: remote)
        try a.ingest(account: "account-a", envelope: remote)
        let conflict = try a.frontier(account: "account-a", entity: "review")
        precondition(conflict.count == 2)
        let pendingBefore = try a.pending(account: "account-a")
        precondition(pendingBefore == [first])
        let otherAccount = try a.pending(account: "account-b")
        precondition(otherAccount.isEmpty)
        do { _ = try a.stage(account: "account-a", entity: "review", device: "a", value: Data("accidental".utf8)); fatalError("unresolved conflict was overwritten") }
        catch SyncRevisionStore.StoreError.unresolvedConflict { }
        do { _ = try a.stage(account: "account-a", entity: "review", device: "a", value: Data("stale".utf8), resolving: ["remote"]); fatalError("stale conflict list was accepted") }
        catch SyncRevisionStore.StoreError.unresolvedConflict { }
        let resolved = try a.stage(account: "account-a", entity: "review", device: "a", value: Data("both".utf8), resolving: Set(conflict.map(\.revisionID)))
        precondition(resolved.revision.version.counters == ["a": 2, "b": 1])
        let frontier = try a.frontier(account: "account-a", entity: "review")
        precondition(frontier == [resolved.revision])
        try a.acknowledge(account: "account-a", revisionID: first.revision.revisionID)
        let reopened = try SyncRevisionStore(url: url)
        let pendingAfter = try reopened.pending(account: "account-a")
        precondition(pendingAfter == [resolved])
        let deleted = try reopened.stage(account: "account-a", entity: "review", device: "a", value: nil)
        let afterDelete = try reopened.frontier(account: "account-a", entity: "review")
        precondition(afterDelete == [deleted.revision])
        precondition(deleted.revision.value == nil)
        print("PASS: durable queue, conflict preservation, account isolation and deletions")
    }
}
