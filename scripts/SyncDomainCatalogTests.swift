import Foundation
import SQLite3

@main struct SyncDomainCatalogTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = NativeDatabase(fileURL: root.appendingPathComponent("native.sqlite"), legacyURL: nil)
        try database.withConnection { db in
            let stmt = try NativeDatabase.prepare("SELECT name FROM sqlite_master WHERE type='table'", in: db)
            defer { sqlite3_finalize(stmt) }
            var tables = Set<String>()
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let name = sqlite3_column_text(stmt, 0) { tables.insert(String(cString: name)) }
            }
            let unknown = SyncDomainCatalog.unknownTables(in: tables)
            precondition(unknown.isEmpty, "Unclassified tables: \(unknown)")
            precondition(SyncDomainCatalog.unknownTables(in: tables.union(["future_user_data"])) == ["future_user_data"])
            precondition(Set(SyncDomainCatalog.domains.map(\.table)).count == SyncDomainCatalog.domains.count)
            for domain in SyncDomainCatalog.domains where tables.contains(domain.table) {
                let cols = try NativeDatabase.prepare("PRAGMA table_info(\(domain.table))", in: db)
                var names = Set<String>()
                while sqlite3_step(cols) == SQLITE_ROW {
                    if let name = sqlite3_column_text(cols, 1) { names.insert(String(cString: name)) }
                }
                sqlite3_finalize(cols)
                switch domain.identity {
                case .natural(let keys): precondition(!keys.isEmpty && Set(keys).isSubset(of: names))
                case .localRowIDWithStableUUID(let key), .logReference(let key): precondition(names.contains(key))
                case .localMetadata: break
                }
            }
        }
        print("PASS: all current data tables classified; unknown tables are rejected")
    }
}
