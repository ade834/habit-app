import Foundation
import SQLite3

struct HabitGardenLiveSnapshot: Equatable {
    let completions: [String: Int]
    let growth: [String: Int]
    let points: [String: Int]
    let inactiveDays: Int
    let lastCompletedAt: [String: Date]

    var habitIDsWithGrowth: Set<String> {
        Set(Set(points.keys).union(completions.keys).filter { id in
            points[id, default: 0] > 0 || completions[id, default: 0] > 0
        })
    }

    // Kept for data-layer compatibility: this is the points-only view.
    var habitIDsWithPoints: Set<String> {
        Set(points.compactMap { id, value in value > 0 ? id : nil })
    }

    static func read(database: NativeDatabase = NativeDatabase(), at date: Date = .now) throws -> Self {
        try database.withConnection { db in
            try NativeDatabase.execute("BEGIN DEFERRED", in: db)
            defer { try? NativeDatabase.execute("ROLLBACK", in: db) }
            let metrics = try database.goalMetrics(in: db, today: date)
            let query = try NativeDatabase.prepare("SELECT l.habit_id, COALESCE(SUM(p.amount), 0), MAX(l.created_at) FROM habit_logs l LEFT JOIN point_transactions p ON p.habit_log_id=l.id GROUP BY l.habit_id", in: db)
            defer { sqlite3_finalize(query) }
            var points: [String: Int] = [:]
            var lastCompletedAt: [String: Date] = [:]
            while sqlite3_step(query) == SQLITE_ROW {
                if let raw = sqlite3_column_text(query, 0) {
                    let id = String(cString: raw)
                    points[id] = Int(sqlite3_column_int(query, 1))
                    lastCompletedAt[id] = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(query, 2)))
                }
            }
            let latest = try NativeDatabase.prepare("SELECT MAX(local_date) FROM habit_logs", in: db)
            defer { sqlite3_finalize(latest) }
            var inactiveDays = 0
            if sqlite3_step(latest) == SQLITE_ROW, let raw = sqlite3_column_text(latest, 0) {
                let parts = String(cString: raw).split(separator: "-").compactMap { Int($0) }
                if parts.count == 3,
                   let last = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) {
                    // Only complete natural days count toward dormancy.
                    inactiveDays = max(0, (Calendar.current.dateComponents([.day], from: last, to: Calendar.current.startOfDay(for: date)).day ?? 0) - 1)
                }
            }
            return Self(completions: metrics.completionCounts, growth: metrics.growthProgress, points: points, inactiveDays: inactiveDays, lastCompletedAt: lastCompletedAt)
        }
    }
}

extension PosyFloraType {
    static let habitOrder: [Self] = [
        .hawthorn, .dandelion, .bayWreath, .cornflower,
        .redBerries, .mimosa, .hydrangea, .allium,
        .lotusPod, .cherryBlossom, .cosmos, .nightJasmine,
        .ginkgo, .iris, .magnolia, .thistle
    ]

    static func forHabit(_ id: String) -> Self {
        let number = Int(id.dropFirst()) ?? 1
        return habitOrder[min(habitOrder.count - 1, max(0, number - 1))]
    }

    var simpleName: String { titleZh.components(separatedBy: ". ").last ?? titleZh }
}
