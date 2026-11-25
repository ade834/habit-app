import Foundation
import SwiftUI
import Combine

// MARK: - Habit To Garden Flower Species Mapping
enum HabitSpeciesMapper {
    static func defaultSpecies(for habitId: String) -> String {
        switch habitId {
        case "H1": return "peony"          // 每天100字复盘 -> 牡丹 (S · 逐层螺旋绽放)
        case "H2": return "orchid"         // 30分钟深度思考 -> 兰花 (S · 不对称光脉)
        case "H3": return "rose"           // 做一件不舒服的事 -> 月季 (S · 瓣缘发光)
        case "H4": return "lily-of-valley" // 睡前断网 -> 铃兰 (B · 纯白串铃)
        case "H6": return "dandelion"      // 管理信息摄入 -> 蒲公英 (A · 绒毛飞散)
        case "H7": return "sunflower"      // 每周财务盘点 -> 向日葵 (A · 斐波那契金盘)
        case "H9": return "lotus"          // 建立知识输出 -> 莲花 (S · 双层放射金粉)
        default:
            return "daisy"
        }
    }

    /// Converts legacy points/completions and inactivity days to Garden Spec levels (-3...3)
    static func calculateStageLevel(points: Int, completions: Int, inactivityDays: Int, isDormant: Bool) -> Int {
        if isDormant || inactivityDays >= 8 {
            return -2 // 凋谢 faded
        } else if inactivityDays >= 4 {
            return -1 // 枯萎 wilting
        }

        // Active growth based on points & completions
        let score = max(points, completions)
        if score >= 6 {
            return 3 // 开花 blooming
        } else if score >= 3 {
            return 2 // 花苞 budding
        } else if score >= 1 {
            return 1 // 发芽 sprouting
        } else {
            return 0 // 埋种 seeded
        }
    }
}

// MARK: - Habit Growth & Flower Record State
struct HabitGardenItem: Identifiable, Sendable {
    var id: String { habit.id }
    let habit: Goal
    var record: BloomRecord
    var points: Int
    var growthValue: Int = 0
    var completions: Int
    var inactivityDays: Int
    var isDormant: Bool
    var renderLevel: Double
    var targetLevel: Int
    var lastLevelChangeTime: Date
    var isDissolving: Bool

    var stageTitle: String {
        return (isDormant ? AppLanguage.text("休眠 · ") : "") + AppLanguage.text(HabitGrowthRules.stage(for: growthValue))
    }

    var stageDescription: String {
        switch targetLevel {
        case 4: return AppLanguage.text("繁茂形态。这是长期坚持留下的生长痕迹。")
        case 3: return AppLanguage.text("全盛绽放。这是你坚持打磨出的绚烂形态。")
        case 2: return AppLanguage.text("花苞饱满，正在积蓄绽放的力量。")
        case 1: return AppLanguage.text("已抽出一对嫩绿新芽，为你刚刚迈出的一步鼓劲。")
        case 0: return AppLanguage.text("一小撮松软沃土与初生芽尖，等待你的第一次行动。")
        case -1: return AppLanguage.text("稍显缺水与低垂，记得今天为它浇水打卡。")
        case -2: return AppLanguage.text("花瓣暂时隐去，只留根茎静候复苏。")
        default: return AppLanguage.text("种子在土里安眠，随时可以重新唤醒。")
        }
    }

    var speciesChineseName: String {
        if let flora = PosyFloraType(rawValue: record.species) { return flora.localizedSimpleName }
        switch record.species {
        case "peony": return AppLanguage.text("牡丹")
        case "orchid": return AppLanguage.text("兰花")
        case "rose": return AppLanguage.text("月季")
        case "lily-of-valley": return AppLanguage.text("铃兰")
        case "dandelion": return AppLanguage.text("蒲公英")
        case "sunflower": return AppLanguage.text("向日葵")
        case "lotus": return AppLanguage.text("莲花")
        default: return AppLanguage.text("雏菊")
        }
    }

    var speciesIconName: String {
        switch record.species {
        case "peony": return "camera.macro"
        case "orchid": return "sparkles"
        case "rose": return "suit.heart.fill"
        case "lily-of-valley": return "bell.fill"
        case "dandelion": return "wind"
        case "sunflower": return "sun.max.fill"
        case "lotus": return "drop.fill"
        default: return "leaf.fill"
        }
    }

    var nextLevelRequirement: (current: Int, target: Int, progress: Double, description: String) {
        let thresholds = [0, 3, 10, 25, 60]
        let level = HabitPlantGrowth.level(growthValue)
        guard level < 4 else { return (growthValue, 60, 1, "繁茂形态已达成") }
        let next = thresholds[level + 1]
        let progress = Double(growthValue - thresholds[level]) / Double(next - thresholds[level])
        return (growthValue, next, min(1, max(0, progress)), String(format: AppLanguage.text("再积累 %lld 养成值进阶"), next - growthValue))
    }
}

// MARK: - Garden Bridge ViewModel
@MainActor
final class GardenHabitViewModel: ObservableObject {
    @Published var items: [HabitGardenItem] = []
    @Published var selectedItem: HabitGardenItem?
    @Published var focusedHabitId: String? = "H1"
    @Published var filterMode: GardenFilterMode = .all
    @Published var activeTabPill: GardenTabPill = .flowers
    @Published var windOffset: CGFloat = 0
    @Published var lastTouchedId: String? = nil
    @Published var bannerMessage: String? = nil
    @Published var dataError: String? = nil
    private var lastSnapshot: HabitGardenLiveSnapshot?
    private var lastPlantLimit: Int?
    private var lastCustomCards: [CustomCard] = []

    private var debounceCancellable: AnyCancellable?
    private let positionsStorageKey = "garden_flower_positions_v1"

    enum GardenFilterMode {
        case all, bloomingOnly, needsCare
    }

    enum GardenTabPill {
        case flowers
        case meanings
    }

    init(goals: [Goal] = []) {
        loadHabitsAndFlowers(goals: goals)
    }

    func loadHabitsAndFlowers(goals: [Goal]) {
        do {
            let snapshot = try HabitGardenLiveSnapshot.read()
            let plantLimit = SubscriptionManager.currentGardenPlantLimit
            let cards = try CustomCardStore().read()
            guard snapshot != lastSnapshot || plantLimit != lastPlantLimit || cards != lastCustomCards else { return }
            let savedPositions = loadSavedPositions()
            let oldItems = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

            func item(for goal: Goal, species: String, growth: Int, points: Int, completions: Int) -> HabitGardenItem {
                let level = HabitPlantGrowth.level(growth)
                let record = BloomRecord(id: goal.id, species: species, level: min(3, level),
                                         position: savedPositions[goal.id] ?? CGPoint(x: 0.5, y: 0.2))
                return HabitGardenItem(habit: goal, record: record, points: points, growthValue: growth,
                    completions: completions, inactivityDays: snapshot.inactiveDays, isDormant: snapshot.inactiveDays >= 7,
                    renderLevel: oldItems[goal.id]?.renderLevel ?? Double(level), targetLevel: level,
                    lastLevelChangeTime: oldItems[goal.id]?.lastLevelChangeTime ?? .now, isDissolving: false)
            }

            var recent = snapshot.lastCompletedAt
            var mappedItems = SharedHabitRepository.catalog
                .filter { snapshot.habitIDsWithGrowth.contains($0.id) }
                .map { goal in
                    item(for: goal, species: PosyFloraType.forHabit(goal.id).rawValue,
                         growth: snapshot.growth[goal.id, default: 0], points: snapshot.points[goal.id, default: 0],
                         completions: snapshot.completions[goal.id, default: 0])
                }
            let active = CustomCard.activeIDs(in: cards, limit: SubscriptionManager.currentCustomCardLimit)
            var usedSpecies = Set<String>()
            for (index, card) in cards.filter({ active.contains($0.id) }).enumerated() {
                // Devices can create the same species independently before a sync.
                let species = ([card.plantSpecies] + CustomCard.species).first {
                    CustomCard.species.contains($0) && !usedSpecies.contains($0)
                }
                guard let species else { continue }
                usedSpecies.insert(species)
                let goal = Goal(id: "custom-card:" + card.id, title: card.title, category: "自定义卡片", summary: "",
                                previewTitle: card.title, previewSummary: "", inputPrimary: "", inputSecondary: "",
                                completionLabel: "", tint: GoalTint(red: 0.41, green: 0.35, blue: 0.65, opacity: 1),
                                order: 13 + index)
                let completions = card.tasks.reduce(0) { $0 + snapshot.completions[$1.goalID, default: 0] }
                let points = card.tasks.reduce(0) { $0 + snapshot.points[$1.goalID, default: 0] }
                recent[goal.id] = card.lastInteractedAt
                mappedItems.append(item(for: goal, species: species, growth: card.plantGrowthValue,
                                        points: points, completions: completions))
            }

            let sortedByRecent = mappedItems.sorted { a, b in
                let aDate = recent[a.id] ?? .distantPast
                let bDate = recent[b.id] ?? .distantPast
                if aDate != bDate { return aDate > bDate }
                if a.growthValue != b.growthValue { return a.growthValue > b.growthValue }
                if a.completions != b.completions { return a.completions > b.completions }
                return a.id < b.id
            }
            items = Array(sortedByRecent.prefix(plantLimit))
            if DevelopmentLaunch.contains("--focus-early") {
                focusedHabitId = items.first(where: { $0.targetLevel == 2 || $0.targetLevel == 1 })?.id ?? items.first?.id
            } else if focusedHabitId == nil || !items.contains(where: { $0.id == focusedHabitId }) {
                focusedHabitId = items.first(where: { $0.targetLevel == 3 })?.id ?? items.first?.id
            }
            if let id = selectedItem?.id { selectedItem = items.first { $0.id == id } }
            lastSnapshot = snapshot
            lastPlantLimit = plantLimit
            lastCustomCards = cards
            dataError = nil
        } catch {
            dataError = "读取养成数据失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Level Updates & Flap Protection (Spec Section 3)
    func updateLevel(for habitId: String, newTarget: Int) {
        guard let index = items.firstIndex(where: { $0.id == habitId }) else { return }
        var item = items[index]

        let now = Date()
        // 400ms flap protection
        if now.timeIntervalSince(item.lastLevelChangeTime) < 0.400 {
            item.targetLevel = newTarget
            items[index] = item
            return
        }

        let oldTarget = item.targetLevel
        let crossesBoundary = (oldTarget >= 0 && newTarget < 0) || (oldTarget < 0 && newTarget >= 0)

        item.targetLevel = newTarget
        item.lastLevelChangeTime = now

        if crossesBoundary {
            // Trigger 0 <-> -1 dissolve exception
            item.isDissolving = true
            items[index] = item

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let idx = self.items.firstIndex(where: { $0.id == habitId }) else { return }
                self.items[idx].isDissolving = false
                self.items[idx].renderLevel = Double(newTarget)
            }
        } else {
            // Critically-damped spring progression
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) {
                item.renderLevel = Double(newTarget)
            }
            items[index] = item
        }
    }

    // MARK: - Nurture / Water Action (浇水培育)
    func nurture(habitId: String) {
        guard let item = items.first(where: { $0.id == habitId }) else { return }
        bannerMessage = String(format: AppLanguage.text("请在今日完成「%@」，完成后将自动更新养成值。"), AppLanguage.text(item.habit.previewTitle))
        loadHabitsAndFlowers(goals: [])
    }

    // MARK: - Position Updating & Debounced Persistence (Spec Section 7)
    func updatePosition(for habitId: String, newPosition: CGPoint) {
        guard let index = items.firstIndex(where: { $0.id == habitId }) else { return }
        // Optimistic update locally
        items[index].record.position = newPosition
        lastTouchedId = habitId
        // Persist immediately to UserDefaults so it is never lost
        persistPositions()
    }

    private func persistPositions() {
        var dict: [String: [CGFloat]] = [:]
        for item in items {
            dict[item.id] = [item.record.position.x, item.record.position.y]
        }
        UserDefaults.standard.set(dict, forKey: positionsStorageKey)
    }

    private func loadSavedPositions() -> [String: CGPoint] {
        guard let dict = UserDefaults.standard.dictionary(forKey: positionsStorageKey) as? [String: [CGFloat]] else {
            return [:]
        }
        var res: [String: CGPoint] = [:]
        for (k, v) in dict where v.count == 2 {
            res[k] = CGPoint(x: v[0], y: v[1])
        }
        return res
    }

    // MARK: - Double-tap Burst
    func triggerBurst(for habitId: String) {
        guard items.contains(where: { $0.id == habitId }) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            windOffset = 8.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            withAnimation(.spring()) {
                self?.windOffset = 0
            }
        }
    }
}
