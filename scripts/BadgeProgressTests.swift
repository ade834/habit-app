import Foundation

@main struct BadgeProgressTests {
    static func main() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let db = NativeDatabase(fileURL: dir.appendingPathComponent("test.sqlite"), legacyURL: nil)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let day = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
        try db.withConnection { connection in
            for id in ["H1", "H2", "H3"] {
                try NativeDatabase.execute("INSERT INTO habit_selections(habit_id, enabled_at) VALUES (?, ?)", bindings: [id, String(Int(now.timeIntervalSince1970))], in: connection)
                try NativeDatabase.execute("INSERT INTO habit_logs(habit_id, local_date, timezone_offset_minutes, created_at) VALUES (?, ?, 0, ?)", bindings: [id, day, String(Int(now.timeIntervalSince1970))], in: connection)
            }
        }
        let beforeEvidence = try BadgeProgressStore(database: db).refresh(now: now)
        precondition(beforeEvidence.isDisjoint(with: [28, 29, 49, 50]), "badges must not unlock without evidence")
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        func key(_ offset: Int) -> String {
            let d = calendar.date(byAdding: .day, value: offset, to: start)!
            let c = calendar.dateComponents([.year, .month, .day], from: d)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        try db.withConnection { connection in
            let reviewDay = key(-110)
            try NativeDatabase.execute("INSERT INTO review_entries(local_date, decision, result, improvement, updated_at) VALUES (?, '', '', 'plan', 0)", bindings: [reviewDay], in: connection)
            try NativeDatabase.execute("INSERT INTO habit_logs(habit_id, local_date, timezone_offset_minutes, created_at) VALUES ('H1', ?, 0, 0)", bindings: [reviewDay], in: connection)
            try NativeDatabase.execute("INSERT INTO badge_review_evidence(local_date, missed_reason, improvement_completed, missed_review) VALUES (?, '原因', 1, 1)", bindings: [reviewDay], in: connection)
            try NativeDatabase.execute("INSERT INTO badge_plan_intervals(habit_id, started_on) VALUES ('H2', ?)", bindings: [key(-110)], in: connection)
            for i in 0..<20 {
                let day = key(-109 + i)
                try NativeDatabase.execute("INSERT INTO daily_selection_records(habit_id, local_date, counts_regular) VALUES ('H2', ?, 1)", bindings: [day], in: connection)
                if i < 14 { try NativeDatabase.execute("INSERT INTO habit_logs(habit_id, local_date, timezone_offset_minutes, created_at) VALUES ('H2', ?, 0, 0)", bindings: [day], in: connection) }
            }
        }
        let store = BadgeProgressStore(database: db)
        let earned = try store.refresh(now: now)
        precondition(earned.contains(11) && earned.contains(45), "first completion and three-habit badges should unlock")
        precondition(Set([28, 29, 49, 50]).isSubset(of: earned), "four evidence-based badges should unlock")
        try db.withConnection { try NativeDatabase.execute("DELETE FROM habit_logs", in: $0) }
        let retained = try store.refresh(now: now)
        precondition(retained.contains(45), "earned badges must persist")
        try db.clearAllUserData()
        let cleared = try store.refresh(now: now)
        precondition(cleared.isEmpty, "clearing user data must clear awards")
        print("PASS: achievement thresholds, persistence and reset")
    }
}
