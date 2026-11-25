import Foundation

/// A version vector is compared by causality, not by either device's wall clock.
nonisolated struct SyncVersion: Codable, Equatable, Sendable {
    let counters: [String: UInt64]

    func dominates(_ other: SyncVersion) -> Bool {
        var strictlyGreater = false
        for id in Set(counters.keys).union(other.counters.keys) {
            let lhs = counters[id, default: 0], rhs = other.counters[id, default: 0]
            if lhs < rhs { return false }
            if lhs > rhs { strictlyGreater = true }
        }
        return strictlyGreater
    }
}

/// Concurrent edits, including edit-versus-delete, remain available for resolution.
nonisolated struct SyncRevision: Codable, Equatable, Sendable {
    let revisionID: String
    let version: SyncVersion
    /// nil represents a deletion; bytes contain an encoded, domain-specific value.
    let value: Data?
}

nonisolated enum SyncConflictResolver {
    enum Error: Swift.Error, Equatable { case inconsistentRevisionID(String) }

    /// Combines replicas without choosing a winner for genuinely concurrent changes.
    static func merge(_ left: [SyncRevision], _ right: [SyncRevision]) throws -> [SyncRevision] {
        var unique: [String: SyncRevision] = [:]
        for revision in left + right {
            if let old = unique[revision.revisionID], old != revision {
                throw Error.inconsistentRevisionID(revision.revisionID)
            }
            unique[revision.revisionID] = revision
        }
        let revisions = Array(unique.values)
        return revisions.filter { candidate in
            !revisions.contains { $0.revisionID != candidate.revisionID && $0.version.dominates(candidate.version) }
        }.sorted { $0.revisionID < $1.revisionID }
    }
}
