import Foundation

@main struct SyncBootstrapTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func db(_ name: String) -> NativeDatabase { NativeDatabase(fileURL: root.appendingPathComponent(name), legacyURL: nil) }
        let source = db("source.sqlite"), target = db("target.sqlite"), partial = db("partial.sqlite")
        try source.withConnection { db in
            try NativeDatabase.execute("INSERT INTO habit_logs(id,habit_id,local_date,timezone_offset_minutes,created_at) VALUES(42,'H1','2026-10-30',480,10)", in: db)
            try NativeDatabase.execute("INSERT INTO point_transactions(id,habit_log_id,amount,created_at) VALUES(5,42,3,10)", in: db)
            try NativeDatabase.execute("INSERT INTO timer_sessions(id,habit_id,target_seconds,started_at,status,focus_topic) VALUES(9,'H2',1800,20,'completed','私人文字')", in: db)
            try NativeDatabase.execute("INSERT INTO review_entries(local_date,decision,result,improvement,updated_at) VALUES('2026-10-30','决定','结果','改进',25)", in: db)
            try NativeDatabase.execute("INSERT INTO habit_activity_entries(habit_id,period_key,primary_text,secondary_text,first_value,second_value,completed_at) VALUES('H7','2026-W44','说明','',2.5,NULL,30)", in: db)
        }
        let snapshot = try SyncSnapshotReader(database: source).read()
        try SyncSnapshotBootstrap(database: target).restoreIntoEmptyDevice(snapshot)
        let restored = try SyncSnapshotReader(database: target).read()
        precondition(snapshot == restored)
        do { try SyncSnapshotBootstrap(database: target).restoreIntoEmptyDevice(snapshot); fatalError("overwrote existing data") }
        catch SyncSnapshotBootstrap.BootstrapError.localDataPresent { }
        let withoutLog = snapshot.filter { $0.table != "habit_logs" }
        do { try SyncSnapshotBootstrap(database: partial).restoreIntoEmptyDevice(withoutLog); fatalError("missing log accepted") }
        catch SyncSnapshotBootstrap.BootstrapError.missingDependency { }
        let afterFailure = try SyncSnapshotReader(database: partial).read()
        precondition(afterFailure.isEmpty, "failed bootstrap must roll back all rows")
        print("PASS: empty-device restore, relationship remapping and overwrite/rollback protection")
    }
}
