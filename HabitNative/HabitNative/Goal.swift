import Foundation

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
}

struct GoalEntry: Sendable {
    let goalID: String
    let date: Date
    let text: String
}

protocol GoalRepository: Sendable {
    func availableGoals(for date: Date) async throws -> [Goal]
    func selectedGoalIDs(for date: Date) async throws -> Set<String>
    func saveSelectedGoalIDs(_ ids: Set<String>, for date: Date) async throws
    func submit(_ entry: GoalEntry) async throws
}

struct InMemoryGoalRepository: GoalRepository {
    func availableGoals(for date: Date) async throws -> [Goal] { Self.goals }
    func selectedGoalIDs(for date: Date) async throws -> Set<String> { [] }
    func saveSelectedGoalIDs(_ ids: Set<String>, for date: Date) async throws {}
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
    var homeSelectedIndex = 0
}
