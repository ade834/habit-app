import Foundation

/// This plans a single entity; the app adapter must apply all selected changes
/// in a local database transaction after rechecking that local state is unchanged.
enum SyncReconciliation {
    enum Decision: Equatable {
        case unchanged
        case apply(Data?)
        case keepLocal
        case conflict([SyncRevision])
        case localChanged
    }

    static func decide(local: Data?, lastApplied: Data?, frontier: [SyncRevision], hasKnownBaseline: Bool = false) -> Decision {
        guard !frontier.isEmpty else { return .unchanged }
        guard frontier.count == 1 else { return .conflict(frontier) }
        let remote = frontier[0].value
        if local == remote { return .unchanged }
        // The cloud still has the last-applied value: preserve the local edit
        // so it can be staged for upload instead of reporting a conflict.
        // A nil baseline could also mean that this device has never seen the
        // remote tombstone. Do not infer a common ancestor in that case.
        if remote == lastApplied, lastApplied != nil || hasKnownBaseline { return .keepLocal }
        guard local == lastApplied else { return .localChanged }
        return .apply(remote)
    }
    /// Classify every known remote entity before applying any changes. A
    /// caller must halt the batch if either conflicts or local edits exist.
    struct BatchDecision: Equatable {
        let changes: [SyncPlannedChange]
        let conflicts: [String]
        let locallyChanged: [String]
    }

    static func planBatch(local: [String: Data], lastApplied: [String: Data], baselineRevisionIDs: [String: String] = [:], frontiers: [String: [SyncRevision]]) -> BatchDecision {
        var changes: [SyncPlannedChange] = []
        var conflicts: [String] = []
        var locallyChanged: [String] = []
        for key in frontiers.keys.sorted() {
            let frontier = frontiers[key] ?? []
            let known = baselineRevisionIDs[key] != nil && baselineRevisionIDs[key] == frontier.first?.revisionID
            switch decide(local: local[key], lastApplied: lastApplied[key], frontier: frontier, hasKnownBaseline: known) {
            case .unchanged, .keepLocal: break
            case .apply(let value): changes.append(SyncPlannedChange(entityKey: key, data: value))
            case .conflict: conflicts.append(key)
            case .localChanged: locallyChanged.append(key)
            }
        }
        return BatchDecision(changes: changes, conflicts: conflicts, locallyChanged: locallyChanged)
    }

    struct InitialMerge: Equatable {
        let upload: [SyncDesiredValue]
        let download: [SyncDesiredValue]
        let conflicts: [String]
    }

    /// A first connection has no common ancestor. Never treat a remote record
    /// as an ancestor of an independently edited local record.
    static func initialMerge(local: [SyncDesiredValue], remote: [SyncDesiredValue]) throws -> InitialMerge {
        func index(_ values: [SyncDesiredValue]) throws -> [String: Data] {
            var result: [String: Data] = [:]
            for value in values {
                guard !value.entityKey.isEmpty else { throw SyncChangePlanner.PlanError.emptyEntity }
                guard result.updateValue(value.data, forKey: value.entityKey) == nil else {
                    throw SyncChangePlanner.PlanError.duplicateEntity
                }
            }
            return result
        }
        let localByKey = try index(local)
        let remoteByKey = try index(remote)
        var upload: [SyncDesiredValue] = []
        var download: [SyncDesiredValue] = []
        var conflicts: [String] = []
        for key in Set(localByKey.keys).union(remoteByKey.keys).sorted() {
            switch (localByKey[key], remoteByKey[key]) {
            case let (.some(left), .some(right)) where left != right:
                conflicts.append(key)
            case let (.some(value), .none):
                upload.append(SyncDesiredValue(entityKey: key, data: value))
            case let (.none, .some(value)):
                download.append(SyncDesiredValue(entityKey: key, data: value))
            default:
                break
            }
        }
        return InitialMerge(upload: upload, download: download, conflicts: conflicts)
    }

}
