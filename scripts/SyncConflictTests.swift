import Foundation

@main struct SyncConflictTests {
    static func main() throws {
        func r(_ id: String, _ clock: [String: UInt64], _ value: String?) -> SyncRevision {
            SyncRevision(revisionID: id, version: SyncVersion(counters: clock), value: value.map { Data($0.utf8) })
        }
        let original = r("a1", ["a": 1], "original")
        let editedA = r("a2", ["a": 2], "first")
        let editedB = r("b1", ["a": 1, "b": 1], "second")
        let deletion = r("b2", ["a": 1, "b": 2], nil)
        let resolved = r("a3", ["a": 3, "b": 2], "merged")
        let linear = try SyncConflictResolver.merge([original], [editedA])
        precondition(linear == [editedA])
        let concurrent = try SyncConflictResolver.merge([editedA], [editedB])
        precondition(concurrent == [editedA, editedB])
        let reverse = try SyncConflictResolver.merge([editedB], [editedA])
        let repeated = try SyncConflictResolver.merge(concurrent, concurrent)
        let editAndDelete = try SyncConflictResolver.merge([editedA], [deletion])
        let afterResolution = try SyncConflictResolver.merge([editedA, deletion], [resolved])
        precondition(reverse == concurrent)
        precondition(repeated == concurrent)
        precondition(editAndDelete == [editedA, deletion])
        precondition(afterResolution == [resolved])
        do {
            _ = try SyncConflictResolver.merge([original], [r("a1", ["a": 2], "different")])
            fatalError("Conflicting revision IDs must fail")
        } catch SyncConflictResolver.Error.inconsistentRevisionID("a1") { }
        print("PASS: causal updates, concurrent edits, deletions and idempotent merges")
    }
}
