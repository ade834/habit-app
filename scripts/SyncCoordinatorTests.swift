import Foundation

actor MemoryCloud: SyncTransport {
    enum Failure: Error { case offline, mismatch }
    var accounts: [String: [SyncEnvelope]] = [:]
    var failUploads = false
    func setFailUploads(_ value: Bool) { failUploads = value }
    func ensureZone(account: String) async throws {}
    func upload(_ envelope: SyncEnvelope, account: String) async throws {
        if failUploads { throw Failure.offline }
        if let existing = accounts[account, default: []].first(where: { $0.revision.revisionID == envelope.revision.revisionID }) {
            guard existing == envelope else { throw Failure.mismatch }
        } else { accounts[account, default: []].append(envelope) }
    }
    func fetchPage(account: String, after token: Data?) async throws -> SyncPage {
        let offset = token.flatMap { String(data: $0, encoding: .utf8) }.flatMap(Int.init) ?? 0
        let all = accounts[account, default: []]
        let end = min(all.count, offset + 1)
        return SyncPage(revisions: Array(all[offset..<end]), token: Data(String(end).utf8), moreComing: end < all.count)
    }
}

@main struct SyncCoordinatorTests {
    static func main() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = try SyncRevisionStore(url: dir.appendingPathComponent("a.sqlite"))
        let b = try SyncRevisionStore(url: dir.appendingPathComponent("b.sqlite"))
        let cloud = MemoryCloud()
        let first = try a.stage(account: "owner", entity: "review", device: "A", value: Data("first".utf8))
        let ca = SyncCoordinator(store: a, transport: cloud)
        let cb = SyncCoordinator(store: b, transport: cloud)
        await cloud.setFailUploads(true)
        do { try await ca.synchronize(account: "owner"); fatalError("expected offline") } catch MemoryCloud.Failure.offline { }
        let stillPending = try a.pending(account: "owner")
        precondition(stillPending == [first])
        await cloud.setFailUploads(false)
        try await ca.synchronize(account: "owner")
        try await cb.synchronize(account: "owner")
        _ = try a.stage(account: "owner", entity: "review", device: "A", value: Data("edited A".utf8))
        _ = try b.stage(account: "owner", entity: "review", device: "B", value: Data("edited B".utf8))
        try await ca.synchronize(account: "owner")
        try await cb.synchronize(account: "owner")
        try await ca.synchronize(account: "owner")
        let frontierA = try a.frontier(account: "owner", entity: "review")
        let frontierB = try b.frontier(account: "owner", entity: "review")
        precondition(frontierA == frontierB && frontierA.count == 2)
        let ownerToken = try a.checkpoint(account: "owner")
        let otherToken = try a.checkpoint(account: "another")
        precondition(ownerToken != nil && otherToken == nil)
        let bad = SyncEnvelope(schemaVersion: 2, entityKey: "review", revision: first.revision)
        do {
            try a.ingestPage(account: "owner", envelopes: [bad], token: Data("99".utf8))
            fatalError("expected invalid page")
        } catch SyncRevisionStore.StoreError.invalidRevision { }
        let unchanged = try a.checkpoint(account: "owner")
        precondition(unchanged == ownerToken)
        print("PASS: offline retry, paginated sync, concurrent edits and atomic checkpoints")
    }
}
