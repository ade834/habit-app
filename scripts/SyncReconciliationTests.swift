import Foundation

@main struct SyncReconciliationTests {
    static func main() {
        let old = Data("old".utf8), local = Data("local".utf8), remote = Data("remote".utf8)
        let remoteRevision = SyncRevision(revisionID: "r", version: SyncVersion(counters: ["B": 1]), value: remote)
        let localRevision = SyncRevision(revisionID: "l", version: SyncVersion(counters: ["A": 1]), value: local)
        let deleted = SyncRevision(revisionID: "d", version: SyncVersion(counters: ["B": 2]), value: nil)
        precondition(SyncReconciliation.decide(local: old, lastApplied: old, frontier: [remoteRevision]) == .apply(remote))
        precondition(SyncReconciliation.decide(local: local, lastApplied: old, frontier: [remoteRevision]) == .localChanged)
        precondition(SyncReconciliation.decide(local: local, lastApplied: old, frontier: [remoteRevision, localRevision]) == .conflict([remoteRevision, localRevision]))
        precondition(SyncReconciliation.decide(local: old, lastApplied: old, frontier: [deleted]) == .apply(nil))
        precondition(SyncReconciliation.decide(local: local, lastApplied: old, frontier: [deleted]) == .localChanged)
        precondition(SyncReconciliation.decide(local: remote, lastApplied: old, frontier: [remoteRevision]) == .unchanged)
        precondition(SyncReconciliation.decide(local: local, lastApplied: nil, frontier: []) == .unchanged)
        print("PASS: no overwrites of local edits, conflict preservation and safe deletions")
    }
}
