import Foundation
import SQLite3

@main
struct NativeDataLayerTests {
    static func main() throws {
        try migrationIsOneTimeAndValid()
        try submissionsUseOriginalRules()
        try timerAndChallengeRulesPersist()
        print("PASS: native SQLite migration and Habit H1–H12 data smoke checks")
    }

    private static func migrationIsOneTimeAndValid() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("legacy.sqlite")
        let nativeURL = root.appendingPathComponent("Application Support/habit.sqlite")
        createLegacyDatabase(at: legacy)
        let native = NativeDatabase(fileURL: nativeURL, legacyURL: legacy)
        try native.withConnection { db in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM habit_logs", in: db) == 1, "backup imports historical logs")
            try expect(NativeDatabase.scalarText("SELECT value FROM native_metadata WHERE key='migration_state'", in: db) == "complete", "migration marker is recorded")
            try expect(NativeDatabase.scalarText("PRAGMA integrity_check", in: db) == "ok", "SQLite integrity check")
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM challenge_history WHERE cycle=1 AND card_index=17", in: db) == 1, "migration carries previously shown H3 challenges into the no-repeat history")
            try NativeDatabase.execute("INSERT INTO habit_logs(habit_id, local_date, timezone_offset_minutes, created_at) VALUES ('H2','2026-10-11',480,200)", in: db)
        }
        try native.withConnection { db in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM habit_logs", in: db) == 2, "subsequent opens do not re-import over native writes")
        }
        try withReadOnlyDatabase(legacy) { db in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM habit_logs", in: db) == 1, "legacy database remains unchanged")
        }
        try native.clearAllUserData()
        try native.withConnection { db in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM habit_logs", in: db) == 0, "settings reset clears native habit records")
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM point_transactions", in: db) == 0, "settings reset clears points")
            try expect(NativeDatabase.scalarText("SELECT value FROM native_metadata WHERE key='migration_state'", in: db) == "complete", "settings reset preserves the one-time migration marker")
            try expect(NativeDatabase.scalarText("PRAGMA integrity_check", in: db) == "ok", "reset database remains valid")
        }
    }

    private static func submissionsUseOriginalRules() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let db = NativeDatabase(fileURL: root.appendingPathComponent("native.sqlite"), legacyURL: nil)
        let now = Date.now
        try db.withConnection { connection in
            try NativeDatabase.execute("INSERT INTO habit_selections(habit_id, commitment_note, enabled_at, is_starred, active_on) VALUES ('H1','',\(epoch(now)),0,\(epoch(now)))", in: connection)
            try NativeDatabase.execute("INSERT INTO habit_selections(habit_id, commitment_note, enabled_at, is_starred, active_on) VALUES ('H6','',\(epoch(now)),1,\(epoch(now)))", in: connection)
        }
        let hundred = String(repeating: "中文", count: 50)
        let backfill = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        try db.submit(GoalEntry(goalID: "H1", date: backfill, payload: .review(decision: hundred, result: "", improvement: "")))
        try db.withConnection { connection in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM habit_logs WHERE habit_id='H1'", in: connection) == 0, "backfilled reviews do not create completion logs")
        }
        let belowTarget = String(repeating: "字", count: 99)
        try db.submit(GoalEntry(goalID: "H1", date: now, payload: .review(decision: belowTarget, result: "", improvement: "")))
        try db.withConnection { connection in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM habit_logs WHERE habit_id='H1'", in: connection) == 0, "99 characters do not meet H1 threshold")
        }
        try db.submit(GoalEntry(goalID: "H1", date: now, payload: .review(decision: hundred, result: "", improvement: "")))
        let persistedReview = try db.reviewEntry(on: now)
        try expect(persistedReview?.decision == hundred, "H1 form can reload its saved content for editing")
        try db.submit(GoalEntry(goalID: "H6", date: now, payload: .activity(primaryText: "清理信息", secondaryText: "可选", firstValue: nil, secondValue: nil)))
        try db.withConnection { connection in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM habit_logs", in: connection) == 2, "valid review and starred activity create logs")
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM point_transactions WHERE amount=0", in: connection) == 1, "starred completion keeps its log and gives zero points")
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM review_entries", in: connection) == 2, "today and backfilled reviews are persisted")
            let metrics = try db.goalMetrics(in: connection, today: now)
            try expect(metrics.completedTodayIDs.contains("H1") && metrics.completedTodayIDs.contains("H6"), "completed selected habits remain identifiable for the selected-habits deck")
        }
        try expectThrows("ordinary primary text length is enforced") {
            try db.submit(GoalEntry(goalID: "H6", date: now, payload: .activity(primaryText: "超过五个字", secondaryText: "", firstValue: nil, secondValue: nil)))
        }
        try db.submit(GoalEntry(goalID: "H5", date: now, payload: .activity(primaryText: "旧友", secondaryText: "联系", firstValue: nil, secondValue: nil)))
        try expectThrows("a periodic habit cannot be completed twice in one period") {
            try db.submit(GoalEntry(goalID: "H5", date: now, payload: .activity(primaryText: "另一位", secondaryText: "", firstValue: nil, secondValue: nil)))
        }
        try db.submit(GoalEntry(goalID: "H11", date: now, payload: .travelPlan(destination: "东京", days: 4, focus: "独处", preparation: "车票", summary: "", completed: false)))
        try expect(try db.travelPlan(year: Calendar.current.component(.year, from: now))?.destination == "东京", "annual travel plan can be loaded from private database")
        try db.submit(GoalEntry(goalID: "H11", date: now, payload: .travelPlan(destination: "东京", days: 4, focus: "独处", preparation: "车票", summary: "学会独自安排", completed: true)))
        try db.withConnection { connection in
            try expect(NativeDatabase.scalarInt("SELECT SUM(amount) FROM point_transactions", in: connection) == 103, "points respect star and periodic multipliers")
        }
    }

    private static func timerAndChallengeRulesPersist() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let db = NativeDatabase(fileURL: root.appendingPathComponent("native.sqlite"), legacyURL: nil)
        try expect(HabitTaskCatalog.challengeCards.count == 500, "challenge corpus has the original 500 cards")
        try expect(Set(HabitTaskCatalog.challengeCards).count == 500, "challenge cards remain unique")
        try expect(HabitTaskCatalog.thinkingTopics(for: .now).count == 3, "daily recommended topics return three entries")
        try expect(Set(HabitTaskCatalog.thinkingTopics(for: .now)).count == 3, "daily recommended topics are distinct")
        try expectThrows("H2 cannot start without a thinking topic") {
            _ = try db.startTimer(habitID: "H2", targetSeconds: 1800, focusTopic: "  ", at: .now)
        }

        let date = Date.now
        let challenge = try db.challengeForToday(at: date)
        var dailyChoices: Set<Int> = []
        for expectedCount in 1...3 {
            let next = try db.swapChallenge(at: date)
            try expect(next.cardIndex != challenge.cardIndex && dailyChoices.insert(next.cardIndex).inserted, "the first three daily H3 swaps draw distinct unseen questions")
            try expect(next.swapCount == expectedCount, "H3 persists the daily swap count")
        }
        try expect(dailyChoices.count == 3, "H3 captures exactly three fresh daily choices")
        for _ in 4...20 {
            let next = try db.swapChallenge(at: date)
            try expect(dailyChoices.contains(next.cardIndex), "the fourth and later H3 swaps recycle only today's three choices")
        }
        try db.withConnection { connection in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM challenge_daily_swaps", in: connection) == 3, "only three fresh choices are persisted for the day")
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM challenge_history WHERE cycle=1", in: connection) == 4, "recycled daily choices do not consume new questions")
        }
        for offset in 1...496 {
            let nextDate = Calendar.current.date(byAdding: .day, value: offset, to: date)!
            _ = try db.challengeForToday(at: nextDate)
        }
        let nextCycleDate = Calendar.current.date(byAdding: .day, value: 497, to: date)!
        _ = try db.challengeForToday(at: nextCycleDate)
        try db.withConnection { connection in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM challenge_history WHERE cycle=1", in: connection) == 500, "H3 history preserves every unique question in the first cycle")
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM challenge_history WHERE cycle=2", in: connection) == 1, "H3 begins a new cycle only after exhausting the question pool")
        }

        let start = date.addingTimeInterval(-3)
        let focus = try db.startTimer(habitID: "H2", targetSeconds: 1, focusTopic: "topic", at: start)
        try db.pauseFocusSession(focus, at: start.addingTimeInterval(1))
        let pauseTotal = try db.resumeFocusSession(focus, at: start.addingTimeInterval(2))
        try expect(pauseTotal == 1, "H2 pause is accumulated")
        try db.submit(GoalEntry(goalID: "H2", date: date, payload: .focus(sessionID: focus)))
        try db.withConnection { connection in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM timer_sessions WHERE habit_id='H2' AND status='completed'", in: connection) == 1, "completed focus session is persisted")
        }
        let endedEarly = try db.startTimer(habitID: "H2", targetSeconds: 1800, focusTopic: "topic", at: date)
        try db.endFocusSessionEarly(endedEarly, at: date.addingTimeInterval(30))
        try db.withConnection { connection in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM timer_sessions WHERE id=\(endedEarly) AND status='failed'", in: connection) == 1, "H2 early end is persisted as failed")
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM habit_logs WHERE habit_id='H2'", in: connection) == 1, "H2 early end does not create a completion log")
        }
        let pausedTooLong = try db.startTimer(habitID: "H2", targetSeconds: 10, focusTopic: "topic", at: start)
        try db.pauseFocusSession(pausedTooLong, at: start.addingTimeInterval(1))
        try expectThrows("H2 pause over five minutes fails") {
            _ = try db.resumeFocusSession(pausedTooLong, at: start.addingTimeInterval(302))
        }
        let timedOutPause = try db.startTimer(habitID: "H2", targetSeconds: 1800, focusTopic: "topic", at: start)
        try db.pauseFocusSession(timedOutPause, at: start.addingTimeInterval(1))
        try expect(try db.failExpiredFocusPause(timedOutPause, at: start.addingTimeInterval(301)) == false, "H2 pause remains valid at exactly five minutes")
        try expect(try db.failExpiredFocusPause(timedOutPause, at: start.addingTimeInterval(302)), "H2 pause automatically expires after five minutes")
        try db.withConnection { connection in
            try expect(NativeDatabase.scalarInt("SELECT COUNT(*) FROM timer_sessions WHERE id=\(timedOutPause) AND status='failed'", in: connection) == 1, "expired H2 pause is persisted as failed")
        }

        let base = date.addingTimeInterval(60)
        for attempt in 0..<3 {
            let started = base.addingTimeInterval(Double(attempt * 2))
            let session = try db.startTimer(habitID: "H4", targetSeconds: 900, at: started)
            try db.abandonDisconnectSession(session, at: started.addingTimeInterval(1))
        }
        try expectThrows("three H4 failures trigger the ten-hour cooldown") {
            _ = try db.startTimer(habitID: "H4", targetSeconds: 900, at: base.addingTimeInterval(5 * 60 * 60))
        }
        _ = try db.startTimer(habitID: "H4", targetSeconds: 900, at: base.addingTimeInterval(11 * 60 * 60))
        try expect(HabitGrowthRules.stage(for: 0) == "种子", "growth stage starts at seed")
        try expect(HabitGrowthRules.stage(for: 3) == "发芽", "growth stage threshold 3")
        try expect(HabitGrowthRules.stage(for: 10) == "成长", "growth stage threshold 10")
        try expect(HabitGrowthRules.stage(for: 25) == "开花", "growth stage threshold 25")
        try expect(HabitGrowthRules.stage(for: 60) == "繁茂", "growth stage threshold 60")
    }

    private static func createLegacyDatabase(at url: URL) {
        var pointer: OpaquePointer?
        guard sqlite3_open(url.path, &pointer) == SQLITE_OK, let db = pointer else { fatalError("create legacy database") }
        defer { sqlite3_close(db) }
        let statements = [
            "CREATE TABLE habit_selections(habit_id TEXT PRIMARY KEY, commitment_note TEXT NOT NULL DEFAULT '', enabled_at INTEGER NOT NULL, is_starred INTEGER NOT NULL DEFAULT 0, active_on INTEGER)",
            "CREATE TABLE habit_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, habit_id TEXT NOT NULL, local_date TEXT NOT NULL, timezone_offset_minutes INTEGER NOT NULL, created_at INTEGER NOT NULL, UNIQUE(habit_id, local_date))",
            "CREATE TABLE point_transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, habit_log_id INTEGER NOT NULL UNIQUE REFERENCES habit_logs(id), amount INTEGER NOT NULL, created_at INTEGER NOT NULL)",
            "CREATE TABLE review_entries(local_date TEXT PRIMARY KEY, decision TEXT NOT NULL, result TEXT NOT NULL, improvement TEXT NOT NULL, updated_at INTEGER NOT NULL)",
            "CREATE TABLE timer_sessions(id INTEGER PRIMARY KEY AUTOINCREMENT, habit_id TEXT NOT NULL, target_seconds INTEGER NOT NULL, started_at INTEGER NOT NULL, paused_at INTEGER, accumulated_pause_seconds INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'running', ended_at INTEGER, focus_topic TEXT)",
            "CREATE TABLE challenge_draws(local_date TEXT PRIMARY KEY, card_index INTEGER NOT NULL, swap_used INTEGER NOT NULL DEFAULT 0, swap_count INTEGER NOT NULL DEFAULT 0)",
            "CREATE TABLE habit_activity_entries(id INTEGER PRIMARY KEY AUTOINCREMENT, habit_id TEXT NOT NULL, period_key TEXT NOT NULL, primary_text TEXT NOT NULL, secondary_text TEXT NOT NULL DEFAULT '', first_value REAL, second_value REAL, completed_at INTEGER NOT NULL, UNIQUE(habit_id, period_key))",
            "CREATE TABLE travel_plans(year INTEGER PRIMARY KEY, destination TEXT NOT NULL, days INTEGER NOT NULL, focus TEXT NOT NULL, preparation TEXT NOT NULL DEFAULT '', planned_at INTEGER NOT NULL)",
            "CREATE TABLE missed_habit_records(habit_id TEXT NOT NULL, local_date TEXT NOT NULL, settled_on TEXT, PRIMARY KEY(habit_id, local_date))",
            "INSERT INTO habit_selections(habit_id, enabled_at, active_on) VALUES ('H1', 100, 100)",
            "INSERT INTO habit_logs(habit_id, local_date, timezone_offset_minutes, created_at) VALUES ('H1', '2026-10-10', 480, 100)",
            "INSERT INTO challenge_draws(local_date, card_index, swap_used, swap_count) VALUES ('2026-10-10', 17, 0, 0)",
            "INSERT INTO point_transactions(habit_log_id, amount, created_at) VALUES (1, 1, 100)",
            "PRAGMA user_version=10"
        ]
        for sql in statements where sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            fatalError("legacy SQL failed: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private static func withReadOnlyDatabase<T>(_ url: URL, _ body: (OpaquePointer) throws -> T) throws -> T {
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db = pointer else { throw TestFailure(message: "open source read-only") }
        defer { sqlite3_close(db) }
        return try body(db)
    }

    private static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("habit-native-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func epoch(_ date: Date) -> Int { Int(date.timeIntervalSince1970) }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure(message: message) }
    }

    private static func expectThrows(_ message: String, _ body: () throws -> Void) throws {
        do { try body(); throw TestFailure(message: "expected rejection: \(message)") }
        catch is TestFailure { throw TestFailure(message: "expected rejection: \(message)") }
        catch { }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
