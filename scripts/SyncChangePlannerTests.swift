import Foundation

@main struct SyncChangePlannerTests {
    static func main() throws {
        let one = SyncDesiredValue(entityKey: "review", data: Data("one".utf8))
        let two = SyncDesiredValue(entityKey: "review", data: Data("two".utf8))
        let extra = SyncDesiredValue(entityKey: "habit", data: Data("habit".utf8))
        let unchanged = try SyncChangePlanner.plan(previous: [one], current: [one])
        precondition(unchanged.isEmpty)
        let updates = try SyncChangePlanner.plan(previous: [one], current: [two, extra])
        precondition(updates == [SyncPlannedChange(entityKey: "habit", data: extra.data), SyncPlannedChange(entityKey: "review", data: two.data)])
        let deletions = try SyncChangePlanner.plan(previous: [one], current: [])
        precondition(deletions == [SyncPlannedChange(entityKey: "review", data: nil)])
        do { _ = try SyncChangePlanner.plan(previous: [], current: [one, one]); fatalError("duplicate accepted") }
        catch SyncChangePlanner.PlanError.duplicateEntity { }
        let item1 = SyncSnapshotItem(entityKey: "review:1", table: "review_entries", fields: ["result": .text("b"), "decision": .text("a")])
        let item2 = SyncSnapshotItem(entityKey: "review:1", table: "review_entries", fields: ["decision": .text("a"), "result": .text("b")])
        let encoded1 = try SyncChangePlanner.desiredDatabaseValues([item1])
        let encoded2 = try SyncChangePlanner.desiredDatabaseValues([item2])
        precondition(encoded1 == encoded2)
        print("PASS: deterministic changes, deletion tombstones and duplicate protection")
    }
}
