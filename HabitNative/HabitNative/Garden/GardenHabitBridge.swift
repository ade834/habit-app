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
    var completions: Int
    var inactivityDays: Int
    var isDormant: Bool
    var renderLevel: Double
    var targetLevel: Int
    var lastLevelChangeTime: Date
    var isDissolving: Bool

    var stageTitle: String {
        switch targetLevel {
        case 3: return "开花 Blooming"
        case 2: return "花苞 Budding"
        case 1: return "发芽 Sprouting"
        case 0: return "埋种 Seeded"
        case -1: return "枯萎 Wilting"
        case -2: return "凋谢 Faded"
        default: return "休眠 Gone"
        }
    }

    var stageDescription: String {
        switch targetLevel {
        case 3: return "全盛绽放。这是你坚持打磨出的绚烂形态。"
        case 2: return "花苞饱满，正在积蓄绽放的力量。"
        case 1: return "已抽出一对嫩绿新芽，为你刚刚迈出的一步鼓劲。"
        case 0: return "一小撮松软沃土与初生芽尖，等待你的第一次行动。"
        case -1: return "稍显缺水与低垂，记得今天为它浇水打卡。"
        case -2: return "花瓣暂时隐去，只留根茎静候复苏。"
        default: return "种子在土里安眠，随时可以重新唤醒。"
        }
    }

    var speciesChineseName: String {
        switch record.species {
        case "peony": return "牡丹"
        case "orchid": return "兰花"
        case "rose": return "月季"
        case "lily-of-valley": return "铃兰"
        case "dandelion": return "蒲公英"
        case "sunflower": return "向日葵"
        case "lotus": return "莲花"
        default: return "雏菊"
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
        switch targetLevel {
        case 3:
            return (current: max(6, completions), target: 6, progress: 1.0, description: "全盛绽放形态达成")
        case 2:
            let target = 6
            let curr = max(3, completions)
            let prog = Double(curr - 3) / 3.0
            let remaining = max(1, target - completions)
            return (current: curr, target: target, progress: min(1.0, max(0.15, prog)), description: "再打卡 \(remaining) 次进阶全盛绽放")
        case 1:
            let target = 3
            let curr = max(1, completions)
            let prog = Double(curr - 1) / 2.0
            let remaining = max(1, target - completions)
            return (current: curr, target: target, progress: min(1.0, max(0.25, prog)), description: "再打卡 \(remaining) 次孕育饱满花苞")
        case 0:
            return (current: completions, target: 1, progress: Double(completions) / 1.0, description: "今日打卡即可破土萌芽")
        case -1:
            return (current: completions, target: 1, progress: 0.25, description: "今日补卡浇水唤醒生机")
        default:
            return (current: completions, target: 1, progress: 0.1, description: "重新唤醒成长")
        }
    }
}

// MARK: - Garden Bridge ViewModel
@MainActor
final class GardenHabitViewModel: ObservableObject {
    @Published var items: [HabitGardenItem] = []
    @Published var selectedItem: HabitGardenItem?
    @Published var focusedHabitId: String? = "H6"
    @Published var filterMode: GardenFilterMode = .all
    @Published var activeTabPill: GardenTabPill = .flowers
    @Published var windOffset: CGFloat = 0
    @Published var lastTouchedId: String? = nil
    @Published var bannerMessage: String? = nil

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
        let activeGoals = goals.isEmpty ? InMemoryGoalRepository.goals : goals
        let savedPositions = loadSavedPositions()

        // Specific default positions per habit ID matching the POSY photo composition:
        // H6 (dandelion): top-left sapphire puff
        // H9 (lotus/teal): top-center radiant bloom
        // H1 (peony): top-right warm rose bloom
        // H3 (rose bud), H4 (lily bells), H7 (sprout), H2 (seed) spread naturally
        let defaultPositionMap: [String: CGPoint] = [
            "H6": CGPoint(x: 0.20, y: 0.33), // Top-left sapphire dandelion puff
            "H9": CGPoint(x: 0.51, y: 0.36), // Top-center cyan/teal bloom
            "H1": CGPoint(x: 0.82, y: 0.30), // Top-right magenta spiral rose
            "H3": CGPoint(x: 0.34, y: 0.20), // Center-left rose bud
            "H4": CGPoint(x: 0.67, y: 0.22), // Center-right lily bells
            "H7": CGPoint(x: 0.42, y: 0.15), // Foreground-left sunflower sprout
            "H2": CGPoint(x: 0.58, y: 0.14)  // Foreground-center orchid mound
        ]

        // Legacy points map aligning with Habit App data:
        // H6 (dandelion), H1 (peony), H9 (lotus) at bloom (level 3)
        // H3 (rose), H4 (lily) at bud (level 2)
        // H7 (sunflower) at sprout (level 1)
        // H2 (orchid) at seed (level 0)
        let legacyMap: [String: (completions: Int, points: Int, inactive: Int)] = [
            "H6": (8, 6, 0), // 管理信息摄入 -> 蒲公英 Dandelion (level 3 盛开!)
            "H1": (7, 6, 0), // 每天100字复盘 -> 牡丹 Peony (level 3 盛开!)
            "H9": (6, 5, 0), // 建立知识输出 -> 莲花 Lotus (level 3 盛开!)
            "H3": (4, 2, 0), // 做一件不舒服的事 -> 月季 Rose (level 2 花苞)
            "H4": (3, 1, 0), // 睡前断网 -> 铃兰 Lily (level 2 花苞)
            "H7": (2, 0, 0), // 每周财务盘点 -> 向日葵 Sunflower (level 1 发芽)
            "H2": (0, 0, 0)  // 30分钟深度思考 -> 兰花 Orchid (level 0 埋种)
        ]

        var newItems: [HabitGardenItem] = []
        for goal in activeGoals {
            let species = HabitSpeciesMapper.defaultSpecies(for: goal.id)
            let legacy = legacyMap[goal.id] ?? (0, 0, 0)
            let level = HabitSpeciesMapper.calculateStageLevel(
                points: legacy.points,
                completions: legacy.completions,
                inactivityDays: legacy.inactive,
                isDormant: false
            )

            let pos = savedPositions[goal.id] ?? defaultPositionMap[goal.id] ?? CGPoint(x: 0.5, y: 0.2)
            let record = BloomRecord(id: goal.id, species: species, level: level, position: pos)

            newItems.append(HabitGardenItem(
                habit: goal,
                record: record,
                points: legacy.points,
                completions: legacy.completions,
                inactivityDays: legacy.inactive,
                isDormant: false,
                renderLevel: Double(level),
                targetLevel: level,
                lastLevelChangeTime: Date(),
                isDissolving: false
            ))
        }

        self.items = newItems
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
        guard let index = items.firstIndex(where: { $0.id == habitId }) else { return }
        var item = items[index]

        item.points += 1
        item.completions += 1
        item.inactivityDays = 0
        item.isDormant = false

        let calculatedLevel = HabitSpeciesMapper.calculateStageLevel(
            points: item.points,
            completions: item.completions,
            inactivityDays: 0,
            isDormant: false
        )

        items[index] = item
        updateLevel(for: habitId, newTarget: calculatedLevel)

        if selectedItem?.id == habitId {
            selectedItem = items[index]
        }

        // Trigger pleasant wind gust
        withAnimation(.interpolatingSpring(stiffness: 120, damping: 8)) {
            windOffset = 6.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                self?.windOffset = 0
            }
        }
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
        guard let index = items.firstIndex(where: { $0.id == habitId }) else { return }
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
