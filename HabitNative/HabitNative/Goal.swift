import Foundation
import SQLite3

struct GoalTint: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
}

struct Goal: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let category: String
    let summary: String
    let previewTitle: String
    let previewSummary: String
    let inputPrimary: String
    let inputSecondary: String
    let completionLabel: String
    let tint: GoalTint
    let order: Int
    var completionCount: Int = 0
    var growthStage: String = "种子"
    var countsTowardQuota: Bool = true
    var isPeriodic: Bool = false
}

struct GoalEntry: Sendable {
    let goalID: String
    let date: Date
    let text: String
}

protocol GoalRepository: Sendable {
    func availableGoals(for date: Date) async throws -> [Goal]
    func selectedGoalIDs(for date: Date) async throws -> Set<String>
    func saveSelectedGoalIDs(_ ids: Set<String>, starredIDs: Set<String>, for date: Date) async throws
    func submit(_ entry: GoalEntry) async throws
}

struct SharedHabitRepository: GoalRepository {
    private let databaseURL: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.deshiru.habitapp")?
        .appendingPathComponent("habit_app.sqlite")

    func availableGoals(for date: Date) async throws -> [Goal] {
        guard let databaseURL, FileManager.default.fileExists(atPath: databaseURL.path) else {
            return []
        }
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else { return [] }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1200)
        var logCounts: [String: Int] = [:]
        var completions: [HabitCompletion] = []
        var statement: OpaquePointer?
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = .current
        dayFormatter.dateFormat = "yyyy-MM-dd"
        if sqlite3_prepare_v2(db, "SELECT habit_id, local_date FROM habit_logs", -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let raw = sqlite3_column_text(statement, 0), let rawDate = sqlite3_column_text(statement, 1) else { continue }
                let id = String(cString: raw)
                logCounts[id, default: 0] += 1
                if let day = dayFormatter.date(from: String(cString: rawDate)) {
                    completions.append(HabitCompletion(id: id, day: day))
                }
            }
        }
        sqlite3_finalize(statement)
        var enabledAt: [String: Date] = [:]
        statement = nil
        if sqlite3_prepare_v2(db, "SELECT habit_id, enabled_at FROM habit_selections", -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let raw = sqlite3_column_text(statement, 0) else { continue }
                enabledAt[String(cString: raw)] = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 1)))
            }
        }
        sqlite3_finalize(statement)
        let growth = HabitGrowthRules.progress(enabledAt: enabledAt, completions: completions, today: date)
        let selection = try SharedHabitSelectionStore().snapshot(at: date)
        let visible = Self.catalog.filter { !selection.completedPeriodicIDs.contains($0.id) }
        return visible.enumerated().map { index, goal in
            let count = logCounts[goal.id, default: 0]
            let stage = HabitGrowthRules.stage(for: growth[goal.id, default: 0])
            return Goal(id: goal.id, title: goal.title, category: goal.category, summary: goal.summary,
                        previewTitle: goal.title, previewSummary: goal.summary,
                        inputPrimary: goal.inputPrimary, inputSecondary: goal.inputSecondary,
                        completionLabel: goal.completionLabel, tint: goal.tint, order: index + 1,
                        completionCount: count, growthStage: stage,
                        countsTowardQuota: !selection.retainedPeriodicIDs.contains(goal.id),
                        isPeriodic: SharedHabitSelectionStore.isPeriodic(goal.id))
        }
    }

    func selectedGoalIDs(for date: Date) async throws -> Set<String> {
        let snapshot = try SharedHabitSelectionStore().snapshot(at: date)
        return snapshot.activeIDs.union(snapshot.starredIDs)
    }
    func saveSelectedGoalIDs(_ ids: Set<String>, starredIDs: Set<String>, for date: Date) async throws {
        try SharedHabitSelectionStore().save(ids, starredIDs: starredIDs, at: date)
    }
    func submit(_ entry: GoalEntry) async throws {}

    private static let catalog: [Goal] = [
        Goal(id: "H1", title: "每天100字复盘", category: "复盘", summary: "写下一个决定、一个结果、一个改进。", previewTitle: "每天100字复盘", previewSummary: "写下今天的关键一刻", inputPrimary: "今天发生了什么？", inputSecondary: "我下一步要怎么做？", completionLabel: "完成一次复盘", tint: tint(0), order: 1),
        Goal(id: "H2", title: "30分钟深度思考", category: "思考", summary: "给自己30分钟不被打断的时间。", previewTitle: "深度思考", previewSummary: "留出完整的不被打断", inputPrimary: "今天要思考什么？", inputSecondary: "思考后的下一步（选填）", completionLabel: "完成深度思考", tint: tint(1), order: 2),
        Goal(id: "H3", title: "做一件不舒服的事", category: "成长", summary: "舒适区外一小步，才是真正的成长区。", previewTitle: "走出舒适区", previewSummary: "做一件需要勇气的事", inputPrimary: "今天做了哪件不舒服的事？", inputSecondary: "它让我看见了什么？（选填）", completionLabel: "完成挑战", tint: tint(2), order: 3),
        Goal(id: "H4", title: "睡前断网", category: "睡眠", summary: "给大脑一个真正安静的收尾。", previewTitle: "睡前断网", previewSummary: "给今天一个安静收尾", inputPrimary: "", inputSecondary: "", completionLabel: "开始断网", tint: tint(3), order: 4),
        Goal(id: "H5", title: "每周联系一位旧友", category: "关系", summary: "真诚联系一位久未联系的人。", previewTitle: "联系旧友", previewSummary: "重新连接重要的人", inputPrimary: "", inputSecondary: "", completionLabel: "完成联系", tint: tint(4), order: 5),
        Goal(id: "H6", title: "管理信息摄入", category: "注意力", summary: "清理一个低价值信息源。", previewTitle: "信息摄入", previewSummary: "选择值得关注的内容", inputPrimary: "清理了哪个信息源？", inputSecondary: "为什么它不值得继续占用注意力？（选填）", completionLabel: "完成清理", tint: tint(5), order: 6),
        Goal(id: "H7", title: "每周财务盘点", category: "秩序", summary: "看清本周的资产投入与消费消耗。", previewTitle: "财务盘点", previewSummary: "看清每一笔钱的去向", inputPrimary: "本周盘点了什么？", inputSecondary: "下周准备怎么安排？（选填）", completionLabel: "完成财务盘点", tint: tint(6), order: 7),
        Goal(id: "H8", title: "勇敢说不", category: "边界", summary: "为重要的事守住一次边界。", previewTitle: "勇敢说不", previewSummary: "守住重要的边界", inputPrimary: "", inputSecondary: "", completionLabel: "完成一次拒绝", tint: tint(7), order: 8),
        Goal(id: "H9", title: "建立知识输出", category: "表达训练", summary: "把一个概念讲成别人能听懂的话。", previewTitle: "知识输出", previewSummary: "把想法讲清楚", inputPrimary: "这次输出讲清了什么？", inputSecondary: "你能讲给我听么？", completionLabel: "完成一次输出", tint: tint(8), order: 9),
        Goal(id: "H10", title: "每月读一本跨界硬核书", category: "学习", summary: "用跨界知识拓宽自己的认知边界。", previewTitle: "跨界阅读", previewSummary: "拓宽认知边界", inputPrimary: "", inputSecondary: "", completionLabel: "完成阅读", tint: tint(9), order: 10),
        Goal(id: "H11", title: "每年一次独自旅行", category: "探索", summary: "独自走进陌生环境，重新看见自己。", previewTitle: "独自旅行", previewSummary: "在陌生环境看见自己", inputPrimary: "", inputSecondary: "", completionLabel: "完成旅行", tint: tint(10), order: 11),
        Goal(id: "H12", title: "每天一句冷酷真话", category: "诚实", summary: "诚实面对今天正在逃避的事。", previewTitle: "冷酷真话", previewSummary: "面对正在逃避的事", inputPrimary: "", inputSecondary: "", completionLabel: "完成记录", tint: tint(11), order: 12)
    ]

    private static func tint(_ index: Int) -> GoalTint {
        let t = Double(index) / 11
        return GoalTint(red: (190 + 36 * t) / 255, green: (64 + 78 * t) / 255, blue: (147 - 38 * t) / 255, opacity: 0.26)
    }
}

struct InMemoryGoalRepository: GoalRepository {
    func availableGoals(for date: Date) async throws -> [Goal] { Self.goals }
    func selectedGoalIDs(for date: Date) async throws -> Set<String> { [] }
    func saveSelectedGoalIDs(_ ids: Set<String>, starredIDs: Set<String>, for date: Date) async throws {}
    func submit(_ entry: GoalEntry) async throws {}

    static let goals = [
        Goal(id: "H9", title: "建立知识输出", category: "表达训练", summary: "把一个概念讲成别人能听懂的话。", previewTitle: "知识输出", previewSummary: "把想法讲清楚", inputPrimary: "这次输出讲清了什么？", inputSecondary: "你能讲给我听么？", completionLabel: "完成一次输出", tint: tint(at: 0), order: 1),
        Goal(id: "H6", title: "管理信息摄入", category: "注意力", summary: "清理一个低价值信息源。", previewTitle: "信息摄入", previewSummary: "选择值得关注的内容", inputPrimary: "清理了哪个信息源？", inputSecondary: "为什么它不值得继续占用注意力？（选填）", completionLabel: "完成清理", tint: tint(at: 1), order: 2),
        Goal(id: "H4", title: "睡前断网", category: "睡眠", summary: "给大脑一个真正安静的收尾。", previewTitle: "睡前断网", previewSummary: "给今天一个安静收尾", inputPrimary: "", inputSecondary: "", completionLabel: "开始断网", tint: tint(at: 2), order: 3),
        Goal(id: "H1", title: "每天100字复盘", category: "复盘", summary: "写下一个决定、一个结果、一个改进。", previewTitle: "每天100字复盘", previewSummary: "写下今天的关键一刻", inputPrimary: "今天发生了什么？", inputSecondary: "我下一步要怎么做？", completionLabel: "完成一次复盘", tint: tint(at: 3), order: 4),
        Goal(id: "H2", title: "30分钟深度思考", category: "思考", summary: "留出一段不被通知和输入打断的完整时间。", previewTitle: "深度思考", previewSummary: "留出完整的不被打断", inputPrimary: "今天要思考什么？", inputSecondary: "思考后的下一步（选填）", completionLabel: "完成深度思考", tint: tint(at: 4), order: 5),
        Goal(id: "H7", title: "每周财务盘点", category: "秩序", summary: "看清本周的钱去了哪里，并决定下周如何使用。", previewTitle: "财务盘点", previewSummary: "看清每一笔钱的去向", inputPrimary: "本周盘点了什么？", inputSecondary: "下周准备怎么安排？（选填）", completionLabel: "完成财务盘点", tint: tint(at: 5), order: 6),
        Goal(id: "H3", title: "做一件不舒服的事", category: "成长", summary: "舒适区外一小步，才是真正的成长区。", previewTitle: "走出舒适区", previewSummary: "做一件需要勇气的事", inputPrimary: "今天做了哪件不舒服的事？", inputSecondary: "它让我看见了什么？（选填）", completionLabel: "完成挑战", tint: tint(at: 6), order: 7)
    ]

    private static func tint(at index: Int) -> GoalTint {
        let start = (190.0, 64.0, 147.0)
        let end = (226.0, 142.0, 109.0)
        let progress = Double(index) / 6.0
        return GoalTint(
            red: (start.0 + (end.0 - start.0) * progress) / 255,
            green: (start.1 + (end.1 - start.1) * progress) / 255,
            blue: (start.2 + (end.2 - start.2) * progress) / 255,
            opacity: index == 2 ? 0.30 : 0.26
        )
    }
}

enum TodayMode: Equatable {
    case homeUnselected
    case browsingDeck
    case homeSelected
    case executing(goalID: String)
}

enum AppTab: Equatable {
    case today, garden, review, settings
}

struct TodayGoalState: Equatable {
    var tab: AppTab = .today
    var mode: TodayMode = .homeUnselected
    var focusedGoalID = "H6"
    var selectedGoalIDs: Set<String> = []
    var starredGoalIDs: Set<String> = []
    var starLimit = 1
    var isFirstSelection = false
    var homeSelectedIndex = 0
}
