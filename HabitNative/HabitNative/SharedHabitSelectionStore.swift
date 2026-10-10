import Foundation
import SQLite3

struct HabitSelectionSnapshot {
    var activeIDs: Set<String> = []
    var starredIDs: Set<String> = []
    var quotaExemptIDs: Set<String> = []
    var retainedPeriodicIDs: Set<String> = []
    var completedPeriodicIDs: Set<String> = []
    var starLimit = 1
    var isFirstSelection = false
}

struct HabitDashboardSnapshot {
    let points: Int
    let missedYesterday: Int
}

enum HabitSelectionError: Error {
    case databaseUnavailable
    case databaseFailure(String)
    case quotaExceeded
    case invalidStarredSelection
    case starLimitExceeded(Int)
    case firstSelectionRequiresGoal
}

struct SharedHabitSelectionStore {
    private let database: NativeDatabase

    init(databaseURL: URL? = nil) {
        database = NativeDatabase(fileURL: databaseURL, legacyURL: databaseURL == nil ? NativeDatabase.legacyDatabaseURL : nil)
    }

    private struct Row {
        let id: String
        let starred: Bool
        let activeOn: Date?
    }

    func dashboard(at date: Date) throws -> HabitDashboardSnapshot {
        try database.withConnection { db in
            let points = try scalar("SELECT COALESCE(SUM(amount), 0) FROM point_transactions", in: db)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
            let parts = Calendar.current.dateComponents([.year, .month, .day], from: yesterday)
            let key = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            let statement = try prepare("SELECT COUNT(*) FROM missed_habit_records WHERE local_date = ?", in: db)
            defer { sqlite3_finalize(statement) }
            bind(key, to: 1, in: statement)
            guard sqlite3_step(statement) == SQLITE_ROW else { throw failure(in: db) }
            return HabitDashboardSnapshot(points: points, missedYesterday: Int(sqlite3_column_int(statement, 0)))
        }
    }

    func snapshot(at date: Date) throws -> HabitSelectionSnapshot {
        try database.withConnection { db in
            let rows = try selections(in: db)
            var snapshot = HabitSelectionSnapshot()
            snapshot.isFirstSelection = rows.isEmpty
            snapshot.starLimit = try scalar("SELECT COUNT(*) FROM habit_logs", in: db) >= 6 ? 2 : 1
            for row in rows {
                let periodic = Self.isPeriodic(row.id)
                let periodKey = Self.periodKey(row.id, date)
                let completedAt = periodic ? try completionDate(for: row.id, periodKey: periodKey, in: db) : nil
                if let completedAt, !Calendar.current.isDate(completedAt, inSameDayAs: date) {
                    snapshot.completedPeriodicIDs.insert(row.id)
                }
                if row.starred { snapshot.starredIDs.insert(row.id) }
                if periodic && row.activeOn.map({ Self.periodKey(row.id, $0) == periodKey }) == true {
                    snapshot.retainedPeriodicIDs.insert(row.id)
                }
                if row.starred || snapshot.retainedPeriodicIDs.contains(row.id) {
                    snapshot.quotaExemptIDs.insert(row.id)
                }
                let selected = row.starred || periodic || row.activeOn.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
                guard selected else { continue }
                if periodic {
                    if let completedAt {
                        guard Calendar.current.isDate(completedAt, inSameDayAs: date) else { continue }
                    } else {
                        guard row.activeOn.map({ Self.periodKey(row.id, $0) == periodKey }) == true else { continue }
                    }
                }
                snapshot.activeIDs.insert(row.id)
            }
            return snapshot
        }
    }

    func save(_ ids: Set<String>, starredIDs: Set<String>, at date: Date) throws {
        try database.withConnection { db in
            let rows = try selections(in: db)
            let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
            guard starredIDs.isSubset(of: ids) else { throw HabitSelectionError.invalidStarredSelection }
            let starLimit = try scalar("SELECT COUNT(*) FROM habit_logs", in: db) >= 6 ? 2 : 1
            guard starredIDs.count <= starLimit else { throw HabitSelectionError.starLimitExceeded(starLimit) }
            if rows.isEmpty && ids.isEmpty { throw HabitSelectionError.firstSelectionRequiresGoal }
            if rows.isEmpty && !starredIDs.isEmpty { throw HabitSelectionError.invalidStarredSelection }
            let regularCount = ids.filter { id in
                if starredIDs.contains(id) { return false }
                guard Self.isPeriodic(id), let activeOn = byID[id]?.activeOn else { return true }
                return Self.periodKey(id, activeOn) != Self.periodKey(id, date)
            }.count
            guard regularCount <= 3 else { throw HabitSelectionError.quotaExceeded }
            try execute("BEGIN IMMEDIATE", in: db)
            do {
                for row in rows where !ids.contains(row.id) {
                    try update(id: row.id, activeOn: nil, starred: false, in: db)
                }
                for id in ids {
                    if byID[id] != nil {
                        try update(id: id, activeOn: date, starred: starredIDs.contains(id), in: db)
                    } else {
                        try insert(id: id, at: date, starred: starredIDs.contains(id), in: db)
                    }
                }
                try execute("COMMIT", in: db)
            } catch {
                try? execute("ROLLBACK", in: db)
                throw error
            }
        }
    }

    private func selections(in db: OpaquePointer) throws -> [Row] {
        let statement = try prepare("SELECT habit_id, is_starred, active_on FROM habit_selections", in: db)
        defer { sqlite3_finalize(statement) }
        var rows: [Row] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let raw = sqlite3_column_text(statement, 0) else { continue }
            rows.append(Row(id: String(cString: raw), starred: sqlite3_column_int(statement, 1) != 0,
                            activeOn: sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2)))))
        }
        return rows
    }

    private func completionDate(for id: String, periodKey: String, in db: OpaquePointer) throws -> Date? {
        let statement = try prepare("SELECT completed_at FROM habit_activity_entries WHERE habit_id = ? AND period_key = ? LIMIT 1", in: db)
        defer { sqlite3_finalize(statement) }
        bind(id, to: 1, in: statement)
        bind(periodKey, to: 2, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 0)))
    }

    private func update(id: String, activeOn: Date?, starred: Bool, in db: OpaquePointer) throws {
        let statement = try prepare("UPDATE habit_selections SET active_on = ?, is_starred = ? WHERE habit_id = ?", in: db)
        defer { sqlite3_finalize(statement) }
        if let activeOn { sqlite3_bind_int64(statement, 1, Int64(activeOn.timeIntervalSince1970)) }
        else { sqlite3_bind_null(statement, 1) }
        sqlite3_bind_int(statement, 2, starred ? 1 : 0)
        bind(id, to: 3, in: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure(in: db) }
    }

    private func insert(id: String, at date: Date, starred: Bool, in db: OpaquePointer) throws {
        let statement = try prepare("INSERT INTO habit_selections (habit_id, commitment_note, enabled_at, is_starred, active_on) VALUES (?, '', ?, ?, ?)", in: db)
        defer { sqlite3_finalize(statement) }
        bind(id, to: 1, in: statement)
        sqlite3_bind_int64(statement, 2, Int64(date.timeIntervalSince1970))
        sqlite3_bind_int(statement, 3, starred ? 1 : 0)
        sqlite3_bind_int64(statement, 4, Int64(date.timeIntervalSince1970))
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure(in: db) }
    }

    private func prepare(_ sql: String, in db: OpaquePointer) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure(in: db) }
        return statement
    }

    private func execute(_ sql: String, in db: OpaquePointer) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure(in: db) }
    }

    private func scalar(_ sql: String, in db: OpaquePointer) throws -> Int {
        let statement = try prepare(sql, in: db)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw failure(in: db) }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, index, value, -1, transient)
    }

    private func failure(in db: OpaquePointer) -> HabitSelectionError {
        .databaseFailure(String(cString: sqlite3_errmsg(db)))
    }

    static func isPeriodic(_ id: String) -> Bool { ["H5", "H7", "H10", "H11"].contains(id) }

    static func periodKey(_ id: String, _ date: Date) -> String {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month], from: date)
        if id == "H11" { return "\(parts.year ?? 0)" }
        if id == "H10" { return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0) }
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: date) ?? date
        let mondayParts = calendar.dateComponents([.year, .month, .day], from: monday)
        return String(format: "week-%04d-%02d-%02d", mondayParts.year ?? 0, mondayParts.month ?? 0, mondayParts.day ?? 0)
    }
}
