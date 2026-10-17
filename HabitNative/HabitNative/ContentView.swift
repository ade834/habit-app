import SwiftUI
import UIKit

// Palette changes are limited to interface surfaces; garden artwork keeps its own colors.
enum HabitColorTheme: String, CaseIterable, Identifiable {
    case original
    case lavender

    static let storageKey = "appearance.colorTheme"
    var id: String { rawValue }
    var title: String { self == .original ? "原色" : "雾紫" }
    var accent: Color { self == .original ? Color(red: 0.93, green: 0.22, blue: 0.65) : Color(red: 0.39, green: 0.23, blue: 0.64) }
    var companion: Color { self == .original ? Color(red: 1, green: 0.57, blue: 0.34) : Color(red: 0.70, green: 0.53, blue: 0.91) }
    var selectedNavigationForeground: Color {
        self == .original ? Color(red: 0.18, green: 0.14, blue: 0.20) : Color(red: 0.84, green: 0.76, blue: 0.98)
    }
    var unselectedNavigationForeground: Color { Color(red: 0.24, green: 0.15, blue: 0.36) }
    var selectedNavigationBackground: Color {
        self == .original ? Color.white.opacity(0.82) : Color(red: 0.21, green: 0.20, blue: 0.22)
    }
    var selectedNavigationBorder: Color {
        self == .original ? Color.white.opacity(0.90) : selectedNavigationForeground.opacity(0.54)
    }
    var deepInk: Color { .black }
    var softSurface: Color { Color(red: 0.91, green: 0.87, blue: 0.96) }
    var canvas: Color { self == .original ? .white : .black }

    var floatingOrbSpherePalettes: (pink: [Color], peach: [Color]) {
        if self == .lavender {
            return (
                [accent, accent.mix(with: companion, by: 0.24), accent.mix(with: companion, by: 0.54)],
                [companion, companion.mix(with: accent, by: 0.20), companion.mix(with: accent, by: 0.52)]
            )
        }
        return (
            [Color(red: 240 / 255, green: 75 / 255, blue: 175 / 255), Color(red: 208 / 255, green: 60 / 255, blue: 165 / 255), Color(red: 175 / 255, green: 65 / 255, blue: 178 / 255)],
            [Color(red: 255 / 255, green: 202 / 255, blue: 130 / 255), Color(red: 255 / 255, green: 150 / 255, blue: 95 / 255), Color(red: 242 / 255, green: 100 / 255, blue: 125 / 255)]
        )
    }

    /// Shared background palette for the orb gaps and the garden intro room.
    var floatingOrbAtmosphere: FloatingOrbAtmospherePalette {
        if self == .lavender {
            return FloatingOrbAtmospherePalette(
                base: Color(red: 0.062, green: 0.028, blue: 0.025),
                gradientStops: [
                    Color(red: 0.045, green: 0.021, blue: 0.020),
                    Color(red: 0.119, green: 0.057, blue: 0.041),
                    Color(red: 0.180, green: 0.094, blue: 0.062),
                    Color(red: 0.078, green: 0.033, blue: 0.029)
                ],
                lowerGlow: [
                    Color(red: 0.254, green: 0.131, blue: 0.086),
                    Color(red: 0.164, green: 0.078, blue: 0.053)
                ],
                upperGlow: Color(red: 0.098, green: 0.037, blue: 0.033)
            ).darkened(by: 0.15)
        }
        return FloatingOrbAtmospherePalette(
            base: .white,
            gradientStops: [.white, .white, .white],
            lowerGlow: [.white, .white],
            upperGlow: .white
        )
    }

    var floatingOrbPalette: [Color] {
        let palettes = floatingOrbSpherePalettes
        return palettes.pink + palettes.peach
    }

    func cardBaseColor(at index: Int, count: Int) -> Color {
        let endpoints = floatingOrbPalette.sorted { luminance($0) < luminance($1) }
        guard let darkest = endpoints.first, let lightest = endpoints.last else { return .white }
        guard count > 1 else { return blend(darkest, lightest, progress: 0.5) }
        return blend(darkest, lightest, progress: Double(min(max(index, 0), count - 1)) / Double(count - 1))
    }

    /// Selected goal cards interpolate between orb-center colors after reducing endpoint saturation by 10%.
    func selectedDeckCardColor(at index: Int, count: Int) -> Color {
        let startColor = reducingSaturation(accent, by: 0.10)
        let endColor = reducingSaturation(companion, by: 0.10)
        guard count > 1 else { return startColor }
        let position = Double(min(max(index, 0), count - 1)) / Double(count - 1)
        return blend(startColor, endColor, progress: position)
    }

    private func reducingSaturation(_ color: Color, by amount: Double) -> Color {
        let resolved = color.resolve(in: EnvironmentValues())
        let source = UIColor(
            red: CGFloat(resolved.red),
            green: CGFloat(resolved.green),
            blue: CGFloat(resolved.blue),
            alpha: CGFloat(resolved.opacity)
        )
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard source.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return color
        }
        return Color(
            hue: Double(hue),
            saturation: Double(saturation) * (1 - min(max(amount, 0), 1)),
            brightness: Double(brightness),
            opacity: Double(alpha)
        )
    }

    private func luminance(_ color: Color) -> Double {
        let resolved = color.resolve(in: EnvironmentValues())
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(Double(resolved.red))
            + 0.7152 * linear(Double(resolved.green))
            + 0.0722 * linear(Double(resolved.blue))
    }

    private func blend(_ first: Color, _ second: Color, progress: Double) -> Color {
        let resolvedA = first.resolve(in: EnvironmentValues())
        let resolvedB = second.resolve(in: EnvironmentValues())
        let a = UIColor(red: CGFloat(resolvedA.red), green: CGFloat(resolvedA.green), blue: CGFloat(resolvedA.blue), alpha: CGFloat(resolvedA.opacity))
        let b = UIColor(red: CGFloat(resolvedB.red), green: CGFloat(resolvedB.green), blue: CGFloat(resolvedB.blue), alpha: CGFloat(resolvedB.opacity))
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        guard a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa),
              b.getRed(&br, green: &bg, blue: &bb, alpha: &ba) else { return first }
        let t = min(max(progress, 0), 1)
        return Color(red: Double(ar + (br - ar) * t), green: Double(ag + (bg - ag) * t), blue: Double(ab + (bb - ab) * t))
    }

    func card(_ original: Color, saturationMultiplier: Double = 1) -> Color {
        guard self == .lavender else { return original }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        let resolved = original.resolve(in: EnvironmentValues())
        let source = UIColor(
            red: CGFloat(resolved.red),
            green: CGFloat(resolved.green),
            blue: CGFloat(resolved.blue),
            alpha: CGFloat(resolved.opacity)
        )
        guard source.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return original
        }
        return Color(
            hue: Double(hue),
            saturation: min(1, Double(saturation) * 0.88 * saturationMultiplier),
            brightness: min(1, Double(brightness) * 1.04)
        )
    }
}

struct FloatingOrbAtmospherePalette {
    let base: Color
    let gradientStops: [Color]
    let lowerGlow: [Color]
    let upperGlow: Color

    func darkened(by amount: Double) -> Self {
        Self(
            base: base.mix(with: .black, by: amount),
            gradientStops: gradientStops.map { $0.mix(with: .black, by: amount) },
            lowerGlow: lowerGlow.map { $0.mix(with: .black, by: amount) },
            upperGlow: upperGlow.mix(with: .black, by: amount)
        )
    }
}

private struct HabitColorThemeKey: EnvironmentKey {
    static let defaultValue = HabitColorTheme.original
}

extension EnvironmentValues {
    var habitColorTheme: HabitColorTheme {
        get { self[HabitColorThemeKey.self] }
        set { self[HabitColorThemeKey.self] = newValue }
    }
}

extension Goal {
    func cardBaseColor(in goals: [Goal], theme: HabitColorTheme) -> Color {
        let orderedGoals = goals.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
        let index = orderedGoals.firstIndex(where: { $0.id == id }) ?? 0
        return theme.cardBaseColor(at: index, count: orderedGoals.count)
    }
}

struct GoalCardAppearance {
    let goalID: String
    let baseColor: Color

    init(goal: Goal, goals: [Goal], theme: HabitColorTheme) {
        goalID = goal.id
        let orderedGoals = goals.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
        baseColor = theme.selectedDeckCardColor(
            at: goal.order - 1,
            count: max(12, orderedGoals.map(\.order).max() ?? 12)
        )
    }
}

// MARK: - 页面视觉固定布局配置
struct UITuningState: Codable, Equatable {
    var titleSize: CGFloat = 46
    var dateSize: CGFloat = 75
    var cardOffsetY: CGFloat = -13
    var cardHeight: CGFloat = 232
    var cardWidth: CGFloat = 216
    var bannerPaddingTop: CGFloat = 6
    var textScale: CGFloat = 1
    var contentOffsetX: CGFloat = 0
    var contentOffsetY: CGFloat = 0
    var navigationScale: CGFloat = 1

    static func load() -> UITuningState {
        guard let data = UserDefaults.standard.data(forKey: "today.ui.tuning"),
              let saved = try? JSONDecoder().decode(UITuningState.self, from: data) else { return UITuningState() }
        return saved
    }
    func save() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: "today.ui.tuning") }
}

struct ContentView: View {
    @AppStorage(HabitColorTheme.storageKey) private var colorTheme = HabitColorTheme.original
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state = TodayGoalState()
    @State private var goals: [Goal] = []
    @State private var selectedGoals: [Goal] = []
    @State private var databaseError: String?
    @State private var dashboard: HabitDashboardSnapshot?
    @State private var tuning = UITuningState.load()
    @State private var gardenPolaroidPhoto: UIImage?
    @State private var gardenCameraFlash = false
    @State private var backgroundFrame: CGRect = .zero

    private let repository: any GoalRepository = SharedHabitRepository()

    var body: some View {
        ZStack {
            TodayAmbientBackground(reduceMotion: reduceMotion, onViewportChange: { backgroundFrame = $0 })
                .ignoresSafeArea()
            TodayRootView(goals: goals, selectedGoals: $selectedGoals, state: $state, tuning: $tuning, reduceMotion: reduceMotion, dashboard: dashboard, onConfirm: confirmSelection, onClearData: clearLocalData, onGardenShare: presentGardenPolaroid)
            if let gardenPolaroidPhoto {
                GardenPolaroidView(photo: gardenPolaroidPhoto) {
                    withAnimation(.easeOut(duration: 0.22)) { self.gardenPolaroidPhoto = nil }
                }
                .transition(.opacity)
                .zIndex(100)
            }
            if gardenCameraFlash {
                Color.white.ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(101)
            }
        }
        .environment(\.habitColorTheme, colorTheme)
        .environment(\.habitBackgroundFrame, backgroundFrame)
        .alert("操作未完成", isPresented: Binding(get: { databaseError != nil }, set: { if !$0 { databaseError = nil } })) {
            Button("知道了", role: .cancel) { databaseError = nil }
        } message: {
            Text(databaseError ?? "请稍后重试")
        }
        .task(id: state.completedSelectedGoalIDs) {
            // Completion must remove the card as soon as the user returns,
            // including starred and periodic habits. Their selection rules stay intact.
            if let refreshed = try? await repository.availableGoals(for: .now) {
                goals = refreshed
            }
        }
        .task {
            try? await repository.recoverInterruptedSessions()
            while !Task.isCancelled {
                let refreshedGoals = (try? await repository.availableGoals(for: .now)) ?? goals
                if refreshedGoals != goals { goals = refreshedGoals }
                dashboard = try? SharedHabitSelectionStore().dashboard(at: .now)
                let selectionSnapshot = try? SharedHabitSelectionStore().snapshot(at: .now)
                if let selectionSnapshot {
                    state.starLimit = selectionSnapshot.starLimit
                    state.isFirstSelection = selectionSnapshot.isFirstSelection
                    state.completedRegularGoalIDs = selectionSnapshot.completedRegularIDs
                    state.completedSelectedGoalIDs = selectionSnapshot.completedSelectedIDs
                }
                if state.mode != .browsingDeck,
                   let selected = try? await repository.selectedGoalIDs(for: .now) {
                    state.selectedGoalIDs = selected
                    if let selectionSnapshot { state.starredGoalIDs = selectionSnapshot.starredIDs }
                    if let refreshedSelectedGoals = try? await repository.selectedGoals(for: .now) {
                        selectedGoals = refreshedSelectedGoals
                    }
                    // Restore the real selected-habits screen after relaunch. The home preview
                    // is only for a first-time/unselected state; keeping that mode after loading
                    // a persisted selection made the app look like the older preview-only UI.
                    if !selected.isEmpty, state.mode == .homeUnselected {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                            state.mode = .homeSelected
                        }
                    }
                }
                if goals.isEmpty {
                    state.mode = .homeUnselected
                } else if !goals.contains(where: { $0.id == state.focusedGoalID }) {
                    state.focusedGoalID = goals.first?.id ?? "H1"
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func presentGardenPolaroid(_ image: UIImage) {
        gardenCameraFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.08 : 0.14)) {
            withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.26)) {
                gardenPolaroidPhoto = image
                gardenCameraFlash = false
            }
        }
    }

    private func confirmSelection() {
        Task {
            do {
                let date = Date()
                let requestedIDs = state.selectedGoalIDs.union(state.completedSelectedGoalIDs)
                let requestedStars = state.starredGoalIDs
                try await repository.saveSelectedGoalIDs(requestedIDs, starredIDs: requestedStars, for: date)
                let persisted = try SharedHabitSelectionStore().snapshot(at: date)
                guard persisted.activeIDs.union(persisted.starredIDs) == requestedIDs,
                      persisted.starredIDs == requestedStars else {
                    throw HabitSelectionError.databaseFailure("保存后重新读取的选择与页面不一致，请重试。")
                }
                goals = try await repository.availableGoals(for: date)
                selectedGoals = try await repository.selectedGoals(for: date)
                state.selectedGoalIDs = persisted.activeIDs.union(persisted.starredIDs).union(persisted.completedSelectedIDs)
                state.starredGoalIDs = persisted.starredIDs
                state.completedRegularGoalIDs = persisted.completedRegularIDs
                state.completedSelectedGoalIDs = persisted.completedSelectedIDs
                state.isFirstSelection = persisted.isFirstSelection
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) { state.mode = .homeSelected }
            } catch {
                switch error {
                case HabitSelectionError.quotaExceeded: databaseError = "当天新建的普通和周期习惯最多 3 个。"
                case HabitSelectionError.starLimitExceeded(let limit): databaseError = "当前阶段最多设置 \(limit) 个星标习惯。"
                case HabitSelectionError.firstSelectionRequiresGoal: databaseError = "首次使用请至少选择一个目标。"
                case HabitSelectionError.invalidStarredSelection: databaseError = "星标必须属于已选目标；首次选择暂不能设置星标。"
                case HabitSelectionError.databaseFailure(let message): databaseError = message
                default: databaseError = "数据库未能保存这次选择：\(error.localizedDescription)"
                }
            }
        }
    }

    private func clearLocalData() {
        Task {
            do {
                try NativeDatabase().clearAllUserData()
                let date = Date.now
                goals = try await repository.availableGoals(for: date)
                selectedGoals = []
                let selection = try SharedHabitSelectionStore().snapshot(at: date)
                state.selectedGoalIDs = []
                state.starredGoalIDs = []
                state.completedRegularGoalIDs = []
                state.completedSelectedGoalIDs = []
                state.starLimit = selection.starLimit
                state.isFirstSelection = true
                state.homeSelectedIndex = 0
                dashboard = try SharedHabitSelectionStore().dashboard(at: date)
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    state.tab = .today
                    state.mode = .homeUnselected
                }
            } catch {
                databaseError = "清除本地数据失败：\(error.localizedDescription)"
            }
        }
    }
}

private struct TodayRootView: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let goals: [Goal]
    @Binding var selectedGoals: [Goal]
    @Binding var state: TodayGoalState
    @Binding var tuning: UITuningState
    let reduceMotion: Bool
    let dashboard: HabitDashboardSnapshot?
    let onConfirm: () -> Void
    let onClearData: () -> Void
    let onGardenShare: (UIImage) -> Void
    @Namespace private var selectionTransitionNamespace
    @State private var executionToast: String?
    @State private var executionToastID = UUID()
    @State private var executionToastExpanded = false
    @State private var isGardenIntroVisible = true
    @State private var deckReturnMode: TodayMode = .homeUnselected
    @State private var deckOriginalSelectedIDs: Set<String> = []
    @State private var deckOriginalStarredIDs: Set<String> = []
    @State private var selectedExecutionCardFrame: CGRect = .zero
    @State private var expansionStartFrame: CGRect = .zero
    @State private var expandingGoal: Goal?
    @State private var expansionProgress: CGFloat = 0
    @State private var executionExpansionIsReturning = false
    @State private var expansionID = UUID()
    @State private var selectedReturnButtonRevealTrigger = UUID()
    @State private var homePreviewIsPressed = false
    @State private var homeDeckOpening = false
    @State private var homeDeckGathered = false
    @State private var homeDeckLaunchFrame: CGRect = .zero

    // 设置弹窗形变的高阻尼流体弹簧曲线 (Fluid Morph)
    private let fluidMorphAnimation = Animation.spring(response: 0.73, dampingFraction: 0.90, blendDuration: 0.05)
    @State private var settingsPresented = false
    @State private var settingsProgress: CGFloat = 0
    @State private var settingsClosing = false
    @State private var settingsButtonFrame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域（包含顶部和卡片/页面）
            VStack(spacing: 0) {
                if state.tab == .today && !isExecuting && state.mode != .browsingDeck {
                    TodayHeaderView(selectedCount: state.selectedGoalIDs.count, mode: state.mode, tuning: tuning, dashboard: dashboard)
                        .offset(y: state.mode == .homeUnselected ? -25 : 0)
                        .transition(.asymmetric(
                            insertion: .offset(y: -220).combined(with: .opacity),
                            removal: .offset(y: -150).combined(with: .scale(scale: 0.94, anchor: .topLeading)).combined(with: .opacity)
                        ))
                }
                if state.tab != .review && state.tab != .garden && state.mode != .browsingDeck && !isExecuting {
                    Spacer(minLength: 16)
                }

                if state.tab == .today {
                    switch state.mode {
                    case .homeUnselected:
                        VStack(spacing: 0) {
                            HomePreviewDeckView(goals: goals, tuning: tuning, reduceMotion: reduceMotion, isPressed: homePreviewIsPressed, isGathered: homeDeckGathered, isHintVisible: !homeDeckOpening)
                                .background {
                                    GeometryReader { geometry in
                                        Color.clear.preference(key: HomeDeckLaunchFrameKey.self, value: geometry.frame(in: .global))
                                    }
                                }
                                .offset(y: tuning.cardOffsetY)
                                .contentShape(Rectangle())
                                .onLongPressGesture(minimumDuration: 0, maximumDistance: 18, pressing: { pressed in
                                    homePreviewIsPressed = pressed
                                }, perform: {
                                    openHomeDeck()
                                })
                                .allowsHitTesting(!homeDeckOpening)
                                .sensoryFeedback(.impact(weight: .light), trigger: homePreviewIsPressed) { _, pressed in pressed }
                        }
                        .transition(reduceMotion ? .opacity : .identity)
                    case .browsingDeck:
                        let colorRangeEndOrder = max(12, goals.map(\.order).max() ?? 12)
                        VStack(spacing: 10) {
                            Button("‹ 返回") { cancelBrowsing() }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(colorTheme.card(colorTheme.cardBaseColor(at: 1, count: 2)))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 28)
                            // A completed habit leaves today's pending deck immediately.
                            // Do not remove its star or periodic selection from storage.
                            TodayStackDeckView(
                                goals: goals.filter { !$0.completedToday && !state.completedSelectedGoalIDs.contains($0.id) },
                                colorRangeEndOrder: colorRangeEndOrder,
                                state: $state,
                                selectionTransitionNamespace: selectionTransitionNamespace,
                                homeLaunchFrame: deckReturnMode == .homeUnselected ? homeDeckLaunchFrame : nil
                            )
                        }
                        .transition(reduceMotion ? .opacity : .identity)
                    case .homeSelected:
                        SelectedGoalView(
                            goals: selectedGoals,
                            allGoals: goals,
                            state: $state,
                            selectionTransitionNamespace: selectionTransitionNamespace,
                            buttonRevealTrigger: selectedReturnButtonRevealTrigger,
                            onBrowseGoals: { browseGoals(returningTo: .homeSelected) },
                            onStartGoal: startExecution
                        )
                        .transition(.identity)
                    case .executing(let id):
                        ExecutionView(
                            goal: selectedGoals.first(where: { $0.id == id }) ?? goals.first(where: { $0.id == id }) ?? goals.first,
                            allGoals: goals,
                            selectedGoals: $selectedGoals,
                            state: $state,
                            onPrompt: showExecutionToast,
                            onExit: closeExecution
                        )
                        .transition(.identity)
                    }
                } else if state.tab == .garden {
                    GrowthView(
                        goals: goals,
                        onStartHabit: { goal in
                            state.tab = .today
                            if selectedGoals.contains(where: { $0.id == goal.id }) {
                                state.mode = .executing(goalID: goal.id)
                            } else {
                                browseGoals(returningTo: .homeSelected)
                            }
                        },
                        onIntroVisibilityChange: { isGardenIntroVisible = $0 },
                        onSharePhoto: onGardenShare
                    )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        ))
                } else if state.tab == .review {
                    ReviewPage(goals: goals)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        ))
                }

                if state.tab != .review && state.tab != .garden && state.mode != .browsingDeck && !isExecuting {
                    Spacer(minLength: 16)
                }

                // 底部占位高度，确保主内容不被底部胶囊栏遮挡
                if state.tab != .review && state.tab != .garden && !isExecuting {
                    Color.clear.frame(height: state.mode == .browsingDeck ? 154 : 94)
                }
            }
            // 目标页内容超过可用高度时仍从安全区顶部开始排版，不能因居中布局向上侵入状态栏。
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(x: tuning.contentOffsetX, y: tuning.contentOffsetY)

            if state.tab == .today && state.mode == .browsingDeck {
                ScrollEdgeBlurOverlay(
                    progress: 1,
                    visibility: .bottom,
                    bottomWhiteOpacity: 0.15,
                    bottomVisibleFraction: 0.25
                )
                .ignoresSafeArea(.container, edges: .bottom)
                .allowsHitTesting(false)
                .zIndex(10)
            }

            // 底部确认栏（选卡片时）
            if state.mode == .browsingDeck && state.tab == .today {
                ConfirmSelectionBar(goals: goals, state: state, action: onConfirm)
                    .padding(.bottom, 99)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(30)
            }

            // 常驻底部液态导航栏（设置打开时淡化或收纳，其余时刻常驻）
            if state.tab != .settings && !isExecuting {
                TodayBottomNavigationView(
                    tab: $state.tab,
                    fluidMorphAnimation: fluidMorphAnimation,
                    onOpenSettings: openSettings
                )
                .scaleEffect(tuning.navigationScale, anchor: .bottom)
                .opacity(state.tab == .garden && isGardenIntroVisible ? 0 : 1)
                .allowsHitTesting(!(state.tab == .garden && isGardenIntroVisible))
                .animation(.easeOut(duration: 0.45), value: isGardenIntroVisible)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                    removal: .identity
                ))
                .zIndex(30)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .onPreferenceChange(SettingsButtonFrameKey.self) { frame in
            if frame.width > 0 { settingsButtonFrame = frame }
        }
        .overlay {
            GeometryReader { geometry in
                if settingsPresented {
                    let origin = geometry.frame(in: .global).origin
                    let source = settingsButtonFrame.offsetBy(dx: -origin.x, dy: -origin.y)
                    let sideInset = max(0, geometry.size.width - source.maxX)
                    let panelTop: CGFloat = 54
                    let destination = CGRect(
                        x: sideInset,
                        y: panelTop,
                        width: max(1, geometry.size.width - sideInset * 2),
                        height: max(1, source.maxY - panelTop)
                    )
                    FluidSettingsExpandedPanel(
                        fluidMorphAnimation: fluidMorphAnimation,
                        onDismiss: closeSettings,
                        onClearData: clearDataFromSettings
                    )
                    .modifier(SettingsPanelMorph(
                        progress: settingsProgress,
                        source: source,
                        destination: destination
                    ))
                    .transition(.identity)
                    .task {
                        // Mount the collapsed panel before starting its geometry animation.
                        try? await Task.sleep(for: .milliseconds(20))
                        guard !Task.isCancelled, !settingsClosing else { return }
                        withAnimation(fluidMorphAnimation) { settingsProgress = 1 }
                    }
                }
            }
            .allowsHitTesting(settingsPresented && !settingsClosing)
        }
        .onChange(of: state.tab) { _, tab in
            // Hide the navigation before the garden's first intro frame draws.
            isGardenIntroVisible = tab == .garden
        }
        .onPreferenceChange(SelectedExecutionCardFrameKey.self) { frame in
            if frame.width > 0 { selectedExecutionCardFrame = frame }
        }
        .onPreferenceChange(HomeDeckLaunchFrameKey.self) { frame in
            if frame.width > 0 {
                homeDeckLaunchFrame = CGRect(x: frame.midX - tuning.cardWidth / 2, y: frame.midY - tuning.cardHeight / 2, width: tuning.cardWidth, height: tuning.cardHeight)
            }
        }
        .overlay {
            if let expandingGoal {
                executionExpansionOverlay(for: expandingGoal)
                    .ignoresSafeArea()
                    .zIndex(200)
            }
        }
        .overlay(alignment: .bottom) {
            if let executionToast, state.tab == .today, isExecuting {
                Text(executionToast.filter { !$0.isPunctuation })
                    .font(.system(size: 18.75, weight: .semibold))
                    .foregroundStyle(Color(red: 0.25, green: 0.20, blue: 0.25))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.78), lineWidth: 1.2))
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 7)
                    .padding(.bottom, 84)
                    .scaleEffect(x: executionToastExpanded ? 1 : 0.58, y: executionToastExpanded ? 1 : 0.88, anchor: .center)
                    .transition(.opacity)
                    .animation(.spring(response: 0.42, dampingFraction: 0.78), value: executionToastExpanded)
                    .allowsHitTesting(false)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(expandingGoal == nil ? (reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.62, dampingFraction: 0.82, blendDuration: 0.14)) : nil, value: state.mode)
    }

    private func startExecution(_ goal: Goal) {
        guard expandingGoal == nil else { return }
        executionExpansionIsReturning = false
        guard !reduceMotion, selectedExecutionCardFrame.width > 0 else {
            withAnimation(.easeOut(duration: 0.16)) { state.mode = .executing(goalID: goal.id) }
            return
        }
        expansionStartFrame = selectedExecutionCardFrame
        expansionProgress = 0
        expandingGoal = goal
        let id = UUID()
        expansionID = id
        withAnimation(
            .spring(response: 0.58, dampingFraction: 0.86),
            completionCriteria: .logicallyComplete
        ) {
            expansionProgress = 1
        } completion: {
            guard expansionID == id else { return }
            withTransaction(Transaction(animation: nil)) {
                state.mode = .executing(goalID: goal.id)
                expandingGoal = nil
            }
        }
    }

    private func closeExecution(_ goal: Goal) {
        guard expandingGoal == nil else { return }
        executionExpansionIsReturning = true
        guard !reduceMotion, selectedExecutionCardFrame.width > 0 else {
            withAnimation(.easeOut(duration: 0.16)) {
                state.mode = .homeSelected
                selectedReturnButtonRevealTrigger = UUID()
            }
            return
        }

        expansionStartFrame = selectedExecutionCardFrame
        expansionProgress = 1
        let id = UUID()
        expansionID = id
        withTransaction(Transaction(animation: nil)) {
            state.mode = .homeSelected
            expandingGoal = goal
        }
        Task {
            try? await Task.sleep(for: .milliseconds(20))
            guard expansionID == id else { return }
            withAnimation(
                .spring(response: 0.58, dampingFraction: 0.86),
                completionCriteria: .logicallyComplete
            ) {
                expansionProgress = 0
            } completion: {
                guard expansionID == id else { return }
                withTransaction(Transaction(animation: nil)) {
                    expandingGoal = nil
                    selectedReturnButtonRevealTrigger = UUID()
                }
            }
        }
    }

    private func executionExpansionOverlay(for goal: Goal) -> some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            let start = expansionStartFrame.offsetBy(dx: -origin.x, dy: -origin.y)
            let target = CGRect(origin: .zero, size: geometry.size)
            let progress = expansionProgress
            let width = start.width + (target.width - start.width) * progress
            let height = start.height + (target.height - start.height) * progress
            let centerX = start.midX + (target.midX - start.midX) * progress
            let centerY = start.midY + (target.midY - start.midY) * progress
            let returnDetailOpacity = executionExpansionIsReturning
                ? 1 - progress
                : 0
            let tint = colorTheme.selectedDeckCardColor(
                at: goal.order - 1,
                count: max(12, goals.map(\.order).max() ?? 12)
            )
            let shape = RoundedRectangle(cornerRadius: 26 * (1 - progress), style: .continuous)
            let safeTop = max(geometry.safeAreaInsets.top, 62)
            let textX = start.minX + 20 + (24 - start.minX - 20) * progress
            let textWidth = start.width - 40 + (target.width - 48 - start.width + 40) * progress
            let titleY = start.minY + 49 + (safeTop + 28 - start.minY - 49) * progress
            let titleInk = Color.white.opacity(0.82 - 0.07 * Double(progress))
            let summaryInk = Color.white.opacity(1 - 0.25 * Double(progress))

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .top) {
                    LinearGradient(stops: [
                        .init(color: tint.opacity(0.99), location: 0),
                        .init(color: tint.opacity(0.97), location: 0.48),
                        .init(color: tint.opacity(0.92), location: 1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.98), tint.opacity(0.90), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: height * 0.43)
                        .opacity(progress)
                }
                .frame(width: width, height: height)
                .clipShape(shape)
                .opacity(1 - 0.05 * returnDetailOpacity)
                .overlay {
                    ZStack {
                        shape.fill(
                            LinearGradient(
                                colors: [.white.opacity(0.28), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        shape.fill(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.12)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .opacity(returnDetailOpacity)
                    .clipShape(shape)
                    .allowsHitTesting(false)
                }
                .overlay {
                    ZStack {
                        SelectedDeckSideHighlight(isLeft: true)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.25),
                                        .init(color: .white.opacity(0.40), location: 0.55),
                                        .init(color: .white.opacity(0.72), location: 0.92)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2.25
                            )
                        SelectedDeckCornerHighlight(isBottomLeft: true)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.72), location: 0),
                                        .init(color: .white.opacity(0.72), location: 0.12),
                                        .init(color: .white.opacity(0.38), location: 0.38),
                                        .init(color: .clear, location: 0.75)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2.25
                            )
                        SelectedDeckCornerHighlight(isBottomLeft: false)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.25),
                                        .init(color: .white.opacity(0.24), location: 0.48),
                                        .init(color: .white.opacity(0.56), location: 0.89),
                                        .init(color: .white.opacity(0.576), location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2.25
                            )
                        SelectedDeckSideHighlight(isLeft: false)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.576), location: 0.08),
                                        .init(color: .white.opacity(0.32), location: 0.28),
                                        .init(color: .clear, location: 0.75)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2.25
                            )
                    }
                    .opacity(returnDetailOpacity)
                    .clipShape(shape)
                    .allowsHitTesting(false)
                }
                .overlay {
                    let outlineOpacity = 0.85 * (1 - progress)
                        * (executionExpansionIsReturning ? progress : 1)
                    shape.stroke(.white.opacity(outlineOpacity), lineWidth: 1.2)
                }
                .position(x: centerX, y: centerY)

                VStack(alignment: .leading, spacing: 10) {
                    Text(goal.previewTitle)
                        .font(.system(size: 42 + 18 * progress, weight: .semibold, design: .rounded))
                        .tracking(-1.8)
                        .foregroundStyle(titleInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(minHeight: 88 * (1 - progress), alignment: .topLeading)
                    Text(goal.previewSummary)
                        .font(.system(size: 20.16 - 3.16 * progress, weight: .medium))
                        .foregroundStyle(summaryInk)
                        .lineLimit(2)
                }
                .frame(width: textWidth, alignment: .leading)
                .offset(x: textX, y: titleY)
            }
        }
        .allowsHitTesting(true)
        .accessibilityHidden(true)
    }

    private func browseGoals(returningTo mode: TodayMode) {
        deckReturnMode = mode
        deckOriginalSelectedIDs = state.selectedGoalIDs
        deckOriginalStarredIDs = state.starredGoalIDs
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : (mode == .homeUnselected ? nil : .spring(response: 0.90, dampingFraction: 0.82))) {
            state.focusedGoalID = goals.first?.id ?? "H6"
            state.mode = .browsingDeck
        }
    }

    private func openHomeDeck() {
        guard !homeDeckOpening else { return }
        guard !reduceMotion else {
            browseGoals(returningTo: .homeUnselected)
            return
        }
        // Anticipation: a brief compression, then the side cards follow into a stack.
        homeDeckOpening = true
        homePreviewIsPressed = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard state.mode == .homeUnselected, state.tab == .today else {
                homeDeckOpening = false
                homePreviewIsPressed = false
                return
            }
            withAnimation(.spring(response: 0.85, dampingFraction: 0.88)) {
                homeDeckGathered = true
                homePreviewIsPressed = false
            }
            try? await Task.sleep(for: .milliseconds(360))
            guard state.mode == .homeUnselected, state.tab == .today else {
                homeDeckGathered = false
                homeDeckOpening = false
                return
            }
            browseGoals(returningTo: .homeUnselected)
        }
    }

    private func cancelBrowsing() {
        homeDeckOpening = false
        homeDeckGathered = false
        homePreviewIsPressed = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            state.selectedGoalIDs = deckOriginalSelectedIDs
            state.starredGoalIDs = deckOriginalStarredIDs
            state.mode = deckReturnMode
        }
    }

    private func openSettings() {
        guard !settingsPresented, settingsButtonFrame.width > 0 else { return }
        settingsProgress = 0
        settingsClosing = false
        settingsPresented = true
    }

    private func closeSettings() {
        guard settingsPresented, !settingsClosing else { return }
        settingsClosing = true
        withAnimation(fluidMorphAnimation, completionCriteria: .removed) {
            settingsProgress = 0
        } completion: {
            // Keep the same view alive until the return to the button has settled.
            settingsPresented = false
            settingsClosing = false
        }
    }

    private func clearDataFromSettings() {
        withAnimation(.easeOut(duration: 0.20)) {
            homeDeckOpening = false
            homeDeckGathered = false
            homePreviewIsPressed = false
            deckReturnMode = .homeUnselected
            deckOriginalSelectedIDs.removeAll()
            deckOriginalStarredIDs.removeAll()
        }
        onClearData()
    }

    private var isExecuting: Bool {
        if case .executing = state.mode { return true }
        return false
    }

    private func showExecutionToast(_ message: String) {
        let id = UUID()
        executionToastID = id
        executionToastExpanded = false
        withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) { executionToast = message }
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            guard executionToastID == id else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { executionToastExpanded = true }
            try? await Task.sleep(for: .seconds(1.5))
            guard executionToastID == id else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                executionToastExpanded = false
                executionToast = nil
            }
        }
    }
}

private struct SettingsButtonFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let frame = nextValue()
        if frame.width > 0 { value = frame }
    }
}

private struct SettingsPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.20, dampingFraction: 0.58), value: configuration.isPressed)
    }
}

/// A persistent surface and its content follow one reversible geometry track.
private struct SettingsPanelMorph: AnimatableModifier {
    var progress: CGFloat
    let source: CGRect
    let destination: CGRect

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = min(1, max(0, progress))
        let fadePhase = smoothPhase(t, start: 0, end: 0.20)
        let horizontalPhase = smoothPhase(t, start: 0.20, end: 0.60)
        let verticalPhase = smoothPhase(t, start: 0.60, end: 1)
        let width = max(1, source.width + (destination.width - source.width) * horizontalPhase)
        let height = max(1, source.height + (destination.height - source.height) * verticalPhase)
        let x = source.maxX - width
        let y = source.maxY - height
        let relativeSize = min(width / destination.width, height / destination.height)
        let contentScaleX = source.width / destination.width + (1 - source.width / destination.width) * horizontalPhase
        let contentScaleY = source.height / destination.height + (1 - source.height / destination.height) * verticalPhase
        let contentOpacity = smoothPhase(relativeSize, start: 0.25, end: 0.42)
        let collapsedCornerRadius = min(source.width, source.height) / 2
        let cornerRadius = collapsedCornerRadius + (38 - collapsedCornerRadius) * verticalPhase
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .frame(width: destination.width, height: destination.height)
            .scaleEffect(x: contentScaleX, y: contentScaleY, anchor: .topLeading)
            .opacity(contentOpacity)
            .frame(width: width, height: height, alignment: .topLeading)
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(fadePhase)
            }
            .clipShape(shape)
            .overlay(shape.stroke(.white.opacity(0.7 * fadePhase), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.14 * fadePhase), radius: 24 * verticalPhase, y: -6 * verticalPhase)
            .offset(x: x, y: y)
    }

    private func smoothPhase(_ value: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        let phase = min(1, max(0, (value - start) / (end - start)))
        return phase * phase * (3 - 2 * phase)
    }
}

// MARK: - 设置专属流体形变展开面板 (Fluid Settings Panel with Interactive Pull-Down Dismiss)
private struct FluidSettingsExpandedPanel: View {
    @AppStorage(HabitColorTheme.storageKey) private var colorTheme = HabitColorTheme.original
    let fluidMorphAnimation: Animation
    let onDismiss: () -> Void
    let onClearData: () -> Void

    @State private var dragOffsetY: CGFloat = 0
    @State private var showingClearConfirmation = false

    // 计算交互式拖动阻尼位移与缩放比例
    private var effectiveDragOffset: CGFloat {
        if dragOffsetY < 0 {
            // 向上拉增加弹性阻尼，防止过度往上漂
            return dragOffsetY * 0.2
        } else {
            // 向下拉随手位移
            return dragOffsetY
        }
    }

    private var interactiveScale: CGFloat {
        if dragOffsetY > 0 {
            let progress = min(1.0, dragOffsetY / 360.0)
            return 1.0 - progress * 0.08
        }
        return 1.0
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端下拉指示胶囊条
            HStack {
                Capsule()
                    .fill(Color(red: 0.30, green: 0.26, blue: 0.31).opacity(0.28))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 20) {
                Text("设置")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))

                Text("习惯记录和积分保存在此设备。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 0.32, green: 0.28, blue: 0.33).opacity(0.72))

                VStack(alignment: .leading, spacing: 12) {
                    Text("界面配色")
                        .font(.system(size: 16, weight: .semibold))
                    HStack(spacing: 12) {
                        ForEach(HabitColorTheme.allCases) { theme in
                            Button {
                                colorTheme = theme
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(LinearGradient(colors: [theme.accent, theme.companion], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 24, height: 24)
                                    Text(theme.title)
                                    Spacer(minLength: 0)
                                    Image(systemName: colorTheme == theme ? "checkmark.circle.fill" : "circle")
                                }
                                .font(.system(size: 15, weight: .medium))
                                .padding(12)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(.white.opacity(colorTheme == theme ? 0.75 : 0.35), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(colorTheme == theme ? .isSelected : [])
                            .accessibilityIdentifier("theme." + theme.rawValue)
                        }
                    }
                }
                .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("清除本地数据并重新开始", systemImage: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .tint(Color(red: 0.62, green: 0.20, blue: 0.28))
                .buttonStyle(SettingsPressButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // 底部关闭返回胶囊（与原胶囊位置呼应）
            Button {
                dismissSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("收起设置")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.26, green: 0.22, blue: 0.27))
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .background(.white.opacity(0.68), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.85), lineWidth: 1.2))
            }
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(interactiveScale, anchor: .bottom)
        .offset(y: effectiveDragOffset)
        .alert("清除本地数据？", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清除并重新开始", role: .destructive, action: confirmClearLocalData)
        } message: {
            Text("这会删除已选习惯、打卡记录、复盘、计时记录和积分，并回到首次选择页面。此操作无法撤销。")
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    dragOffsetY = value.translation.height
                }
                .onEnded { value in
                    // 速度较快或下拉超过 110pt 时执行随拉随放弹回收起
                    let shouldDismiss = value.translation.height > 110 || (value.velocity.height > 300 && value.translation.height > 40)
                    if shouldDismiss {
                        dismissSettings()
                    } else {
                        // 未达到阈值，随拉随放平滑弹回原位
                        withAnimation(fluidMorphAnimation) {
                            dragOffsetY = 0
                        }
                    }
                }
        )
    }

    private func dismissSettings() {
        withAnimation(fluidMorphAnimation) { dragOffsetY = 0 }
        onDismiss()
    }

    private func confirmClearLocalData() {
        dismissSettings()
        onClearData()
    }

}

private struct AppTabPage: View {
    let tab: AppTab
    let goals: [Goal]
    @Binding var state: TodayGoalState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.system(size: 38, weight: .medium))
            Text(subtitle).font(.system(size: 15, weight: .medium)).opacity(0.72)
            if tab == .garden {
                ForEach(goals.prefix(3)) { goal in
                    HStack {
                        Text(goal.title).font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Text("按原规则显示").font(.system(size: 13)).opacity(0.6)
                    }.padding(16).background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 20))
                }
            } else if tab == .review {
                VStack(alignment: .leading, spacing: 12) {
                    Text("本月小结").font(.system(size: 22, weight: .semibold))
                    Text("完成记录、积分和习惯明细将沿用原 Flutter 复盘口径。")
                    Text("复盘视觉页面正在按参考图迁移。").foregroundStyle(.secondary)
                }.padding(18).background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 22))
            } else {
                Text("设置页面入口已接通，具体设置项沿用原 App。")
                    .padding(18).background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 22))
            }
            Spacer()
        }.padding(.horizontal, 24)
    }

    private var title: String { tab == .garden ? "养成物" : tab == .review ? "复盘" : "设置" }
    private var subtitle: String { tab == .garden ? "看见习惯完成后留下的成长。" : tab == .review ? "只读回看每天的习惯完成和记录。" : "管理你的习惯 App。" }
}

private struct GoalDeckView: View {
    let goals: [Goal]
    @Binding var state: TodayGoalState

    private var focus: Int { max(0, goals.firstIndex(where: { $0.id == state.focusedGoalID }) ?? 0) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        state.mode = .homeUnselected
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.29))
                }

                Spacer()

                Text("选择今天的习惯")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))

                Spacer()

                Text("上下翻阅")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.65)
                    .frame(width: 50, alignment: .trailing)
            }.padding(.horizontal, 22)
            ZStack(alignment: .top) {
                ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                    let distance = (index - focus + goals.count) % goals.count
                    let visible = distance <= 4
                    DeckCard(goal: goal, index: index + 1, expanded: distance == 0, selected: state.selectedGoalIDs.contains(goal.id), goals: goals)
                        .frame(width: 286, height: distance == 0 ? 390 : 58)
                        .offset(y: CGFloat(distance) * 42)
                        .opacity(visible ? (distance == 0 ? 1 : 0.78) : 0)
                        .zIndex(Double(goals.count - distance))
                }
            }
            .frame(height: 430)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 12).onEnded { value in
                if abs(value.translation.height) > abs(value.translation.width), abs(value.translation.height) > 30 {
                    move(value.translation.height > 0 ? -1 : 1)
                } else if value.translation.width > 60 {
                    toggleSelection()
                }
            })
            HStack(spacing: 28) {
                Button("↑ 上一张") { move(-1) }
                Button("下一张 ↓") { move(1) }
            }.buttonStyle(.bordered)
        }.padding(.top, 10)
    }

    private func move(_ delta: Int) {
        guard !goals.isEmpty else { return }
        let next = (focus + delta + goals.count) % goals.count
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { state.focusedGoalID = goals[next].id }
    }

    private func toggleSelection() {
        guard let id = goals[safe: focus]?.id else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if state.selectedGoalIDs.contains(id) { state.selectedGoalIDs.remove(id) }
            else if state.selectedGoalIDs.count < 3 { state.selectedGoalIDs.insert(id) }
        }
    }
}

private struct DeckCard: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let goal: Goal; let index: Int; let expanded: Bool; let selected: Bool; let goals: [Goal]
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(String(format: "%02d", index)).font(.system(size: 11, weight: .medium)).tracking(1.3).foregroundStyle(.white.opacity(0.8))
            if expanded {
                Text(goal.title).font(.system(size: 29, weight: .medium)).foregroundStyle(.white)
                Text(goal.category.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.4).foregroundStyle(.white.opacity(0.76))
                Text(goal.summary).font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.86))
                Spacer()
                Text(selected ? "已选择 · 右滑取消" : "右滑选择此目标").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            }
        }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 26).fill(colorTheme.card(goal.cardBaseColor(in: goals, theme: colorTheme)).opacity(goal.tint.opacity + (expanded ? 0.18 : 0.05))))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.62)))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
    }
}

private struct ConfirmSelectionBar: View {
    let goals: [Goal]
    let state: TodayGoalState
    let action: () -> Void
    private var regularCount: Int {
        let current = Set(goals.filter {
            state.selectedGoalIDs.contains($0.id) && !state.starredGoalIDs.contains($0.id) && $0.countsTowardQuota
        }.map(\.id))
        return current.union(state.completedRegularGoalIDs).count
    }
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("当天新建 \(regularCount)/3 · 星标 \(state.starredGoalIDs.count)/\(state.starLimit)")
                    .font(.system(size: 12, weight: .semibold))
                Text(state.isFirstSelection ? "首日周期计名额 · 完成后可设星标" : "点星标可额外选 · 周期次日保留")
                    .font(.system(size: 11))
            }
            .foregroundStyle(Color(red: 0.27, green: 0.23, blue: 0.29))
            Spacer(minLength: 4)
            Button("确认选择") { action() }
                .buttonStyle(ConfirmPressStyle())
                .disabled(state.isFirstSelection && state.selectedGoalIDs.isEmpty)
                .opacity(state.isFirstSelection && state.selectedGoalIDs.isEmpty ? 0.42 : 1)
        }
        .padding(.horizontal, 14).frame(height: 66)
        .background(.white.opacity(0.32), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.66), lineWidth: 1))
        .padding(.horizontal, 22).padding(.bottom, 6)
    }
}

private struct ConfirmPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 44)
            .background {
                Capsule()
                    .fill(Color(red: 0.23, green: 0.18, blue: 0.22).opacity(0.92))
                    .overlay {
                        Capsule()
                            .stroke(.black.opacity(configuration.isPressed ? 0.42 : 0.12), lineWidth: 3)
                            .blur(radius: configuration.isPressed ? 3 : 1)
                            .offset(y: configuration.isPressed ? 2 : 0)
                            .mask(Capsule())
                    }
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.22), radius: configuration.isPressed ? 2 : 8, y: configuration.isPressed ? 1 : 5)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.34, dampingFraction: 0.55), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

private struct StarredGoalBadge: View {
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.12))
            .frame(width: 36, height: 36)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("星标习惯")
    }
}

private struct SelectedExecutionCardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0 { value = next }
    }
}

private struct SelectedGoalView: View {
    private struct DeckItem: Identifiable {
        let goal: Goal
        let index: Int
        let depth: Int

        var id: String { goal.id }
    }

    let goals: [Goal]
    let allGoals: [Goal]
    @Binding var state: TodayGoalState
    let selectionTransitionNamespace: Namespace.ID
    let buttonRevealTrigger: UUID
    let onBrowseGoals: () -> Void
    let onStartGoal: (Goal) -> Void
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragX: CGFloat = 0
    @State private var departingGoal: Goal?
    @State private var departingOffsetX: CGFloat = 0
    @State private var stackStep = 1
    @State private var startDeckScale: CGFloat = 1
    @State private var startDeckAnimationID = UUID()
    @State private var returnButtonExpansion: CGFloat = 1
    @State private var returnButtonTitleOpacity: Double = 1
    @State private var returnButtonSheenEnabled = true
    @State private var returnButtonRevealTaskID = UUID()

    private var selected: [Goal] { goals.filter { state.selectedGoalIDs.contains($0.id) } }
    private var activeIndex: Int { selected.isEmpty ? 0 : state.homeSelectedIndex % selected.count }
    private var deckSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.55, dampingFraction: 0.68, blendDuration: 0.08)
    }

    var body: some View {
        VStack(spacing: 18) {
            if !selected.isEmpty {
                selectedDeck
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("今日目标已全部完成")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(state.selectedGoalIDs.union(state.completedSelectedGoalIDs).count < 3
                         ? "已完成的习惯已从待做卡片中移除，可继续选择今天的目标。"
                         : "已完成的习惯已从待做卡片中移除。")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            }
            if state.selectedGoalIDs.union(state.completedSelectedGoalIDs).count < 3 {
                Button(action: onBrowseGoals) {
                    Label("继续选择今天的目标", systemImage: "square.stack.3d.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.27, green: 0.23, blue: 0.29))
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(.white.opacity(0.72), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.86), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHint("打开卡片集，添加今天的目标")
            }
        }
        .padding(.horizontal, 24)
        .onChange(of: buttonRevealTrigger) { _, _ in
            revealStartButtonAfterReturn()
        }
    }

    private var selectedDeck: some View {
        GeometryReader { proxy in
            let visibleCount = min(3, selected.count)
            let progress = min(1, abs(dragX) / 170)
            let cardWidth = proxy.size.width - 12
            let cardHeight: CGFloat = 300
            let backOffsets: [(x: CGFloat, y: CGFloat, rotation: Double)] = [
                (0, 0, 0), (-22, 25, -2), (24, 50, 2.5)
            ]
            let deckItems = (0..<visibleCount).reversed().map { depth in
                let index = (activeIndex + stackStep * depth + selected.count * 2) % selected.count
                return DeckItem(goal: selected[index], index: index, depth: depth)
            }

            ZStack {
                ForEach(deckItems) { item in
                    let depth = item.depth
                    let cardIndex = item.index
                    let goal = item.goal
                    let isFront = depth == 0
                    let direction: CGFloat = dragX < 0 ? -1 : 1
                    let pose = backOffsets[depth]

                    PreviewGoalCard(
                        goal: goal,
                        paletteGoals: allGoals,
                        theme: colorTheme,
                        index: cardIndex + 1,
                        surfaceOpacity: 1,
                        isPrimary: isFront,
                        textScale: 1.68,
                        showsContent: true
                    )
                    .frame(width: cardWidth - CGFloat(depth) * 18, height: cardHeight - CGFloat(depth) * 10)
                    .scaleEffect(isFront ? startDeckScale : 1, anchor: .center)
                    .overlay(alignment: .topTrailing) {
                        if goal.isStarred {
                            StarredGoalBadge()
                                .padding(.top, 18)
                                .padding(.trailing, 18)
                                .accessibilityLabel("星标习惯")
                        }
                    }
                    .matchedGeometryEffect(
                        id: "selected-goal-card-\(goal.id)",
                        in: selectionTransitionNamespace,
                        properties: .frame,
                        anchor: .center,
                        isSource: false
                    )
                    // 按钮必须先成为卡片本体的一部分，再接受卡片的位移和旋转。
                    .overlay(alignment: .bottom) {
                        if isFront {
                            Button {
                                startGoalWithDeckMotion(goal)
                            } label: {
                                Text(goal.completedToday ? "今日已完成" : "开始目标")
                                    .opacity(returnButtonTitleOpacity)
                                    .offset(y: (1 - returnButtonTitleOpacity) * 5)
                            }
                            .buttonStyle(LiquidGlassGoalButtonStyle(sheenEnabled: returnButtonSheenEnabled))
                            .frame(width: 50 + ((cardWidth - 40) * 0.5 - 50) * returnButtonExpansion)
                            .disabled(goal.completedToday || startDeckScale != 1)
                            .opacity(goal.completedToday ? 0.64 : 0.70)
                            .padding(.bottom, 41)
                            .accessibilityHint("开始当前目标")
                        }
                    }
                    .compositingGroup()
                    .scaleEffect(
                        x: isFront ? 1 - progress * 0.055 : 1,
                        y: isFront ? 1 + progress * 0.028 : 1
                    )
                    .rotation3DEffect(
                        .degrees(isFront ? Double(-dragX / 22) : Double(direction * progress * CGFloat(depth) * 2.2)),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.72
                    )
                    .rotationEffect(.degrees(isFront ? Double(-dragX / 42) : pose.rotation))
                    .offset(
                        x: isFront ? dragX : pose.x - direction * progress * CGFloat(depth) * 12,
                        y: isFront ? progress * 11 : pose.y - progress * CGFloat(depth) * 8
                    )
                    .background {
                        if isFront {
                            GeometryReader { cardGeometry in
                                Color.clear.preference(
                                    key: SelectedExecutionCardFrameKey.self,
                                    value: cardGeometry.frame(in: .global)
                                )
                            }
                        }
                    }
                    .shadow(
                        color: Color(red: 0.42, green: 0.16, blue: 0.30)
                            .opacity(isFront ? 0.17 : (depth == 1 ? 0.11 : 0.07)),
                        radius: isFront ? 16 : (depth == 1 ? 12 : 9),
                        y: isFront ? 10 : (depth == 1 ? 7 : 5)
                    )
                    .shadow(color: .black.opacity(isFront ? 0.035 : 0.02), radius: 3, y: 2)
                    .zIndex(Double(visibleCount - depth))
                    .allowsHitTesting(isFront)
                    .accessibilityHidden(!isFront)
                    .transition(.identity)
                }

                if let departingGoal {
                    PreviewGoalCard(
                        goal: departingGoal,
                        paletteGoals: allGoals,
                        theme: colorTheme,
                        index: (selected.firstIndex(where: { $0.id == departingGoal.id }) ?? 0) + 1,
                        surfaceOpacity: 1,
                        isPrimary: true,
                        textScale: 1.68,
                        showsContent: true
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .overlay(alignment: .topTrailing) {
                        if departingGoal.isStarred {
                            StarredGoalBadge()
                                .padding(.top, 18)
                                .padding(.trailing, 18)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Button("开始目标") {}
                            .buttonStyle(LiquidGlassGoalButtonStyle())
                            .frame(width: (cardWidth - 40) * 0.5)
                            .opacity(0.70)
                            .padding(.bottom, 41)
                            .allowsHitTesting(false)
                    }
                    .compositingGroup()
                    .rotationEffect(.degrees(Double(-departingOffsetX / 50)))
                    .offset(x: departingOffsetX)
                    .shadow(color: Color(red: 0.42, green: 0.16, blue: 0.30).opacity(0.17), radius: 16, y: 10)
                    .shadow(color: .black.opacity(0.035), radius: 3, y: 2)
                    .zIndex(100)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityHint("向左或向右滑动切换今日目标")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: shift(by: 1)
                case .decrement: shift(by: -1)
                @unknown default: break
                }
            }
        }
        // 让整组内容落在状态栏与底部导航之间，避免 VStack 因超高而把页首推入状态栏。
        .frame(height: 336)
        .scaleEffect(0.85 * 1.15, anchor: .center)
        .animation(deckSpring, value: state.homeSelectedIndex)
        .animation(reduceMotion ? .none : .linear(duration: 0.06), value: dragX)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($dragX) { value, state, _ in
                state = rubberBand(value.translation.width, limit: 170)
            }
            .onChanged { value in
                let step = value.translation.width < 0 ? 1 : -1
                if stackStep != step { stackStep = step }
            }
            .onEnded { value in
                finishDrag(value)
            }
    }

    private func finishDrag(_ value: DragGesture.Value) {
        let projected = value.predictedEndTranslation.width
        guard abs(projected) >= 70 || abs(value.translation.width) >= 42,
              selected.count > 1,
              departingGoal == nil else { return }

        let direction = value.translation.width < 0 ? 1 : -1
        stackStep = direction
        departingGoal = selected[activeIndex]
        departingOffsetX = rubberBand(value.translation.width, limit: 170)
        withAnimation(deckSpring) {
            state.homeSelectedIndex = (activeIndex + direction + selected.count) % selected.count
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.24)) {
            departingOffsetX = direction > 0 ? -520 : 520
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.13 : 0.25)) {
            departingGoal = nil
            departingOffsetX = 0
        }
    }

    private func startGoalWithDeckMotion(_ goal: Goal) {
        guard startDeckScale == 1 else { return }
        guard !reduceMotion else {
            onStartGoal(goal)
            return
        }

        let animationID = UUID()
        startDeckAnimationID = animationID
        withAnimation(.spring(response: 0.20, dampingFraction: 0.68)) {
            startDeckScale = 0.94
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard startDeckAnimationID == animationID else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                startDeckScale = 1
            }
            try? await Task.sleep(for: .milliseconds(250))
            guard startDeckAnimationID == animationID else { return }
            onStartGoal(goal)
        }
    }

    private func revealStartButtonAfterReturn() {
        let taskID = UUID()
        returnButtonRevealTaskID = taskID
        withTransaction(Transaction(animation: nil)) {
            returnButtonExpansion = 0
            returnButtonTitleOpacity = 0
            returnButtonSheenEnabled = false
        }
        guard !reduceMotion else {
            withTransaction(Transaction(animation: nil)) {
                returnButtonExpansion = 1
                returnButtonTitleOpacity = 1
                returnButtonSheenEnabled = true
            }
            return
        }

        Task { @MainActor in
            await Task.yield()
            guard returnButtonRevealTaskID == taskID else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                returnButtonExpansion = 1
            }
            try? await Task.sleep(for: .milliseconds(230))
            guard returnButtonRevealTaskID == taskID else { return }
            withAnimation(.easeOut(duration: 0.20)) {
                returnButtonTitleOpacity = 1
            }
            try? await Task.sleep(for: .milliseconds(180))
            guard returnButtonRevealTaskID == taskID else { return }
            returnButtonSheenEnabled = true
        }
    }

    private func shift(by direction: Int) {
        guard selected.count > 1 else { return }
        let next = (activeIndex + direction + selected.count) % selected.count
        stackStep = direction
        withAnimation(deckSpring) { state.homeSelectedIndex = next }
    }

    private func rubberBand(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        let magnitude = abs(value)
        guard magnitude > limit else { return value }
        let resisted = limit + (magnitude - limit) * 0.28
        return value.sign == .minus ? -resisted : resisted
    }
}

private struct LiquidGlassGoalButtonStyle: ButtonStyle {
    var sheenEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.22, green: 0.18, blue: 0.24))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                Capsule()
                    .fill(.white)
                    .overlay { GoalButtonSheen(isEnabled: sheenEnabled).clipShape(Capsule()) }
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.12 : 0.22), radius: configuration.isPressed ? 3 : 8, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.linear(duration: 0.14), value: configuration.isPressed)
    }
}

private struct GoalButtonSheen: View {
    let isEnabled: Bool
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSweeping = false

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            (colorTheme == .original ? Color(red: 1, green: 0.70, blue: 0.84) : colorTheme.companion).opacity(0.18),
                            .white.opacity(0.42),
                            (colorTheme == .original ? Color(red: 1, green: 0.70, blue: 0.84) : colorTheme.companion).opacity(0.18),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geometry.size.width * 0.68, height: geometry.size.height * 3)
                .rotationEffect(.degrees(-20))
                .position(
                    x: geometry.size.width * (isSweeping ? 1.1 : -0.1),
                    y: geometry.size.height * 0.5
                )
                .opacity(1)
        }
        .clipShape(Capsule())
        .onAppear {
            startSweepIfAllowed()
        }
        .onChange(of: isEnabled) { _, enabled in
            if enabled {
                startSweepIfAllowed()
            } else {
                isSweeping = false
            }
        }
        .opacity(isEnabled ? 1 : 0)
        .allowsHitTesting(false)
    }

    private func startSweepIfAllowed() {
        guard isEnabled, !reduceMotion else { return }
        isSweeping = false
        withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
            isSweeping = true
        }
    }
}


private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct TodayHeaderView: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let selectedCount: Int
    var mode: TodayMode = .homeUnselected
    var tuning: UITuningState = UITuningState()
    let dashboard: HabitDashboardSnapshot?

    private var headerTitle: String {
        mode == .homeSelected ? "已选择\n今天的\n目标" : "选择\n今天的\n目标"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部艺术化排版：大号换行标题 + 右侧大号艺术日期
            HStack(alignment: .top, spacing: 8) {
                // 左侧主标题
                Text(headerTitle)
                    .font(.system(size: tuning.titleSize * tuning.textScale, weight: .medium))
                    .tracking(-0.6)
                    .lineSpacing(-8)
                    .foregroundStyle(colorTheme == .lavender ? Color.white : Color(red: 0.22, green: 0.20, blue: 0.24))
                    .shadow(color: colorTheme == .lavender ? .black.opacity(0.52) : .clear, radius: 1.5, y: 1)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                // 右侧大号艺术日期 (实时同步当前日期，调大字号使上下跨度与左侧标题等高)
                VStack(alignment: .trailing, spacing: -8) {
                    Text(dayString)
                        .font(.system(size: tuning.dateSize * tuning.textScale, weight: .regular))
                        .tracking(-3.0)
                    Text(monthString)
                        .font(.system(size: tuning.dateSize * tuning.textScale, weight: .regular))
                        .tracking(-4.5)
                }
                .foregroundStyle(.white.opacity(colorTheme == .lavender ? 0.98 : 0.82))
                .shadow(color: colorTheme == .lavender ? .black.opacity(0.52) : .clear, radius: 1.5, y: 1)
                .fixedSize(horizontal: true, vertical: false)
            }

            // 中间行：副标题与右侧积分胶囊垂直居中对齐
            HStack(alignment: .center, spacing: 10) {
                Text("把注意力留给想变好的自己。")
                    .font(.system(size: 17, weight: .medium)) // 13.5 * 1.25 ≈ 17
                    .foregroundStyle(colorTheme == .lavender ? Color.white.opacity(0.95) : Color.white.opacity(0.72))
                    .shadow(color: colorTheme == .lavender ? .black.opacity(0.52) : .clear, radius: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                // 积分展示按钮（右对齐，与上方月份边缘对齐，且与左侧副标垂直居中）
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 22, weight: .semibold)) // 放大 2 倍
                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.38))
                    Text("\(dashboard?.points ?? 0)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.24, green: 0.34, blue: 0.28))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.72), in: Capsule())
                .overlay(Capsule().stroke(Color(red: 0.26, green: 0.52, blue: 0.38).opacity(0.25), lineWidth: 1))
            }

            // 昨天的回顾提示位（保持柔和淡粉底色与清晰呼吸空间）
            if mode == .homeUnselected {
                YesterdayReviewBanner(missedCount: dashboard?.missedYesterday ?? 0)
                    .padding(.top, tuning.bannerPaddingTop)
            }
        }
        .padding(.horizontal, 22)
        // 页面背景延伸到状态栏，但内容必须从 Dynamic Island / 时间下方开始。
        .padding(.top, mode == .homeSelected ? 15 : 64)
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: .now)
    }

    private var monthString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter.string(from: .now).uppercased()
    }
}

private struct YesterdayReviewBanner: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let missedCount: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(missedCount == 0 ? "昨天没有未完成的习惯记录。" : "昨天有 \(missedCount) 个习惯未完成，已记入日历。未完成不直接扣分；连续7天没有完成才会进入休眠与衰减。")
                .font(.system(size: 13.5, weight: .medium))
                .lineSpacing(4)
                .foregroundStyle(Color(red: 0.36, green: 0.26, blue: 0.28))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill((colorTheme == .original ? Color(red: 0.99, green: 0.88, blue: 0.88) : colorTheme.softSurface).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke((colorTheme == .original ? Color(red: 0.95, green: 0.78, blue: 0.78) : colorTheme.companion), lineWidth: 1)
        )
    }
}

private struct HomeSelectionHint: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerEnd: CGFloat = 0

    private let title = "轻触卡片，\n选择今日目标"
    private let ink = Color(red: 1, green: 0.95, blue: 0.97)

    var body: some View {
        Text(title)
            .font(.system(size: 18.7, weight: .heavy))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 240)
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: ink.opacity(0.90), location: 0),
                        .init(color: ink.opacity(0.90), location: 0.39),
                        .init(color: ink.opacity(0.94), location: 0.46),
                        .init(color: Color.white, location: 0.50),
                        .init(color: ink.opacity(0.94), location: 0.54),
                        .init(color: ink.opacity(0.90), location: 0.61),
                        .init(color: ink.opacity(0.90), location: 1)
                    ],
                    startPoint: UnitPoint(x: reduceMotion ? 0 : shimmerEnd - 1, y: 0),
                    endPoint: UnitPoint(x: reduceMotion ? 1 : shimmerEnd, y: 0)
                )
            )
            .shadow(color: .black.opacity(0.184), radius: 3, x: 0, y: 2)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 2.45).repeatForever(autoreverses: false)) {
                    shimmerEnd = 2
                }
            }
    }
}

private struct HomeDeckLaunchFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0 { value = next }
    }
}

private struct HomePreviewDeckView: View {
    let goals: [Goal]
    let tuning: UITuningState
    let reduceMotion: Bool
    let isPressed: Bool
    let isGathered: Bool
    let isHintVisible: Bool

    // 首页虚拟卡片代表待选卡片集的首张、中间张和末张。
    private var cards: [HomePreviewCard] {
        let source = goals.isEmpty ? SharedHabitRepository.catalog : goals
        let ordered = source.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
        guard !ordered.isEmpty else { return [] }
        let positions = [0, (ordered.count - 1) / 2, ordered.count - 1]
        return positions.map { position in
            let goal = ordered[position]
            return HomePreviewCard(
                id: goal.id,
                title: goal.previewTitle,
                summary: goal.previewSummary,
                order: goal.order
            )
        }
    }
    @State private var animateBreathing = false

    private var poses: [PreviewPose] {
        [
            PreviewPose(x: 0, y: 0, width: tuning.cardWidth, rotation: 0, opacity: 1),
            PreviewPose(x: tuning.cardWidth * 0.32 - 8, y: 18, width: tuning.cardWidth * 0.94, rotation: 12, opacity: 1),
            PreviewPose(x: -tuning.cardWidth * 0.32 + 15, y: 20, width: tuning.cardWidth * 0.94, rotation: -20, opacity: 1)
        ]
    }

    private func cardPosition(_ index: Int) -> CGPoint {
        if isGathered {
            return CGPoint(x: 0, y: index == 0 ? 0 : 8)
        }
        let float: CGFloat = animateBreathing ? [-11, -7, 8][index] : 0
        return CGPoint(x: poses[index].x, y: poses[index].y + float)
    }

    private func cardRotation(_ index: Int) -> Double {
        isGathered ? 0 : poses[index].rotation
    }

    private func shadowOffset(from upperIndex: Int, onto lowerIndex: Int) -> CGSize {
        let upper = cardPosition(upperIndex)
        let lower = cardPosition(lowerIndex)
        let radians = cardRotation(lowerIndex) * .pi / 180
        let dx = upper.x - lower.x
        let dy = upper.y - lower.y + 4
        return CGSize(
            width: dx * cos(radians) + dy * sin(radians),
            height: -dx * sin(radians) + dy * cos(radians)
        )
    }

    var body: some View {
        ZStack {
            ForEach(Swift.Array(cards.enumerated()), id: \.element.id) { index, card in
                let pose = poses[index]
                let position = cardPosition(index)

                PreviewGoalCard(card: card, index: card.order, surfaceOpacity: pose.opacity, isPrimary: index == 0, isPressed: isPressed)
                    .frame(width: pose.width, height: tuning.cardHeight)
                    .overlay(alignment: .center) {
                        if index == 0 {
                            HomeSelectionHint()
                                .offset(y: tuning.cardHeight * 0.22 + 5)
                                .opacity(isHintVisible ? 1 : 0)
                                .animation(.easeOut(duration: 0.1), value: isHintVisible)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay {
                        if index > 0 {
                            ZStack {
                                ForEach(0..<index, id: \.self) { upperIndex in
                                    let upperPose = poses[upperIndex]
                                    let offset = shadowOffset(from: upperIndex, onto: index)
                                    let shadowOpacity = upperIndex == 0 && index == 2 ? 0.15 : 0.30

                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(.black.opacity(shadowOpacity))
                                        .frame(width: upperPose.width, height: tuning.cardHeight)
                                        .blur(radius: CGFloat(upperIndex == 0 ? 4 : 7))
                                        .rotationEffect(.degrees(cardRotation(upperIndex) - cardRotation(index)))
                                        .offset(x: offset.width, y: offset.height)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        }
                    }
                    .scaleEffect(x: isPressed ? 1.025 : 1, y: isPressed ? 0.965 : 1)
                    .rotationEffect(.degrees(cardRotation(index)))
                    .offset(x: position.x, y: position.y)
                    .transition(.identity)
                    .animation(.spring(response: 0.42, dampingFraction: 0.84).delay(index == 2 ? 0 : (index == 1 ? 0.06 : 0.18)), value: isGathered)
                    .animation(.easeOut(duration: 0.14), value: isPressed)
                    .zIndex(Double(index == 0 ? 3 : (index == 1 ? 2 : 1)))
            }
        }
        .frame(height: tuning.cardHeight + 44)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("三张虚拟引导卡")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 1.15, dampingFraction: 0.55).repeatForever(autoreverses: true)) {
                animateBreathing = true
            }
        }
    }
}

private struct HomePreviewCard: Identifiable {
    let id: String
    let title: String
    let summary: String
    let order: Int
}

private struct PreviewPose {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let rotation: Double
    let opacity: Double
}

private struct SelectedDeckCornerHighlight: Shape {
    let isBottomLeft: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 26
        var path = Path()
        if isBottomLeft {
            path.move(to: CGPoint(x: rect.minX + 1, y: rect.maxY - radius - 1))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius + 1, y: rect.maxY - 1),
                control: CGPoint(x: rect.minX + 1, y: rect.maxY - 1)
            )
            path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.maxY - 1))
        } else {
            path.move(to: CGPoint(x: rect.width * 0.25, y: rect.minY + 1))
            path.addLine(to: CGPoint(x: rect.maxX - radius - 1, y: rect.minY + 1))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 1, y: rect.minY + radius + 1),
                control: CGPoint(x: rect.maxX - 1, y: rect.minY + 1)
            )
        }
        return path
    }
}

private struct SelectedDeckSideHighlight: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = isLeft ? rect.minX + 1 : rect.maxX - 1
        path.move(to: CGPoint(x: x, y: isLeft ? rect.height * 0.25 : rect.minY + 27))
        path.addLine(to: CGPoint(x: x, y: isLeft ? rect.maxY - 27 : rect.height * 0.75))
        return path
    }
}

private struct PreviewGoalCard: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let title: String
    let summary: String
    let appearance: GoalCardAppearance?
    let paletteGoals: [Goal]?
    let index: Int
    var surfaceOpacity: Double = 0.9
    var isPrimary = true
    var textScale: CGFloat = 1
    var showsContent = true
    var isPressed = false
    init(card: HomePreviewCard, index: Int, surfaceOpacity: Double = 0.9, isPrimary: Bool = true, textScale: CGFloat = 1, showsContent: Bool = true, isPressed: Bool = false) {
        self.title = card.title
        self.summary = card.summary
        self.appearance = nil
        self.paletteGoals = nil
        self.index = index
        self.surfaceOpacity = surfaceOpacity
        self.isPrimary = isPrimary
        self.textScale = textScale
        self.showsContent = showsContent
        self.isPressed = isPressed
    }

    init(goal: Goal, paletteGoals: [Goal], theme: HabitColorTheme, index: Int, surfaceOpacity: Double = 0.9, isPrimary: Bool = true, textScale: CGFloat = 1, showsContent: Bool = true) {
        self.title = goal.previewTitle
        self.summary = goal.previewSummary
        self.appearance = GoalCardAppearance(goal: goal, goals: paletteGoals, theme: theme)
        self.paletteGoals = paletteGoals
        self.index = index
        self.surfaceOpacity = surfaceOpacity
        self.isPrimary = isPrimary
        self.textScale = textScale
        self.showsContent = showsContent
    }

    private var textColor: Color {
        .white
    }

    private var usesSelectedDeckLayout: Bool {
        textScale > 1
    }

    private var cardTintColor: Color {
        let goals = paletteGoals ?? SharedHabitRepository.catalog
        let ordered = goals.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
        let cardOrder = ordered.first(where: { $0.id == appearance?.goalID })?.order ?? index
        return colorTheme.selectedDeckCardColor(
            at: cardOrder - 1,
            count: max(12, ordered.map(\.order).max() ?? 12)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: usesSelectedDeckLayout ? 10 : 14) {
            Text(String(format: "%02d", index))
                .font(.system(size: 11 * textScale, weight: .medium))
                .tracking(1.32)
                .foregroundStyle(textColor.opacity(colorTheme == .lavender ? (usesSelectedDeckLayout ? 1 : (isPrimary ? 0.92 : 0.78)) : (usesSelectedDeckLayout ? 1 : (isPrimary ? 0.6375 : 0.255))))
            Text(title)
                    .font(.system(size: (isPrimary ? 25 : 21) * textScale, weight: .semibold))
                    .tracking(-0.77)
                    .foregroundStyle(textColor.opacity(colorTheme == .lavender ? (usesSelectedDeckLayout ? 0.96 : (isPrimary ? 0.92 : 0.80)) : (usesSelectedDeckLayout ? 0.82 : (isPrimary ? 0.69 : 0.34))))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .frame(maxWidth: .infinity, minHeight: usesSelectedDeckLayout ? 88 : 0, alignment: .topLeading)
            Text(summary)
                    .font(.system(size: (isPrimary ? 12 : 11) * textScale, weight: .medium))
                    .foregroundStyle(textColor.opacity(colorTheme == .lavender ? (usesSelectedDeckLayout ? 1 : (isPrimary ? 0.86 : 0.74)) : (usesSelectedDeckLayout ? 1 : (isPrimary ? 0.645 : 0.408))))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    // 说明文字始终从同一高度开始，避免标题换行时上下跳动。
                    .frame(maxWidth: .infinity, minHeight: usesSelectedDeckLayout ? 46 : 0, alignment: .topLeading)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, usesSelectedDeckLayout ? 20 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(showsContent ? 1 : 0)
        .background {
            SelectedDeckCardSurface(
                shape: RoundedRectangle(cornerRadius: 26, style: .continuous),
                tint: cardTintColor
            )
                .overlay {
                    if !usesSelectedDeckLayout && isPressed {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [.white.opacity(0.88), .white.opacity(0.38), .white.opacity(0.08), .clear],
                                    center: .center,
                                    startRadius: 1,
                                    endRadius: 126
                                )
                            )
                            .blur(radius: 13)
                            .blendMode(.screen)
                            .transition(.opacity)
                    }
                }
                .overlay {
                    if !usesSelectedDeckLayout {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.26), .clear, .black.opacity(0.08)],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                    }
                }
                .opacity(usesSelectedDeckLayout ? 0.95 : 1)
        }
        .overlay {
            if usesSelectedDeckLayout {
                ZStack {
                    SelectedDeckSideHighlight(isLeft: true)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.25),
                                    .init(color: .white.opacity(0.40), location: 0.55),
                                    .init(color: .white.opacity(0.72), location: 0.92)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2.25
                        )
                    SelectedDeckCornerHighlight(isBottomLeft: true)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.72), location: 0),
                                    .init(color: .white.opacity(0.72), location: 0.12),
                                    .init(color: .white.opacity(0.38), location: 0.38),
                                    .init(color: .clear, location: 0.75)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2.25
                        )
                    SelectedDeckCornerHighlight(isBottomLeft: false)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.25),
                                    .init(color: .white.opacity(0.24), location: 0.48),
                                    .init(color: .white.opacity(0.56), location: 0.89),
                                    .init(color: .white.opacity(0.576), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2.25
                        )
                    SelectedDeckSideHighlight(isLeft: false)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.576), location: 0.08),
                                    .init(color: .white.opacity(0.32), location: 0.28),
                                    .init(color: .clear, location: 0.75)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2.25
                        )
                }
                .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.90), .white.opacity(0.32), .white.opacity(0.58)],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        ),
                        lineWidth: 1.2
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: isPressed)
    }

}

private struct HomeCaptionView: View {
    var body: some View {
        VStack(spacing: 9) {
            Text("昨天有 3 个习惯未完成，已记入日历。")
                .font(.system(size: 17.5, weight: .medium))
            Text("今天，从一个小小的目标开始。")
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.29).opacity(0.78))
        .multilineTextAlignment(.center)
    }
}

private struct TodayBottomNavigationView: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Binding var tab: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let fluidMorphAnimation: Animation
    let onOpenSettings: () -> Void

    // 水滴中心在各个 Tab 上的目标相对索引：今天(0.0), 养成物(1.0), 复盘(2.0)
    @State private var animatedIndex: Double = 0.0

    // 优雅放慢弹簧响应时间（0.62s 舒缓流体弹簧），让水滴形变与流动看得一清二楚，从容优雅
    private let fluidSpring = Animation.spring(response: 0.62, dampingFraction: 0.86)

    var body: some View {
        HStack(spacing: 12) {
            // 左侧三个按键容器（极致通透的 iOS 27 水晶液态玻璃大胶囊，收窄宽度更精致）
            ZStack(alignment: .leading) {
                // 1. 胶囊外壳晶莹透明液态玻璃底座
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(Color.black.opacity(colorTheme == .lavender ? 0.12 : 0)))
                    .opacity(colorTheme == .lavender ? 0.68 : 0.20)
                    .overlay(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorTheme == .lavender ? 0.055 : 0.08),
                                        .white.opacity(colorTheme == .lavender ? 0.018 : 0.025),
                                        .clear,
                                        .white.opacity(colorTheme == .lavender ? 0.065 : 0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: colorTheme == .lavender ? [.white.opacity(0.62), .white.opacity(0.15), .white.opacity(0.08), .white.opacity(0.42)] : [
                                        .white.opacity(0.86),
                                        .white.opacity(0.16),
                                        .white.opacity(0.08),
                                        .white.opacity(0.55)
                                    ],
                                    startPoint: .bottomLeading,
                                    endPoint: .topTrailing
                                ),
                                lineWidth: 1.1
                            )
                    )
                    .shadow(color: .white.opacity(colorTheme == .lavender ? 0.20 : 0.42), radius: 7, x: -3, y: 3)
                    .shadow(color: Color.black.opacity(0.045), radius: 12, y: 6)

                // 2. 空间连续滑动的动态水滴（在两按键之间约 20px 的过渡区自然扁平化，进入按钮恢复饱满）
                GeometryReader { geo in
                    let availableWidth = geo.size.width
                    let itemWidth = availableWidth / 3

                    FluidContinuousDropletView(
                        progress: animatedIndex,
                        itemWidth: itemWidth,
                        totalHeight: geo.size.height,
                        reduceMotion: reduceMotion
                    )
                    .allowsHitTesting(false)
                }

                // 3. 三个按键排布
                HStack(spacing: 0) {
                    ForEach([AppTab.today, .garden, .review], id: \.self) { itemTab in
                        Button {
                            switchTab(to: itemTab)
                        } label: {
                            NavigationItem(
                                symbol: itemTab == .today ? "house" : (itemTab == .garden ? "leaf" : "list.bullet"),
                                title: itemTab == .today ? "今天" : (itemTab == .garden ? "养成物" : "复盘"),
                                selected: tab == itemTab
                            )
                        }
                    }
                }
                .padding(5)
            }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: colorTheme == .lavender ? [.white.opacity(0.62), .white.opacity(0.15), .white.opacity(0.42)] : [.white.opacity(0.74), .white.opacity(0.12), .white.opacity(0.40)],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60) // 恢复舒适大气的底层导航栏高度
            .onAppear {
                animatedIndex = tabTargetIndex(for: tab)
            }

            // 右侧设置按钮（晶莹透亮圆形液态玻璃球，尺寸适配底层导航高度 60x60）
            Button {
                onOpenSettings()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.black.opacity(colorTheme == .lavender ? 0.58 : 0)))
                        .opacity(colorTheme == .lavender ? 1 : 0.20)
                        .overlay(
                            Circle()
                                .fill(
                                    RadialGradient(
                                    colors: colorTheme == .lavender ? [.white.opacity(0.05), .white.opacity(0.01), .clear] : [.white.opacity(0.12), .white.opacity(0.025), .clear],
                                        center: .bottomLeading,
                                        startRadius: 3,
                                        endRadius: 30
                                    )
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: colorTheme == .lavender ? [.white.opacity(0.22), .white.opacity(0.08), .black.opacity(0.12), .white.opacity(0.16)] : [
                                            .white.opacity(0.86),
                                            .white.opacity(0.18),
                                            .white.opacity(0.08),
                                            .white.opacity(0.55)
                                        ],
                                        startPoint: .bottomLeading,
                                        endPoint: .topTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: .white.opacity(colorTheme == .lavender ? 0.08 : 0.42), radius: 7, x: -3, y: 3)
                        .shadow(color: Color.black.opacity(0.045), radius: 12, y: 6)

                    PrototypeIcon(kind: .settings, isEmphasized: true)
                        .frame(width: 21, height: 21)
                }
                .frame(width: 60, height: 60)
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: SettingsButtonFrameKey.self, value: geometry.frame(in: .global))
                }
            }
            .buttonStyle(SettingsPressButtonStyle())
            .accessibilityLabel("设置")
        }
        .padding(.horizontal, 16) // 最底层导航栏比例舒展大气
        .padding(.bottom, 22)
    }

    private func tabTargetIndex(for t: AppTab) -> Double {
        switch t {
        case .today: return 0.0
        case .garden: return 1.0
        case .review: return 2.0
        case .settings: return animatedIndex
        }
    }

    private func switchTab(to newTab: AppTab) {
        guard tab != newTab else { return }
        tab = newTab
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : fluidSpring) {
            animatedIndex = tabTargetIndex(for: newTab)
        }
    }
}

// MARK: - 连续线性动感水滴 (Fluid Continuous Droplet View)
private struct FluidContinuousDropletView: View, Animatable {
    @Environment(\.habitColorTheme) private var colorTheme
    var progress: Double
    let itemWidth: CGFloat
    let totalHeight: CGFloat
    let reduceMotion: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    // 计算当前离两按钮中点的距离，并将过渡区间精确拉宽至 20px
    private var transitFactor: CGFloat {
        let frac = progress - floor(progress)
        let distToCenter = abs(frac - 0.5) // 中点为 0.0，按键中心为 0.5
        // 20px 对应的相对索引跨度半宽 (20px / itemWidth / 2)
        let halfTransitWidth = max(0.14, (20.0 / itemWidth) / 2.0)
        guard distToCenter < halfTransitWidth else { return 0 }
        let normalized = (halfTransitWidth - distToCenter) / halfTransitWidth
        // 平滑三次缓动曲线（SmoothStep），过渡温润自然
        return CGFloat(normalized * normalized * (3 - 2 * normalized))
    }

    var body: some View {
        let xPos = CGFloat(progress) * itemWidth
        let dropletWidth = itemWidth - 4
        let dropletOffsetX = xPos + 2
        let scaleX = reduceMotion ? 1 : 1 + transitFactor * 0.18
        let scaleY = reduceMotion ? 1 : 1 - transitFactor * 0.42

        ZStack {
            // 选中态采用调节杆滑钮的高透液态玻璃：主体近透明，只保留折射、边缘高光和微弱暗边。
            Capsule()
                .fill(colorTheme == .lavender ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.ultraThinMaterial))
                .overlay(Capsule().fill(
                    colorTheme.selectedNavigationBackground.opacity(colorTheme == .lavender ? 0.71 : 0)
                ))
                .glassEffect(
                    .clear.tint(colorTheme.selectedNavigationBackground.opacity(colorTheme == .lavender ? 0.54 : 0.03)).interactive(),
                    in: Capsule()
                )

            Capsule()
                .fill(
                    RadialGradient(
                        colors: colorTheme == .lavender ? [.white.opacity(0.12), .white.opacity(0.035), .clear] : [.white.opacity(0.30), .white.opacity(0.08), .clear],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 42
                    )
                )

            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: colorTheme == .lavender ? [
                            .white.opacity(0.38),
                            .white.opacity(0.16),
                            .black.opacity(0.28),
                            .white.opacity(0.20)
                        ] : [
                            .white.opacity(0.88),
                            .white.opacity(0.24),
                            .black.opacity(0.10),
                            .white.opacity(0.46)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )

        }
        .frame(width: dropletWidth, height: totalHeight - 4)
        .scaleEffect(x: scaleX, y: scaleY)
        .offset(x: dropletOffsetX, y: 2)
        .shadow(
            color: (colorTheme == .original ? Color(red: 0.88, green: 0.65, blue: 0.75) : colorTheme.companion).opacity(0.20 + Double(transitFactor) * 0.14),
            radius: 7 + transitFactor * 3,
            y: 2.5 - transitFactor * 1.5
        )
        .shadow(color: Color.black.opacity(0.09), radius: 7, y: 3)
    }
}

private struct NavigationItem: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let symbol: String
    let title: String
    var selected = false

    var body: some View {
        VStack(spacing: 3) {
            PrototypeIcon(kind: iconKind, isEmphasized: selected)
                .frame(width: 20, height: 20)
                .scaleEffect(selected ? 1.08 : 0.95)
            Text(title)
                .font(.system(size: 11, weight: selected ? .semibold : .medium))
        }
        .foregroundStyle(selected
            ? colorTheme.selectedNavigationForeground
            : (colorTheme == .lavender ? colorTheme.unselectedNavigationForeground : Color(red: 0.32, green: 0.28, blue: 0.34).opacity(0.75))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var iconKind: PrototypeIcon.Kind {
        switch symbol {
        case "house": .home
        case "leaf": .leaf
        default: .review
        }
    }
}

private struct PrototypeIcon: View {
    @Environment(\.habitColorTheme) private var colorTheme
    enum Kind { case home, leaf, review, settings }

    let kind: Kind
    var isEmphasized = false

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            var context = context
            context.scaleBy(x: scale, y: scale)
            let color = colorTheme == .lavender ? (isEmphasized ? colorTheme.selectedNavigationForeground : colorTheme.unselectedNavigationForeground) : Color(red: 0.31, green: 0.27, blue: 0.32)

            switch kind {
            case .home:
                var path = Path()
                path.move(to: CGPoint(x: 3, y: 10))
                path.addLine(to: CGPoint(x: 12, y: 3))
                path.addLine(to: CGPoint(x: 21, y: 10))
                path.move(to: CGPoint(x: 5, y: 9))
                path.addLine(to: CGPoint(x: 5, y: 21))
                path.addLine(to: CGPoint(x: 10, y: 21))
                path.addLine(to: CGPoint(x: 10, y: 14))
                path.addLine(to: CGPoint(x: 14, y: 14))
                path.addLine(to: CGPoint(x: 14, y: 21))
                path.addLine(to: CGPoint(x: 19, y: 21))
                path.addLine(to: CGPoint(x: 19, y: 9))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            case .leaf:
                var path = Path()
                path.move(to: CGPoint(x: 12, y: 21))
                path.addLine(to: CGPoint(x: 12, y: 9))
                path.move(to: CGPoint(x: 12, y: 16))
                path.addCurve(to: CGPoint(x: 3, y: 10), control1: CGPoint(x: 4, y: 17), control2: CGPoint(x: 3, y: 10))
                path.addCurve(to: CGPoint(x: 12, y: 16), control1: CGPoint(x: 10, y: 9), control2: CGPoint(x: 12, y: 16))
                path.move(to: CGPoint(x: 12, y: 13))
                path.addCurve(to: CGPoint(x: 20, y: 6), control1: CGPoint(x: 12, y: 13), control2: CGPoint(x: 12, y: 6))
                path.addCurve(to: CGPoint(x: 12, y: 13), control1: CGPoint(x: 20, y: 6), control2: CGPoint(x: 21, y: 14))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            case .review:
                var path = Path()
                path.move(to: CGPoint(x: 4, y: 5)); path.addLine(to: CGPoint(x: 20, y: 5))
                path.move(to: CGPoint(x: 4, y: 11)); path.addLine(to: CGPoint(x: 14, y: 11))
                path.move(to: CGPoint(x: 4, y: 17)); path.addLine(to: CGPoint(x: 11, y: 17))
                path.move(to: CGPoint(x: 16, y: 20)); path.addLine(to: CGPoint(x: 21, y: 15)); path.addLine(to: CGPoint(x: 18, y: 12)); path.addLine(to: CGPoint(x: 13, y: 17)); path.addLine(to: CGPoint(x: 12, y: 21)); path.closeSubpath()
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            case .settings:
                var path = Path()
                path.addEllipse(in: CGRect(x: 8, y: 8, width: 8, height: 8))
                path.move(to: CGPoint(x: 9, y: 3)); path.addLine(to: CGPoint(x: 15, y: 3)); path.addLine(to: CGPoint(x: 16, y: 6)); path.addLine(to: CGPoint(x: 19, y: 7)); path.addLine(to: CGPoint(x: 21, y: 12)); path.addLine(to: CGPoint(x: 19, y: 17)); path.addLine(to: CGPoint(x: 16, y: 18)); path.addLine(to: CGPoint(x: 15, y: 21)); path.addLine(to: CGPoint(x: 9, y: 21)); path.addLine(to: CGPoint(x: 8, y: 18)); path.addLine(to: CGPoint(x: 5, y: 17)); path.addLine(to: CGPoint(x: 3, y: 12)); path.addLine(to: CGPoint(x: 5, y: 7)); path.addLine(to: CGPoint(x: 8, y: 6)); path.closeSubpath()
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct HabitBackgroundFrameKey: EnvironmentKey {
    static let defaultValue: CGRect = .zero
}

extension EnvironmentValues {
    var habitBackgroundFrame: CGRect {
        get { self[HabitBackgroundFrameKey.self] }
        set { self[HabitBackgroundFrameKey.self] = newValue }
    }
}

// 今日、养成物和复盘共用的连续流体背景。
struct TodayAmbientBackground: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let reduceMotion: Bool
    var onViewportChange: ((CGRect) -> Void)? = nil

    var body: some View {
        GeometryReader { viewport in
            TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 45)) { timeline in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    draw(in: &context, size: size, time: time)
                }
                .frame(width: viewport.size.width, height: viewport.size.height)
                .background {
                    ColorThemeAtmosphereBase(colorTheme: colorTheme)
                }
            }
            .onGeometryChange(for: CGRect.self) { _ in viewport.frame(in: .global) } action: { frame in
                onViewportChange?(frame)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let minDim = min(size.width, size.height)
        let travel = reduceMotion ? 0.48 : 0.5 + 0.5 * sin(time * 0.34)
        let collision = smoothstep(0.08, 0.92, travel)
        let exchange = smoothstep(0.38, 0.62, collision)

        let largeRadius = minDim * (1.225 + 0.04375 * sin(time * 0.47))
        let smallRadius = minDim * (0.6125 + 0.0245 * cos(time * 0.53))
        let largeCenter = CGPoint(
            x: size.width * (0.17 + 0.36 * collision),
            y: size.height * (0.82 - 0.35 * collision)
        )
        let smallCenter = CGPoint(
            x: size.width * (0.86 - 0.34 * collision),
            y: size.height * (0.18 + 0.35 * collision)
        )

        let violet = colorTheme.accent
        let deepViolet = colorTheme.companion
        let largeColor = violet.mix(with: deepViolet, by: exchange)
        let smallColor = deepViolet.mix(with: violet, by: exchange)

        context.addFilter(.blur(radius: 52))
        drawSphere(in: &context, center: largeCenter, radius: largeRadius, color: largeColor)
        drawSphere(in: &context, center: smallCenter, radius: smallRadius, color: smallColor)

        let distance = hypot(smallCenter.x - largeCenter.x, smallCenter.y - largeCenter.y)
        let overlap = 1 - smoothstep(
            (largeRadius + smallRadius) * 0.62,
            (largeRadius + smallRadius) * 1.08,
            distance
        )
        let midpoint = CGPoint(
            x: largeCenter.x * 0.55 + smallCenter.x * 0.45,
            y: largeCenter.y * 0.55 + smallCenter.y * 0.45
        )
        let coreRadius = smallRadius * (0.48 + overlap * 0.26)
        context.opacity = overlap * 0.72
        context.fill(
            Path(ellipseIn: CGRect(x: midpoint.x - coreRadius, y: midpoint.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)),
            with: .radialGradient(
                Gradient(colors: [deepViolet.mix(with: violet, by: 0.5).opacity(0.9), .clear]),
                center: midpoint,
                startRadius: 4,
                endRadius: coreRadius
            )
        )
        context.opacity = 1

        drawAccent(in: &context, center: CGPoint(x: size.width * 0.88 + cos(time * 0.9) * 22, y: size.height * 0.26 + sin(time * 0.82) * 24), radius: minDim * 0.17, color: deepViolet.opacity(0.42))
        drawAccent(in: &context, center: CGPoint(x: size.width * 0.12 + sin(time * 0.84) * 20, y: size.height * 0.48 + cos(time * 0.92) * 22), radius: minDim * 0.13, color: violet.opacity(0.36))
    }

    private func drawSphere(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [color.opacity(0.96), color.opacity(0.72), color.opacity(0)]),
                center: CGPoint(x: center.x - radius * 0.12, y: center.y - radius * 0.14),
                startRadius: radius * 0.04,
                endRadius: radius
            )
        )
    }

    private func drawAccent(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(Gradient(colors: [color, .clear]), center: center, startRadius: 2, endRadius: radius)
        )
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let x = min(1, max(0, (value - edge0) / max(0.0001, edge1 - edge0)))
        return x * x * (3 - 2 * x)
    }
}

#Preview { ContentView() }
