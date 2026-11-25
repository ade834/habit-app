import Foundation
import SQLite3
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Builds a readable export entirely on device. It is not a database backup.
enum LocalRecordExport {
    static func createFile(database: NativeDatabase = NativeDatabase(), goalNames: [String: String]? = nil) throws -> URL {
        let goals = goalNames ?? Dictionary(SharedHabitRepository.historyCatalog().map { ($0.id, AppLanguage.text($0.title)) }, uniquingKeysWith: { first, _ in first })
        var text = "# MAYBII \(AppLanguage.text("export.title"))\n\n\(AppLanguage.text("export.created")): \(Date.now.formatted(date: .numeric, time: .shortened))\n"
        try database.withConnection { db in
            func rows(_ sql: String, columns: Int, consume: ([String]) -> Void) throws {
                let statement = try NativeDatabase.prepare(sql, in: db)
                defer { sqlite3_finalize(statement) }
                while true {
                    let result = sqlite3_step(statement)
                    if result == SQLITE_DONE { break }
                    guard result == SQLITE_ROW else { throw NativeDatabaseError.unavailable("无法读取导出数据。") }
                    consume((0..<columns).map { index in
                        let column = Int32(index)
                        guard let bytes = sqlite3_column_text(statement, column) else { return "" }
                        let count = Int(sqlite3_column_bytes(statement, column))
                        return String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self)
                    })
                }
            }
            text += "\n## \(AppLanguage.text("export.checkins"))\n"
            try rows("SELECT local_date, habit_id FROM habit_logs ORDER BY local_date DESC, id", columns: 2) { row in
                text += "\n- \(row[0]) · \(goals[row[1]] ?? row[1]) · \(AppLanguage.text("export.completed"))"
            }
            text += "\n\n## \(AppLanguage.text("export.entries"))\n"
            try rows("SELECT local_date, decision, result, improvement FROM review_entries ORDER BY local_date DESC", columns: 4) { row in
                text += "\n### \(row[0])\n\n\(AppLanguage.text("export.decision")): \(row[1])\n\n\(AppLanguage.text("export.result")): \(row[2])\n\n\(AppLanguage.text("export.improvement")): \(row[3])\n"
            }
            for (table, key, label) in [("weekly_ai_reports", "week_key", "export.weekly"), ("monthly_ai_reports", "month_key", "export.monthly")] {
                text += "\n## \(AppLanguage.text(label))\n"
                try rows("SELECT \(key), analysis, encouragement FROM \(table) ORDER BY \(key) DESC", columns: 3) { row in
                    text += "\n### \(row[0])\n\n\(row[1])\n\n\(row[2])\n"
                }
            }
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        let url = directory.appendingPathComponent("MAYBII-export.md")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            return url
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}

struct LocalExportItem: Identifiable { let id = UUID(); let url: URL }
#if canImport(UIKit)
struct LocalExportShareSheet: UIViewControllerRepresentable {
    let item: LocalExportItem
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [item.url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: item.url.deletingLastPathComponent())
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
