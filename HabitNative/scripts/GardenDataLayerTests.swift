import Foundation
import SQLite3

@main struct GardenDataProbe {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = NativeDatabase(fileURL: folder.appendingPathComponent("test.sqlite"), legacyURL: nil)
        let today = Calendar.current.startOfDay(for: .now)
        let enabled = today.addingTimeInterval(-5 * 86400)
        try database.withConnection { db in
            for n in 1...12 {
                try NativeDatabase.execute("INSERT INTO habit_selections(habit_id,commitment_note,enabled_at,is_starred,active_on) VALUES ('H\(n)','',\(Int(enabled.timeIntervalSince1970)),\(n == 6 ? 1 : 0),\(Int(today.timeIntervalSince1970)))", in: db)
            }
        }
        func log(_ id: String, _ daysAgo: Int, _ points: Int) throws {
            let day = today.addingTimeInterval(Double(-daysAgo * 86400))
            let c = Calendar.current.dateComponents([.year,.month,.day], from: day)
            let key = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
            try database.withConnection { db in
                try NativeDatabase.execute("INSERT INTO habit_logs(habit_id,local_date,timezone_offset_minutes,created_at) VALUES ('\(id)','\(key)',480,\(Int(day.timeIntervalSince1970)))", in: db)
                try NativeDatabase.execute("INSERT INTO point_transactions(habit_log_id,amount,created_at) VALUES (last_insert_rowid(),\(points),\(Int(day.timeIntervalSince1970)))", in: db)
            }
        }
        try log("H1",3,1); try log("H1",2,1); try log("H1",1,1)
        try log("H5",1,3); try log("H6",0,0); try log("H11",1,99)
        let initial = try HabitGardenLiveSnapshot.read(database: database, at: today)
        precondition(initial.growth.count == 12)
        precondition(initial.growth["H1"] == 3 && initial.points["H1"] == 3)
        precondition(initial.growth["H5"] == 1 && initial.points["H5"] == 3)
        precondition(initial.growth["H6"] == 1 && initial.points["H6"] == 0)
        precondition(initial.growth["H11"] == 1 && initial.points["H11"] == 99)
        precondition(initial.habitIDsWithPoints == ["H1", "H5", "H11"])
        try log("H1",0,1)
        let updated = try HabitGardenLiveSnapshot.read(database: database, at: today)
        precondition(updated != initial && updated.growth["H1"] == 4 && updated.points["H1"] == 4)
        let later = try HabitGardenLiveSnapshot.read(database: database, at: today.addingTimeInterval(12 * 86400))
        precondition(later.growth["H1",default:0] < 4 && later.inactiveDays >= 7)
        precondition(Set((1...12).map { PosyFloraType.forHabit("H\($0)") }).count == 12)
        precondition(PosyFloraType.forHabit("H6") == .mimosa && PosyFloraType.forHabit("H7") == .hydrangea)
        precondition([0,3,10,25,60].map(HabitPlantGrowth.level) == [0,1,2,3,4])
        for value in 0..<70 { precondition(HabitPlantGrowth.progress(value) <= HabitPlantGrowth.progress(value + 1)) }
        print("PASS: 12 live plants, per-habit points, starred/periodic rules, live refresh, dormancy, five growth thresholds and unique species mapping")
    }
}

