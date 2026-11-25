import Foundation
import SQLite3

/// Local journal for one installation. This is intentionally separate from the
/// application database until all domain mappings and recovery paths are ready.
nonisolated final class SyncRevisionStore: @unchecked Sendable {
    enum StoreError: Error { case sqlite(String), invalidRevision, unresolvedConflict, staleFrontier }
    private let db: OpaquePointer
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL) throws {
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let opened = pointer else {
            if let pointer { sqlite3_close(pointer) }
            throw StoreError.sqlite("open")
        }
        db = opened
        sqlite3_busy_timeout(db, 2500)
        do {
            try exec("CREATE TABLE IF NOT EXISTS revisions (account TEXT NOT NULL, entity TEXT NOT NULL, revision_id TEXT NOT NULL, envelope BLOB NOT NULL, pending INTEGER NOT NULL, PRIMARY KEY(account, revision_id))")
            try exec("CREATE INDEX IF NOT EXISTS revisions_entity ON revisions(account, entity)")
            try exec("CREATE TABLE IF NOT EXISTS counters (account TEXT NOT NULL, device TEXT NOT NULL, counter INTEGER NOT NULL, PRIMARY KEY(account, device))")
            try exec("CREATE TABLE IF NOT EXISTS checkpoints (account TEXT NOT NULL PRIMARY KEY, token BLOB NOT NULL)")
            try exec("CREATE TABLE IF NOT EXISTS local_revisions (account TEXT NOT NULL, revision_id TEXT NOT NULL, PRIMARY KEY(account, revision_id))")
            try exec("CREATE TABLE IF NOT EXISTS local_revision_lineage (account TEXT NOT NULL, revision_id TEXT NOT NULL, parents BLOB NOT NULL, PRIMARY KEY(account, revision_id))")
        } catch { sqlite3_close(db); throw error }
    }

    deinit { sqlite3_close(db) }

    /// Each local mutation observes all known revisions; concurrent changes remain separate.
    func stage(account: String, entity: String, device: String, value: Data?, resolving revisionIDs: Set<String>? = nil, observedFrontier: Set<String>? = nil) throws -> SyncEnvelope {
        lock.lock(); defer { lock.unlock() }
        guard !account.isEmpty, !entity.isEmpty, !device.isEmpty else { throw StoreError.invalidRevision }
        try exec("BEGIN IMMEDIATE")
        do {
            let known = try rows(account: account, entity: entity)
            let frontier = try SyncConflictResolver.merge(known.map(\.revision), [])
            // Do not claim a remote version as an ancestor unless the caller
            // actually reconciled that exact frontier with its local data.
            if let observedFrontier, observedFrontier != Set(frontier.map(\.revisionID)) {
                throw StoreError.staleFrontier
            }
            if frontier.count > 1, revisionIDs != Set(frontier.map(\.revisionID)) {
                throw StoreError.unresolvedConflict
            }
            var clock: [String: UInt64] = [:]
            for entry in known {
                for (id, count) in entry.revision.version.counters { clock[id] = max(clock[id, default: 0], count) }
            }
            let counterStatement = try prepare("SELECT counter FROM counters WHERE account=? AND device=?")
            bind(account, counterStatement, 1); bind(device, counterStatement, 2)
            let stored = sqlite3_step(counterStatement) == SQLITE_ROW ? UInt64(sqlite3_column_int64(counterStatement, 0)) : 0
            sqlite3_finalize(counterStatement)
            let last = max(stored, clock[device, default: 0])
            guard last < UInt64(Int64.max) else { throw StoreError.invalidRevision }
            let next = last + 1
            clock[device] = next
            let counter = try prepare("INSERT INTO counters(account,device,counter) VALUES(?,?,?) ON CONFLICT(account,device) DO UPDATE SET counter=excluded.counter")
            bind(account, counter, 1); bind(device, counter, 2); sqlite3_bind_int64(counter, 3, Int64(next))
            defer { sqlite3_finalize(counter) }
            try done(counter)
            let revision = SyncRevision(revisionID: UUID().uuidString, version: SyncVersion(counters: clock), value: value)
            let envelope = SyncEnvelope(schemaVersion: 1, entityKey: entity, revision: revision)
            try insert(account: account, envelope: envelope, pending: true)
            try recordLocal(account: account, revisionID: revision.revisionID, parents: Set(frontier.map(\.revisionID)))
            try exec("COMMIT")
            return envelope
        } catch { try? exec("ROLLBACK"); throw error }
    }

    struct StageChange: Sendable {
        let entity: String
        let value: Data?
        let observedFrontier: Set<String>
        let resolving: Set<String>?
    }

    /// Stage a whole batch or none. The observed frontier is mandatory so an
    /// unmerged remote revision cannot become an accidental ancestor.
    func stageBatch(account: String, device: String, changes: [StageChange]) throws -> [SyncEnvelope] {
        lock.lock(); defer { lock.unlock() }
        guard !account.isEmpty, !device.isEmpty,
              changes.allSatisfy({ !$0.entity.isEmpty }),
              Set(changes.map(\.entity)).count == changes.count else { throw StoreError.invalidRevision }
        try exec("BEGIN IMMEDIATE")
        do {
            var results: [SyncEnvelope] = []
            for change in changes {
            let known = try rows(account: account, entity: change.entity)
            let frontier = try SyncConflictResolver.merge(known.map(\.revision), [])
            // Do not claim a remote version as an ancestor unless the caller
            // actually reconciled that exact frontier with its local data.
            if change.observedFrontier != Set(frontier.map(\.revisionID)) {
                throw StoreError.staleFrontier
            }
            if frontier.count > 1, change.resolving != Set(frontier.map(\.revisionID)) {
                throw StoreError.unresolvedConflict
            }
            var clock: [String: UInt64] = [:]
            for entry in known {
                for (id, count) in entry.revision.version.counters { clock[id] = max(clock[id, default: 0], count) }
            }
            let counterStatement = try prepare("SELECT counter FROM counters WHERE account=? AND device=?")
            bind(account, counterStatement, 1); bind(device, counterStatement, 2)
            let stored = sqlite3_step(counterStatement) == SQLITE_ROW ? UInt64(sqlite3_column_int64(counterStatement, 0)) : 0
            sqlite3_finalize(counterStatement)
            let last = max(stored, clock[device, default: 0])
            guard last < UInt64(Int64.max) else { throw StoreError.invalidRevision }
            let next = last + 1
            clock[device] = next
            let counter = try prepare("INSERT INTO counters(account,device,counter) VALUES(?,?,?) ON CONFLICT(account,device) DO UPDATE SET counter=excluded.counter")
            bind(account, counter, 1); bind(device, counter, 2); sqlite3_bind_int64(counter, 3, Int64(next))
            defer { sqlite3_finalize(counter) }
            try done(counter)
            let revision = SyncRevision(revisionID: UUID().uuidString, version: SyncVersion(counters: clock), value: change.value)
            let envelope = SyncEnvelope(schemaVersion: 1, entityKey: change.entity, revision: revision)
            try insert(account: account, envelope: envelope, pending: true)
            try recordLocal(account: account, revisionID: revision.revisionID, parents: change.observedFrontier)
                results.append(envelope)
            }
            try exec("COMMIT")
            return results
        } catch { try? exec("ROLLBACK"); throw error }
    }

    func ingest(account: String, envelope: SyncEnvelope) throws {
        lock.lock(); defer { lock.unlock() }
        guard !account.isEmpty, !envelope.entityKey.isEmpty, envelope.schemaVersion == 1 else { throw StoreError.invalidRevision }
        try insert(account: account, envelope: envelope, pending: false)
    }

    /// A change token is committed in the same transaction as all records in its page.
    func ingestPage(account: String, envelopes: [SyncEnvelope], token: Data) throws {
        lock.lock(); defer { lock.unlock() }
        guard !account.isEmpty, !token.isEmpty else { throw StoreError.invalidRevision }
        try exec("BEGIN IMMEDIATE")
        do {
            for envelope in envelopes {
                guard !envelope.entityKey.isEmpty, envelope.schemaVersion == 1 else { throw StoreError.invalidRevision }
                try insert(account: account, envelope: envelope, pending: false)
            }
            let stmt = try prepare("INSERT INTO checkpoints(account,token) VALUES(?,?) ON CONFLICT(account) DO UPDATE SET token=excluded.token")
            defer { sqlite3_finalize(stmt) }
            bind(account, stmt, 1)
            _ = token.withUnsafeBytes { sqlite3_bind_blob(stmt, 2, $0.baseAddress, Int32(token.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            try done(stmt)
            try exec("COMMIT")
        } catch { try? exec("ROLLBACK"); throw error }
    }

    func checkpoint(account: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        let stmt = try prepare("SELECT token FROM checkpoints WHERE account=?")
        defer { sqlite3_finalize(stmt) }
        bind(account, stmt, 1)
        let result = sqlite3_step(stmt)
        if result == SQLITE_DONE { return nil }
        guard result == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) else { throw StoreError.sqlite("read checkpoint") }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0)))
    }

    func frontier(account: String, entity: String) throws -> [SyncRevision] {
        lock.lock(); defer { lock.unlock() }
        return try SyncConflictResolver.merge(rows(account: account, entity: entity).map(\.revision), [])
    }

    /// Return the current revisions for every entity owned by this account.
    /// Concurrent versions remain separate for the caller to resolve.
    func frontiers(account: String) throws -> [String: [SyncRevision]] {
        lock.lock(); defer { lock.unlock() }
        guard !account.isEmpty else { throw StoreError.invalidRevision }
        let stmt = try prepare("SELECT envelope FROM revisions WHERE account=? ORDER BY entity, rowid")
        defer { sqlite3_finalize(stmt) }
        bind(account, stmt, 1)
        let envelopes = try decodeRows(stmt)
        let grouped = Dictionary(grouping: envelopes, by: \.entityKey)
        var result: [String: [SyncRevision]] = [:]
        for (entity, values) in grouped {
            result[entity] = try SyncConflictResolver.merge(values.map(\.revision), [])
        }
        return result
    }

    func pending(account: String) throws -> [SyncEnvelope] {
        lock.lock(); defer { lock.unlock() }
        let stmt = try prepare("SELECT envelope FROM revisions WHERE account=? AND pending=1 ORDER BY rowid")
        defer { sqlite3_finalize(stmt) }
        bind(account, stmt, 1)
        return try decodeRows(stmt)
    }

    /// This marker is committed with the revision, and survives upload ACKs.
    /// It must never be inferred merely from a received version vector.
    func isLocal(account: String, revisionID: String) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !account.isEmpty, !revisionID.isEmpty else { throw StoreError.invalidRevision }
        let stmt = try prepare("SELECT 1 FROM local_revisions WHERE account=? AND revision_id=?")
        defer { sqlite3_finalize(stmt) }
        bind(account, stmt, 1); bind(revisionID, stmt, 2)
        let step = sqlite3_step(stmt)
        guard step == SQLITE_ROW || step == SQLITE_DONE else { throw StoreError.sqlite("read local origin") }
        return step == SQLITE_ROW
    }

    /// Prove a chain of locally staged revisions from a known ancestor.
    /// Missing lineage and conflict merges fail closed, including old journals.
    func hasLocalLineage(account: String, revisionID: String, since ancestor: String?) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !account.isEmpty, !revisionID.isEmpty, ancestor?.isEmpty != true else { throw StoreError.invalidRevision }
        var current = revisionID
        var visited = Set<String>()
        while current != ancestor {
            guard visited.insert(current).inserted else { throw StoreError.invalidRevision }
            let stmt = try prepare("SELECT parents FROM local_revision_lineage WHERE account=? AND revision_id=?")
            bind(account, stmt, 1); bind(current, stmt, 2)
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { sqlite3_finalize(stmt); return false }
            guard step == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) else {
                sqlite3_finalize(stmt); throw StoreError.sqlite("read local lineage")
            }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0)))
            sqlite3_finalize(stmt)
            let parents = try decoder.decode([String].self, from: data)
            if parents.isEmpty { return ancestor == nil }
            guard parents.count == 1 else { return false }
            current = parents[0]
        }
        return true
    }

    private func recordLocal(account: String, revisionID: String, parents: Set<String>) throws {
        let stmt = try prepare("INSERT INTO local_revisions(account,revision_id) VALUES(?,?)")
        defer { sqlite3_finalize(stmt) }
        bind(account, stmt, 1); bind(revisionID, stmt, 2)
        try done(stmt)
        let parentStatement = try prepare("INSERT INTO local_revision_lineage(account,revision_id,parents) VALUES(?,?,?)")
        defer { sqlite3_finalize(parentStatement) }
        bind(account, parentStatement, 1); bind(revisionID, parentStatement, 2)
        let data = try encoder.encode(parents.sorted())
        _ = data.withUnsafeBytes { sqlite3_bind_blob(parentStatement, 3, $0.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        try done(parentStatement)
    }

    func acknowledge(account: String, revisionID: String) throws {
        lock.lock(); defer { lock.unlock() }
        let stmt = try prepare("UPDATE revisions SET pending=0 WHERE account=? AND revision_id=?")
        defer { sqlite3_finalize(stmt) }
        bind(account, stmt, 1); bind(revisionID, stmt, 2)
        try done(stmt)
    }

    private func rows(account: String, entity: String) throws -> [SyncEnvelope] {
        let stmt = try prepare("SELECT envelope FROM revisions WHERE account=? AND entity=? ORDER BY rowid")
        defer { sqlite3_finalize(stmt) }
        bind(account, stmt, 1); bind(entity, stmt, 2)
        return try decodeRows(stmt)
    }

    private func insert(account: String, envelope: SyncEnvelope, pending: Bool) throws {
        let find = try prepare("SELECT envelope FROM revisions WHERE account=? AND revision_id=?")
        defer { sqlite3_finalize(find) }
        bind(account, find, 1); bind(envelope.revision.revisionID, find, 2)
        let existing = try decodeRows(find)
        if let old = existing.first {
            guard old == envelope else { throw StoreError.invalidRevision }
            return
        }
        let stmt = try prepare("INSERT INTO revisions(account,entity,revision_id,envelope,pending) VALUES(?,?,?,?,?)")
        defer { sqlite3_finalize(stmt) }
        bind(account, stmt, 1); bind(envelope.entityKey, stmt, 2); bind(envelope.revision.revisionID, stmt, 3)
        let data = try encoder.encode(envelope)
        _ = data.withUnsafeBytes { sqlite3_bind_blob(stmt, 4, $0.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        sqlite3_bind_int(stmt, 5, pending ? 1 : 0)
        try done(stmt)
    }

    private func decodeRows(_ stmt: OpaquePointer) throws -> [SyncEnvelope] {
        var result: [SyncEnvelope] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { return result }
            guard step == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) else { throw StoreError.sqlite("read") }
            result.append(try decoder.decode(SyncEnvelope.self, from: Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0)))))
        }
    }

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw StoreError.sqlite("execute") }
    }
    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw StoreError.sqlite("prepare") }
        return stmt
    }
    private func bind(_ value: String, _ stmt: OpaquePointer, _ index: Int32) {
        _ = value.withCString { sqlite3_bind_text(stmt, index, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }
    private func done(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw StoreError.sqlite("write") }
    }
}
