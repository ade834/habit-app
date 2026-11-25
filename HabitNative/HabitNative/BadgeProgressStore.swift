import Foundation
import SQLite3

/// Reconstructs achievements only from recorded events, then stores awards once.
struct BadgeProgressStore {
    var database = NativeDatabase()
    private struct Event { let id: String; let date: Date }

    func pending() throws -> Int? {
        try database.withConnection { db in
            let stmt = try NativeDatabase.prepare("SELECT badge_id FROM badge_unlocks WHERE presented=0 ORDER BY unlocked_at, badge_id LIMIT 1", in: db)
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            return Int(sqlite3_column_int(stmt, 0))
        }
    }

    func markPresented(_ id: Int) throws {
        try database.withConnection { db in
            try NativeDatabase.execute("UPDATE badge_unlocks SET presented=1 WHERE badge_id=?", bindings: [String(id)], in: db)
        }
    }

    func refresh(now: Date = .now) throws -> Set<Int> {
        try database.withConnection { db in
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: now)
            func date(_ value: String) -> Date? {
                let p = value.split(separator: "-").compactMap { Int($0) }
                guard p.count == 3 else { return nil }
                return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
            }
            func rows(_ sql: String) throws -> [[String]] {
                let statement = try NativeDatabase.prepare(sql, in: db)
                defer { sqlite3_finalize(statement) }
                var result: [[String]] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                    result.append((0..<sqlite3_column_count(statement)).map { i in
                        sqlite3_column_text(statement, i).map { String(cString: $0) } ?? ""
                    })
                }
                return result
            }
            let logs = try rows("SELECT habit_id, local_date FROM habit_logs ORDER BY local_date").compactMap { row -> Event? in
                guard row.count == 2, let day = date(row[1]), day <= today else { return nil }
                return Event(id: row[0], date: day)
            }
            let plans = try rows("SELECT habit_id, local_date FROM daily_selection_records ORDER BY local_date").compactMap { row -> Event? in
                guard row.count == 2, let day = date(row[1]), day <= today else { return nil }
                return Event(id: row[0], date: day)
            }
            let reviews = try rows("SELECT r.local_date FROM review_entries r JOIN habit_logs l ON l.habit_id='H1' AND l.local_date=r.local_date ORDER BY r.local_date").compactMap { $0.first.flatMap(date) }.filter { $0 <= today }
            let done = Set(logs.map { "\($0.id)|\(Int($0.date.timeIntervalSince1970))" })
            var awards = Set<Int>()
            func grant(_ id: Int, _ condition: Bool) { if condition { awards.insert(id) } }
            let counts = Dictionary(grouping: logs, by: \.id).mapValues(\.count)
            let metrics = try database.goalMetrics(in: db, today: now)
            let starts = try rows("SELECT habit_id, enabled_at FROM habit_selections")
            let enabledAt = Dictionary(uniqueKeysWithValues: starts.compactMap { row -> (String, Date)? in
                guard row.count == 2, let seconds = TimeInterval(row[1]) else { return nil }
                return (row[0], Date(timeIntervalSince1970: seconds))
            })
            let levels = metrics.growthProgress.values.map { value -> Int in
                value >= 60 ? 4 : value >= 25 ? 3 : value >= 10 ? 2 : value >= 3 ? 1 : 0
            }
            grant(1, !logs.isEmpty)
            grant(2, levels.contains { $0 >= 1 }); grant(3, levels.contains { $0 >= 2 }); grant(4, levels.contains { $0 >= 3 })
            let mature = levels.filter { $0 >= 4 }.count
            for (id, number) in [(5,2),(6,3),(7,5),(8,10)] { grant(id, mature >= number) }
            grant(9, levels.filter { $0 >= 1 }.count >= 3)
            // Replay growth at completion dates so past monthly stage gains can
            // still be recognized after the current garden has faded.
            var gainsByMonth: [Date: Set<String>] = [:]
            let completionEvents = logs.map { HabitCompletion(id: $0.id, day: $0.date) }
            func stage(_ progress: Int) -> Int { progress >= 60 ? 4 : progress >= 25 ? 3 : progress >= 10 ? 2 : progress >= 3 ? 1 : 0 }
            for day in Set(logs.map(\.date)).sorted() {
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { continue }
                let before = HabitGrowthRules.progress(enabledAt: enabledAt, completions: completionEvents.filter { $0.day < day }, today: previousDay)
                let after = HabitGrowthRules.progress(enabledAt: enabledAt, completions: completionEvents.filter { $0.day <= day }, today: day)
                let month = calendar.dateInterval(of: .month, for: day)?.start ?? day
                for event in logs where event.date == day && stage(after[event.id, default: 0]) > stage(before[event.id, default: 0]) {
                    gainsByMonth[month, default: []].insert(event.id)
                }
            }
            grant(10, gainsByMonth.values.contains { $0.count >= 3 })
            let maxCount = counts.values.max() ?? 0
            for (id, threshold) in [(11,1),(12,7),(13,30),(14,100),(15,365),(16,1000)] { grant(id, maxCount >= threshold) }
            var bestStreak = 0
            for (_, schedule) in Dictionary(grouping: plans, by: \.id) {
                var streak = 0
                for item in schedule.sorted(by: { $0.date < $1.date }) {
                    let key = "\(item.id)|\(Int(item.date.timeIntervalSince1970))"
                    if done.contains(key) { streak += 1; bestStreak = max(bestStreak, streak) }
                    else if item.date < today { streak = 0 }
                }
            }
            for (id, n) in [(17,3),(18,7),(19,14),(20,30),(21,60),(22,100)] { grant(id, bestStreak >= n) }
            for (id, n) in [(23,1),(24,3),(25,7),(26,30),(27,100)] { grant(id, reviews.count >= n) }
            let reviewEvidence = try rows("SELECT e.local_date, e.missed_reason, e.improvement_completed, e.missed_review FROM badge_review_evidence e JOIN review_entries r ON r.local_date=e.local_date JOIN habit_logs l ON l.habit_id='H1' AND l.local_date=e.local_date")
            grant(28, reviewEvidence.contains { $0.count >= 2 && !$0[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            grant(29, reviewEvidence.contains { $0.count >= 3 && $0[2] == "1" })
            func period(_ day: Date, component: Calendar.Component) -> Date {
                calendar.dateInterval(of: component, for: day)?.start ?? day
            }
            func longest(_ dates: [Date], component: Calendar.Component) -> Int {
                let values = Set(dates.map { period($0, component: component) }).sorted()
                var best = 0, run = 0, previous: Date?
                for value in values {
                    if let previous, calendar.date(byAdding: component, value: 1, to: previous) == value { run += 1 } else { run = 1 }
                    best = max(best, run); previous = value
                }
                return best
            }
            grant(30, longest(reviews, component: .weekOfYear) >= 4)
            grant(31, longest(reviews, component: .month) >= 3)
            grant(32, longest(reviews, component: .month) >= 12)
            let weekly = logs.filter { ["H5", "H7"].contains($0.id) }.map(\.date)
            let monthly = logs.filter { $0.id == "H10" }.map(\.date)
            let yearly = logs.filter { $0.id == "H11" }.map(\.date)
            let weeks = Set(weekly.map { period($0, component: .weekOfYear) }).count
            let months = Set(monthly.map { period($0, component: .month) }).count
            let years = Set(yearly.map { period($0, component: .year) }).count
            grant(33, weeks >= 1); grant(34, longest(weekly, component: .weekOfYear) >= 4); grant(35, weeks >= 12); grant(36, weeks >= 52)
            grant(37, months >= 1); grant(38, longest(monthly, component: .month) >= 3); grant(39, months >= 6); grant(40, months >= 12)
            grant(41, years >= 1); grant(42, longest(yearly, component: .year) >= 2); grant(43, years >= 3); grant(44, years >= 5)
            grant(45, Dictionary(grouping: logs, by: \.date).values.contains { Set($0.map(\.id)).count >= 3 })
            let weeksPlans = Dictionary(grouping: plans.filter { $0.date < period(today, component: .weekOfYear) }, by: { period($0.date, component: .weekOfYear) })
            grant(46, weeksPlans.values.contains { week in week.count >= 3 && week.allSatisfy { done.contains("\($0.id)|\(Int($0.date.timeIntervalSince1970))") } })
            grant(47, weeks > 0 && months > 0 && years > 0)
            grant(48, Dictionary(grouping: logs, by: \.id).values.contains { events in
                let days = events.map(\.date).sorted()
                return zip(days, days.dropFirst()).contains { pair in
                    (calendar.dateComponents([.day], from: pair.0, to: pair.1).day ?? 0) > 8
                }
            })
            let missedReviews = reviewEvidence.compactMap { row -> Date? in
                guard row.count >= 4, row[3] == "1" else { return nil }
                return date(row[0])
            }
            grant(49, missedReviews.contains { reviewDate in
                let subsequent = plans.filter { $0.date > reviewDate && $0.date < today }.sorted {
                    $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date
                }.prefix(7)
                return subsequent.count == 7 && subsequent.filter { done.contains("\($0.id)|\(Int($0.date.timeIntervalSince1970))") }.count >= 5
            })
            let intervals = try rows("SELECT habit_id, started_on, COALESCE(ended_on, '') FROM badge_plan_intervals")
            grant(50, intervals.contains { row in
                guard row.count == 3, let start = date(row[1]), let minimumEnd = calendar.date(byAdding: .day, value: 100, to: start) else { return false }
                let end = row[2].isEmpty ? today : (date(row[2]) ?? start)
                guard end >= minimumEnd else { return false }
                let scheduled = plans.filter { $0.id == row[0] && $0.date >= start && $0.date <= end && $0.date < today }
                let completed = scheduled.filter { done.contains("\($0.id)|\(Int($0.date.timeIntervalSince1970))") }.count
                return scheduled.count >= 20 && completed * 10 >= scheduled.count * 7
            })
            try NativeDatabase.execute("BEGIN IMMEDIATE", in: db)
            do {
                for id in awards {
                    try NativeDatabase.execute("INSERT OR IGNORE INTO badge_unlocks(badge_id, unlocked_at) VALUES (?, ?)", bindings: [String(id), String(Int(now.timeIntervalSince1970))], in: db)
                }
                let unlocked = try rows("SELECT badge_id FROM badge_unlocks").compactMap { $0.first.flatMap(Int.init) }
                try NativeDatabase.execute("COMMIT", in: db)
                return Set(unlocked)
            } catch { try? NativeDatabase.execute("ROLLBACK", in: db); throw error }
        }
    }
}
