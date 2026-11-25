import Foundation
import CryptoKit
import SQLite3

/// Bootstrap into an empty device only. Merging a nonempty device needs a separate
/// causal reconciliation flow and must never be approximated by overwriting rows.
struct SyncSnapshotBootstrap {
    enum BootstrapError: Error { case localDataPresent, invalidData, missingDependency, sqlite, accountChanged, localDataCleared, conflict(String) }
    let database: NativeDatabase

    func restoreIntoEmptyDevice(_ items: [SyncSnapshotItem]) throws {
        try database.withConnection { db in
            try NativeDatabase.execute("BEGIN IMMEDIATE", in: db)
            do {
                let tableStatement = try NativeDatabase.prepare("SELECT name FROM sqlite_master WHERE type='table'", in: db)
                var names = Set<String>()
                var tableResult = sqlite3_step(tableStatement)
                while tableResult == SQLITE_ROW {
                    if let raw = sqlite3_column_text(tableStatement, 0) { names.insert(String(cString: raw)) }
                    tableResult = sqlite3_step(tableStatement)
                }
                sqlite3_finalize(tableStatement)
                guard tableResult == SQLITE_DONE else { throw BootstrapError.sqlite }
                guard SyncDomainCatalog.unknownTables(in: names).isEmpty,
                      Set(SyncDomainCatalog.domains.map(\.table)).isSubset(of: names) else { throw BootstrapError.invalidData }
                for domain in SyncDomainCatalog.domains where domain.identity != .localMetadata {
                    guard try NativeDatabase.scalarInt("SELECT COUNT(*) FROM \(domain.table)", in: db) == 0 else { throw BootstrapError.localDataPresent }
                }
                try NativeDatabase.execute("CREATE TABLE IF NOT EXISTS sync_row_identity (table_name TEXT NOT NULL, local_id INTEGER NOT NULL, stable_id TEXT NOT NULL, PRIMARY KEY(table_name, local_id), UNIQUE(table_name, stable_id))", in: db)
                guard Set(items.map(\.entityKey)).count == items.count else { throw BootstrapError.invalidData }
                let order = Dictionary(uniqueKeysWithValues: SyncDomainCatalog.domains.enumerated().map { ($0.element.table, $0.offset) })
                let sorted = items.sorted { (order[$0.table] ?? Int.max) < (order[$1.table] ?? Int.max) }
                for item in sorted { try restore(item, db: db) }
                try NativeDatabase.execute("COMMIT", in: db)
            } catch { try? NativeDatabase.execute("ROLLBACK", in: db); throw error }
        }
    }

    /// Merge only missing or identical rows. Conflicts abort the whole transaction.
    func mergeNonconflicting(_ incoming: [SyncSnapshotItem]) throws {
        try database.withConnection { db in
            try NativeDatabase.execute("BEGIN IMMEDIATE", in: db)
            do {
                guard Set(incoming.map(\.entityKey)).count == incoming.count else { throw BootstrapError.invalidData }
                let existing = try SyncSnapshotReader(database: database).read(in: db)
                let local = Dictionary(uniqueKeysWithValues: existing.map { ($0.entityKey, $0) })
                for item in incoming {
                    if let current = local[item.entityKey], current != item {
                        throw BootstrapError.conflict(item.entityKey)
                    }
                }
                let order = Dictionary(uniqueKeysWithValues: SyncDomainCatalog.domains.enumerated().map { ($0.element.table, $0.offset) })
                let missing = incoming.filter { local[$0.entityKey] == nil }
                    .sorted { (order[$0.table] ?? Int.max) < (order[$1.table] ?? Int.max) }
                for item in missing { try restore(item, db: db) }
                try NativeDatabase.execute("COMMIT", in: db)
            } catch {
                try? NativeDatabase.execute("ROLLBACK", in: db)
                throw error
            }
        }
    }

    struct AppliedBaseline: Codable, Equatable {
        let values: [String: Data]
        let revisionIDs: [String: String]
    }

    private func baselineKey(_ account: String) throws -> String {
        guard !account.isEmpty else { throw BootstrapError.invalidData }
        return "sync_baseline_" + SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The first enabled account owns this installation's local dataset.
    /// A different iCloud account must never receive it implicitly.
    func bindAccount(_ account: String) throws {
        let value = try baselineKey(account)
        try database.withConnection { db in
            try NativeDatabase.execute("BEGIN IMMEDIATE", in: db)
            do {
                let pause = try NativeDatabase.prepare("SELECT 1 FROM native_metadata WHERE key='sync_paused_after_local_clear'", in: db)
                let pauseResult = sqlite3_step(pause)
                sqlite3_finalize(pause)
                guard pauseResult == SQLITE_DONE else {
                    if pauseResult == SQLITE_ROW { throw BootstrapError.localDataCleared }
                    throw BootstrapError.sqlite
                }
                let stmt = try NativeDatabase.prepare("SELECT value FROM native_metadata WHERE key='sync_bound_account'", in: db)
                let result = sqlite3_step(stmt)
                let existing = result == SQLITE_ROW ? sqlite3_column_text(stmt, 0).map { String(cString: $0) } : nil
                sqlite3_finalize(stmt)
                guard result == SQLITE_ROW || result == SQLITE_DONE else { throw BootstrapError.sqlite }
                if let existing {
                    guard existing == value else { throw BootstrapError.accountChanged }
                } else {
                    guard result == SQLITE_DONE else { throw BootstrapError.invalidData }
                    try NativeDatabase.execute("INSERT INTO native_metadata(key,value) VALUES ('sync_bound_account',?)", bindings: [value], in: db)
                }
                try NativeDatabase.execute("COMMIT", in: db)
            } catch {
                try? NativeDatabase.execute("ROLLBACK", in: db)
                throw error
            }
        }
    }

    func readBaseline(account: String) throws -> AppliedBaseline? {
        let key = try baselineKey(account)
        return try database.withConnection { db in
            let statement = try NativeDatabase.prepare("SELECT value FROM native_metadata WHERE key=?", in: db)
            defer { sqlite3_finalize(statement) }
            try bind(.text(key), to: statement, at: 1)
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return nil }
            guard result == SQLITE_ROW, let raw = sqlite3_column_text(statement, 0),
                  let data = Data(base64Encoded: String(cString: raw)) else { throw BootstrapError.invalidData }
            return try JSONDecoder().decode(AppliedBaseline.self, from: data)
        }
    }

    /// Apply a remote batch only if every entity can be reconciled safely.
    /// Preferences use a separate store and cannot be silently imported here.
    func applyRemoteBatch(expected: [SyncSnapshotItem], lastApplied: [String: Data], baselineRevisionIDs: [String: String] = [:], frontiers: [String: [SyncRevision]], account: String? = nil) throws {
        guard Set(expected.map(\.entityKey)).count == expected.count else { throw BootstrapError.invalidData }
        let localValues = try SyncChangePlanner.desiredDatabaseValues(expected)
        let local = Dictionary(uniqueKeysWithValues: localValues.map { ($0.entityKey, $0.data) })
        let batch = SyncReconciliation.planBatch(local: local, lastApplied: lastApplied, baselineRevisionIDs: baselineRevisionIDs, frontiers: frontiers)
        guard batch.conflicts.isEmpty, batch.locallyChanged.isEmpty else {
            throw BootstrapError.conflict((batch.conflicts + batch.locallyChanged).sorted().joined(separator: ","))
        }
        var items = Dictionary(uniqueKeysWithValues: expected.map { ($0.entityKey, $0) })
        for change in batch.changes {
            guard change.entityKey.hasPrefix("db/") else { throw BootstrapError.invalidData }
            let key = String(change.entityKey.dropFirst(3))
            if let data = change.data {
                let item = try JSONDecoder().decode(SyncSnapshotItem.self, from: data)
                guard item.entityKey == key else { throw BootstrapError.invalidData }
                items[key] = item
            } else {
                items.removeValue(forKey: key)
            }
        }
        let baseline: (String, String)?
        if let account {
            guard frontiers.keys.allSatisfy({ $0.hasPrefix("db/") }), frontiers.values.allSatisfy({ $0.count == 1 }) else { throw BootstrapError.invalidData }
            var values: [String: Data] = [:]
            var revisionIDs: [String: String] = [:]
            for (key, revisions) in frontiers {
                let revision = revisions[0]
                values[key] = revision.value
                revisionIDs[key] = revision.revisionID
            }
            let data = try JSONEncoder().encode(AppliedBaseline(values: values, revisionIDs: revisionIDs))
            baseline = (try baselineKey(account), data.base64EncodedString())
        } else { baseline = nil }
        if !batch.changes.isEmpty || baseline != nil {
            try applyReconciledSnapshot(Array(items.values), expected: expected, baseline: baseline,
                                        requiredAccountBinding: try account.map { try baselineKey($0) })
        }
    }

    /// Apply a reconciled complete snapshot only while its local ancestor still
    /// matches. The transaction preserves all data on races or invalid imports.
    func applyReconciledSnapshot(_ incoming: [SyncSnapshotItem], expected: [SyncSnapshotItem], baseline: (String, String)? = nil,
                                 requiredAccountBinding: String? = nil) throws {
        try database.withConnection { db in
            try NativeDatabase.execute("BEGIN IMMEDIATE", in: db)
            do {
                if let requiredAccountBinding {
                    let paused = try NativeDatabase.prepare("SELECT 1 FROM native_metadata WHERE key='sync_paused_after_local_clear'", in: db)
                    let pauseResult = sqlite3_step(paused)
                    sqlite3_finalize(paused)
                    guard pauseResult == SQLITE_DONE else {
                        if pauseResult == SQLITE_ROW { throw BootstrapError.localDataCleared }
                        throw BootstrapError.sqlite
                    }
                    let bound = try NativeDatabase.prepare("SELECT value FROM native_metadata WHERE key='sync_bound_account'", in: db)
                    let result = sqlite3_step(bound)
                    let value = result == SQLITE_ROW ? sqlite3_column_text(bound, 0).map { String(cString: $0) } : nil
                    sqlite3_finalize(bound)
                    guard result == SQLITE_ROW || result == SQLITE_DONE else { throw BootstrapError.sqlite }
                    guard value == requiredAccountBinding else { throw BootstrapError.accountChanged }
                }
                let current = try SyncSnapshotReader(database: database).read(in: db)
                guard current.sorted(by: { $0.entityKey < $1.entityKey }) == expected.sorted(by: { $0.entityKey < $1.entityKey }) else {
                    throw BootstrapError.conflict("local_snapshot_changed")
                }
                guard Set(incoming.map(\.entityKey)).count == incoming.count else { throw BootstrapError.invalidData }
                if incoming.sorted(by: { $0.entityKey < $1.entityKey }) != current.sorted(by: { $0.entityKey < $1.entityKey }) {
                    let old = Dictionary(uniqueKeysWithValues: current.map { ($0.entityKey, $0) })
                    let new = Dictionary(uniqueKeysWithValues: incoming.map { ($0.entityKey, $0) })
                    let order = Dictionary(uniqueKeysWithValues: SyncDomainCatalog.domains.enumerated().map { ($0.element.table, $0.offset) })
                    for item in current.filter({ new[$0.entityKey] == nil }).sorted(by: { (order[$0.table] ?? Int.max) > (order[$1.table] ?? Int.max) }) {
                        try remove(item, db: db)
                    }
                    for item in incoming.sorted(by: { (order[$0.table] ?? Int.max) < (order[$1.table] ?? Int.max) }) {
                        if let existing = old[item.entityKey] {
                            if existing != item { try update(item, db: db) }
                        } else {
                            try restore(item, db: db)
                        }
                    }
                }
                if let baseline {
                    try NativeDatabase.execute("INSERT OR REPLACE INTO native_metadata(key,value) VALUES (?,?)", bindings: [baseline.0, baseline.1], in: db)
                }
                try NativeDatabase.execute("COMMIT", in: db)
            } catch {
                try? NativeDatabase.execute("ROLLBACK", in: db)
                throw error
            }
        }
    }

    private func rowID(_ item: SyncSnapshotItem, db: OpaquePointer) throws -> Int64 {
        guard let domain = SyncDomainCatalog.domains.first(where: { $0.table == item.table }), domain.identity != .localMetadata,
              item.entityKey.hasPrefix(item.table + ":"),
              let raw = Data(base64Encoded: String(item.entityKey.dropFirst(item.table.count + 1))),
              let identity = try? JSONDecoder().decode([SyncFieldValue].self, from: raw) else { throw BootstrapError.invalidData }
        let sql: String
        let values: [SyncFieldValue]
        switch domain.identity {
        case .natural(let keys):
            guard identity.count == keys.count, zip(keys, identity).allSatisfy({ item.fields[$0.0] == $0.1 && $0.1 != .null }) else { throw BootstrapError.invalidData }
            sql = "SELECT rowid FROM \(item.table) WHERE " + keys.map { "\($0)=?" }.joined(separator: " AND ")
            values = identity
        case .localRowIDWithStableUUID:
            guard identity.count == 1, case .text(let stableID) = identity[0], UUID(uuidString: stableID) != nil else { throw BootstrapError.invalidData }
            sql = "SELECT local_id FROM sync_row_identity WHERE table_name=? AND stable_id=?"
            values = [.text(item.table), .text(stableID)]
        case .logReference(let column):
            guard identity.count == 2, case .text(let habit) = identity[0], case .text(let day) = identity[1],
                  item.fields["sync_log_habit_id"] == .text(habit), item.fields["sync_log_local_date"] == .text(day) else { throw BootstrapError.invalidData }
            sql = "SELECT rowid FROM \(item.table) WHERE \(column)=?"
            values = [.integer(try findLog(habit: habit, day: day, db: db))]
        case .localMetadata: throw BootstrapError.invalidData
        }
        let stmt = try NativeDatabase.prepare(sql, in: db)
        defer { sqlite3_finalize(stmt) }
        for (index, value) in values.enumerated() { try bind(value, to: stmt, at: Int32(index + 1)) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw BootstrapError.missingDependency }
        let id = sqlite3_column_int64(stmt, 0)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw BootstrapError.invalidData }
        return id
    }

    private func remove(_ item: SyncSnapshotItem, db: OpaquePointer) throws {
        let id = try rowID(item, db: db)
        let stmt = try NativeDatabase.prepare("DELETE FROM \(item.table) WHERE rowid=?", in: db)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        let result = sqlite3_step(stmt)
        if result == SQLITE_CONSTRAINT { throw BootstrapError.missingDependency }
        guard result == SQLITE_DONE, sqlite3_changes(db) == 1 else { throw BootstrapError.sqlite }
        let mapping = try NativeDatabase.prepare("DELETE FROM sync_row_identity WHERE table_name=? AND local_id=?", in: db)
        defer { sqlite3_finalize(mapping) }
        try bind(.text(item.table), to: mapping, at: 1)
        sqlite3_bind_int64(mapping, 2, id)
        guard sqlite3_step(mapping) == SQLITE_DONE else { throw BootstrapError.sqlite }
    }

    private func update(_ item: SyncSnapshotItem, db: OpaquePointer) throws {
        let id = try rowID(item, db: db)
        var fields = item.fields
        if let domain = SyncDomainCatalog.domains.first(where: { $0.table == item.table }), case .logReference(let column) = domain.identity {
            guard case .text(let habit) = fields.removeValue(forKey: "sync_log_habit_id"),
                  case .text(let day) = fields.removeValue(forKey: "sync_log_local_date") else { throw BootstrapError.invalidData }
            fields[column] = .integer(try findLog(habit: habit, day: day, db: db))
        }
        let generatedIDTables: Set<String> = ["habit_logs", "point_transactions", "habit_activity_entries", "timer_sessions", "badge_plan_intervals"]
        let allowed = try tableColumns(item.table, db: db)
        let expected = generatedIDTables.contains(item.table) ? allowed.subtracting(["id"]) : allowed
        guard Set(fields.keys) == expected, !fields.isEmpty else { throw BootstrapError.invalidData }
        let columns = fields.keys.sorted()
        let stmt = try NativeDatabase.prepare("UPDATE \(item.table) SET " + columns.map { "\($0)=?" }.joined(separator: ",") + " WHERE rowid=?", in: db)
        defer { sqlite3_finalize(stmt) }
        for (index, key) in columns.enumerated() { try bind(fields[key]!, to: stmt, at: Int32(index + 1)) }
        sqlite3_bind_int64(stmt, Int32(columns.count + 1), id)
        guard sqlite3_step(stmt) == SQLITE_DONE, sqlite3_changes(db) == 1 else { throw BootstrapError.sqlite }
    }

    private func restore(_ item: SyncSnapshotItem, db: OpaquePointer) throws {
        guard let domain = SyncDomainCatalog.domains.first(where: { $0.table == item.table }), domain.identity != .localMetadata else { throw BootstrapError.invalidData }
        let prefix = item.table + ":"
        guard item.entityKey.hasPrefix(prefix), let raw = Data(base64Encoded: String(item.entityKey.dropFirst(prefix.count))),
              let identity = try? JSONDecoder().decode([SyncFieldValue].self, from: raw) else { throw BootstrapError.invalidData }
        var fields = item.fields
        var stableID: String?
        switch domain.identity {
        case .natural(let keys):
            guard identity.count == keys.count, zip(keys, identity).allSatisfy({ fields[$0.0] == $0.1 && $0.1 != .null }) else { throw BootstrapError.invalidData }
        case .localRowIDWithStableUUID:
            guard identity.count == 1, case .text(let id) = identity[0], UUID(uuidString: id) != nil else { throw BootstrapError.invalidData }
            stableID = id
        case .logReference(let column):
            guard identity.count == 2, case .text(let habit) = identity[0], case .text(let day) = identity[1],
                  fields.removeValue(forKey: "sync_log_habit_id") == .text(habit), fields.removeValue(forKey: "sync_log_local_date") == .text(day) else { throw BootstrapError.invalidData }
            fields[column] = .integer(try findLog(habit: habit, day: day, db: db))
        case .localMetadata: throw BootstrapError.invalidData
        }
        let allowed = try tableColumns(item.table, db: db)
        let generatedIDTables: Set<String> = ["habit_logs", "point_transactions", "habit_activity_entries", "timer_sessions", "badge_plan_intervals"]
        let expected = generatedIDTables.contains(item.table) ? allowed.subtracting(["id"]) : allowed
        guard Set(fields.keys) == expected, !fields.isEmpty else { throw BootstrapError.invalidData }
        let columns = fields.keys.sorted()
        let sql = "INSERT INTO \(item.table)(\(columns.joined(separator: ","))) VALUES(\(Array(repeating: "?", count: columns.count).joined(separator: ",")))"
        let statement = try NativeDatabase.prepare(sql, in: db)
        defer { sqlite3_finalize(statement) }
        for (index, key) in columns.enumerated() { try bind(fields[key]!, to: statement, at: Int32(index + 1)) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw BootstrapError.sqlite }
        if let stableID {
            let mapping = try NativeDatabase.prepare("INSERT INTO sync_row_identity(table_name,local_id,stable_id) VALUES(?,?,?)", in: db)
            defer { sqlite3_finalize(mapping) }
            try bind(.text(item.table), to: mapping, at: 1)
            sqlite3_bind_int64(mapping, 2, sqlite3_last_insert_rowid(db))
            try bind(.text(stableID), to: mapping, at: 3)
            guard sqlite3_step(mapping) == SQLITE_DONE else { throw BootstrapError.sqlite }
        }
    }

    private func tableColumns(_ table: String, db: OpaquePointer) throws -> Set<String> {
        let stmt = try NativeDatabase.prepare("PRAGMA table_info(\(table))", in: db)
        defer { sqlite3_finalize(stmt) }
        var names = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW { if let name = sqlite3_column_text(stmt, 1) { names.insert(String(cString: name)) } }
        return names
    }

    private func findLog(habit: String, day: String, db: OpaquePointer) throws -> Int64 {
        let stmt = try NativeDatabase.prepare("SELECT id FROM habit_logs WHERE habit_id=? AND local_date=?", in: db)
        defer { sqlite3_finalize(stmt) }
        try bind(.text(habit), to: stmt, at: 1); try bind(.text(day), to: stmt, at: 2)
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw BootstrapError.missingDependency }
        return sqlite3_column_int64(stmt, 0)
    }

    private func bind(_ value: SyncFieldValue, to statement: OpaquePointer, at index: Int32) throws {
        let result: Int32
        switch value {
        case .null: result = sqlite3_bind_null(statement, index)
        case .integer(let number): result = sqlite3_bind_int64(statement, index, number)
        case .real(let number):
            guard number.isFinite else { throw BootstrapError.invalidData }
            result = sqlite3_bind_double(statement, index, number)
        case .text(let string): result = string.withCString { sqlite3_bind_text(statement, index, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        case .blob(let data):
            result = data.isEmpty ? sqlite3_bind_zeroblob(statement, index, 0) : data.withUnsafeBytes { sqlite3_bind_blob(statement, index, $0.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        }
        guard result == SQLITE_OK else { throw BootstrapError.sqlite }
    }
}
