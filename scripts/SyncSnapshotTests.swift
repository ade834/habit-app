import Foundation
import SQLite3

@main struct SyncSnapshotTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = NativeDatabase(fileURL: root.appendingPathComponent("native.sqlite"), legacyURL: nil)
        try db.withConnection { connection in
            try NativeDatabase.execute("INSERT INTO habit_logs(id,habit_id,local_date,timezone_offset_minutes,created_at) VALUES(42,'H1','2026-10-30',480,10)", in: connection)
            try NativeDatabase.execute("INSERT INTO point_transactions(id,habit_log_id,amount,created_at) VALUES(5,42,3,10)", in: connection)
            try NativeDatabase.execute("INSERT INTO timer_sessions(id,habit_id,target_seconds,started_at,status,focus_topic) VALUES(9,'H2',1800,20,'completed','私人文字')", in: connection)
            try NativeDatabase.execute("INSERT INTO review_entries(local_date,decision,result,improvement,updated_at) VALUES('2026-10-30','决定','结果','改进',25)", in: connection)
            try NativeDatabase.execute("INSERT INTO habit_activity_entries(habit_id,period_key,primary_text,secondary_text,first_value,second_value,completed_at) VALUES('H7','2026-W44','说明','',2.5,NULL,30)", in: connection)
        }
        let reader = SyncSnapshotReader(database: db)
        let first = try reader.read()
        let second = try reader.read()
        precondition(first == second)
        let points = first.first { $0.table == "point_transactions" }!
        precondition(points.fields["sync_log_habit_id"] == .text("H1"))
        precondition(points.fields["sync_log_local_date"] == .text("2026-10-30"))
        precondition(points.fields["id"] == nil && points.fields["habit_log_id"] == nil)
        let timer = first.first { $0.table == "timer_sessions" }!
        precondition(timer.fields["id"] == nil && timer.fields["focus_topic"] == .text("私人文字"))
        let finance = first.first { $0.table == "habit_activity_entries" }!
        precondition(finance.fields["first_value"] == .real(2.5) && finance.fields["second_value"] == .null)
        let roundTrip = try JSONDecoder().decode([SyncSnapshotItem].self, from: JSONEncoder().encode(first))
        precondition(roundTrip == first)
        try db.withConnection { try NativeDatabase.execute("CREATE TABLE future_private_data (value TEXT)", in: $0) }
        do { _ = try reader.read(); fatalError("unknown table must stop sync") }
        catch SyncSnapshotReader.SnapshotError.unknownSchema(let names) { precondition(names.contains("future_private_data")) }
        print("PASS: stable identities, foreign references, typed values and unknown-schema protection")
    }
}
