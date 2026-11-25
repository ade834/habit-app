import Foundation
import SQLite3

struct CustomTaskItem: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let cardId: String
    var title: String
    var promptQuestion: String
    var createdAt: Date
    var archived: Bool? = nil

    static let idPrefix = "custom-task:"
    var goalID: String { Self.idPrefix + id }

    func goal(cardTitle: String, plantSpecies: String? = nil, order: Int) -> Goal {
        Goal(id: goalID, title: title, category: "自定义卡片", summary: cardTitle,
             previewTitle: title, previewSummary: cardTitle, inputPrimary: promptQuestion,
             inputSecondary: "", completionLabel: "完成打卡",
             tint: GoalTint(red: 0.41, green: 0.35, blue: 0.65, opacity: 1), order: order,
             plantSpecies: plantSpecies)
    }
}

struct CustomCard: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var title: String
    var plantSpecies: String
    var plantGrowthValue: Int
    var createdAt: Date
    var lastInteractedAt: Date
    var tasks: [CustomTaskItem]

    static let species = ["ginkgo", "iris", "magnolia", "thistle"]

    static func activeIDs(in cards: [Self], limit: Int) -> Set<String> {
        let ranked = cards.sorted {
            let left = HabitPlantGrowth.level($0.plantGrowthValue)
            let right = HabitPlantGrowth.level($1.plantGrowthValue)
            if left != right { return left > right }
            if $0.lastInteractedAt != $1.lastInteractedAt { return $0.lastInteractedAt > $1.lastInteractedAt }
            return $0.id < $1.id
        }
        return Set(ranked.prefix(limit).map(\.id))
    }

    static func goals(from cards: [Self], includeArchived: Bool = false) -> [Goal] {
        let pairs = cards.flatMap { card in
            card.tasks.filter { includeArchived || $0.archived != true }.map { (card, $0) }
        }
        return pairs.enumerated().map { index, pair in
            pair.1.goal(cardTitle: pair.0.title, plantSpecies: pair.0.plantSpecies, order: 13 + index)
        }
    }
}

struct CustomCardStore {
    enum StoreError: LocalizedError {
        case invalidTitle, invalidSpecies, cardLimit, taskLimit, unavailable
        var errorDescription: String? {
            let key: String
            switch self {
            case .invalidTitle: key = "custom.error.title"
            case .invalidSpecies: key = "custom.error.species"
            case .cardLimit: key = "custom.error.cardLimit"
            case .taskLimit: key = "custom.error.taskLimit"
            case .unavailable: key = "custom.error.unavailable"
            }
            return AppLanguage.text(key)
        }
    }

    static let legacyKey = "habitnative.custom_cards.v1"
    let database: NativeDatabase

    init(database: NativeDatabase = NativeDatabase()) { self.database = database }

    func read() throws -> [CustomCard] {
        try database.withConnection { try Self.read(in: $0) }
    }

    static func read(in db: OpaquePointer) throws -> [CustomCard] {
        let tasks = try NativeDatabase.prepare("""
            SELECT t.id, t.card_id, t.title, t.prompt, t.created_at, t.archived, COUNT(l.id), MAX(l.created_at)
            FROM custom_tasks t LEFT JOIN habit_logs l ON l.habit_id = 'custom-task:' || t.id
            GROUP BY t.id ORDER BY t.created_at, t.id
            """, in: db)
        defer { sqlite3_finalize(tasks) }
        var byCard: [String: [CustomTaskItem]] = [:]
        var growth: [String: Int] = [:]
        var latest: [String: Date] = [:]
        var result = sqlite3_step(tasks)
        while result == SQLITE_ROW {
            let card = string(tasks, 1)
            byCard[card, default: []].append(CustomTaskItem(
                id: string(tasks, 0), cardId: card, title: string(tasks, 2),
                promptQuestion: string(tasks, 3), createdAt: date(tasks, 4),
                archived: sqlite3_column_int(tasks, 5) != 0
            ))
            growth[card, default: 0] += Int(sqlite3_column_int64(tasks, 6))
            if sqlite3_column_type(tasks, 7) != SQLITE_NULL {
                latest[card] = max(latest[card] ?? .distantPast, date(tasks, 7))
            }
            result = sqlite3_step(tasks)
        }
        try checkRead(result, db: db)

        let rows = try NativeDatabase.prepare("SELECT id,title,species,created_at,touched_at,initial_growth FROM custom_cards ORDER BY created_at,id", in: db)
        defer { sqlite3_finalize(rows) }
        var cards: [CustomCard] = []
        result = sqlite3_step(rows)
        while result == SQLITE_ROW {
            let id = string(rows, 0)
            cards.append(CustomCard(id: id, title: string(rows, 1), plantSpecies: string(rows, 2),
                                    plantGrowthValue: Int(sqlite3_column_int64(rows, 5)) + growth[id, default: 0],
                                    createdAt: date(rows, 3), lastInteractedAt: max(date(rows, 4), latest[id] ?? .distantPast),
                                    tasks: byCard[id, default: []]))
            result = sqlite3_step(rows)
        }
        try checkRead(result, db: db)
        return cards
    }

    static func activeTaskIDs(in db: OpaquePointer, limit: Int) throws -> Set<String> {
        let cards = try read(in: db)
        let active = CustomCard.activeIDs(in: cards, limit: limit)
        return Set(cards.filter { active.contains($0.id) }.flatMap(\.tasks).filter { $0.archived != true }.map(\.goalID))
    }

    func usedCreations(in bucket: String) throws -> Int {
        try database.withConnection { try Self.usedCreations(in: bucket, db: $0) }
    }

    private static func usedCreations(in bucket: String, db: OpaquePointer) throws -> Int {
        let row = try NativeDatabase.prepare("SELECT COUNT(*) FROM custom_tasks WHERE quota_bucket = ?", in: db)
        defer { sqlite3_finalize(row) }
        bucket.withCString { _ = sqlite3_bind_text(row, 1, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        guard sqlite3_step(row) == SQLITE_ROW else { throw StoreError.unavailable }
        return Int(sqlite3_column_int64(row, 0))
    }

    func saveCard(id: String?, title: String, species: String, limit: Int, at now: Date = .now) throws {
        let title = try Self.checkedTitle(title)
        try write { db in
            let cards = try Self.read(in: db)
            guard CustomCard.species.contains(species),
                  !cards.contains(where: { $0.id != id && $0.plantSpecies == species }) else { throw StoreError.invalidSpecies }
            let timestamp = Self.timestamp(now)
            if let id {
                guard CustomCard.activeIDs(in: cards, limit: limit).contains(id) else { throw StoreError.unavailable }
                try NativeDatabase.execute("UPDATE custom_cards SET title=?, species=?, touched_at=? WHERE id=?",
                                           bindings: [title, species, timestamp, id], in: db)
            } else {
                guard cards.count < limit else { throw StoreError.cardLimit }
                try NativeDatabase.execute("INSERT INTO custom_cards(id,title,species,created_at,touched_at) VALUES(?,?,?,?,?)",
                                           bindings: [UUID().uuidString, title, species, timestamp, timestamp], in: db)
            }
        }
    }

    func saveTask(cardID: String, id: String?, title: String, prompt: String, cardLimit: Int,
                  bucket: String, taskLimit: Int?, at now: Date = .now) throws {
        let title = try Self.checkedTitle(title)
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        try write { db in
            let cards = try Self.read(in: db)
            guard CustomCard.activeIDs(in: cards, limit: cardLimit).contains(cardID),
                  let card = cards.first(where: { $0.id == cardID }) else { throw StoreError.unavailable }
            if let id {
                guard card.tasks.contains(where: { $0.id == id && $0.archived != true }) else { throw StoreError.unavailable }
                try NativeDatabase.execute("UPDATE custom_tasks SET title=?, prompt=? WHERE id=?", bindings: [title, prompt, id], in: db)
            } else {
                if let taskLimit, try Self.usedCreations(in: bucket, db: db) >= taskLimit { throw StoreError.taskLimit }
                try NativeDatabase.execute("INSERT INTO custom_tasks(id,card_id,title,prompt,created_at,quota_bucket) VALUES(?,?,?,?,?,?)",
                                           bindings: [UUID().uuidString, cardID, title, prompt, Self.timestamp(now), bucket], in: db)
            }
            try Self.touch(cardID, at: now, in: db)
        }
    }

    func archiveTask(_ task: CustomTaskItem, cardLimit: Int) throws {
        try write { db in
            let cards = try Self.read(in: db)
            guard CustomCard.activeIDs(in: cards, limit: cardLimit).contains(task.cardId) else { throw StoreError.unavailable }
            try NativeDatabase.execute("UPDATE custom_tasks SET archived=1 WHERE id=? AND card_id=?",
                                       bindings: [task.id, task.cardId], in: db)
        }
    }

    static func touch(_ cardID: String, at date: Date, in db: OpaquePointer) throws {
        try NativeDatabase.execute("UPDATE custom_cards SET touched_at=MAX(touched_at, ?) WHERE id=?",
                                   bindings: [timestamp(date), cardID], in: db)
    }

    func migrateLegacy() throws {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.legacyKey) else { return }
        let legacy = try JSONDecoder().decode([CustomCard].self, from: data)
        try write { db in
            let migrated = try NativeDatabase.scalarInt("SELECT COUNT(*) FROM native_metadata WHERE key='custom_cards_imported'", in: db)
            guard migrated == 0 else { return }
            var used = Set(try Self.read(in: db).map(\.plantSpecies))
            for card in legacy {
                let preferred = CustomCard.species.contains(card.plantSpecies) ? card.plantSpecies : CustomCard.species[0]
                let species = used.contains(preferred) ? (CustomCard.species.first { !used.contains($0) } ?? preferred) : preferred
                used.insert(species)
                try NativeDatabase.execute("INSERT OR IGNORE INTO custom_cards VALUES(?,?,?,?,?,?)",
                                           bindings: [card.id, card.title, species, Self.timestamp(card.createdAt),
                                                      Self.timestamp(card.lastInteractedAt), String(max(0, card.plantGrowthValue))], in: db)
                for task in card.tasks {
                    try NativeDatabase.execute("INSERT OR IGNORE INTO custom_tasks VALUES(?,?,?,?,?,?,?)",
                                               bindings: [task.id, card.id, task.title, task.promptQuestion,
                                                          Self.timestamp(task.createdAt), "free", task.archived == true ? "1" : "0"], in: db)
                }
            }
            try NativeDatabase.execute("INSERT INTO native_metadata VALUES('custom_cards_imported','1')", in: db)
        }
        defaults.removeObject(forKey: Self.legacyKey)
    }

    private func write(_ operation: (OpaquePointer) throws -> Void) throws {
        try database.withConnection { db in
            try NativeDatabase.execute("BEGIN IMMEDIATE", in: db)
            do {
                try operation(db)
                try NativeDatabase.execute("COMMIT", in: db)
            } catch {
                try? NativeDatabase.execute("ROLLBACK", in: db)
                throw error
            }
        }
    }

    private static func checkedTitle(_ value: String) throws -> String {
        let title = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw StoreError.invalidTitle }
        return title
    }

    private static func string(_ row: OpaquePointer, _ column: Int32) -> String {
        sqlite3_column_text(row, column).map { String(cString: $0) } ?? ""
    }

    private static func date(_ row: OpaquePointer, _ column: Int32) -> Date {
        Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(row, column)))
    }

    private static func timestamp(_ date: Date) -> String { String(Int64(date.timeIntervalSince1970)) }

    private static func checkRead(_ result: Int32, db: OpaquePointer) throws {
        guard result == SQLITE_DONE else {
            throw NativeDatabaseError.unavailable(String(cString: sqlite3_errmsg(db)))
        }
    }
}
