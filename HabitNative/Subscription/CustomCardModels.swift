import Foundation
import SwiftUI
import Combine

/// 自定义任务实体
public struct CustomTaskItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let cardId: String
    public var title: String
    public var promptQuestion: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, cardId: String, title: String, promptQuestion: String = "今天有什么新的体会或收获？", createdAt: Date = Date()) {
        self.id = id
        self.cardId = cardId
        self.title = title
        self.promptQuestion = promptQuestion
        self.createdAt = createdAt
    }
}

/// 自定义卡片实体（任务容器，对应一株植物与成长值）
public struct CustomCard: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var plantSpecies: String // 16 种花卉之一，如 peony, iris, ginkgo 等
    public var plantGrowthValue: Int
    public var createdAt: Date
    public var lastInteractedAt: Date
    public var tasks: [CustomTaskItem]

    public init(
        id: String = UUID().uuidString,
        title: String,
        plantSpecies: String = "peony",
        plantGrowthValue: Int = 0,
        createdAt: Date = Date(),
        lastInteractedAt: Date = Date(),
        tasks: [CustomTaskItem] = []
    ) {
        self.id = id
        self.title = title
        self.plantSpecies = plantSpecies
        self.plantGrowthValue = plantGrowthValue
        self.createdAt = createdAt
        self.lastInteractedAt = lastInteractedAt
        self.tasks = tasks
    }
}

/// 自定义卡片与任务持久化存储管理
@MainActor
public final class CustomCardStore: ObservableObject {
    public static let shared = CustomCardStore()

    private static let storageKey = "habitnative.custom_cards.v1"

    @Published public private(set) var cards: [CustomCard] = []

    private init() {
        loadCards()
    }

    public func loadCards() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            self.cards = []
            return
        }
        do {
            self.cards = try JSONDecoder().decode([CustomCard].self, from: data)
        } catch {
            self.cards = []
        }
    }

    public func saveCards() {
        do {
            let data = try JSONEncoder().encode(cards)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            // Log or ignore
        }
    }

    /// 获取当前会员状态下被激活的卡片（受权益限制与降级排序规则约束）
    public var activeCards: [CustomCard] {
        let manager = SubscriptionManager.shared
        let summaries = cards.map { (id: $0.id, plantLevel: HabitPlantGrowth.level($0.plantGrowthValue), lastInteractedAt: $0.lastInteractedAt) }
        let activeIDs = manager.resolveActiveCardIDs(from: summaries)
        return cards.filter { activeIDs.contains($0.id) }
    }

    /// 冻结/暂不可执行任务的卡片（到期或超额部分，数据完全保留）
    public var pausedCards: [CustomCard] {
        let activeIDs = Set(activeCards.map(\.id))
        return cards.filter { !activeIDs.contains($0.id) }
    }

    /// 是否可以创建新自定义卡片
    public var canCreateNewCard: Bool {
        cards.count < SubscriptionManager.shared.currentTier.maxCustomCards
    }

    /// 创建自定义卡片
    @discardableResult
    public func createCard(title: String, plantSpecies: String) -> CustomCard? {
        guard canCreateNewCard else { return nil }
        let card = CustomCard(title: title, plantSpecies: plantSpecies)
        cards.append(card)
        saveCards()
        return card
    }

    /// 在指定卡片下成功创建新任务（依据规范第二节：成功保存新任务才消耗额度）
    @discardableResult
    public func createTask(in cardId: String, title: String, promptQuestion: String) -> CustomTaskItem? {
        guard SubscriptionManager.shared.canCreateCustomTask else { return nil }
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return nil }

        let task = CustomTaskItem(cardId: cardId, title: title, promptQuestion: promptQuestion)
        cards[index].tasks.append(task)
        cards[index].lastInteractedAt = Date()
        saveCards()

        // 仅在成功保存后消耗额度
        SubscriptionManager.shared.recordCustomTaskCreationSuccess()
        return task
    }

    /// 修改已有任务（依据规范第二节：修改任务不消耗额度）
    public func updateTask(cardId: String, taskId: String, newTitle: String, newPrompt: String) {
        guard let cardIndex = cards.firstIndex(where: { $0.id == cardId }),
              let taskIndex = cards[cardIndex].tasks.firstIndex(where: { $0.id == taskId }) else { return }

        cards[cardIndex].tasks[taskIndex].title = newTitle
        cards[cardIndex].tasks[taskIndex].promptQuestion = newPrompt
        cards[cardIndex].lastInteractedAt = Date()
        saveCards()
    }

    /// 删除任务（依据规范第二节：删除任务不返还额度）
    public func deleteTask(cardId: String, taskId: String) {
        guard let cardIndex = cards.firstIndex(where: { $0.id == cardId }) else { return }
        cards[cardIndex].tasks.removeAll { $0.id == taskId }
        cards[cardIndex].lastInteractedAt = Date()
        saveCards()
    }
}
