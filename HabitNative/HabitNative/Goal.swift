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
    var completedToday: Bool = false
    var isStarred: Bool = false
}

enum HabitSubmissionPayload: Sendable {
    case review(decision: String, result: String, improvement: String)
    case focus(sessionID: Int64)
    case challenge(cardIndex: Int, primaryText: String, secondaryText: String)
    case disconnect(sessionID: Int64)
    case activity(primaryText: String, secondaryText: String, firstValue: Double?, secondValue: Double?)
    case travelPlan(destination: String, days: Int, focus: String, preparation: String, summary: String, completed: Bool)
}

struct TravelPlanRecord: Sendable {
    let destination: String
    let days: Int
    let focus: String
    let preparation: String
}

struct HabitChallengeRecord: Sendable {
    let cardIndex: Int
    let swapCount: Int
    let title: String
}

struct NativeTimerRecord: Sendable {
    let id: Int64
    let startedAt: Date
    let pausedAt: Date?
    let accumulatedPauseSeconds: Int
    let status: String
}

struct GoalEntry: Sendable {
    let goalID: String
    let date: Date
    let payload: HabitSubmissionPayload
}

protocol GoalRepository: Sendable {
    func availableGoals(for date: Date) async throws -> [Goal]
    func selectedGoals(for date: Date) async throws -> [Goal]
    func selectedGoalIDs(for date: Date) async throws -> Set<String>
    func saveSelectedGoalIDs(_ ids: Set<String>, starredIDs: Set<String>, for date: Date) async throws
    func submit(_ entry: GoalEntry) async throws
    func recoverInterruptedSessions() async throws
    func travelPlanForCurrentYear() async throws -> TravelPlanRecord?
    func challengeForToday() async throws -> HabitChallengeRecord
    func swapChallenge() async throws -> HabitChallengeRecord
}

struct SharedHabitRepository: GoalRepository {
    private let database = NativeDatabase()

    func availableGoals(for date: Date) async throws -> [Goal] {
        let data = try database.withConnection { db in try database.goalMetrics(in: db, today: date) }
        let selection = try SharedHabitSelectionStore().snapshot(at: date)
        let visible = Self.catalog.filter { !selection.completedPeriodicIDs.contains($0.id) }
        return makeGoals(visible, selection: selection, data: data)
    }

    func selectedGoals(for date: Date) async throws -> [Goal] {
        let selection = try SharedHabitSelectionStore().snapshot(at: date)
        let selectedIDs = selection.activeIDs.union(selection.starredIDs)
        let metrics = try database.withConnection { db in try database.goalMetrics(in: db, today: date) }
        let selected = Self.catalog.filter {
            selectedIDs.contains($0.id) && !metrics.completedTodayIDs.contains($0.id)
        }
        return makeGoals(selected, selection: selection, data: metrics)
    }

    private func makeGoals(_ source: [Goal], selection: HabitSelectionSnapshot, data: HabitGoalMetrics) -> [Goal] {
        return source.map { goal in
            let count = data.completionCounts[goal.id, default: 0]
            let stage = HabitGrowthRules.stage(for: data.growthProgress[goal.id, default: 0])
            return Goal(id: goal.id, title: goal.title, category: goal.category, summary: goal.summary,
                        previewTitle: goal.title, previewSummary: goal.summary,
                        inputPrimary: goal.inputPrimary, inputSecondary: goal.inputSecondary,
                        completionLabel: goal.completionLabel, tint: goal.tint, order: goal.order,
                        completionCount: count, growthStage: stage,
                        countsTowardQuota: !selection.retainedPeriodicIDs.contains(goal.id),
                        isPeriodic: SharedHabitSelectionStore.isPeriodic(goal.id),
                        completedToday: data.completedTodayIDs.contains(goal.id),
                        isStarred: selection.starredIDs.contains(goal.id))
        }
    }

    func selectedGoalIDs(for date: Date) async throws -> Set<String> {
        let snapshot = try SharedHabitSelectionStore().snapshot(at: date)
        return snapshot.activeIDs.union(snapshot.starredIDs)
    }
    func saveSelectedGoalIDs(_ ids: Set<String>, starredIDs: Set<String>, for date: Date) async throws {
        try SharedHabitSelectionStore().save(ids, starredIDs: starredIDs, at: date)
    }
    func submit(_ entry: GoalEntry) async throws { try database.submit(entry) }
    func recoverInterruptedSessions() async throws { try database.recoverInterruptedDisconnectSessions() }
    func travelPlanForCurrentYear() async throws -> TravelPlanRecord? { try database.travelPlan(year: Calendar.current.component(.year, from: .now)) }
    func challengeForToday() async throws -> HabitChallengeRecord { try database.challengeForToday() }
    func swapChallenge() async throws -> HabitChallengeRecord { try database.swapChallenge() }

    static let catalog: [Goal] = [
        Goal(id: "H1", title: "每日百字复盘", category: "复盘", summary: "写下一个决定、一个结果、一个改进。", previewTitle: "每日百字复盘", previewSummary: "写下今天的关键一刻", inputPrimary: "今天发生了什么？", inputSecondary: "我下一步要怎么做？", completionLabel: "完成一次复盘", tint: tint(0), order: 1),
        Goal(id: "H2", title: "深度思考", category: "思考", summary: "给自己30分钟不被打断的时间。", previewTitle: "深度思考", previewSummary: "留出完整的不被打断", inputPrimary: "今天要思考什么？", inputSecondary: "思考后的下一步（选填）", completionLabel: "完成深度思考", tint: tint(1), order: 2),
        Goal(id: "H3", title: "走出舒适区", category: "成长", summary: "舒适区外一小步，才是真正的成长区。", previewTitle: "走出舒适区", previewSummary: "做一件需要勇气的事", inputPrimary: "今天做了哪件不舒服的事？", inputSecondary: "它让我看见了什么？（选填）", completionLabel: "完成挑战", tint: tint(2), order: 3),
        Goal(id: "H4", title: "睡前断网", category: "睡眠", summary: "给大脑一个真正安静的收尾。", previewTitle: "睡前断网", previewSummary: "给今天一个安静收尾", inputPrimary: "", inputSecondary: "", completionLabel: "开始断网", tint: tint(3), order: 4),
        Goal(id: "H5", title: "联系旧友", category: "关系", summary: "真诚联系一位久未联系的人。", previewTitle: "联系旧友", previewSummary: "重新连接重要的人", inputPrimary: "", inputSecondary: "", completionLabel: "完成联系", tint: tint(4), order: 5),
        Goal(id: "H6", title: "管理信息摄入", category: "注意力", summary: "清理一个低价值信息源。", previewTitle: "管理信息摄入", previewSummary: "选择值得关注的内容", inputPrimary: "清理了哪个信息源？", inputSecondary: "为什么它不值得继续占用注意力？（选填）", completionLabel: "完成清理", tint: tint(5), order: 6),
        Goal(id: "H7", title: "每周财务盘点", category: "秩序", summary: "看清本周的资产投入与消费消耗。", previewTitle: "每周财务盘点", previewSummary: "看清每一笔钱的去向", inputPrimary: "本周盘点了什么？", inputSecondary: "下周准备怎么安排？（选填）", completionLabel: "完成财务盘点", tint: tint(6), order: 7),
        Goal(id: "H8", title: "勇敢说不", category: "边界", summary: "为重要的事守住一次边界。", previewTitle: "勇敢说不", previewSummary: "守住重要的边界", inputPrimary: "", inputSecondary: "", completionLabel: "完成一次拒绝", tint: tint(7), order: 8),
        Goal(id: "H9", title: "建立知识输出", category: "表达训练", summary: "把一个概念讲成别人能听懂的话。", previewTitle: "建立知识输出", previewSummary: "把想法讲清楚", inputPrimary: "这次输出讲清了什么？", inputSecondary: "你能讲给我听么？", completionLabel: "完成一次输出", tint: tint(8), order: 9),
        Goal(id: "H10", title: "每月跨界阅读", category: "学习", summary: "用跨界知识拓宽自己的认知边界。", previewTitle: "每月跨界阅读", previewSummary: "拓宽认知边界", inputPrimary: "", inputSecondary: "", completionLabel: "完成阅读", tint: tint(9), order: 10),
        Goal(id: "H11", title: "年度独自旅行", category: "探索", summary: "独自走进陌生环境，重新看见自己。", previewTitle: "年度独自旅行", previewSummary: "在陌生环境看见自己", inputPrimary: "", inputSecondary: "", completionLabel: "完成旅行", tint: tint(10), order: 11),
        Goal(id: "H12", title: "每日一句真话", category: "诚实", summary: "诚实面对今天正在逃避的事。", previewTitle: "每日一句真话", previewSummary: "面对正在逃避的事", inputPrimary: "", inputSecondary: "", completionLabel: "完成记录", tint: tint(11), order: 12)
    ]

    private static func tint(_ index: Int) -> GoalTint {
        let t = Double(index) / 11
        return GoalTint(red: (190 + 36 * t) / 255, green: (64 + 78 * t) / 255, blue: (147 - 38 * t) / 255, opacity: 0.26)
    }
}

struct InMemoryGoalRepository: GoalRepository {
    func availableGoals(for date: Date) async throws -> [Goal] { Self.goals }
    func selectedGoals(for date: Date) async throws -> [Goal] { [] }
    func selectedGoalIDs(for date: Date) async throws -> Set<String> { [] }
    func saveSelectedGoalIDs(_ ids: Set<String>, starredIDs: Set<String>, for date: Date) async throws {}
    func submit(_ entry: GoalEntry) async throws {}
    func recoverInterruptedSessions() async throws {}
    func travelPlanForCurrentYear() async throws -> TravelPlanRecord? { nil }
    func challengeForToday() async throws -> HabitChallengeRecord { HabitChallengeRecord(cardIndex: 0, swapCount: 0, title: "每日挑战") }
    func swapChallenge() async throws -> HabitChallengeRecord { try await challengeForToday() }

    static let goals = [
        Goal(id: "H9", title: "建立知识输出", category: "表达训练", summary: "把一个概念讲成别人能听懂的话。", previewTitle: "建立知识输出", previewSummary: "把想法讲清楚", inputPrimary: "这次输出讲清了什么？", inputSecondary: "你能讲给我听么？", completionLabel: "完成一次输出", tint: tint(at: 0), order: 1),
        Goal(id: "H6", title: "管理信息摄入", category: "注意力", summary: "清理一个低价值信息源。", previewTitle: "管理信息摄入", previewSummary: "选择值得关注的内容", inputPrimary: "清理了哪个信息源？", inputSecondary: "为什么它不值得继续占用注意力？（选填）", completionLabel: "完成清理", tint: tint(at: 1), order: 2),
        Goal(id: "H4", title: "睡前断网", category: "睡眠", summary: "给大脑一个真正安静的收尾。", previewTitle: "睡前断网", previewSummary: "给今天一个安静收尾", inputPrimary: "", inputSecondary: "", completionLabel: "开始断网", tint: tint(at: 2), order: 3),
        Goal(id: "H1", title: "每日百字复盘", category: "复盘", summary: "写下一个决定、一个结果、一个改进。", previewTitle: "每日百字复盘", previewSummary: "写下今天的关键一刻", inputPrimary: "今天发生了什么？", inputSecondary: "我下一步要怎么做？", completionLabel: "完成一次复盘", tint: tint(at: 3), order: 4),
        Goal(id: "H2", title: "深度思考", category: "思考", summary: "留出一段不被通知和输入打断的完整时间。", previewTitle: "深度思考", previewSummary: "留出完整的不被打断", inputPrimary: "今天要思考什么？", inputSecondary: "思考后的下一步（选填）", completionLabel: "完成深度思考", tint: tint(at: 4), order: 5),
        Goal(id: "H7", title: "每周财务盘点", category: "秩序", summary: "看清本周的钱去了哪里，并决定下周如何使用。", previewTitle: "每周财务盘点", previewSummary: "看清每一笔钱的去向", inputPrimary: "本周盘点了什么？", inputSecondary: "下周准备怎么安排？（选填）", completionLabel: "完成财务盘点", tint: tint(at: 5), order: 6),
        Goal(id: "H3", title: "走出舒适区", category: "成长", summary: "舒适区外一小步，才是真正的成长区。", previewTitle: "走出舒适区", previewSummary: "做一件需要勇气的事", inputPrimary: "今天做了哪件不舒服的事？", inputSecondary: "它让我看见了什么？（选填）", completionLabel: "完成挑战", tint: tint(at: 6), order: 7)
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
    var completedRegularGoalIDs: Set<String> = []
    var completedSelectedGoalIDs: Set<String> = []
    var starLimit = 1
    var isFirstSelection = false
    var homeSelectedIndex = 0
}
