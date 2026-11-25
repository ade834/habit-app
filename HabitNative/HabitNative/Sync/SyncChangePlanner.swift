import Foundation

struct SyncDesiredValue: Equatable, Sendable {
    let entityKey: String
    let data: Data
}

struct SyncPlannedChange: Equatable, Sendable {
    let entityKey: String
    /// A missing value is an explicit tombstone, not an omitted row.
    let data: Data?
}

enum SyncChangePlanner {
    enum PlanError: Error { case duplicateEntity, emptyEntity }

    /// Call only with complete, validated snapshots. A partial snapshot would
    /// otherwise appear to delete data that wasn't read successfully.
    static func plan(previous: [SyncDesiredValue], current: [SyncDesiredValue]) throws -> [SyncPlannedChange] {
        func index(_ values: [SyncDesiredValue]) throws -> [String: Data] {
            var result: [String: Data] = [:]
            for value in values {
                guard !value.entityKey.isEmpty else { throw PlanError.emptyEntity }
                guard result.updateValue(value.data, forKey: value.entityKey) == nil else { throw PlanError.duplicateEntity }
            }
            return result
        }
        let old = try index(previous), new = try index(current)
        return Set(old.keys).union(new.keys).sorted().compactMap { key in
            guard old[key] != new[key] else { return nil }
            return SyncPlannedChange(entityKey: key, data: new[key])
        }
    }

    /// Construct local revisions only after checking the remote frontier against
    /// the exact last-applied value. A missing frontier is safe only when the
    /// entity has never had a synchronized ancestor.
    static func prepareLocalBatch(previous: [SyncDesiredValue], current: [SyncDesiredValue], baselineRevisionIDs: [String: String], frontiers: [String: [SyncRevision]]) throws -> [SyncRevisionStore.StageChange] {
        let changes = try plan(previous: previous, current: current)
        let baseline = Dictionary(uniqueKeysWithValues: previous.map { ($0.entityKey, $0.data) })
        return try changes.map { change in
            let frontier = frontiers[change.entityKey] ?? []
            guard frontier.count <= 1 else { throw SyncRevisionStore.StoreError.unresolvedConflict }
            if let remote = frontier.first {
                // Equal values alone are not proof of ancestry. In particular,
                // an unseen tombstone and an absent baseline are both nil.
                guard baselineRevisionIDs[change.entityKey] == remote.revisionID,
                      remote.value == baseline[change.entityKey] else { throw SyncRevisionStore.StoreError.staleFrontier }
            } else if baseline[change.entityKey] != nil || baselineRevisionIDs[change.entityKey] != nil {
                throw SyncRevisionStore.StoreError.staleFrontier
            }
            return SyncRevisionStore.StageChange(entity: change.entityKey, value: change.data,
                observedFrontier: Set(frontier.map(\.revisionID)), resolving: nil)
        }
    }

    static func desiredDatabaseValues(_ items: [SyncSnapshotItem]) throws -> [SyncDesiredValue] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try items.map { SyncDesiredValue(entityKey: "db/" + $0.entityKey, data: try encoder.encode($0)) }
    }

    static func desiredPreferenceValues(_ items: [SyncPreferenceItem]) throws -> [SyncDesiredValue] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try items.map { SyncDesiredValue(entityKey: "preferences/" + $0.key, data: try encoder.encode($0)) }
    }
}
