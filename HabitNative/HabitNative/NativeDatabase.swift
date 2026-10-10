import Foundation
import SQLite3

enum NativeDatabaseError: LocalizedError {
    case unavailable(String)
    case migration(String)
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): "本地数据库不可用：\(message)"
        case .migration(let message): "旧数据迁移失败：\(message)"
        case .unsupportedSchema(let version): "不支持的数据库版本：\(version)"
        }
    }
}

/// The native app writes only to Application Support. The App Group database is an import source.
struct NativeDatabase: Sendable {
    static let schemaVersion = 10
    static let legacyGroup = "group.com.deshiru.habitapp"

    let fileURL: URL
    let legacyURL: URL?

    init(fileURL: URL? = nil, legacyURL: URL? = NativeDatabase.legacyDatabaseURL) {
        self.fileURL = fileURL ?? Self.defaultDatabaseURL
        self.legacyURL = legacyURL
    }

    static var defaultDatabaseURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("HabitNative", isDirectory: true)
            .appendingPathComponent("habit_app.sqlite")
    }

    static var legacyDatabaseURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: legacyGroup)?
            .appendingPathComponent("habit_app.sqlite")
    }

    func withConnection<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        try prepareStoreIfNeeded()
        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(fileURL.path, &pointer, flags, nil) == SQLITE_OK, let db = pointer else {
            let message = pointer.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite 无法打开文件"
            if let pointer { sqlite3_close(pointer) }
            throw NativeDatabaseError.unavailable(message)
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 2500)
        try Self.execute("PRAGMA foreign_keys = ON", in: db)
        return try body(db)
    }

    private func prepareStoreIfNeeded() throws {
        try Self.preparationLock.withLock {
            let manager = FileManager.default
            try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard !manager.fileExists(atPath: fileURL.path) else {
                try migrateExistingDatabase(at: fileURL)
                return
            }

            let temporary = fileURL.deletingLastPathComponent()
                .appendingPathComponent("habit_app.import-\(UUID().uuidString).sqlite")
            defer { try? manager.removeItem(at: temporary) }

            var importedLegacy = false
            if let legacyURL, manager.fileExists(atPath: legacyURL.path), legacyURL.standardizedFileURL != fileURL.standardizedFileURL {
                try backupDatabase(from: legacyURL, to: temporary)
                importedLegacy = true
            } else {
                try createEmptyDatabase(at: temporary)
            }

            try migrateExistingDatabase(at: temporary)
            try setMigrationState(importedLegacy ? "complete" : "source_absent", at: temporary)
            try verifyIntegrity(at: temporary)
            if importedLegacy, let legacyURL {
                try verifyRowCounts(source: legacyURL, destination: temporary)
            }
            try manager.moveItem(at: temporary, to: fileURL)
        }
    }

    private static let preparationLock = NSRecursiveLock()

    private func createEmptyDatabase(at url: URL) throws {
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db = pointer else {
            throw NativeDatabaseError.unavailable("无法创建 \(url.lastPathComponent)")
        }
        defer { sqlite3_close(db) }
        try Self.createSchemaV10(in: db)
    }

    private func backupDatabase(from sourceURL: URL, to destinationURL: URL) throws {
        var source: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &source, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let source else {
            throw NativeDatabaseError.migration("无法只读打开旧库")
        }
        defer { sqlite3_close(source) }
        sqlite3_busy_timeout(source, 5000)

        var destination: OpaquePointer?
        guard sqlite3_open_v2(destinationURL.path, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let destination else {
            throw NativeDatabaseError.migration("无法创建导入快照")
        }
        defer { sqlite3_close(destination) }
        sqlite3_busy_timeout(destination, 5000)

        guard let backup = sqlite3_backup_init(destination, "main", source, "main") else {
            throw NativeDatabaseError.migration(String(cString: sqlite3_errmsg(destination)))
        }
        var result = sqlite3_backup_step(backup, -1)
        var attempts = 0
        while result == SQLITE_BUSY || result == SQLITE_LOCKED {
            attempts += 1
            guard attempts <= 200 else { break }
            sqlite3_sleep(25)
            result = sqlite3_backup_step(backup, -1)
        }
        let finishResult = sqlite3_backup_finish(backup)
        guard result == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw NativeDatabaseError.migration(String(cString: sqlite3_errmsg(destination)))
        }
    }

    private func migrateExistingDatabase(at url: URL) throws {
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db = pointer else {
            throw NativeDatabaseError.migration("无法打开迁移目标库")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5000)
        let version = try Self.scalarInt("PRAGMA user_version", in: db)
        guard version <= Self.schemaVersion else { throw NativeDatabaseError.unsupportedSchema(version) }
        let hasTables = try Self.hasUserTables(in: db)
        if version == 0 && !hasTables {
            try Self.createSchemaV10(in: db)
        } else if version < Self.schemaVersion {
            try Self.migrate(from: version, in: db)
        }
        try Self.execute("CREATE TABLE IF NOT EXISTS native_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)", in: db)
        try Self.execute("INSERT OR IGNORE INTO native_metadata(key, value) VALUES ('migration_source', 'app_group_snapshot')", in: db)
    }

    private static func createSchemaV10(in db: OpaquePointer) throws {
        try execute("BEGIN IMMEDIATE", in: db)
        do {
            for sql in schemaV10 { try execute(sql, in: db) }
            try execute("PRAGMA user_version = 10", in: db)
            try execute("COMMIT", in: db)
        } catch {
            try? execute("ROLLBACK", in: db)
            throw error
        }
    }

    private static func migrate(from version: Int, in db: OpaquePointer) throws {
        try execute("BEGIN IMMEDIATE", in: db)
        do {
            if version < 2 {
                try execute(schemaV10[3], in: db) // review_entries
                try execute(schemaV10[4], in: db) // timer_sessions
                try execute(schemaV10[5], in: db) // challenge_draws
            }
            if try version >= 2 && version < 3 && !hasColumn("challenge_draws", "swap_count", in: db) {
                try execute("ALTER TABLE challenge_draws ADD COLUMN swap_count INTEGER NOT NULL DEFAULT 0", in: db)
                try execute("UPDATE challenge_draws SET swap_count = 1 WHERE swap_used = 1", in: db)
            }
            if try version >= 2 && version < 4 && !hasColumn("timer_sessions", "focus_topic", in: db) {
                try execute("ALTER TABLE timer_sessions ADD COLUMN focus_topic TEXT", in: db)
            }
            if version < 5 { try execute(schemaV10[6], in: db) }
            if version < 6 { try execute(schemaV10[7], in: db) }
            if try version < 7 && !hasColumn("habit_selections", "is_starred", in: db) {
                try execute("ALTER TABLE habit_selections ADD COLUMN is_starred INTEGER NOT NULL DEFAULT 0", in: db)
            }
            if version < 8 {
                if try !hasColumn("habit_selections", "active_on", in: db) {
                    try execute("ALTER TABLE habit_selections ADD COLUMN active_on INTEGER", in: db)
                }
                try execute("UPDATE habit_selections SET active_on = enabled_at", in: db)
            }
            if version < 9 { try execute(schemaV10[8], in: db) }
            if try version < 10 && !hasColumn("missed_habit_records", "settled_on", in: db) {
                try execute("ALTER TABLE missed_habit_records ADD COLUMN settled_on TEXT", in: db)
            }
            for sql in schemaV10 where sql.contains("CREATE INDEX") { try execute(sql, in: db) }
            try execute("PRAGMA user_version = 10", in: db)
            try execute("COMMIT", in: db)
        } catch {
            try? execute("ROLLBACK", in: db)
            throw error
        }
    }

    private static let schemaV10 = [
        "CREATE TABLE IF NOT EXISTS habit_selections (habit_id TEXT NOT NULL PRIMARY KEY, commitment_note TEXT NOT NULL DEFAULT '', enabled_at INTEGER NOT NULL, is_starred INTEGER NOT NULL DEFAULT 0, active_on INTEGER)",
        "CREATE TABLE IF NOT EXISTS habit_logs (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, habit_id TEXT NOT NULL, local_date TEXT NOT NULL, timezone_offset_minutes INTEGER NOT NULL, created_at INTEGER NOT NULL, UNIQUE(habit_id, local_date))",
        "CREATE TABLE IF NOT EXISTS point_transactions (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, habit_log_id INTEGER NOT NULL UNIQUE REFERENCES habit_logs(id), amount INTEGER NOT NULL, created_at INTEGER NOT NULL)",
        "CREATE TABLE IF NOT EXISTS review_entries (local_date TEXT NOT NULL PRIMARY KEY, decision TEXT NOT NULL, result TEXT NOT NULL, improvement TEXT NOT NULL, updated_at INTEGER NOT NULL)",
        "CREATE TABLE IF NOT EXISTS timer_sessions (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, habit_id TEXT NOT NULL, target_seconds INTEGER NOT NULL, started_at INTEGER NOT NULL, paused_at INTEGER, accumulated_pause_seconds INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'running', ended_at INTEGER, focus_topic TEXT)",
        "CREATE TABLE IF NOT EXISTS challenge_draws (local_date TEXT NOT NULL PRIMARY KEY, card_index INTEGER NOT NULL, swap_used INTEGER NOT NULL DEFAULT 0, swap_count INTEGER NOT NULL DEFAULT 0)",
        "CREATE TABLE IF NOT EXISTS habit_activity_entries (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, habit_id TEXT NOT NULL, period_key TEXT NOT NULL, primary_text TEXT NOT NULL, secondary_text TEXT NOT NULL DEFAULT '', first_value REAL, second_value REAL, completed_at INTEGER NOT NULL, UNIQUE(habit_id, period_key))",
        "CREATE TABLE IF NOT EXISTS travel_plans (year INTEGER NOT NULL PRIMARY KEY, destination TEXT NOT NULL, days INTEGER NOT NULL, focus TEXT NOT NULL, preparation TEXT NOT NULL DEFAULT '', planned_at INTEGER NOT NULL)",
        "CREATE TABLE IF NOT EXISTS missed_habit_records (habit_id TEXT NOT NULL, local_date TEXT NOT NULL, settled_on TEXT, PRIMARY KEY(habit_id, local_date))"
    ]

    private func verifyIntegrity(at url: URL) throws {
        try withTemporaryConnection(at: url) { db in
            let statement = try Self.prepare("PRAGMA integrity_check", in: db)
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let raw = sqlite3_column_text(statement, 0), String(cString: raw) == "ok" else {
                throw NativeDatabaseError.migration("PRAGMA integrity_check 未通过")
            }
        }
    }

    private func verifyRowCounts(source: URL, destination: URL) throws {
        try withTemporaryConnection(at: source) { sourceDB in
            try withTemporaryConnection(at: destination) { destinationDB in
                for table in Self.dataTables {
                    let sourceCount = (try? Self.scalarInt("SELECT COUNT(*) FROM \(table)", in: sourceDB)) ?? 0
                    let destinationCount = try Self.scalarInt("SELECT COUNT(*) FROM \(table)", in: destinationDB)
                    guard sourceCount == destinationCount else {
                        throw NativeDatabaseError.migration("\(table) 行数不一致（旧 \(sourceCount)，新 \(destinationCount)）")
                    }
                }
                let aggregates = [
                    "SELECT COALESCE(SUM(amount), 0) || ':' || COUNT(*) FROM point_transactions",
                    "SELECT COALESCE(group_concat(value, '|'), '') FROM (SELECT habit_id || ':' || COUNT(*) AS value FROM habit_logs GROUP BY habit_id ORDER BY habit_id)",
                    "SELECT COALESCE(group_concat(value, '|'), '') FROM (SELECT habit_id || ':' || enabled_at AS value FROM habit_selections ORDER BY habit_id)"
                ]
                for query in aggregates {
                    let oldValue = try Self.scalarText(query, in: sourceDB)
                    let newValue = try Self.scalarText(query, in: destinationDB)
                    guard oldValue == newValue else { throw NativeDatabaseError.migration("关键数据聚合校验不一致：\(query)") }
                }
            }
        }
    }

    private func withTemporaryConnection<T>(at url: URL, _ body: (OpaquePointer) throws -> T) throws -> T {
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db = pointer else { throw NativeDatabaseError.migration("无法验证数据库快照") }
        defer { sqlite3_close(db) }
        return try body(db)
    }

    static let dataTables = [
        "habit_selections", "habit_logs", "point_transactions", "review_entries",
        "timer_sessions", "challenge_draws", "habit_activity_entries", "travel_plans",
        "missed_habit_records"
    ]

    private static func hasUserTables(in db: OpaquePointer) throws -> Bool {
        try scalarInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'", in: db) > 0
    }

    private static func hasColumn(_ table: String, _ column: String, in db: OpaquePointer) throws -> Bool {
        let statement = try prepare("PRAGMA table_info(\(table))", in: db)
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let raw = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: raw) == column { return true }
        }
        return false
    }

    private func setMigrationState(_ state: String, at url: URL) throws {
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db = pointer else {
            throw NativeDatabaseError.migration("无法更新迁移标记")
        }
        defer { sqlite3_close(db) }
        try Self.execute(
            "INSERT OR REPLACE INTO native_metadata(key, value) VALUES ('migration_state', ?)",
            bindings: [state], in: db
        )
    }

    static func prepare(_ sql: String, in db: OpaquePointer) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    static func execute(_ sql: String, in db: OpaquePointer) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db)))
        }
    }

    static func execute(_ sql: String, bindings: [String], in db: OpaquePointer) throws {
        let statement = try prepare(sql, in: db)
        defer { sqlite3_finalize(statement) }
        for (offset, value) in bindings.enumerated() {
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, Int32(offset + 1), value, -1, transient)
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db)))
        }
    }

    static func scalarInt(_ sql: String, in db: OpaquePointer) throws -> Int {
        let statement = try prepare(sql, in: db)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    static func scalarText(_ sql: String, in db: OpaquePointer) throws -> String {
        let statement = try prepare(sql, in: db)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
        return sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
    }
}

private extension NSRecursiveLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
