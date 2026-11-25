import Foundation
import SQLite3

/// Values retain SQLite types so financial values, timestamps and empty fields
/// are not converted into locale-dependent display strings.
enum SyncFieldValue: Codable, Equatable, Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
}

struct SyncSnapshotItem: Codable, Equatable, Sendable {
    let entityKey: String
    let table: String
    let fields: [String: SyncFieldValue]
}

/// Read-only with respect to user data. Local row IDs receive stable UUID mappings
/// in the same database transaction so future imports can remap foreign keys safely.
struct SyncSnapshotReader {
    enum SnapshotError: Error { case unknownSchema(Set<String>), missingSchema(Set<String>), invalidIdentity, invalidReference, sqlite }
    let database: NativeDatabase

    func read() throws -> [SyncSnapshotItem] {
        try database.withConnection { db in
            try NativeDatabase.execute("BEGIN IMMEDIATE", in: db)
            do {
                let items = try read(in: db)
                try NativeDatabase.execute("COMMIT", in: db)
                return items.sorted { $0.entityKey < $1.entityKey }
            } catch {
                try? NativeDatabase.execute("ROLLBACK", in: db)
                throw error
            }
        }
    }

    /// Caller holds the write transaction while comparing and applying data.
    func read(in db: OpaquePointer) throws -> [SyncSnapshotItem] {
        let tables = try tableNames(db)
        let unknown = SyncDomainCatalog.unknownTables(in: tables)
        guard unknown.isEmpty else { throw SnapshotError.unknownSchema(unknown) }
        let missing = Set(SyncDomainCatalog.domains.map(\.table)).subtracting(tables)
        guard missing.isEmpty else { throw SnapshotError.missingSchema(missing) }
        try NativeDatabase.execute("CREATE TABLE IF NOT EXISTS sync_row_identity (table_name TEXT NOT NULL, local_id INTEGER NOT NULL, stable_id TEXT NOT NULL, PRIMARY KEY(table_name, local_id), UNIQUE(table_name, stable_id))", in: db)
        var items: [SyncSnapshotItem] = []
        for domain in SyncDomainCatalog.domains {
            guard tables.contains(domain.table), domain.identity != .localMetadata else { continue }
            let statement = try NativeDatabase.prepare("SELECT * FROM \(domain.table)", in: db)
            defer { sqlite3_finalize(statement) }
            while true {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE { break }
                guard result == SQLITE_ROW else { throw SnapshotError.sqlite }
                var fields: [String: SyncFieldValue] = [:]
                for index in 0..<sqlite3_column_count(statement) {
                    guard let rawName = sqlite3_column_name(statement, index) else { throw SnapshotError.sqlite }
                    fields[String(cString: rawName)] = try value(statement, index)
                }
                let identity: [SyncFieldValue]
                switch domain.identity {
                case .natural(let names):
                    identity = try names.map { name in guard let field = fields[name], field != .null else { throw SnapshotError.invalidIdentity }; return field }
                case .localRowIDWithStableUUID(let column):
                    guard case .integer(let localID) = fields[column] else { throw SnapshotError.invalidIdentity }
                    identity = [.text(try stableID(table: domain.table, localID: localID, db: db))]
                case .logReference(let column):
                    guard case .integer(let logID) = fields[column] else { throw SnapshotError.invalidReference }
                    let referenced = try logIdentity(logID, db: db)
                    identity = referenced
                    fields.removeValue(forKey: column)
                    fields["sync_log_habit_id"] = referenced[0]
                    fields["sync_log_local_date"] = referenced[1]
                case .localMetadata: continue
                }
                // Database-generated IDs are local implementation details, not cross-device identities.
                if ["habit_logs", "point_transactions", "habit_activity_entries", "timer_sessions", "badge_plan_intervals"].contains(domain.table) {
                    fields.removeValue(forKey: "id")
                }
                let keyData = try JSONEncoder().encode(identity)
                let key = domain.table + ":" + keyData.base64EncodedString()
                items.append(SyncSnapshotItem(entityKey: key, table: domain.table, fields: fields))
            }
        }
        guard Set(items.map(\.entityKey)).count == items.count else { throw SnapshotError.invalidIdentity }
        return items.sorted { $0.entityKey < $1.entityKey }
    }

    private func tableNames(_ db: OpaquePointer) throws -> Set<String> {
        let stmt = try NativeDatabase.prepare("SELECT name FROM sqlite_master WHERE type='table'", in: db)
        defer { sqlite3_finalize(stmt) }
        var names = Set<String>()
        while true {
            let result = sqlite3_step(stmt)
            if result == SQLITE_DONE { return names }
            guard result == SQLITE_ROW, let name = sqlite3_column_text(stmt, 0) else { throw SnapshotError.sqlite }
            names.insert(String(cString: name))
        }
    }

    private func value(_ stmt: OpaquePointer, _ index: Int32) throws -> SyncFieldValue {
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_NULL: return .null
        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(stmt, index))
        case SQLITE_FLOAT: return .real(sqlite3_column_double(stmt, index))
        case SQLITE_TEXT:
            guard let raw = sqlite3_column_text(stmt, index) else { throw SnapshotError.sqlite }
            return .text(String(cString: raw))
        case SQLITE_BLOB:
            let size = Int(sqlite3_column_bytes(stmt, index))
            if size == 0 { return .blob(Data()) }
            guard let bytes = sqlite3_column_blob(stmt, index) else { throw SnapshotError.sqlite }
            return .blob(Data(bytes: bytes, count: size))
        default: throw SnapshotError.sqlite
        }
    }

    private func stableID(table: String, localID: Int64, db: OpaquePointer) throws -> String {
        let lookup = try NativeDatabase.prepare("SELECT stable_id FROM sync_row_identity WHERE table_name=? AND local_id=?", in: db)
        defer { sqlite3_finalize(lookup) }
        bind(table, lookup, 1); sqlite3_bind_int64(lookup, 2, localID)
        let result = sqlite3_step(lookup)
        if result == SQLITE_ROW, let raw = sqlite3_column_text(lookup, 0) { return String(cString: raw) }
        guard result == SQLITE_DONE else { throw SnapshotError.sqlite }
        let id = UUID().uuidString
        let insert = try NativeDatabase.prepare("INSERT INTO sync_row_identity(table_name,local_id,stable_id) VALUES(?,?,?)", in: db)
        defer { sqlite3_finalize(insert) }
        bind(table, insert, 1); sqlite3_bind_int64(insert, 2, localID); bind(id, insert, 3)
        guard sqlite3_step(insert) == SQLITE_DONE else { throw SnapshotError.sqlite }
        return id
    }

    private func logIdentity(_ id: Int64, db: OpaquePointer) throws -> [SyncFieldValue] {
        let stmt = try NativeDatabase.prepare("SELECT habit_id,local_date FROM habit_logs WHERE id=?", in: db)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_ROW, let habit = sqlite3_column_text(stmt, 0), let day = sqlite3_column_text(stmt, 1) else { throw SnapshotError.invalidReference }
        return [.text(String(cString: habit)), .text(String(cString: day))]
    }

    private func bind(_ value: String, _ stmt: OpaquePointer, _ index: Int32) {
        _ = value.withCString { sqlite3_bind_text(stmt, index, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }
}
