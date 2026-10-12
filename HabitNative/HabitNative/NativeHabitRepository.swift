import Foundation
import SQLite3

struct HabitGoalMetrics {
    let completionCounts: [String: Int]
    let growthProgress: [String: Int]
    let completedTodayIDs: Set<String>
}

struct NativeReviewRecord: Sendable {
    let decision: String
    let result: String
    let improvement: String
}

struct NativeDisconnectStatus: Sendable {
    let consecutiveFailures: Int
    let lockedUntil: Date?
}

enum HabitSubmissionError: LocalizedError {
    case invalid(String)
    case alreadyCompleted

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        case .alreadyCompleted: "这个周期已经记录过该习惯。"
        }
    }
}

extension NativeDatabase {
    func reviewEntry(on date: Date) throws -> NativeReviewRecord? {
        try withConnection { db in
            let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
            let key = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            let statement = try Self.prepare("SELECT decision, result, improvement FROM review_entries WHERE local_date=?", in: db)
            defer { sqlite3_finalize(statement) }
            Self.bind(key, to: 1, in: statement)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            func text(_ column: Int32) -> String {
                sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
            }
            return NativeReviewRecord(decision: text(0), result: text(1), improvement: text(2))
        }
    }

    func disconnectStatus(at date: Date = .now) throws -> NativeDisconnectStatus {
        try withConnection { db in
            let state = try disconnectAttemptState(in: db, now: date)
            return NativeDisconnectStatus(consecutiveFailures: state.failures, lockedUntil: state.lockedUntil)
        }
    }

    func goalMetrics(in db: OpaquePointer, today: Date) throws -> HabitGoalMetrics {
        var counts: [String: Int] = [:]
        var completions: [HabitCompletion] = []
        var completedTodayIDs: Set<String> = []
        let todayParts = Calendar.current.dateComponents([.year, .month, .day], from: today)
        let todayKey = String(format: "%04d-%02d-%02d", todayParts.year ?? 0, todayParts.month ?? 0, todayParts.day ?? 0)
        let logs = try Self.prepare("SELECT habit_id, local_date FROM habit_logs", in: db)
        defer { sqlite3_finalize(logs) }
        while sqlite3_step(logs) == SQLITE_ROW {
            guard let rawID = sqlite3_column_text(logs, 0), let rawDate = sqlite3_column_text(logs, 1) else { continue }
            let id = String(cString: rawID)
            if String(cString: rawDate) == todayKey { completedTodayIDs.insert(id) }
            counts[id, default: 0] += 1
            if let day = Self.parseLocalDate(String(cString: rawDate)) {
                completions.append(HabitCompletion(id: id, day: day))
            }
        }

        var enabledAt: [String: Date] = [:]
        let selections = try Self.prepare("SELECT habit_id, enabled_at FROM habit_selections", in: db)
        defer { sqlite3_finalize(selections) }
        while sqlite3_step(selections) == SQLITE_ROW {
            guard let rawID = sqlite3_column_text(selections, 0) else { continue }
            enabledAt[String(cString: rawID)] = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(selections, 1)))
        }
        return HabitGoalMetrics(
            completionCounts: counts,
            growthProgress: HabitGrowthRules.progress(enabledAt: enabledAt, completions: completions, today: today),
            completedTodayIDs: completedTodayIDs
        )
    }

    func submit(_ entry: GoalEntry) throws {
        try withConnection { db in
            try Self.execute("BEGIN IMMEDIATE", in: db)
            do {
                switch (entry.goalID, entry.payload) {
                case let ("H1", .review(decision, result, improvement)):
                    try saveReview(decision: decision, result: result, improvement: improvement, date: entry.date, in: db)
                case let ("H2", .focus(sessionID)):
                    try finishTimer(sessionID: sessionID, at: .now, in: db)
                case let ("H3", .challenge(cardIndex, primary, secondary)):
                    _ = primary; _ = secondary
                    let activeChallenge = try challengeRecord(at: entry.date, in: db)
                    guard activeChallenge.cardIndex == cardIndex else { throw HabitSubmissionError.invalid("挑战内容已经变化，请重新查看后再提交。") }
                    try recordCompletion("H3", at: entry.date, points: 1, in: db)
                case let ("H4", .disconnect(sessionID)):
                    try finishTimer(sessionID: sessionID, at: .now, in: db)
                case let (id, .activity(primary, secondary, first, second)) where ["H5", "H6", "H7", "H8", "H9", "H10", "H12"].contains(id):
                    guard !primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw HabitSubmissionError.invalid("请填写必填内容。") }
                    if id != "H11" && primary.count > 5 { throw HabitSubmissionError.invalid("主记录最多 5 个字。") }
                    if id == "H7" {
                        for value in [first, second].compactMap({ $0 }) where !value.isFinite {
                            throw HabitSubmissionError.invalid("资产和消费金额需为有效数字。")
                        }
                    }
                    try saveActivity(habitID: id, primary: primary, secondary: secondary, first: first, second: second, at: entry.date, in: db)
                    let multiplier = id == "H5" || id == "H7" ? 3 : id == "H10" ? 4 : 1
                    try recordCompletion(id, at: entry.date, points: multiplier, in: db)
                case let ("H11", .travelPlan(destination, days, focus, preparation, summary, completed)):
                    guard !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          (1...30).contains(days) else { throw HabitSubmissionError.invalid("旅行目的地、计划天数（1–30 天）和旅行主题都需要填写。") }
                    try saveTravelPlan(destination: destination, days: days, focus: focus, preparation: preparation, at: entry.date, in: db)
                    if completed {
                        guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw HabitSubmissionError.invalid("请填写旅行后的总结。") }
                        try saveActivity(habitID: "H11", primary: destination, secondary: summary, first: Double(days), second: nil, at: entry.date, in: db)
                        try recordCompletion("H11", at: entry.date, points: 99, in: db)
                    }
                default:
                    throw HabitSubmissionError.invalid("提交内容与习惯类型不匹配。")
                }
                try Self.execute("COMMIT", in: db)
            } catch {
                try? Self.execute("ROLLBACK", in: db)
                throw error
            }
        }
    }

    func startTimer(habitID: String, targetSeconds: Int, focusTopic: String? = nil, at date: Date = .now) throws -> Int64 {
        guard habitID == "H2" || habitID == "H4", targetSeconds > 0 else { throw HabitSubmissionError.invalid("计时参数无效。") }
        if habitID == "H2", focusTopic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            throw HabitSubmissionError.invalid("开始前请先选择或填写一个思考议题。")
        }
        return try withConnection { db in
            let supersede = try Self.prepare("UPDATE timer_sessions SET status='failed', ended_at=? WHERE habit_id=? AND status IN ('running','paused')", in: db)
            sqlite3_bind_int64(supersede, 1, Int64(date.timeIntervalSince1970)); Self.bind(habitID, to: 2, in: supersede)
            guard sqlite3_step(supersede) == SQLITE_DONE else { sqlite3_finalize(supersede); throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
            sqlite3_finalize(supersede)
            if habitID == "H4" {
                let status = try disconnectAttemptState(in: db, now: date)
                if let lockedUntil = status.lockedUntil, date < lockedUntil {
                    throw HabitSubmissionError.invalid("断网任务正在冷却，\(lockedUntil.formatted(date: .omitted, time: .shortened)) 后再试。")
                }
            }
            let statement = try Self.prepare("INSERT INTO timer_sessions(habit_id, target_seconds, started_at, accumulated_pause_seconds, status, focus_topic) VALUES (?, ?, ?, 0, 'running', ?)", in: db)
            defer { sqlite3_finalize(statement) }
            Self.bind([habitID], to: statement)
            sqlite3_bind_int(statement, 2, Int32(targetSeconds))
            sqlite3_bind_int64(statement, 3, Int64(date.timeIntervalSince1970))
            if let focusTopic { Self.bind(focusTopic, to: 4, in: statement) } else { sqlite3_bind_null(statement, 4) }
            guard sqlite3_step(statement) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
            return sqlite3_last_insert_rowid(db)
        }
    }

    func activeTimer(habitID: String) throws -> NativeTimerRecord? {
        try withConnection { db in
            let statement = try Self.prepare("SELECT id, started_at, paused_at, accumulated_pause_seconds, status FROM timer_sessions WHERE habit_id=? AND status IN ('running','paused') ORDER BY id DESC LIMIT 1", in: db)
            defer { sqlite3_finalize(statement) }
            Self.bind(habitID, to: 1, in: statement)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            let pausedAt = sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2)))
            return NativeTimerRecord(id: sqlite3_column_int64(statement, 0), startedAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 1))), pausedAt: pausedAt, accumulatedPauseSeconds: Int(sqlite3_column_int(statement, 3)), status: sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? "running")
        }
    }

    func abandonDisconnectSession(_ id: Int64, at date: Date = .now) throws {
        try withConnection { db in
            let statement = try Self.prepare("UPDATE timer_sessions SET status='failed', ended_at=? WHERE id=? AND habit_id='H4' AND status='running'", in: db)
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(date.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 2, id)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
        }
    }

    func pauseFocusSession(_ id: Int64, at date: Date = .now) throws {
        try withConnection { db in
            let statement = try Self.prepare("UPDATE timer_sessions SET status='paused', paused_at=? WHERE id=? AND habit_id='H2' AND status='running'", in: db)
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(date.timeIntervalSince1970)); sqlite3_bind_int64(statement, 2, id)
            guard sqlite3_step(statement) == SQLITE_DONE, sqlite3_changes(db) == 1 else { throw HabitSubmissionError.invalid("当前没有可暂停的专注计时。") }
        }
    }

    func endFocusSessionEarly(_ id: Int64, at date: Date = .now) throws {
        try withConnection { db in
            let statement = try Self.prepare("UPDATE timer_sessions SET status='failed', ended_at=? WHERE id=? AND habit_id='H2' AND status IN ('running','paused')", in: db)
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(date.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 2, id)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
            guard sqlite3_changes(db) == 1 else { throw HabitSubmissionError.invalid("当前没有可提前结束的专注计时。") }
        }
    }

    @discardableResult
    func failExpiredFocusPause(_ id: Int64, at date: Date = .now) throws -> Bool {
        try withConnection { db in
            let query = try Self.prepare("SELECT paused_at, accumulated_pause_seconds FROM timer_sessions WHERE id=? AND habit_id='H2' AND status='paused'", in: db)
            sqlite3_bind_int64(query, 1, id)
            guard sqlite3_step(query) == SQLITE_ROW, sqlite3_column_type(query, 0) != SQLITE_NULL else {
                sqlite3_finalize(query)
                return false
            }
            let pausedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(query, 0)))
            let accumulated = Int(sqlite3_column_int(query, 1))
            sqlite3_finalize(query)
            let totalPauseSeconds = accumulated + max(0, Int(date.timeIntervalSince(pausedAt)))
            guard totalPauseSeconds > 300 else { return false }

            let fail = try Self.prepare("UPDATE timer_sessions SET status='failed', ended_at=? WHERE id=? AND habit_id='H2' AND status='paused'", in: db)
            defer { sqlite3_finalize(fail) }
            sqlite3_bind_int64(fail, 1, Int64(date.timeIntervalSince1970))
            sqlite3_bind_int64(fail, 2, id)
            guard sqlite3_step(fail) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
            return sqlite3_changes(db) == 1
        }
    }

    func resumeFocusSession(_ id: Int64, at date: Date = .now) throws -> Int {
        try withConnection { db in
            let query = try Self.prepare("SELECT paused_at, accumulated_pause_seconds FROM timer_sessions WHERE id=? AND habit_id='H2' AND status='paused'", in: db)
            sqlite3_bind_int64(query, 1, id)
            guard sqlite3_step(query) == SQLITE_ROW, sqlite3_column_type(query, 0) != SQLITE_NULL else { sqlite3_finalize(query); throw HabitSubmissionError.invalid("当前没有暂停中的专注计时。") }
            let pausedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(query, 0)))
            let previous = Int(sqlite3_column_int(query, 1))
            sqlite3_finalize(query)
            let total = previous + max(0, Int(date.timeIntervalSince(pausedAt)))
            guard total <= 300 else {
                let fail = try Self.prepare("UPDATE timer_sessions SET status='failed', ended_at=? WHERE id=?", in: db)
                sqlite3_bind_int64(fail, 1, Int64(date.timeIntervalSince1970)); sqlite3_bind_int64(fail, 2, id); _ = sqlite3_step(fail); sqlite3_finalize(fail)
                throw HabitSubmissionError.invalid("暂停累计超过 5 分钟，本次专注没有完成。")
            }
            let update = try Self.prepare("UPDATE timer_sessions SET status='running', paused_at=NULL, accumulated_pause_seconds=? WHERE id=?", in: db)
            sqlite3_bind_int(update, 1, Int32(total)); sqlite3_bind_int64(update, 2, id)
            defer { sqlite3_finalize(update) }
            guard sqlite3_step(update) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
            return total
        }
    }

    func recoverInterruptedDisconnectSessions(at date: Date = .now) throws {
        try withConnection { db in
            let statement = try Self.prepare("UPDATE timer_sessions SET status='failed', ended_at=? WHERE habit_id='H4' AND status='running'", in: db)
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(date.timeIntervalSince1970))
            guard sqlite3_step(statement) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
        }
    }

    func travelPlan(year: Int) throws -> TravelPlanRecord? {
        try withConnection { db in
            let statement = try Self.prepare("SELECT destination, days, focus, preparation FROM travel_plans WHERE year=?", in: db)
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, Int32(year))
            guard sqlite3_step(statement) == SQLITE_ROW, let raw = sqlite3_column_text(statement, 0) else { return nil }
            return TravelPlanRecord(
                destination: String(cString: raw), days: Int(sqlite3_column_int(statement, 1)),
                focus: sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? "",
                preparation: sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
            )
        }
    }

    func challengeForToday(at date: Date = .now) throws -> HabitChallengeRecord {
        try withConnection { db in
            try Self.execute("BEGIN IMMEDIATE", in: db)
            do {
                let record = try challengeRecord(at: date, in: db)
                try Self.execute("COMMIT", in: db)
                return record
            } catch {
                try? Self.execute("ROLLBACK", in: db)
                throw error
            }
        }
    }

    func swapChallenge(at date: Date = .now) throws -> HabitChallengeRecord {
        try withConnection { db in
            try Self.execute("BEGIN IMMEDIATE", in: db)
            do {
                let current = try challengeRecord(at: date, in: db)
                let nextCount = current.swapCount + 1
                let nextIndex: Int
                if current.swapCount < 3 {
                    nextIndex = try drawNextChallenge(at: date, in: db)
                    let insert = try Self.prepare("INSERT INTO challenge_daily_swaps(local_date, slot, card_index) VALUES (?, ?, ?)", in: db)
                    Self.bind(Self.localDate(date), to: 1, in: insert)
                    sqlite3_bind_int(insert, 2, Int32(nextCount))
                    sqlite3_bind_int(insert, 3, Int32(nextIndex))
                    guard sqlite3_step(insert) == SQLITE_DONE else { sqlite3_finalize(insert); throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
                    sqlite3_finalize(insert)
                } else {
                    let choices = try Self.prepare("SELECT card_index FROM challenge_daily_swaps WHERE local_date=? ORDER BY slot", in: db)
                    Self.bind(Self.localDate(date), to: 1, in: choices)
                    var indexes: [Int] = []
                    while sqlite3_step(choices) == SQLITE_ROW { indexes.append(Int(sqlite3_column_int(choices, 0))) }
                    sqlite3_finalize(choices)
                    let pool = indexes.isEmpty ? [current.cardIndex] : indexes
                    guard let selected = pool.randomElement() else { throw NativeDatabaseError.migration("今日挑战题目为空") }
                    nextIndex = selected
                }
                let update = try Self.prepare("UPDATE challenge_draws SET card_index=?, swap_used=?, swap_count=? WHERE local_date=?", in: db)
                sqlite3_bind_int(update, 1, Int32(nextIndex)); sqlite3_bind_int(update, 2, nextCount >= 3 ? 1 : 0); sqlite3_bind_int(update, 3, Int32(nextCount))
                Self.bind(Self.localDate(date), to: 4, in: update)
                guard sqlite3_step(update) == SQLITE_DONE else { sqlite3_finalize(update); throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
                sqlite3_finalize(update)
                let updated = try challengeRecord(at: date, in: db)
                try Self.execute("COMMIT", in: db)
                return updated
            } catch {
                try? Self.execute("ROLLBACK", in: db)
                throw error
            }
        }
    }

    private func challengeRecord(at date: Date, in db: OpaquePointer) throws -> HabitChallengeRecord {
        let key = Self.localDate(date)
        let statement = try Self.prepare("SELECT card_index, swap_count FROM challenge_draws WHERE local_date=?", in: db)
        Self.bind(key, to: 1, in: statement)
        if sqlite3_step(statement) == SQLITE_ROW {
            let index = Int(sqlite3_column_int(statement, 0))
            let swaps = Int(sqlite3_column_int(statement, 1))
            sqlite3_finalize(statement)
            let cards = HabitTaskCatalog.challengeCards
            guard cards.indices.contains(index) else { throw NativeDatabaseError.migration("挑战卡片编号超出范围") }
            return HabitChallengeRecord(cardIndex: index, swapCount: swaps, title: cards[index])
        }
        sqlite3_finalize(statement)
        let index = try drawNextChallenge(at: date, in: db)
        let insert = try Self.prepare("INSERT INTO challenge_draws(local_date, card_index, swap_used, swap_count) VALUES (?, ?, 0, 0)", in: db)
        Self.bind(key, to: 1, in: insert); sqlite3_bind_int(insert, 2, Int32(index))
        guard sqlite3_step(insert) == SQLITE_DONE else { sqlite3_finalize(insert); throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
        sqlite3_finalize(insert)
        return HabitChallengeRecord(cardIndex: index, swapCount: 0, title: HabitTaskCatalog.challengeCards[index])
    }

    private func drawNextChallenge(at date: Date, in db: OpaquePointer) throws -> Int {
        let cards = HabitTaskCatalog.challengeCards
        let latestCycle = max(1, try NativeDatabase.scalarInt("SELECT COALESCE(MAX(cycle), 0) FROM challenge_history", in: db))
        var cycle = latestCycle
        let usedStatement = try Self.prepare("SELECT card_index FROM challenge_history WHERE cycle=?", in: db)
        sqlite3_bind_int(usedStatement, 1, Int32(cycle))
        var used = Set<Int>()
        while sqlite3_step(usedStatement) == SQLITE_ROW {
            used.insert(Int(sqlite3_column_int(usedStatement, 0)))
        }
        sqlite3_finalize(usedStatement)

        var available = cards.indices.filter { !used.contains($0) }
        if available.isEmpty {
            cycle += 1
            available = Array(cards.indices)
        }
        guard let index = available.randomElement() else {
            throw NativeDatabaseError.migration("H3 挑战题库为空")
        }

        let history = try Self.prepare("INSERT INTO challenge_history(cycle, card_index, drawn_at, local_date) VALUES (?, ?, ?, ?)", in: db)
        defer { sqlite3_finalize(history) }
        sqlite3_bind_int(history, 1, Int32(cycle))
        sqlite3_bind_int(history, 2, Int32(index))
        sqlite3_bind_int64(history, 3, Int64(date.timeIntervalSince1970))
        Self.bind(Self.localDate(date), to: 4, in: history)
        guard sqlite3_step(history) == SQLITE_DONE else {
            throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db)))
        }
        return index
    }

    private func finishTimer(sessionID: Int64, at date: Date, in db: OpaquePointer) throws {
        let query = try Self.prepare("SELECT habit_id, target_seconds, started_at, accumulated_pause_seconds, status FROM timer_sessions WHERE id=?", in: db)
        sqlite3_bind_int64(query, 1, sessionID)
        guard sqlite3_step(query) == SQLITE_ROW, let rawID = sqlite3_column_text(query, 0) else {
            sqlite3_finalize(query); throw HabitSubmissionError.invalid("找不到正在计时的任务。")
        }
        let habitID = String(cString: rawID)
        let target = Int(sqlite3_column_int(query, 1))
        let started = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(query, 2)))
        let pauses = Int(sqlite3_column_int(query, 3))
        let isRunning = sqlite3_column_text(query, 4).map { String(cString: $0) == "running" } ?? false
        sqlite3_finalize(query)
        guard isRunning, habitID == "H2" || habitID == "H4" else { throw HabitSubmissionError.invalid("计时任务已结束或类型不匹配。") }
        let elapsed = Int(date.timeIntervalSince(started))
        let completed = habitID == "H2" ? elapsed - pauses >= target && pauses <= 300 : elapsed >= target
        guard completed else { throw HabitSubmissionError.invalid("计时尚未达到设定时长。") }
        let update = try Self.prepare("UPDATE timer_sessions SET status='completed', ended_at=? WHERE id=? AND status='running'", in: db)
        sqlite3_bind_int64(update, 1, Int64(date.timeIntervalSince1970))
        sqlite3_bind_int64(update, 2, sessionID)
        defer { sqlite3_finalize(update) }
        guard sqlite3_step(update) == SQLITE_DONE, sqlite3_changes(db) == 1 else { throw HabitSubmissionError.invalid("计时状态已变化，请刷新后重试。") }
        try recordCompletion(habitID, at: date, points: 1, in: db)
    }

    private func disconnectAttemptState(in db: OpaquePointer, now: Date) throws -> (failures: Int, lockedUntil: Date?) {
        let statement = try Self.prepare("SELECT status, COALESCE(ended_at, started_at) FROM timer_sessions WHERE habit_id='H4' ORDER BY id ASC", in: db)
        defer { sqlite3_finalize(statement) }
        var failures = 0
        var lockedUntil: Date?
        while sqlite3_step(statement) == SQLITE_ROW {
            let status = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
            let ended = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 1)))
            if status == "completed" { failures = 0; lockedUntil = nil; continue }
            guard status == "failed" else { continue }
            if let until = lockedUntil {
                if ended < until { continue }
                failures = 0; lockedUntil = nil
            }
            failures += 1
            if failures == 3 { lockedUntil = ended.addingTimeInterval(10 * 60 * 60) }
        }
        if let lockedUntil, now >= lockedUntil { return (0, nil) }
        return (failures, lockedUntil)
    }

    private func saveReview(decision: String, result: String, improvement: String, date: Date, in db: OpaquePointer) throws {
        let today = Calendar.current.startOfDay(for: .now)
        let target = Calendar.current.startOfDay(for: date)
        let daysAgo = Calendar.current.dateComponents([.day], from: target, to: today).day ?? -1
        guard (0...3).contains(daysAgo) else { throw HabitSubmissionError.invalid("复盘只能填写今天或之前 3 天。") }
        let allText = decision + result + improvement
        let count = allText.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).contains(scalar)
        }.count
        let key = Self.localDate(date)
        try Self.execute("INSERT INTO review_entries(local_date, decision, result, improvement, updated_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(local_date) DO UPDATE SET decision=excluded.decision, result=excluded.result, improvement=excluded.improvement, updated_at=excluded.updated_at", bindings: [key, decision, result, improvement, "\(Int(Date.now.timeIntervalSince1970))"], in: db)
        if count >= 100 && Calendar.current.isDate(date, inSameDayAs: .now) {
            try recordCompletion("H1", at: .now, points: 1, in: db)
        }
    }

    private func saveActivity(habitID: String, primary: String, secondary: String, first: Double?, second: Double?, at date: Date, in db: OpaquePointer) throws {
        let period = Self.periodKey(habitID, date)
        let statement = try Self.prepare("INSERT OR IGNORE INTO habit_activity_entries(habit_id, period_key, primary_text, secondary_text, first_value, second_value, completed_at) VALUES (?, ?, ?, ?, ?, ?, ?)", in: db)
        defer { sqlite3_finalize(statement) }
        Self.bind([habitID, period, primary.trimmingCharacters(in: .whitespacesAndNewlines), secondary.trimmingCharacters(in: .whitespacesAndNewlines)], to: statement)
        if let first { sqlite3_bind_double(statement, 5, first) } else { sqlite3_bind_null(statement, 5) }
        if let second { sqlite3_bind_double(statement, 6, second) } else { sqlite3_bind_null(statement, 6) }
        sqlite3_bind_int64(statement, 7, Int64(date.timeIntervalSince1970))
        guard sqlite3_step(statement) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
        guard sqlite3_changes(db) > 0 else { throw HabitSubmissionError.alreadyCompleted }
    }

    private func saveTimer(habitID: String, started: Date, ended: Date, target: Int, pauses: Int, topic: String?, in db: OpaquePointer) throws {
        let statement = try Self.prepare("INSERT INTO timer_sessions(habit_id, target_seconds, started_at, paused_at, accumulated_pause_seconds, status, ended_at, focus_topic) VALUES (?, ?, ?, NULL, ?, 'completed', ?, ?)", in: db)
        defer { sqlite3_finalize(statement) }
        Self.bind([habitID], to: statement)
        sqlite3_bind_int(statement, 2, Int32(target))
        sqlite3_bind_int64(statement, 3, Int64(started.timeIntervalSince1970))
        sqlite3_bind_int(statement, 4, Int32(pauses))
        sqlite3_bind_int64(statement, 5, Int64(ended.timeIntervalSince1970))
        if let topic { Self.bind(topic, to: 6, in: statement) } else { sqlite3_bind_null(statement, 6) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
    }

    private func saveChallenge(cardIndex: Int, at date: Date, in db: OpaquePointer) throws {
        let key = Self.localDate(date)
        try Self.execute("INSERT OR IGNORE INTO challenge_draws(local_date, card_index, swap_used, swap_count) VALUES (?, ?, 0, 0)", bindings: [key, "\(max(0, cardIndex))"], in: db)
    }

    private func saveTravelPlan(destination: String, days: Int, focus: String, preparation: String, at date: Date, in db: OpaquePointer) throws {
        let statement = try Self.prepare("INSERT INTO travel_plans(year, destination, days, focus, preparation, planned_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(year) DO UPDATE SET destination=excluded.destination, days=excluded.days, focus=excluded.focus, preparation=excluded.preparation, planned_at=excluded.planned_at", in: db)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(Calendar.current.component(.year, from: date)))
        Self.bind([destination.trimmingCharacters(in: .whitespacesAndNewlines)], to: statement, startingAt: 2)
        sqlite3_bind_int(statement, 3, Int32(days))
        Self.bind([focus.trimmingCharacters(in: .whitespacesAndNewlines), preparation.trimmingCharacters(in: .whitespacesAndNewlines)], to: statement, startingAt: 4)
        sqlite3_bind_int64(statement, 6, Int64(date.timeIntervalSince1970))
        guard sqlite3_step(statement) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
    }

    private func recordCompletion(_ habitID: String, at date: Date, points: Int, in db: OpaquePointer) throws {
        let key = Self.localDate(date)
        let existing = try Self.prepare("SELECT 1 FROM habit_logs WHERE habit_id = ? AND local_date = ? LIMIT 1", in: db)
        Self.bind([habitID, key], to: existing)
        let alreadyLogged = sqlite3_step(existing) == SQLITE_ROW
        sqlite3_finalize(existing)
        guard !alreadyLogged else { throw HabitSubmissionError.alreadyCompleted }

        let star = try Self.prepare("SELECT is_starred FROM habit_selections WHERE habit_id = ?", in: db)
        Self.bind(habitID, to: 1, in: star)
        let starred = sqlite3_step(star) == SQLITE_ROW && sqlite3_column_int(star, 0) != 0
        sqlite3_finalize(star)

        let insert = try Self.prepare("INSERT INTO habit_logs(habit_id, local_date, timezone_offset_minutes, created_at) VALUES (?, ?, ?, ?)", in: db)
        defer { sqlite3_finalize(insert) }
        Self.bind([habitID, key], to: insert)
        sqlite3_bind_int(insert, 3, Int32(TimeZone.current.secondsFromGMT(for: date) / 60))
        sqlite3_bind_int64(insert, 4, Int64(date.timeIntervalSince1970))
        guard sqlite3_step(insert) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
        let logID = sqlite3_last_insert_rowid(db)
        let transaction = try Self.prepare("INSERT INTO point_transactions(habit_log_id, amount, created_at) VALUES (?, ?, ?)", in: db)
        defer { sqlite3_finalize(transaction) }
        sqlite3_bind_int64(transaction, 1, logID)
        sqlite3_bind_int(transaction, 2, starred ? 0 : Int32(points))
        sqlite3_bind_int64(transaction, 3, Int64(date.timeIntervalSince1970))
        guard sqlite3_step(transaction) == SQLITE_DONE else { throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db))) }
    }

    private static func localDate(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func parseLocalDate(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func periodKey(_ habitID: String, _ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        if habitID == "H11" { return "\(parts.year ?? 0)" }
        if habitID == "H10" { return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0) }
        if habitID == "H5" || habitID == "H7" {
            let weekday = Calendar.current.component(.weekday, from: date)
            let monday = Calendar.current.date(byAdding: .day, value: -((weekday + 5) % 7), to: date) ?? date
            return "week-\(localDate(monday))"
        }
        return localDate(date)
    }

    private static func bind(_ values: [String], to statement: OpaquePointer, startingAt start: Int32 = 1) {
        for (index, value) in values.enumerated() { bind(value, to: start + Int32(index), in: statement) }
    }

    private static func bind(_ value: String, to index: Int32, in statement: OpaquePointer) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, index, value, -1, transient)
    }
}
