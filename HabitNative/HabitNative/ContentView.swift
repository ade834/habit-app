import SwiftUI
import UIKit
import UserNotifications

// MARK: - 电影感光影剧本配置 (Cinematic Lighting Script)
public struct CinematicLightingScript: Sendable {
    public let wallStops: [Color]
    public let floorStops: [Color]
    public let sunlightDiffuse: [Color]
    public let sunlightBeam: [Color]
    public let sunlightCore: [Color]
    public let sunlightStartPoint: UnitPoint
    public let sunlightEndPoint: UnitPoint
    public let sunlightOpacity: Double
    public let thresholdContactShadow: Color
    public let interiorBacklightRamp: [Color]
    public let interiorBacklightCore: [Color]

    public init(
        wallStops: [Color],
        floorStops: [Color],
        sunlightDiffuse: [Color],
        sunlightBeam: [Color],
        sunlightCore: [Color],
        sunlightStartPoint: UnitPoint,
        sunlightEndPoint: UnitPoint,
        sunlightOpacity: Double,
        thresholdContactShadow: Color,
        interiorBacklightRamp: [Color],
        interiorBacklightCore: [Color]
    ) {
        self.wallStops = wallStops
        self.floorStops = floorStops
        self.sunlightDiffuse = sunlightDiffuse
        self.sunlightBeam = sunlightBeam
        self.sunlightCore = sunlightCore
        self.sunlightStartPoint = sunlightStartPoint
        self.sunlightEndPoint = sunlightEndPoint
        self.sunlightOpacity = sunlightOpacity
        self.thresholdContactShadow = thresholdContactShadow
        self.interiorBacklightRamp = interiorBacklightRamp
        self.interiorBacklightCore = interiorBacklightCore
    }
}

// Palette changes are limited to interface surfaces; garden artwork keeps its own colors.
enum HabitColorTheme: String, CaseIterable, Identifiable {
    case original
    case lavender

    static let storageKey = "appearance.colorTheme"
    var id: String { rawValue }
    var title: String { self == .original ? AppLanguage.text("原色") : AppLanguage.text("雾紫") }

    // ==========================================
    // MARK: - 面板 1：背景光球与底色 (Atmosphere & Orbs Panel)
    // ==========================================
    var accent: Color {
        self == .original ? Color(red: 0.93, green: 0.22, blue: 0.65) : Color(red: 0.39, green: 0.23, blue: 0.64)
    }
    var companion: Color {
        self == .original ? Color(red: 1.00, green: 0.57, blue: 0.34) : Color(red: 0.70, green: 0.53, blue: 0.91)
    }

    /// The two bottom-layer background orbs define the shared color sources.
    var largeOrbPalette: [Color] { floatingOrbSpherePalettes.large }
    var smallOrbPalette: [Color] { floatingOrbSpherePalettes.small }
    var largeOrbCenterColor: Color { largeOrbPalette.first ?? accent }
    var smallOrbCenterColor: Color { smallOrbPalette.first ?? companion }

    /// Top-layer floating small orbs sample the centers of the two bottom orbs.
    var floatingSmallOrb1Color: Color { largeOrbCenterColor }
    var floatingSmallOrb2Color: Color { smallOrbCenterColor }

    var floatingOrbSpherePalettes: (large: [Color], small: [Color]) {
        if self == .lavender {
            return (
                [accent, accent.mix(with: companion, by: 0.24), accent.mix(with: companion, by: 0.54)],
                [companion, companion.mix(with: accent, by: 0.20), companion.mix(with: accent, by: 0.52)]
            )
        }
        return (
            [Color(red: 240 / 255, green: 75 / 255, blue: 175 / 255), Color(red: 241 / 255, green: 92 / 255, blue: 180 / 255), Color(red: 246 / 255, green: 155 / 255, blue: 204 / 255)],
            [Color(red: 255 / 255, green: 160 / 255, blue: 108 / 255), Color(red: 255 / 255, green: 177 / 255, blue: 135 / 255), Color(red: 255 / 255, green: 205 / 255, blue: 177 / 255)]
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
        return largeOrbPalette + smallOrbPalette
    }

    // ==========================================
    // MARK: - 面板 3：导航栏专属对比与微呼应 (Navigation Bar Panel)
    // ==========================================
    var selectedNavigationForeground: Color {
        self == .original ? .black : .white
    }
    var unselectedNavigationForeground: Color {
        self == .original ? Color(white: 0.28) : Color(white: 0.84)
    }
    /// 导航栏保持中性液态玻璃材质
    var selectedNavigationBackground: Color {
        self == .original ? Color.white.opacity(0.68) : Color(red: 0.075, green: 0.045, blue: 0.12).opacity(0.46)
    }
    var selectedNavigationBorder: Color {
        self == .original ? Color.white.opacity(0.90) : Color.white.opacity(0.24)
    }
    /// 微弱高光边缘或投影带有 10% 的光球伴随色轻微呼应
    var navigationGlowTint: Color {
        companion.opacity(0.10)
    }
    var deepInk: Color { .black }
    var softSurface: Color { Color(red: 0.91, green: 0.87, blue: 0.96) }
    var canvas: Color { self == .original ? .white : .black }

    // ==========================================
    // MARK: - 面板 4：电影感光影剧本 (Cinematic Lighting Script Panel)
    // ==========================================
    var cinematicLighting: CinematicLightingScript {
        switch self {
        case .original:
            // 暖色调暖：纯正暖阳、琥珀与晨曦金橙光晕
            return CinematicLightingScript(
                wallStops: [
                    Color(red: 0.040, green: 0.040, blue: 0.045),
                    Color(red: 0.025, green: 0.025, blue: 0.028),
                    Color(red: 0.012, green: 0.012, blue: 0.015)
                ],
                floorStops: [
                    Color(red: 0.022, green: 0.022, blue: 0.025),
                    Color(red: 0.010, green: 0.010, blue: 0.012),
                    Color(red: 0.004, green: 0.004, blue: 0.006)
                ],
                sunlightDiffuse: [
                    Color(red: 1.00, green: 0.60, blue: 0.16).opacity(0.75),
                    Color(red: 1.00, green: 0.68, blue: 0.22).opacity(0.46),
                    Color(red: 0.47, green: 0.28, blue: 0.13),
                    Color(red: 0.010, green: 0.010, blue: 0.012)
                ],
                sunlightBeam: [
                    Color(red: 1.00, green: 0.66, blue: 0.18).opacity(0.88),
                    Color(red: 1.00, green: 0.72, blue: 0.26).opacity(0.62),
                    Color(red: 0.50, green: 0.30, blue: 0.13),
                    Color(red: 0.010, green: 0.010, blue: 0.012)
                ],
                sunlightCore: [
                    Color(red: 1.00, green: 0.84, blue: 0.45).opacity(0.95),
                    Color(red: 1.00, green: 0.70, blue: 0.22).opacity(0.76),
                    Color(red: 0.53, green: 0.32, blue: 0.14),
                    Color(red: 0.010, green: 0.010, blue: 0.012)
                ],
                sunlightStartPoint: .topTrailing,
                sunlightEndPoint: .bottomLeading,
                sunlightOpacity: 1.0,
                thresholdContactShadow: Color.black.opacity(0.65),
                interiorBacklightRamp: [
                    Color(red: 1.00, green: 0.90, blue: 0.70),
                    Color(red: 1.00, green: 0.76, blue: 0.38),
                    Color(red: 1.00, green: 0.62, blue: 0.22),
                    Color.clear
                ],
                interiorBacklightCore: [
                    Color(red: 1.00, green: 0.96, blue: 0.85),
                    Color(red: 1.00, green: 0.82, blue: 0.46),
                    Color.clear
                ]
            )
        case .lavender:
            // 冷色调冷：静谧冷淡丁香月白、清幽冷紫与深木冷棕光影
            return CinematicLightingScript(
                wallStops: floatingOrbAtmosphere.gradientStops,
                floorStops: floatingOrbAtmosphere.gradientStops,
                sunlightDiffuse: [
                    Color(red: 0.85, green: 0.75, blue: 1.00).opacity(0.72),
                    Color(red: 0.69, green: 0.52, blue: 0.87).opacity(0.58),
                    Color(red: 0.42, green: 0.28, blue: 0.38),
                    Color(red: 0.060, green: 0.025, blue: 0.040)
                ],
                sunlightBeam: [
                    Color(red: 0.88, green: 0.80, blue: 1.00).opacity(0.85),
                    Color(red: 0.73, green: 0.57, blue: 0.93).opacity(0.70),
                    Color(red: 0.46, green: 0.30, blue: 0.40),
                    Color(red: 0.060, green: 0.025, blue: 0.040)
                ],
                sunlightCore: [
                    Color(red: 0.96, green: 0.90, blue: 1.00).opacity(0.92),
                    Color(red: 0.82, green: 0.68, blue: 0.96).opacity(0.72),
                    Color(red: 0.50, green: 0.34, blue: 0.44),
                    Color(red: 0.060, green: 0.025, blue: 0.040)
                ],
                sunlightStartPoint: UnitPoint(x: 0.5, y: 0.60),
                sunlightEndPoint: UnitPoint(x: 0.5, y: 1.15),
                sunlightOpacity: 0.55,
                thresholdContactShadow: Color(red: 0.075, green: 0.032, blue: 0.040).opacity(0.65),
                interiorBacklightRamp: [
                    Color(red: 0.90, green: 0.84, blue: 1.00),
                    Color(red: 0.78, green: 0.66, blue: 0.94),
                    Color(red: 0.60, green: 0.45, blue: 0.80),
                    Color.clear
                ],
                interiorBacklightCore: [
                    Color(red: 0.95, green: 0.92, blue: 1.00),
                    Color(red: 0.80, green: 0.70, blue: 0.96),
                    Color.clear
                ]
            )
        }
    }

    // ==========================================
    // MARK: - 面板 2：卡片与质感派生 (Cards Panel)
    // ==========================================

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
    @AppStorage("reminder.intro.shown") private var reminderIntroShown = false
    @AppStorage("reminder.permissionIntro.shown") private var permissionIntroShown = false
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
    @State private var themeTransitionImage: UIImage?
    @State private var themeTransitionOrigin: CGPoint = .zero
    @State private var themeTransitionRadius: CGFloat = 0
    @State private var showingReminderIntro = false
    @State private var showingReminderSettings = false
    @State private var showingPermissionIntro = false
    @State private var showingPaywallPreview = false
    @State private var showingCustomCardsModal = false
    @State private var addCardButtonSourceFrame: CGRect = .zero
    @AppStorage("app.mgOnboarding.hasCompleted.v1") private var hasCompletedMGOnboarding = false
    @State private var showMGOnboarding = false

    private let repository: any GoalRepository = SharedHabitRepository()

    var body: some View {
        ZStack {
            TodayAmbientBackground(reduceMotion: reduceMotion, onViewportChange: { backgroundFrame = $0 })
                .ignoresSafeArea()
            TodayRootView(goals: goals, selectedGoals: $selectedGoals, state: $state, tuning: $tuning, reduceMotion: reduceMotion, dashboard: dashboard, showingCustomCardsModal: $showingCustomCardsModal, addCardButtonSourceFrame: $addCardButtonSourceFrame, onConfirm: confirmSelection, onClearData: clearLocalData, onGardenShare: presentGardenPolaroid, onThemeSelect: changeTheme, onReloadGoals: { Task { await reloadGoals() } })
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
            if showMGOnboarding {
                MGOnboardingView(isPresented: Binding(
                    get: { showMGOnboarding },
                    set: { newValue in
                        showMGOnboarding = newValue
                        if !newValue {
                            hasCompletedMGOnboarding = true
                        }
                    }
                ))
                .zIndex(99999)
                .transition(.opacity)
            }
        }
        .environment(\.habitColorTheme, colorTheme)
        .environment(\.habitBackgroundFrame, backgroundFrame)
        .overlay {
            if showingCustomCardsModal {
                LiquidGlassCustomCardsModal(
                    isPresented: $showingCustomCardsModal,
                    sourceFrame: addCardButtonSourceFrame
                ) {
                    Task { await reloadGoals() }
                }
                .ignoresSafeArea(.all)
                .zIndex(1000)
            }
        }
        .overlay {
            if let snapshot = themeTransitionImage {
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .global)
                    Image(uiImage: snapshot)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .mask {
                            ThemeRevealMask(center: CGPoint(x: themeTransitionOrigin.x - frame.minX,
                                                           y: themeTransitionOrigin.y - frame.minY),
                                            radius: themeTransitionRadius)
                                .fill(style: FillStyle(eoFill: true))
                        }
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ReminderManager.openDestination)) { notification in
            state.tab = (notification.object as? String) == "plant" ? .garden : .today
            UserDefaults.standard.removeObject(forKey: "reminder.destination")
        }
        .onReceive(NotificationCenter.default.publisher(for: ICloudSyncManager.dataChanged)) { _ in
            Task { await reloadGoals() }
        }
        .onAppear {
            if !hasCompletedMGOnboarding {
                hasCompletedMGOnboarding = true
                showMGOnboarding = true
            }
            if let destination = UserDefaults.standard.string(forKey: "reminder.destination") {
                state.tab = destination == "plant" ? .garden : .today
                UserDefaults.standard.removeObject(forKey: "reminder.destination")
            }
        }
        .onChange(of: state.mode) { previous, current in
            guard !reminderIntroShown, current == .homeSelected,
                  case let .executing(goalID) = previous,
                  state.completedSelectedGoalIDs.contains(goalID),
                  ReminderManager.shared.hasExactlyOneCompletion() else { return }
            reminderIntroShown = true
            showingReminderIntro = true
        }
        .alert(AppLanguage.text("reminder.intro"), isPresented: $showingReminderIntro) {
            Button(AppLanguage.text("reminder.open")) { showingReminderSettings = true }
            Button(AppLanguage.text("reminder.later"), role: .cancel) { }
        }
        .sheet(isPresented: $showingReminderSettings) { ReminderSettingsView() }
        .sheet(isPresented: $showingPaywallPreview) { SubscriptionPaywallView() }
        .alert(AppLanguage.text("reminder.permission.title"), isPresented: $showingPermissionIntro) {
            Button(AppLanguage.text("reminder.permission.continue")) {
                permissionIntroShown = true
                Task {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                    ReminderManager.shared.refresh()
                }
            }
        } message: {
            Text(AppLanguage.text("reminder.permission.message"))
        }
        .task {
            guard !permissionIntroShown else { return }
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            if status == .notDetermined { showingPermissionIntro = true }
            else { permissionIntroShown = true }
        }
        .alert(AppLanguage.text("操作未完成"), isPresented: Binding(get: { databaseError != nil }, set: { if !$0 { databaseError = nil } })) {
            Button(AppLanguage.text("知道了"), role: .cancel) { databaseError = nil }
        } message: {
            Text(databaseError ?? AppLanguage.text("请稍后重试"))
        }
        .task(id: state.completedSelectedGoalIDs) {
            ReminderManager.shared.refresh()
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
                let newDashboard = try? SharedHabitSelectionStore().dashboard(at: .now)
                if newDashboard != dashboard { dashboard = newDashboard }
                let selectionSnapshot = try? SharedHabitSelectionStore().snapshot(at: .now)
                if let selectionSnapshot {
                    if state.starLimit != selectionSnapshot.starLimit { state.starLimit = selectionSnapshot.starLimit }
                    if state.isFirstSelection != selectionSnapshot.isFirstSelection { state.isFirstSelection = selectionSnapshot.isFirstSelection }
                    if state.completedRegularGoalIDs != selectionSnapshot.completedRegularIDs { state.completedRegularGoalIDs = selectionSnapshot.completedRegularIDs }
                    if state.completedSelectedGoalIDs != selectionSnapshot.completedSelectedIDs { state.completedSelectedGoalIDs = selectionSnapshot.completedSelectedIDs }
                }
                if state.mode != .browsingDeck,
                   let selected = try? await repository.selectedGoalIDs(for: .now) {
                    if state.selectedGoalIDs != selected { state.selectedGoalIDs = selected }
                    if let selectionSnapshot, state.starredGoalIDs != selectionSnapshot.starredIDs { state.starredGoalIDs = selectionSnapshot.starredIDs }
                    if let refreshedSelectedGoals = try? await repository.selectedGoals(for: .now) {
                        if selectedGoals != refreshedSelectedGoals { selectedGoals = refreshedSelectedGoals }
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
                if DevelopmentLaunch.contains("--theme-lavender") {
                    colorTheme = .lavender
                } else if DevelopmentLaunch.contains("--theme-original") {
                    colorTheme = .original
                }
                if goals.isEmpty {
                    state.mode = .homeUnselected
                } else if DevelopmentLaunch.contains("--focus-custom"), let customGoal = goals.first(where: { $0.id.hasPrefix("custom-task:") }) {
                    state.focusedGoalID = customGoal.id
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

    private func changeTheme(_ theme: HabitColorTheme, from point: CGPoint) {
        guard theme != colorTheme, themeTransitionImage == nil else { return }
        guard !reduceMotion,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            colorTheme = theme
            return
        }
        let snapshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        themeTransitionOrigin = point
        themeTransitionRadius = 12
        themeTransitionImage = snapshot
        colorTheme = theme
        let farX = max(point.x, window.bounds.width - point.x)
        let farY = max(point.y, window.bounds.height - point.y)
        let radius = hypot(farX, farY) + 24
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.easeInOut(duration: 0.75)) { themeTransitionRadius = radius }
            try? await Task.sleep(for: .milliseconds(800))
            themeTransitionImage = nil
        }
    }

    private func reloadGoals() async {
        if let refreshed = try? await repository.availableGoals(for: .now) {
            goals = refreshed
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
                ReminderManager.shared.refresh()
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
                case HabitSelectionError.quotaExceeded: databaseError = String(format: AppLanguage.text("当天新建的普通和周期习惯最多 %lld 个。"), 3 + SubscriptionManager.currentExtraDailyHabitsQuota)
                case HabitSelectionError.starLimitExceeded(let limit): databaseError = String(format: AppLanguage.text("当前阶段最多设置 %lld 个星标习惯。"), limit)
                case HabitSelectionError.firstSelectionRequiresGoal: databaseError = AppLanguage.text("首次使用请至少选择一个目标。")
                case HabitSelectionError.invalidStarredSelection: databaseError = AppLanguage.text("星标必须属于已选目标；首次选择暂不能设置星标。")
                case HabitSelectionError.databaseFailure(let message): databaseError = message
                default: databaseError = String(format: AppLanguage.text("数据库未能保存这次选择：%@"), error.localizedDescription)
                }
            }
        }
    }

    private func clearLocalData() {
        Task {
            do {
                #if DEBUG
                try NativeDatabase().clearAllUserData()
                #else
                try NativeDatabase().clearAllUserData(scheduleTrialReset: true)
                #endif
                ReminderManager.shared.refresh()
                ReviewWritingDrafts.removeAll()
                ReviewAICooldown.reset()
                SubscriptionManager.shared.resetQuotasOnDataClear()
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
                databaseError = String(format: AppLanguage.text("清除本地数据失败：%@"), error.localizedDescription)
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
    @Binding var showingCustomCardsModal: Bool
    @Binding var addCardButtonSourceFrame: CGRect
    let onConfirm: () -> Void
    let onClearData: () -> Void
    let onGardenShare: (UIImage) -> Void
    let onThemeSelect: (HabitColorTheme, CGPoint) -> Void
    var onReloadGoals: (() -> Void)? = nil
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
    @State private var showingPaywallPreview = false
    @State private var executionExpansionIsReturning = false
    @State private var expansionID = UUID()
    @State private var selectedReturnButtonRevealTrigger = UUID()
    @State private var homePreviewIsPressed = false
    @State private var homeDeckOpening = false
    @State private var homeDeckGathered = false
    @State private var homeDeckLaunchFrame: CGRect = .zero
    @State private var reviewReceiptPresentation = ReviewReceiptPresentation()
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var viewportSize: CGSize = .zero
    @State private var topSafeInset: CGFloat = 0
    @State private var bottomSafeInset: CGFloat = 0
    @State private var trailingSafeInset: CGFloat = 0
    @State private var leadingSafeInset: CGFloat = 0
    // iPhone Duo 硬件识别与形态判定
    private var isDuoDevice: Bool {
        UIDevice.current.name.contains("Duo")
            || ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?.contains("Duo") == true
            || ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]?.contains("Duo") == true
            || ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] == "iPhone19,4"
            || (trailingSafeInset >= 30 && min(viewportSize.width, viewportSize.height) >= 450)
    }

    private var isLandscape: Bool {
        (viewportSize.width > viewportSize.height && viewportSize.width > 0) || verticalSizeClass == .compact
    }

    /// iPhone Duo 内部展开大屏 (Display 3: 951x669 或 669x951)
    private var isDuoInnerDisplay: Bool {
        isDuoDevice && min(viewportSize.width, viewportSize.height) > 500 && max(viewportSize.width, viewportSize.height) > 750
    }

    /// iPhone Duo 外部折叠屏 (Display 1: 678x466 或 466x678)
    private var isDuoOuterDisplay: Bool {
        isDuoDevice && !isDuoInnerDisplay
    }

    /// iPhone Duo 内部展开横屏
    private var isDuoInnerLandscape: Bool {
        isDuoInnerDisplay && isLandscape
    }

    /// iPhone Duo 外部折叠横屏
    private var isDuoOuterLandscape: Bool {
        isDuoOuterDisplay && isLandscape
    }

    /// 常规紧凑型 iPhone 横屏 (高 < 500 且非 Duo)
    private var isCompactLandscapePhone: Bool {
        !isDuoDevice && isLandscape && viewportSize.height < 500
    }

    /// iPad 设备判定
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// 是否使用右侧竖向侧边栏 (Duo 全形态有侧边栏，或普通 iPhone 横屏)
    private var usesSideNavigation: Bool {
        isCompactLandscapePhone || (isDuoDevice && trailingSafeInset >= 30)
    }

    /// 是否使用横向双栏宽屏布局
    private var usesWideLayout: Bool {
        (isLandscape && (viewportSize.width >= 600 || isDuoDevice)) || isCompactLandscapePhone
    }

    /// 今日页未选择模式下的双栏布局
    private var usesWideHome: Bool {
        usesWideLayout && state.mode == .homeUnselected
    }

    /// 今日页已选择模式下的双栏布局 (Duo 展开与折叠横屏均采用左右双栏，避免纵向溢出切割)
    private var usesWideHomeSelected: Bool {
        usesWideLayout && state.mode == .homeSelected && (isDuoInnerLandscape || isDuoOuterLandscape)
    }

    /// 侧边导航栏垂直对齐方式
    private var sideNavigationAlignment: Alignment {
        if isDuoOuterLandscape {
            // 外屏折叠横屏：垂直居中排放，避开角落摄像头
            return .trailing
        } else if isDuoDevice {
            // 内部展开或其它 Duo 状态：统一放在系统栏右下方竖放
            return .bottomTrailing
        } else {
            return .trailing
        }
    }

    /// 侧边导航栏底部边距
    private var sideNavigationBottomPadding: CGFloat {
        if isDuoOuterLandscape {
            return 0 // 垂直居中无需底部偏移
        } else if isDuoDevice {
            return 44 // 统一右下方放置，避开 Home 指示条
        } else {
            return 16
        }
    }

    // 设置弹窗形变的高阻尼流体弹簧曲线 (Fluid Morph)
    private let fluidMorphAnimation = Animation.spring(response: 0.73, dampingFraction: 0.90, blendDuration: 0.05)
    @State private var settingsPresented = DevelopmentLaunch.contains("--open-settings")
    @State private var settingsProgress: CGFloat = DevelopmentLaunch.contains("--open-settings") ? 1 : 0
    @State private var settingsClosing = false
    @State private var settingsButtonFrame: CGRect = .zero
    @State private var settingsAnimationSource: CGRect = .zero
    @State private var wideCardsFrame: CGRect = .zero
    @State private var navigationFrame: CGRect = .zero

    @ViewBuilder
    private var executingBackgroundGlow: some View {
        if case .executing(let id) = state.mode,
           let goal = selectedGoals.first(where: { $0.id == id }) ?? goals.first(where: { $0.id == id }) {
            GeometryReader { geometry in
                let cardColor = GoalCardAppearance(goal: goal, goals: goals, theme: colorTheme).baseColor
                LinearGradient(stops: [
                    .init(color: cardColor, location: 0),
                    .init(color: cardColor, location: 0.62),
                    .init(color: cardColor.opacity(0.62), location: 0.82),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .frame(height: geometry.size.height / 3 + 88)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .blur(radius: 14)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            executingBackgroundGlow
            // 主内容区域（包含顶部和卡片/页面）
            VStack(spacing: 0) {
                if state.tab == .today && !isExecuting && state.mode != .browsingDeck && !usesWideHome && !usesWideHomeSelected {
                    TodayHeaderView(
                        selectedCount: state.selectedGoalIDs.count,
                        mode: state.mode,
                        tuning: tuning,
                        dashboard: dashboard,
                        pointsOpacity: 1 - Double(activeExecutionExpansionProgress),
                        headerOpacity: 1 - Double(activeExecutionExpansionProgress),
                        titleScale: isDuoDevice ? (isDuoOuterDisplay ? 0.82 : 1.10) : (usesSideNavigation ? 0.76 : 1),
                        compactTop: usesSideNavigation,
                        dateScale: isDuoDevice ? (isDuoOuterDisplay ? 0.80 : 1.05) : (usesSideNavigation ? 0.70 : 1),
                        onAddCustomCard: { showingCustomCardsModal = true }
                    )
                        .padding(.top, isDuoDevice && !isLandscape ? max(topSafeInset + 12, 46) : (usesSideNavigation ? 8 : max(topSafeInset, 14)))
                        .transition(.asymmetric(
                            insertion: .offset(y: -220).combined(with: .opacity),
                            removal: .offset(y: -150).combined(with: .scale(scale: 0.94, anchor: .topLeading)).combined(with: .opacity)
                        ))
                }
                if state.tab != .review && state.tab != .garden && state.mode != .browsingDeck && !isExecuting && !usesWideHome && !usesWideHomeSelected {
                    Spacer(minLength: 16)
                }

                if state.tab == .today {
                    switch state.mode {
                    case .homeUnselected:
                        Group {
                            if usesWideHome {
                                HStack(alignment: .top, spacing: isDuoInnerLandscape ? 32 : (isDuoOuterLandscape ? 18 : (isPad ? 28 : (usesSideNavigation ? 16 : 36)))) {
                                    // 左侧艺术排版：主标题 + 英文格言 + 大号艺术日期
                                    VStack(alignment: .leading, spacing: isDuoInnerLandscape ? 16 : (isDuoOuterLandscape ? 10 : (isPad ? 14 : (usesSideNavigation ? 12 : 24)))) {
                                        VStack(alignment: .leading, spacing: isDuoInnerLandscape ? 14 : (isDuoOuterLandscape ? 8 : (isPad ? 12 : (usesSideNavigation ? 10 : 24)))) {
                                            TodayHeaderView(
                                                selectedCount: state.selectedGoalIDs.count,
                                                mode: state.mode,
                                                tuning: tuning,
                                                dashboard: dashboard,
                                                titleScale: isDuoInnerLandscape ? 1.35 : (isDuoOuterLandscape ? 1.05 : (isCompactLandscapePhone ? 0.72 : (isPad ? 1.25 : 1.30))),
                                                showsBanner: false,
                                                compactTop: true,
                                                showsPoints: false,
                                                showsDate: false,
                                                subtitleScale: isDuoInnerLandscape ? 1.10 : (isDuoOuterLandscape ? 0.92 : (isCompactLandscapePhone ? 0.85 : (isPad ? 1.05 : 1.10)))
                                            )
                                            Text("SMALL STEPS\nA LITTLE EVERY DAY")
                                                .font(.system(size: isDuoInnerLandscape ? 13.5 : (isDuoOuterLandscape ? 11 : (isCompactLandscapePhone ? 12 : (isPad ? 14 : 14))), weight: .semibold, design: .rounded))
                                                .tracking(isDuoInnerLandscape ? 1.6 : (isDuoOuterLandscape ? 1.4 : 1.8))
                                                .lineSpacing(isDuoInnerLandscape ? 2.5 : (isDuoOuterLandscape ? 2 : 3))
                                                .fixedSize(horizontal: false, vertical: true)
                                                .foregroundStyle(.white.opacity(0.72))
                                                .padding(.horizontal, 22)
                                        }
                                        .offset(y: (isDuoInnerLandscape || isDuoOuterLandscape) ? 0 : (isCompactLandscapePhone ? 0 : (isPad ? 12 : 52)))
                                        if !isCompactLandscapePhone { Spacer(minLength: 0) }
                                        WideTodayDateView(size: tuning.dateSize * tuning.textScale * (isDuoInnerLandscape ? 1.25 : (isDuoOuterLandscape ? 0.95 : (isCompactLandscapePhone ? 0.65 : (isPad ? 1.25 : 1.35)))))
                                            .frame(maxWidth: .infinity, alignment: isCompactLandscapePhone ? .leading : .trailing)
                                            .padding(.horizontal, 22)
                                            .padding(.bottom, isDuoInnerLandscape ? 38 : (isDuoOuterLandscape ? 18 : (isCompactLandscapePhone ? 6 : (isPad ? 24 : 12))))
                                        if isCompactLandscapePhone { Spacer(minLength: 0) }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                                    // 右侧区域：顶部状态（积分与通知）+ 下方居中浮动卡片预览组
                                    VStack(spacing: isDuoOuterLandscape ? 6 : 10) {
                                        // 顶部右侧状态条 (积分 + 回顾)
                                        VStack(alignment: .trailing, spacing: isDuoOuterLandscape ? 6 : 8) {
                                            // 积分胶囊（右对齐）
                                            HStack(spacing: 6) {
                                                Image(systemName: "star.fill").foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.38))
                                                Text("\(dashboard?.points ?? 0)")
                                            }
                                            .font(.system(size: isDuoOuterLandscape ? 13 : (isDuoInnerLandscape ? 15 : (isPad ? 16 : 15)), weight: .semibold))
                                            .padding(.horizontal, isDuoOuterLandscape ? 12 : (isPad ? 16 : 14))
                                            .padding(.vertical, isDuoOuterLandscape ? 6 : (isPad ? 8 : 7))
                                            .background(.white.opacity(0.72), in: Capsule())

                                            // 昨天的卡片完成情况通知（放在积分按钮下方，右对齐，卡片更长更从容）
                                            YesterdayReviewBanner(
                                                missedCount: dashboard?.missedYesterday ?? 0,
                                                scale: isDuoOuterLandscape ? 0.82 : (isDuoInnerLandscape ? 0.92 : (isPad ? 0.95 : 0.90))
                                            )
                                            .frame(maxWidth: isDuoInnerLandscape ? 400 : (isDuoOuterLandscape ? 300 : (isPad ? 420 : 380)))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.top, isDuoInnerLandscape ? 48 : (isPad ? 12 : 0))

                                        Spacer(minLength: 4)

                                        // 3 个样式卡片：按右边半屏的尺寸中线居中放置
                                        let deckScale: CGFloat = isDuoInnerLandscape ? 0.96 : (isDuoOuterLandscape ? 0.68 : (isPad ? 0.88 : (isCompactLandscapePhone ? 0.65 : 0.90)))
                                        homePreviewDeck
                                            .scaleEffect(deckScale)
                                            .frame(maxWidth: .infinity, alignment: .center)

                                        Spacer(minLength: isPad ? 80 : 12)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .padding(.top, max(topSafeInset + 18, isDuoInnerLandscape ? 44 : (usesSideNavigation ? 38 : (isPad ? 32 : 28))))
                                .padding(.leading, max(usesSideNavigation ? 16 : (isPad ? 36 : 28), leadingSafeInset + 8))
                                .padding(.trailing, (isDuoInnerLandscape || isDuoOuterLandscape) ? 28 : (usesSideNavigation ? 80 : (isPad ? 40 : 28)))
                                .frame(maxWidth: 1500)
                                .frame(maxHeight: .infinity)
                            } else {
                                homePreviewDeck
                                    .scaleEffect(usesSideNavigation ? 0.78 : (isPad ? 0.90 : 1))
                            }
                        }
                        .transition(reduceMotion ? .opacity : .identity)
                    case .browsingDeck:
                        let colorRangeEndOrder = max(12, goals.map(\.order).max() ?? 12)
                        VStack(spacing: 10) {
                            if !usesSideNavigation { Button(AppLanguage.text("‹ 返回")) { cancelBrowsing() }
                                .font(.system(size: usesWideLayout ? 28 : 16, weight: .medium))
                                .foregroundStyle(colorTheme.card(colorTheme.cardBaseColor(at: 1, count: 2)))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 28)
                            }
                            // A completed habit leaves today's pending deck immediately.
                            // Do not remove its star or periodic selection from storage.
                            TodayStackDeckView(
                                goals: goals.filter { !$0.completedToday && !state.completedSelectedGoalIDs.contains($0.id) },
                                colorRangeEndOrder: colorRangeEndOrder,
                                state: $state,
                                selectionTransitionNamespace: selectionTransitionNamespace,
                                homeLaunchFrame: deckReturnMode == .homeUnselected ? homeDeckLaunchFrame : nil,
                                useCoverFlow: usesWideLayout,
                                compactCardScale: usesSideNavigation ? 0.95 : 1,
                                showingCustomCardsModal: $showingCustomCardsModal,
                                onReloadGoals: {
                                    onReloadGoals?()
                                }
                            )
                        }
                        .frame(maxWidth: usesWideLayout ? 1500 : 680)
                        .frame(maxWidth: .infinity)
                        .transition(reduceMotion ? .opacity : .identity)
                    case .homeSelected:
                        if usesWideHomeSelected {
                            HStack(alignment: .top, spacing: isDuoInnerLandscape ? 32 : 18) {
                                VStack(alignment: .leading, spacing: isDuoInnerLandscape ? 16 : 10) {
                                    VStack(alignment: .leading, spacing: isDuoInnerLandscape ? 14 : 8) {
                                        TodayHeaderView(
                                            selectedCount: state.selectedGoalIDs.count,
                                            mode: state.mode,
                                            tuning: tuning,
                                            dashboard: dashboard,
                                            titleScale: isDuoInnerLandscape ? 1.45 : 1.05,
                                            showsBanner: false,
                                            compactTop: true,
                                            showsPoints: false,
                                            showsDate: false,
                                            subtitleScale: isDuoInnerLandscape ? 1.15 : 0.92
                                        )
                                    }

                                    Spacer(minLength: 0)

                                    WideTodayDateView(size: tuning.dateSize * tuning.textScale * (isDuoInnerLandscape ? 1.35 : 0.95))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.horizontal, 22)
                                        .padding(.bottom, isDuoInnerLandscape ? 38 : 18)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                                VStack(spacing: 12) {
                                    Spacer(minLength: 4)
                                    SelectedGoalView(
                                        goals: selectedGoals,
                                        allGoals: goals,
                                        state: $state,
                                        selectionTransitionNamespace: selectionTransitionNamespace,
                                        hiddenExecutionGoalID: executionExpansionIsReturning ? nil : expandingGoal?.id,
                                        executionExpansionProgress: activeExecutionExpansionProgress,
                                        buttonRevealTrigger: selectedReturnButtonRevealTrigger,
                                        useWideLayout: false,
                                        centerContinueButton: true,
                                        onBrowseGoals: { browseGoals(returningTo: .homeSelected) },
                                        onCardFrame: { selectedExecutionCardFrame = $0 },
                                        onStartGoal: { goal in
                                            startExecution(goal)
                                        }
                                    )
                                    .scaleEffect(isDuoOuterLandscape ? 0.76 : 0.95)
                                    Spacer(minLength: 4)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            }
                            .padding(.top, max(topSafeInset + 18, isDuoInnerLandscape ? 44 : (usesSideNavigation ? 38 : 28)))
                            .padding(.leading, max(16, leadingSafeInset + 8))
                            .padding(.trailing, 28)
                            .frame(maxWidth: 1500)
                            .frame(maxHeight: .infinity)
                            .transition(.identity)
                        } else {
                            SelectedGoalView(
                                goals: selectedGoals,
                                allGoals: goals,
                                state: $state,
                                selectionTransitionNamespace: selectionTransitionNamespace,
                                hiddenExecutionGoalID: executionExpansionIsReturning ? nil : expandingGoal?.id,
                                executionExpansionProgress: activeExecutionExpansionProgress,
                                buttonRevealTrigger: selectedReturnButtonRevealTrigger,
                                useWideLayout: usesWideLayout,
                                centerContinueButton: usesSideNavigation,
                                onBrowseGoals: { browseGoals(returningTo: .homeSelected) },
                                onCardFrame: { selectedExecutionCardFrame = $0 },
                                onStartGoal: { goal in
                                    startExecution(goal)
                                }
                            )
                            .transition(.identity)
                        }
                    case .executing(let id):
                        ExecutionView(
                            goal: selectedGoals.first(where: { $0.id == id }) ?? goals.first(where: { $0.id == id }) ?? goals.first,
                            allGoals: goals,
                            selectedGoals: $selectedGoals,
                            state: $state,
                            sideSystemInset: usesSideNavigation ? trailingSafeInset : 0,
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
                        onSharePhoto: onGardenShare,
                        usesSideNavigation: usesSideNavigation,
                        navigationFrame: navigationFrame
                    )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        ))
                } else if state.tab == .review {
                    ReviewPage(goals: goals, receiptPresentation: reviewReceiptPresentation)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        ))
                }

                if state.tab != .review && state.tab != .garden && state.mode != .browsingDeck && !isExecuting && !usesWideHome {
                    Spacer(minLength: 16)
                }

                // 底部占位高度，确保主内容不被底部胶囊栏遮挡
                if state.tab != .review && state.tab != .garden && !isExecuting {
                    Color.clear.frame(height: usesSideNavigation ? (state.mode == .browsingDeck ? 85 : 8) : (state.mode == .browsingDeck ? 154 : 94))
                }
            }
            // 目标页内容超过可用高度时仍从安全区顶部开始排版，不能因居中布局向上侵入状态栏。
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.trailing, usesSideNavigation ? 12 : 0)
            .offset(x: tuning.contentOffsetX, y: tuning.contentOffsetY)

            if state.tab == .today && state.mode == .browsingDeck {
                ScrollEdgeBlurOverlay(
                    progress: 1,
                    visibility: .bottom,
                    bottomWhiteOpacity: 0.15,
                    bottomVisibleFraction: 0.36,
                    softBottomFade: true
                )
                .ignoresSafeArea(.container, edges: usesSideNavigation ? [.bottom, .trailing] : .bottom)
                .opacity(0.5)
                .allowsHitTesting(false)
                .zIndex(10)
            }

            // 底部确认栏（选卡片时）
            if state.mode == .browsingDeck && state.tab == .today {
                ConfirmSelectionBar(goals: goals, state: state, useWideLayout: usesWideLayout, action: onConfirm)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, usesSideNavigation ? 12 : 0)
                    .padding(.bottom, usesSideNavigation ? 16 : 99)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(30)
            }

            if usesWideLayout && !usesSideNavigation && state.tab == .today && state.mode == .homeSelected && !isExecuting && state.selectedGoalIDs.union(state.completedSelectedGoalIDs).count < 3 {
                GeometryReader { geometry in
                    if wideCardsFrame.height > 0 && navigationFrame.height > 0 {
                        let origin = geometry.frame(in: .global).origin
                        ContinueGoalSelectionButton { browseGoals(returningTo: .homeSelected) }
                            .position(x: geometry.size.width / 2, y: (wideCardsFrame.maxY + navigationFrame.minY) / 2 - origin.y)
                    }
                }
                .zIndex(31)
            }

            // 常驻底部液态导航栏（设置打开时淡化或收纳，其余时刻常驻）
            if state.tab != .settings && !isExecuting {
                Group {
                if usesSideNavigation {
                    TodaySideNavigationView(
                        tab: $state.tab,
                        width: isDuoDevice ? 52 : min(62, max(54, trailingSafeInset > 0 ? trailingSafeInset - 20 : 54)),
                        showsLabels: viewportSize.width >= 600,
                        onOpenSettings: openSettings,
                        onBack: state.tab == .today && state.mode == .browsingDeck ? { cancelBrowsing() } : nil
                    )
                    .padding(.trailing, isDuoDevice ? max(5, (trailingSafeInset - 52) / 2) : max(15, trailingSafeInset))
                    .padding(.bottom, sideNavigationBottomPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: sideNavigationAlignment)
                    .ignoresSafeArea(.container, edges: .trailing)
                } else {
                TodayBottomNavigationView(
                    tab: $state.tab,
                    fluidMorphAnimation: fluidMorphAnimation,
                    sizeScale: usesWideLayout ? 1.18 : 1,
                    onOpenSettings: openSettings
                )
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { navigationFrame = $0 }
                .frame(maxWidth: .infinity, alignment: usesWideHome ? .trailing : .center)
                .padding(.trailing, usesWideHome ? 28 : 0)
                }
                }
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
        .onGeometryChange(for: CGSize.self) { $0.size } action: {
            if abs($0.width - viewportSize.width) > 1 || abs($0.height - viewportSize.height) > 1 {
                viewportSize = $0
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: {
            if abs($0 - topSafeInset) > 1 {
                topSafeInset = $0
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: {
            if abs($0 - bottomSafeInset) > 1 {
                bottomSafeInset = $0
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.trailing } action: {
            if abs($0 - trailingSafeInset) > 1 {
                trailingSafeInset = $0
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.leading } action: {
            if abs($0 - leadingSafeInset) > 1 {
                leadingSafeInset = $0
            }
        }
        .onPreferenceChange(SettingsButtonFrameKey.self) { frame in
            guard frame.width > 0 else { return }
            let dx = abs(frame.minX - settingsButtonFrame.minX)
            let dy = abs(frame.minY - settingsButtonFrame.minY)
            let dw = abs(frame.width - settingsButtonFrame.width)
            let dh = abs(frame.height - settingsButtonFrame.height)
            if dx > 1 || dy > 1 || dw > 1 || dh > 1 {
                settingsButtonFrame = frame
                if !settingsPresented {
                    settingsAnimationSource = frame
                }
            }
        }
        .overlay {
            GeometryReader { geometry in
                if settingsPresented {
                    let origin = geometry.frame(in: .global).origin
                    let activeSource = settingsButtonFrame.width > 0 ? settingsButtonFrame : settingsAnimationSource
                    let source = activeSource.offsetBy(dx: -origin.x, dy: -origin.y)
                    if usesSideNavigation {
                        let sideBarWidth: CGFloat = isDuoDevice ? 72 : (trailingSafeInset > 0 ? trailingSafeInset + 54 : 76)
                        let panelTop: CGFloat = max(24, topSafeInset + 8)
                        let compactDestination = CGRect(
                            x: max(16, leadingSafeInset + 8),
                            y: panelTop,
                            width: max(1, geometry.size.width - max(16, leadingSafeInset + 8) - sideBarWidth),
                            height: max(1, geometry.size.height - panelTop - max(20, bottomSafeInset + 12))
                        )
                        FluidSettingsExpandedPanel(
                            fluidMorphAnimation: fluidMorphAnimation,
                            onDismiss: closeSettings,
                            onClearData: clearDataFromSettings,
                            onThemeSelect: onThemeSelect,
                            allowsDragToDismiss: false
                        )
                        .modifier(SettingsPanelMorph(progress: settingsProgress, source: source, destination: compactDestination))
                        .task {
                            try? await Task.sleep(for: .milliseconds(20))
                            guard !Task.isCancelled, !settingsClosing else { return }
                            withAnimation(fluidMorphAnimation) { settingsProgress = 1 }
                        }
                    } else {
                        let sideInset = max(16, (geometry.size.width - min(460, geometry.size.width - 32)) / 2)
                        let panelTop: CGFloat = max(54, topSafeInset + 12)
                        let panelBottom = max(24, geometry.size.height - source.minY + 6)
                        let destination = CGRect(
                            x: sideInset,
                            y: panelTop,
                            width: max(1, geometry.size.width - sideInset * 2),
                            height: max(1, geometry.size.height - panelTop - panelBottom)
                        )
                        FluidSettingsExpandedPanel(
                            fluidMorphAnimation: fluidMorphAnimation,
                            onDismiss: closeSettings,
                            onClearData: clearDataFromSettings,
                            onThemeSelect: onThemeSelect
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
            }
            .ignoresSafeArea(.all)
            .allowsHitTesting(settingsPresented && !settingsClosing)
        }
        .onPreferenceChange(SelectedExecutionCardFrameKey.self) { frame in
            if frame.width > 0 { selectedExecutionCardFrame = frame }
        }
        .onPreferenceChange(WideSelectedCardsFrameKey.self) { frame in
            if frame.height > 0 { wideCardsFrame = frame }
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
                Text(AppLanguage.text(executionToast))
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
        .overlay {
            ReviewReceiptOverlay(presentation: reviewReceiptPresentation)
        }
        .sheet(isPresented: $showingPaywallPreview) { SubscriptionPaywallView() }
        .onPreferenceChange(AddCardButtonSourceFrameKey.self) { frame in
            guard frame.width > 0 else { return }
            let dx = abs(frame.minX - addCardButtonSourceFrame.minX)
            let dy = abs(frame.minY - addCardButtonSourceFrame.minY)
            let dw = abs(frame.width - addCardButtonSourceFrame.width)
            let dh = abs(frame.height - addCardButtonSourceFrame.height)
            if dx > 1 || dy > 1 || dw > 1 || dh > 1 {
                addCardButtonSourceFrame = frame
            }
        }
        .statusBarHidden(reviewReceiptPresentation.isActive)
        .task {
            #if DEBUG
            if DevelopmentLaunch.contains("-review-receipt-preview") || DevelopmentLaunch.contains("--review-receipt-landed") || DevelopmentLaunch.contains("--review-tab") {
                state.tab = .review
            }
            if DevelopmentLaunch.contains("--garden-tab") {
                state.tab = .garden
            }
            if DevelopmentLaunch.contains("--today-tab") {
                state.tab = .today
            }
            if ProcessInfo.processInfo.arguments.contains("-paywall-preview") {
                showingPaywallPreview = true
            }
            if ProcessInfo.processInfo.arguments.contains("--open-custom-cards") {
                state.tab = .today
                state.mode = .browsingDeck
                showingCustomCardsModal = true
            }
            if DevelopmentLaunch.contains("--open-browsing") {
                state.tab = .today
                state.mode = .browsingDeck
            }
            #endif
        }
        .animation(expandingGoal == nil ? (reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.62, dampingFraction: 0.82, blendDuration: 0.14)) : nil, value: state.mode)
    }

    private var homePreviewDeck: some View {
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
            }, perform: { openHomeDeck() })
            .allowsHitTesting(!homeDeckOpening)
            .sensoryFeedback(.impact(weight: .light), trigger: homePreviewIsPressed) { _, pressed in pressed }
    }

    // Completion and early timer exits can return without the card morph.
    // A retained progress of 1 must never hide the stable Today screen.
    private var activeExecutionExpansionProgress: CGFloat {
        expandingGoal == nil ? 0 : expansionProgress
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
            let hasCardArtwork = goal.cardArtworkAsset != nil || goal.resolvedFloraType != nil
            let target = CGRect(
                origin: .zero,
                size: CGSize(
                    width: geometry.size.width,
                    height: hasCardArtwork ? geometry.size.height / 3 : geometry.size.height
                )
            )
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
            let startArtworkWidth = start.width * 2.1875
            let targetArtworkWidth = geometry.size.width * 2.10
            let artworkWidth = startArtworkWidth + (targetArtworkWidth - startArtworkWidth) * progress
            let textX = start.minX + 20 + (24 - start.minX - 20) * progress
            let textWidth = start.width - 40 + (target.width - 48 - start.width + 40) * progress
            let titleY = start.minY + 49 + (safeTop + 28 - start.minY - 49) * progress
            let titleInk = Color.white.opacity(0.82 - 0.07 * Double(progress))
            let summaryInk = Color.white.opacity(1 - 0.25 * Double(progress))

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .top) {
                    // Keep the moving card's own surface solid while the cards
                    // behind it fade with the same transition progress.
                    tint
                    LinearGradient(stops: [
                        .init(color: .white.opacity(0.14), location: 0),
                        .init(color: .white.opacity(0.06), location: 0.48),
                        .init(color: .clear, location: 1)
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
                .overlay {
                    if hasCardArtwork {
                        GoalCardArtwork(goal: goal, widthScale: artworkWidth / max(width, 1))
                            .clipShape(shape)
                    }
                }
                .mask {
                    if hasCardArtwork {
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.68),
                                .init(color: .white.opacity(1 - progress), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.white
                    }
                }
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
                    Text(AppLanguage.text(goal.previewTitle))
                        .font(.system(size: 42 + 18 * progress, weight: .semibold, design: .rounded))
                        .tracking(-1.8)
                        .foregroundStyle(titleInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(minHeight: 88 * (1 - progress), alignment: .topLeading)
                    Text(AppLanguage.text(goal.previewSummary))
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
        if settingsPresented {
            closeSettings()
            return
        }
        guard settingsButtonFrame.width > 0 else { return }
        settingsAnimationSource = settingsButtonFrame
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
        let x = source.minX + (destination.minX - source.minX) * horizontalPhase
        let y = source.minY + (destination.minY - source.minY) * verticalPhase
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
            .position(x: x + width / 2, y: y + height / 2)
    }

    private func smoothPhase(_ value: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        let phase = min(1, max(0, (value - start) / (end - start)))
        return phase * phase * (3 - 2 * phase)
    }
}

private struct ThemeRevealMask: Shape {
    var center: CGPoint
    var radius: CGFloat
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2))
        return path
    }
}

private struct PrivacyPolicyReadingView: View {
    @Environment(\.dismiss) private var dismiss
    var embedded = false

    private var paragraphs: [String] {
        AppLanguage.text("privacy.policy.body").components(separatedBy: "\n\n").filter { !$0.isEmpty }
    }

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }

    private var content: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(paragraphs.first ?? AppLanguage.text("privacy.policy.title"))
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Color(red: 0.25, green: 0.19, blue: 0.29))
                        .padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 25) {
                        ForEach(Array(paragraphs.dropFirst().enumerated()), id: \.offset) { _, paragraph in
                            section(paragraph)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .textSelection(.enabled)
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 22)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity)
            }
            .background(Color(red: 0.97, green: 0.96, blue: 0.98))
            .navigationTitle(AppLanguage.text("privacy.policy.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppLanguage.text("privacy.policy.done")) { dismiss() }
                    }
                }
            }
    }

    @ViewBuilder private func section(_ paragraph: String) -> some View {
        if let separator = paragraph.firstIndex(where: { $0 == "：" || $0 == ":" }),
           paragraph.distance(from: paragraph.startIndex, to: separator) < 40 {
            VStack(alignment: .leading, spacing: 9) {
                Text(String(paragraph[..<separator]))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color(red: 0.36, green: 0.27, blue: 0.42))
                Text(String(paragraph[paragraph.index(after: separator)...]).trimmingCharacters(in: .whitespaces))
                    .font(.body)
                    .foregroundStyle(Color(red: 0.25, green: 0.23, blue: 0.28))
                    .lineSpacing(5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(paragraph)
                .font(.body)
                .foregroundStyle(Color(red: 0.25, green: 0.23, blue: 0.28))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 设置专属流体形变展开面板 (Fluid Settings Panel with Interactive Pull-Down Dismiss)
private struct FluidSettingsExpandedPanel: View {
    @AppStorage("review.ai.privacy-consent.v5") private var hasAIPrivacyConsent = false
    @AppStorage(AppLanguage.storageKey) private var language = "system"
    @AppStorage(HabitColorTheme.storageKey) private var colorTheme = HabitColorTheme.original
    @AppStorage(AppSoundSettings.storageKey) private var soundEffectsEnabled = true
    let fluidMorphAnimation: Animation
    let onDismiss: () -> Void
    let onClearData: () -> Void
    let onThemeSelect: (HabitColorTheme, CGPoint) -> Void
    var allowsDragToDismiss = true

    @State private var themeCircleFrames: [HabitColorTheme: CGRect] = [:]
    @State private var dragOffsetY: CGFloat = 0
    @State private var showingClearConfirmation = false
    @State private var pendingLanguage = "system"
    @State private var showingPrivacyPolicy = false
    @State private var showingReminders = false
    @State private var showingPaywall = false
    @State private var exportItem: LocalExportItem?
    @State private var exportFailed = false
    @State private var showingAbout = false
    @State private var showingHelp = false
    @State private var showingMGOnboarding = false
    @State private var mailUnavailable = false
    @ObservedObject private var subscription = SubscriptionManager.shared
    @ObservedObject private var iCloudSync = ICloudSyncManager.shared

    private func settingsUtilityLabel(_ key: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
            Text(AppLanguage.text(key))
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(Color(red: 0.36, green: 0.30, blue: 0.40))
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(.white.opacity(0.58), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.75), lineWidth: 0.8))
        .contentShape(Capsule())
    }

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
            .contentShape(Rectangle())
            .gesture(settingsDismissGesture, including: allowsDragToDismiss ? .all : .none)

            ScrollView {
            VStack(alignment: .leading, spacing: allowsDragToDismiss ? 12 : 6) {
                Text(AppLanguage.text("设置"))
                    .font(.system(size: allowsDragToDismiss ? 30 : 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))

                Text(AppLanguage.text("习惯记录和积分保存在此设备。"))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color(red: 0.32, green: 0.28, blue: 0.33).opacity(0.72))

                Picker(AppLanguage.text("语言"), selection: $pendingLanguage) {
                    Text("中文").tag("zh-Hans")
                    Text("English").tag("en-US")
                    Text("日本語").tag("ja")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.language")

                Button {
                    language = pendingLanguage
                    NotificationCenter.default.post(name: AppLanguage.didApply, object: pendingLanguage)
                } label: {
                    Label(AppLanguage.text("应用语言并刷新"), systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, allowsDragToDismiss ? 12 : 8)
                        .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.applyLanguage")

                Button { showingMGOnboarding = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(red: 0.88, green: 0.32, blue: 0.58))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(supportText("重温动画引导", "Replay Onboarding Tour", "アニメーションガイドを見る"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))
                            Text(supportText("极简视觉指南 · 了解习惯养成与花盘", "Visual motion guide to habit loop", "習慣の育成と花園のビジュアルガイド"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(red: 0.32, green: 0.28, blue: 0.33).opacity(0.68))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.42, green: 0.38, blue: 0.45).opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, allowsDragToDismiss ? 12 : 8)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color(red: 0.98, green: 0.94, blue: 0.98).opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: allowsDragToDismiss ? 12 : 6) {
                    Text(AppLanguage.text("界面配色"))
                        .font(.system(size: 16, weight: .semibold))
                    HStack(spacing: 12) {
                        ForEach(HabitColorTheme.allCases) { theme in
                            Button {
                                let frame = themeCircleFrames[theme] ?? .zero
                                onThemeSelect(theme, CGPoint(x: frame.midX, y: frame.midY))
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(LinearGradient(colors: [theme.accent, theme.companion], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 24, height: 24)
                                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                                        action: { themeCircleFrames[theme] = $0 }
                                    Text(AppLanguage.text(theme.title))
                                    Spacer(minLength: 0)
                                    Image(systemName: colorTheme == theme ? "checkmark.circle.fill" : "circle")
                                }
                                .font(.system(size: 15, weight: .medium))
                                .padding(allowsDragToDismiss ? 12 : 8)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(.white.opacity(colorTheme == theme ? 0.75 : 0.35), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(colorTheme == theme ? .isSelected : [])
                            .accessibilityIdentifier("theme." + theme.rawValue)
                        }
                    }
                }
                .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))

                VStack(alignment: .leading, spacing: allowsDragToDismiss ? 10 : 6) {
                    Text(AppLanguage.text("声音反馈"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))
                    HStack(spacing: 12) {
                        Image(systemName: soundEffectsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color(red: 0.49, green: 0.34, blue: 0.53))
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppLanguage.text("总体音效"))
                                .font(.system(size: 15, weight: .semibold))
                            Text(AppLanguage.text("打字、打印与完成提示"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(red: 0.32, green: 0.28, blue: 0.33).opacity(0.68))
                        }
                        Spacer(minLength: 8)
                        Toggle(AppLanguage.text("总体音效"), isOn: $soundEffectsEnabled)
                            .labelsHidden()
                            .tint(Color(red: 0.62, green: 0.39, blue: 0.70))
                            .accessibilityIdentifier("settings.soundEffects")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, allowsDragToDismiss ? 12 : 7)
                    .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button { showingPaywall = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(red: 0.90, green: 0.65, blue: 0.28))
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(AppLanguage.text("会员计划"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))
                                Text(AppLanguage.text(subscription.currentTier.badge))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(subscription.currentTier != .free ? Color.white : Color(red: 0.52, green: 0.36, blue: 0.62))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(
                                        subscription.currentTier != .free
                                            ? Color(red: 0.52, green: 0.36, blue: 0.62)
                                            : Color(red: 0.52, green: 0.36, blue: 0.62).opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                            Text(subscription.currentTier != .free ? String(format: AppLanguage.text("生效中：%@ · 管理会员"), AppLanguage.text(subscription.currentTier.title)) : AppLanguage.text("解锁更多自定义卡片、全庭院与持续复盘"))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color(red: 0.42, green: 0.38, blue: 0.45))
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.42, green: 0.38, blue: 0.45).opacity(0.6))
                    }
                    .padding(allowsDragToDismiss ? 13 : 9)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.72),
                                Color(red: 0.97, green: 0.94, blue: 0.98).opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
                    )
                }
                .buttonStyle(SettingsPressButtonStyle())
                .accessibilityIdentifier("settings.subscription")

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { iCloudSync.isEnabled },
                        set: { iCloudSync.setEnabled($0, membership: subscription.currentTier) }
                    )) {
                        Label(AppLanguage.text("sync.title"), systemImage: "icloud.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .disabled(subscription.currentTier == .free && !iCloudSync.isEnabled)
                    .accessibilityIdentifier("settings.iCloudSync")

                    let status = iCloudSync.detail
                    if !status.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: iCloudSync.state == .needsAttention ? "exclamationmark.triangle" : "icloud")
                                .font(.system(size: 12, weight: .semibold))
                            Text(AppLanguage.text(status))
                                .font(.system(size: 12, weight: .regular))
                            Spacer(minLength: 0)
                            if iCloudSync.state == .unavailable || iCloudSync.state == .needsAttention {
                                Button(AppLanguage.text("sync.retry")) {
                                    iCloudSync.requestSync(membership: subscription.currentTier)
                                }
                                .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .foregroundStyle(Color(red: 0.42, green: 0.38, blue: 0.45))
                    } else if subscription.currentTier == .free {
                        Text(AppLanguage.text("sync.membershipHint"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(red: 0.42, green: 0.38, blue: 0.45))
                    }
                }
                .padding(allowsDragToDismiss ? 14 : 9)
                .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button { showingReminders = true } label: {
                    Label(AppLanguage.text("reminder.title"), systemImage: "bell")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(allowsDragToDismiss ? 14 : 9)
                        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SettingsPressButtonStyle())
                .accessibilityIdentifier("settings.reminders")

                ForEach(SettingsSupportEntry.allCases) { entry in
                    Button {
                        switch entry {
                        case .feedback: openFeedback()
                        case .about: showingAbout = true
                        case .help: showingHelp = true
                        }
                    } label: {
                        HStack {
                            Label(entry.title, systemImage: entry.icon)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        }
                        .font(.system(size: 15, weight: .medium))
                        .padding(allowsDragToDismiss ? 14 : 9)
                        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(SettingsPressButtonStyle())
                    .accessibilityIdentifier("settings." + entry.rawValue)
                }

                HStack(spacing: 8) {
                    Button { showingPrivacyPolicy = true } label: {
                        settingsUtilityLabel("privacy.policy.title", icon: "hand.raised")
                    }
                    .accessibilityIdentifier("settings.privacyPolicy")

                    Button {
                        do { exportItem = LocalExportItem(url: try LocalRecordExport.createFile()) }
                        catch { exportFailed = true }
                    } label: {
                        settingsUtilityLabel("export.action", icon: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("settings.export")

                    Spacer(minLength: 0)
                }
                .buttonStyle(SettingsPressButtonStyle())

                if hasAIPrivacyConsent {
                    Button(AppLanguage.text("撤回 AI 复盘同意")) { hasAIPrivacyConsent = false }
                        .accessibilityIdentifier("settings.revokeAIConsent")
                }

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label(AppLanguage.text("清除本地数据并重新开始"), systemImage: "trash")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(allowsDragToDismiss ? 14 : 9)
                        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .tint(Color(red: 0.62, green: 0.20, blue: 0.28))
                .buttonStyle(SettingsPressButtonStyle())

            }
            .padding(.horizontal, 24)
            .padding(.top, allowsDragToDismiss ? 14 : 6)
            .padding(.bottom, 64)
            .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 底部关闭返回胶囊（与原胶囊位置呼应）
            Button {
                dismissSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text(AppLanguage.text("收起设置"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.26, green: 0.22, blue: 0.27))
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .background(.white.opacity(0.68), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.85), lineWidth: 1.2))
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAbout) { SettingsInformationView(isHelp: false) }
        .sheet(isPresented: $showingHelp) { SettingsInformationView(isHelp: true) }
        .alert(supportText("无法打开邮件应用", "Unable to open a mail app", "メールアプリを開けません"), isPresented: $mailUnavailable) {
            Button(AppLanguage.text("知道了"), role: .cancel) {}
        } message: {
            Text(supportText("请先安装或设置邮件应用，或手动发送至 deshiru@foxmail.com。", "Set up a mail app, or email deshiru@foxmail.com.", "メールアプリを設定するか、deshiru@foxmail.com に送信してください。"))
        }
        .sheet(isPresented: $showingPaywall) { SubscriptionPaywallView() }
        .sheet(isPresented: $showingReminders) { ReminderSettingsView() }
        .sheet(item: $exportItem) { LocalExportShareSheet(item: $0) }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyReadingView()
        }
        .onAppear { pendingLanguage = AppLanguage.resolve(language) }
        .alert(AppLanguage.text("export.failed"), isPresented: $exportFailed) {
            Button(AppLanguage.text("知道了"), role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showingMGOnboarding) {
            MGOnboardingView(isPresented: $showingMGOnboarding)
        }
        .scaleEffect(interactiveScale, anchor: .bottom)
        .offset(y: effectiveDragOffset)
        .alert(AppLanguage.text("清除本地数据？"), isPresented: $showingClearConfirmation) {
            Button(AppLanguage.text("取消"), role: .cancel) {}
            Button(AppLanguage.text("清除并重新开始"), role: .destructive, action: confirmClearLocalData)
        } message: {
            Text(AppLanguage.text("这会删除已选习惯、打卡记录、复盘、计时记录和积分，并回到首次选择页面。此操作无法撤销。"))
        }
    }

    private var settingsDismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in dragOffsetY = max(0, value.translation.height) }
            .onEnded { value in
                let shouldDismiss = value.translation.height > 110 || (value.velocity.height > 300 && value.translation.height > 40)
                if shouldDismiss { dismissSettings() }
                else { withAnimation(fluidMorphAnimation) { dragOffsetY = 0 } }
            }
    }

    private func openFeedback() {
        let info = Bundle.main.infoDictionary ?? [:]
        var system = utsname()
        uname(&system)
        let machineSize = MemoryLayout.size(ofValue: system.machine)
        let model = withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: machineSize) { String(cString: $0) }
        }
        let name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? "MAYBII"
        let version = (info["CFBundleShortVersionString"] as? String) ?? "—"
        let build = (info["CFBundleVersion"] as? String) ?? "—"
        let components = FeedbackDraft.components(language: AppLanguage.current, appName: name, version: version, build: build, model: model, system: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)", bundleID: Bundle.main.bundleIdentifier ?? "—")
        guard let url = components.url else { mailUnavailable = true; return }
        UIApplication.shared.open(url) { success in
            if !success { mailUnavailable = true }
        }
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
            Text(AppLanguage.text(title)).font(.system(size: 38, weight: .medium))
            Text(AppLanguage.text(subtitle)).font(.system(size: 15, weight: .medium)).opacity(0.72)
            if tab == .garden {
                ForEach(goals.prefix(3)) { goal in
                    HStack {
                        Text(AppLanguage.text(goal.title)).font(.system(size: 17, weight: .semibold))
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

    private var title: String { tab == .garden ? AppLanguage.text("养成物") : tab == .review ? AppLanguage.text("复盘") : AppLanguage.text("设置") }
    private var subtitle: String { tab == .garden ? AppLanguage.text("看见习惯完成后留下的成长。") : tab == .review ? AppLanguage.text("只读回看每天的习惯完成和记录。") : AppLanguage.text("管理你的习惯 App。") }
}

private struct GoalDeckView: View {
    let goals: [Goal]
    @Binding var state: TodayGoalState
    @AppStorage(AppSoundSettings.storageKey) private var soundEffectsEnabled = true
    @State private var cardMovementSound = AppSoundFeedback()

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
                        Text(AppLanguage.text("返回"))
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.29))
                }

                Spacer()

                Text(AppLanguage.text("选择今天的习惯"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))

                Spacer()

                Text(AppLanguage.text("上下翻阅"))
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
                Button(AppLanguage.text("↑ 上一张")) { move(-1) }
                Button(AppLanguage.text("下一张 ↓")) { move(1) }
            }.buttonStyle(.bordered)
        }.padding(.top, 10)
    }

    private func move(_ delta: Int) {
        guard !goals.isEmpty else { return }
        let next = (focus + delta + goals.count) % goals.count
        cardMovementSound.play(.navigation, enabled: soundEffectsEnabled)
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
                Text(AppLanguage.text(goal.title)).font(.system(size: 29, weight: .medium)).foregroundStyle(.white)
                Text(AppLanguage.text(goal.category).uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.4).foregroundStyle(.white.opacity(0.76))
                Text(AppLanguage.text(goal.summary)).font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.86))
                Spacer()
                Text(selected ? AppLanguage.text("已选择 · 右滑取消") : AppLanguage.text("右滑选择此目标")).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            }
        }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 26).fill(colorTheme.card(goal.cardBaseColor(in: goals, theme: colorTheme)).opacity(goal.tint.opacity + (expanded ? 0.18 : 0.05))))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.62)))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
    }
}

private struct ConfirmSelectionBar: View {
    @AppStorage(AppSoundSettings.storageKey) private var soundEffectsEnabled = true
    @State private var confirmationSound = AppSoundFeedback()
    let goals: [Goal]
    let state: TodayGoalState
    var useWideLayout = false
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
                Text(String(format: AppLanguage.text("当天新建 %lld/3 · 星标 %lld/%lld"), regularCount, state.starredGoalIDs.count, state.starLimit))
                    .font(.system(size: useWideLayout ? 17.85 : 12, weight: .semibold))
                Text(state.isFirstSelection ? AppLanguage.text("首日周期计名额 · 首次确认后可设星标") : AppLanguage.text("点星标可额外选 · 周期次日保留"))
                    .font(.system(size: useWideLayout ? 16.3625 : 11))
            }
            .foregroundStyle(Color(red: 0.27, green: 0.23, blue: 0.29))
            Spacer(minLength: 4)
            Button(AppLanguage.text("确认选择")) {
                confirmationSound.play(.gardenSelect, enabled: soundEffectsEnabled)
                action()
            }
                .buttonStyle(ConfirmPressStyle(fontSize: useWideLayout ? 24.5 : 14))
                .disabled(state.isFirstSelection && state.selectedGoalIDs.isEmpty)
                .opacity(state.isFirstSelection && state.selectedGoalIDs.isEmpty ? 0.42 : 1)
        }
        .padding(.horizontal, 14).frame(height: useWideLayout ? 90 : 66)
        .background(.white.opacity(0.32), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.66), lineWidth: 1))
        .padding(.horizontal, 22).padding(.bottom, 6)
    }
}

private struct ConfirmPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var fontSize: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
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
            .accessibilityLabel(AppLanguage.text("星标习惯"))
    }
}

private struct SelectedExecutionCardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0 { value = next }
    }
}

private struct WideGoalCardFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct WideSelectedCardsFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.height > 0 { value = next }
    }
}

private struct ContinueGoalSelectionButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(AppLanguage.text("继续选择今天的目标"), systemImage: "square.stack.3d.up")
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(Color(red: 0.27, green: 0.23, blue: 0.29))
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(.white.opacity(0.72), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.86), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint(AppLanguage.text("打开卡片集，添加今天的目标"))
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
    let hiddenExecutionGoalID: String?
    let executionExpansionProgress: CGFloat
    let buttonRevealTrigger: UUID
    var useWideLayout = false
    var centerContinueButton = false
    let onBrowseGoals: () -> Void
    let onCardFrame: (CGRect) -> Void
    let onStartGoal: (Goal) -> Void
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSoundSettings.storageKey) private var soundEffectsEnabled = true
    @GestureState private var dragX: CGFloat = 0
    @State private var cardSwitchSound = AppSoundFeedback()
    @State private var departingGoal: Goal?
    @State private var departingOffsetX: CGFloat = 0
    @State private var stackStep = 1
    @State private var startDeckScale: CGFloat = 1
    @State private var startDeckAnimationID = UUID()
    @State private var returnButtonExpansion: CGFloat = 1
    @State private var returnButtonTitleOpacity: Double = 1
    @State private var returnButtonSheenEnabled = true
    @State private var returnButtonRevealTaskID = UUID()
    @State private var wideCardFrames: [String: CGRect] = [:]

    private var selected: [Goal] { goals.filter { state.selectedGoalIDs.contains($0.id) } }
    private var activeIndex: Int { selected.isEmpty ? 0 : state.homeSelectedIndex % selected.count }
    private var deckSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.55, dampingFraction: 0.68, blendDuration: 0.08)
    }

    var body: some View {
        VStack(spacing: 18) {
            if !selected.isEmpty {
                if useWideLayout { wideSelectedDeck } else { selectedDeck }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(AppLanguage.text("今日目标已全部完成"))
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(AppLanguage.text(state.selectedGoalIDs.union(state.completedSelectedGoalIDs).count < 3
                         ? "已完成的习惯已从待做卡片中移除，可继续选择今天的目标。"
                         : "已完成的习惯已从待做卡片中移除。"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            }
            if (!useWideLayout || centerContinueButton) && state.selectedGoalIDs.union(state.completedSelectedGoalIDs).count < 3 {
                ContinueGoalSelectionButton(action: onBrowseGoals)
                .frame(maxWidth: .infinity, alignment: centerContinueButton ? .center : .trailing)
            }
        }
        .padding(.horizontal, 24)
        // Keep cards and their actions readable in wide or resizable windows.
        .frame(maxWidth: useWideLayout ? 1200 : 480)
        .frame(maxWidth: .infinity)
        .onChange(of: buttonRevealTrigger) { _, _ in
            revealStartButtonAfterReturn()
        }
        .onPreferenceChange(WideGoalCardFramesKey.self) { wideCardFrames = $0 }
    }

    private var wideSelectedDeck: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 16
            let columns = max(1, min(selected.count, 4))
            let cardWidth = min(300, max(100, (geometry.size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(Array(selected.enumerated()), id: \.element.id) { index, goal in
                        PreviewGoalCard(goal: goal, paletteGoals: allGoals, theme: colorTheme, index: index + 1, surfaceOpacity: 1, isPrimary: true, textScale: 1.15, showsContent: true)
                            .frame(width: cardWidth, height: 270)
                            .background {
                                GeometryReader { cardGeometry in
                                    Color.clear.preference(key: WideGoalCardFramesKey.self, value: [goal.id: cardGeometry.frame(in: .global)])
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if goal.isStarred { StarredGoalBadge().padding(12) }
                            }
                            .overlay(alignment: .bottom) {
                                Button(goal.completedToday ? AppLanguage.text("今日已完成") : AppLanguage.text("开始目标")) {
                                    onCardFrame(wideCardFrames[goal.id] ?? .zero)
                                    onStartGoal(goal)
                                }
                                    .buttonStyle(LiquidGlassGoalButtonStyle())
                                    .frame(width: max(80, cardWidth - 48))
                                    .disabled(goal.completedToday)
                                    .opacity(goal.completedToday ? 0.64 : 0.70)
                                    .padding(.bottom, 22)
                            }
                    }
                }
                .frame(minWidth: geometry.size.width, alignment: .center)
            }
        }
        .frame(height: 270)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: WideSelectedCardsFrameKey.self, value: geometry.frame(in: .global))
            }
        }
        .offset(y: -55)
    }

    private var selectedDeck: some View {
        GeometryReader { proxy in
            let visibleCount = min(3, selected.count)
            let progress = min(1, abs(dragX) / 170)
            let cardWidth = max(1, proxy.size.width - 12)
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
                    let isBottom = depth == visibleCount - 1
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
                                .accessibilityLabel(AppLanguage.text("星标习惯"))
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
                                Text(goal.completedToday ? AppLanguage.text("今日已完成") : AppLanguage.text("开始目标"))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .opacity(returnButtonTitleOpacity)
                                    .offset(y: (1 - returnButtonTitleOpacity) * 5)
                            }
                            .buttonStyle(LiquidGlassGoalButtonStyle(sheenEnabled: returnButtonSheenEnabled))
                            .frame(width: max(116, 50 + ((cardWidth - 40) * 0.5 - 50) * returnButtonExpansion))
                            .disabled(goal.completedToday || startDeckScale != 1)
                            .opacity(goal.completedToday ? 0.64 : 0.70)
                            .padding(.bottom, 41)
                            .accessibilityHint(AppLanguage.text("开始当前目标"))
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
                            .opacity((isFront ? 0.17 : (depth == 1 ? 0.11 : 0.07)) + (isBottom ? 0 : 0.04)),
                        radius: (isFront ? 16 : (depth == 1 ? 12 : 9)) + (isBottom ? 0 : 4),
                        y: isFront ? 10 : (depth == 1 ? 7 : 5)
                    )
                    .shadow(color: .black.opacity((isFront ? 0.035 : 0.02) + (isBottom ? 0 : 0.008)), radius: isBottom ? 3 : 4.5, y: 2)
                    // The expansion overlay takes ownership of the front card at
                    // the same frame. Hide this source so it cannot remain as a
                    // translucent duplicate while the overlay moves away.
                    .opacity(goal.id == hiddenExecutionGoalID ? 0 : 1)
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
                        Button(AppLanguage.text("开始目标")) {}
                            .buttonStyle(LiquidGlassGoalButtonStyle())
                            .frame(width: (cardWidth - 40) * 0.5)
                            .opacity(0.70)
                            .padding(.bottom, 41)
                            .allowsHitTesting(false)
                    }
                    .compositingGroup()
                    .rotationEffect(.degrees(Double(-departingOffsetX / 50)))
                    .offset(x: departingOffsetX)
                    .shadow(color: Color(red: 0.42, green: 0.16, blue: 0.30).opacity(visibleCount > 1 ? 0.21 : 0.17), radius: visibleCount > 1 ? 20 : 16, y: 10)
                    .shadow(color: .black.opacity(visibleCount > 1 ? 0.043 : 0.035), radius: visibleCount > 1 ? 4.5 : 3, y: 2)
                    .zIndex(100)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(1 - executionExpansionProgress)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityHint(AppLanguage.text("向左或向右滑动切换今日目标"))
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
        cardSwitchSound.play(.navigation, enabled: soundEffectsEnabled)
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
        cardSwitchSound.play(.goalStartClick, enabled: soundEffectsEnabled)
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
        cardSwitchSound.play(.navigation, enabled: soundEffectsEnabled)
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
    @Environment(\.locale) private var locale
    @Environment(\.habitColorTheme) private var colorTheme
    let selectedCount: Int
    var mode: TodayMode = .homeUnselected
    var tuning: UITuningState = UITuningState()
    let dashboard: HabitDashboardSnapshot?
    var pointsOpacity: Double = 1
    var headerOpacity: Double = 1
    var titleScale: CGFloat = 1
    var showsBanner = true
    var compactTop = false
    var showsPoints = true
    var dateScale: CGFloat = 1
    var showsDate = true
    var subtitleScale: CGFloat = 1
    var onAddCustomCard: (() -> Void)? = nil

    private var headerTitle: String {
        mode == .homeSelected ? AppLanguage.text("已选择\n今天的\n目标") : AppLanguage.text("选择\n今天的\n目标")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部艺术化排版：大号换行标题 + 右侧大号艺术日期
            HStack(alignment: .top, spacing: 8) {
                // 左侧主标题
                Text(headerTitle)
                    .font(.system(size: tuning.titleSize * tuning.textScale * titleScale, weight: .medium))
                    .tracking(-0.6)
                    .lineSpacing(-8)
                    .foregroundStyle(colorTheme == .lavender ? Color.white : Color(red: 0.22, green: 0.20, blue: 0.24))
                    .shadow(color: colorTheme == .lavender ? .black.opacity(0.52) : .clear, radius: 1.5, y: 1)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(headerOpacity)

                Spacer(minLength: 4)

                // 右侧大号艺术日期 (实时同步当前日期，调大字号使上下跨度与左侧标题等高)
                if showsDate { VStack(alignment: .trailing, spacing: -8) {
                    Text(dayString)
                        .font(.system(size: tuning.dateSize * tuning.textScale * dateScale, weight: .regular))
                        .tracking(-3.0)
                    Text(monthString)
                        .font(.system(size: tuning.dateSize * tuning.textScale * dateScale, weight: .regular))
                        .tracking(-4.5)
                }
                .foregroundStyle(.white.opacity(colorTheme == .lavender ? 0.98 : 0.82))
                .shadow(color: colorTheme == .lavender ? .black.opacity(0.52) : .clear, radius: 1.5, y: 1)
                .fixedSize(horizontal: true, vertical: false)
                .opacity(headerOpacity)
                }
            }

            // 中间行：副标题与右侧积分胶囊垂直居中对齐
            HStack(alignment: .center, spacing: 10) {
                Text(AppLanguage.text("萌芽小习惯，重启新人生。"))
                    .font(.system(size: 17 * subtitleScale, weight: .medium))
                    .foregroundStyle(colorTheme == .lavender ? Color.white.opacity(0.95) : Color.white.opacity(0.72))
                    .shadow(color: colorTheme == .lavender ? .black.opacity(0.52) : .clear, radius: 1, y: 1)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(headerOpacity)

                Spacer(minLength: 8)

                // 积分展示按钮（右对齐，与上方月份边缘对齐，且与左侧副标垂直居中）
                if showsPoints {
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
                    .opacity(pointsOpacity)
                }
            }

            // 昨天的回顾提示位（保持柔和淡粉底色与清晰呼吸空间）
            if mode == .homeUnselected && showsBanner {
                YesterdayReviewBanner(missedCount: dashboard?.missedYesterday ?? 0)
                    .padding(.top, tuning.bannerPaddingTop)
                    .opacity(headerOpacity)
            }
        }
        .padding(.horizontal, 22)
        // 页面背景延伸到状态栏，但内容必须从 Dynamic Island / 时间下方开始。
        .padding(.top, compactTop ? 28 : (mode == .homeSelected ? 24 : 64))
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateFormat = "d"
        return formatter.string(from: .now)
    }

    private var monthString: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateFormat = "MMM"
        return formatter.string(from: .now).uppercased(with: AppLanguage.locale)
    }
}

private struct WideTodayDateView: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let size: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: -8) {
            Text(dayString)
                .tracking(-3)
            Text(AppLanguage.date(.now, template: "MMM").uppercased(with: AppLanguage.locale))
                .tracking(-4.5)
        }
        .font(.system(size: size, weight: .regular))
        .foregroundStyle(.white.opacity(colorTheme == .lavender ? 0.98 : 0.82))
        .shadow(color: colorTheme == .lavender ? .black.opacity(0.52) : .clear, radius: 1.5, y: 1)
        .fixedSize()
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateFormat = "d"
        return formatter.string(from: .now)
    }
}

private struct YesterdayReviewBanner: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let missedCount: Int
    var scale: CGFloat = 1
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(missedCount == 0 ? AppLanguage.text("昨天没有未完成的习惯记录。") : String(format: AppLanguage.text("昨天有 %lld 个习惯未完成，已记入日历。未完成不直接扣分；连续7天没有完成才会进入休眠与衰减。"), missedCount))
                .font(.system(size: 13.5 * scale, weight: .medium))
                .lineSpacing(4)
                .foregroundStyle(Color(red: 0.36, green: 0.26, blue: 0.28))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14 * scale)
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

    private var title: String { AppLanguage.text("轻触卡片，\n选择今日目标") }
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

    private func previewCardShadow(upperIndex: Int, lowerIndex: Int, opacity: Double) -> some View {
        let upperPose = poses[upperIndex]
        let offset = shadowOffset(from: upperIndex, onto: lowerIndex)
        return RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.black.opacity(opacity))
            .frame(width: upperPose.width, height: tuning.cardHeight)
            .blur(radius: CGFloat(upperIndex == 0 ? 4 : 7))
            .rotationEffect(.degrees(cardRotation(upperIndex) - cardRotation(lowerIndex)))
            .offset(x: offset.width, y: offset.height)
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
                                if index == 2 {
                                    previewCardShadow(upperIndex: 0, lowerIndex: index, opacity: 0.15)
                                    // Partially knock out the overlap so the lighter first-card shadow remains visible.
                                    previewCardShadow(upperIndex: 1, lowerIndex: index, opacity: 0.30)
                                        .blendMode(.destinationOut)
                                    previewCardShadow(upperIndex: 1, lowerIndex: index, opacity: 0.30)
                                } else {
                                    previewCardShadow(upperIndex: 0, lowerIndex: index, opacity: 0.30)
                                }
                            }
                            .compositingGroup()
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
        .accessibilityLabel(AppLanguage.text("三张虚拟引导卡"))
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

    private var artworkGoal: Goal? {
        guard let goalID = appearance?.goalID else { return nil }
        return paletteGoals?.first(where: { $0.id == goalID })
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
            Text(AppLanguage.text(title))
                    .font(.system(size: (isPrimary ? 25 : 21) * textScale, weight: .semibold))
                    .tracking(-0.77)
                    .foregroundStyle(textColor.opacity(colorTheme == .lavender ? (usesSelectedDeckLayout ? 0.96 : (isPrimary ? 0.92 : 0.80)) : (usesSelectedDeckLayout ? 0.82 : (isPrimary ? 0.69 : 0.34))))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .frame(maxWidth: .infinity, minHeight: usesSelectedDeckLayout ? 88 : 0, alignment: .topLeading)
            Text(AppLanguage.text(summary))
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
                tint: cardTintColor
            )
                .overlay {
                    if let artworkGoal, artworkGoal.cardArtworkAsset != nil || artworkGoal.resolvedFloraType != nil {
                        GoalCardArtwork(goal: artworkGoal, widthScale: 2.1875, floats: usesSelectedDeckLayout && isPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }
                }
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
                .opacity(usesSelectedDeckLayout && !isPrimary ? 0.95 : 1)
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
            Text(AppLanguage.text("昨天有 3 个习惯未完成，已记入日历。"))
                .font(.system(size: 17.5, weight: .medium))
            Text(AppLanguage.text("今天，从一个小小的目标开始。"))
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.29).opacity(0.78))
        .multilineTextAlignment(.center)
    }
}

private struct TodaySideNavigationView: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Binding var tab: AppTab
    let width: CGFloat
    let showsLabels: Bool
    let onOpenSettings: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: showsLabels ? 12 : 3) {
                ForEach([AppTab.today, .garden, .review], id: \.self) { item in
                    Button { tab = item } label: {
                        VStack(spacing: 2) {
                        PrototypeIcon(kind: item == .today ? .home : (item == .garden ? .leaf : .review), isEmphasized: tab == item)
                        .frame(width: 25, height: 25)
                        if showsLabels {
                            Text(item == .today ? AppLanguage.text("今天") : (item == .garden ? AppLanguage.text("养成物") : AppLanguage.text("复盘")))
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        }
                        .foregroundStyle(tab == item ? colorTheme.selectedNavigationForeground : colorTheme.unselectedNavigationForeground)
                        .frame(width: width - 10, height: 52)
                        .background(tab == item ? Color.white.opacity(0.28) : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item == .today ? AppLanguage.text("今天") : (item == .garden ? AppLanguage.text("养成物") : AppLanguage.text("复盘")))
                }
            }
            .padding(5)
            .glassEffect(.clear, in: Capsule())

            Button(action: onOpenSettings) {
                PrototypeIcon(kind: .settings, isEmphasized: true)
                    .frame(width: 25, height: 25)
                    .frame(width: width - 10, height: width - 10)
            }
            .buttonStyle(.glass(.regular))
            .buttonBorderShape(.circle)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: SettingsButtonFrameKey.self, value: geometry.frame(in: .global))
                }
            }
            .accessibilityLabel(AppLanguage.text("设置"))
            .padding(.top, 14)

            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 21, weight: .semibold))
                        .frame(width: width - 10, height: width - 10)
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.circle)
                .accessibilityLabel(AppLanguage.text("返回"))
            }
        }
        .environment(\.colorScheme, colorTheme == .lavender ? .dark : .light)
    }
}

private struct TodayBottomNavigationView: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Binding var tab: AppTab
    @AppStorage(AppSoundSettings.storageKey) private var soundEffectsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedIndex: Double = 0
    @State private var navigationSound = AppSoundFeedback()
    let fluidMorphAnimation: Animation
    var sizeScale: CGFloat = 1
    let onOpenSettings: () -> Void

    var body: some View {
        LiveOpticalNavigationHost {
            navigationContent
                .environment(\.habitColorTheme, colorTheme)
                .environment(\.colorScheme, colorTheme == .lavender ? .dark : .light)
        }
        .frame(height: 60 * sizeScale)
        .frame(maxWidth: 520 * sizeScale)
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
    }

    private var navigationContent: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    GeometryReader { geometry in
                        FluidOpticalSelectionView(
                            progress: animatedIndex,
                            itemWidth: geometry.size.width / 3,
                            totalHeight: geometry.size.height,
                            reduceMotion: reduceMotion
                        )
                        .allowsHitTesting(false)
                    }
                    HStack(spacing: 0) {
                        ForEach([AppTab.today, .garden, .review], id: \.self) { itemTab in
                            Button {
                                switchTab(to: itemTab)
                            } label: {
                                NavigationItem(
                                    symbol: itemTab == .today ? "house" : (itemTab == .garden ? "leaf" : "list.bullet"),
                                    title: itemTab == .garden ? AppLanguage.text("养成物") : (itemTab == .review ? AppLanguage.text("复盘") : AppLanguage.text("今天")),
                                    selected: tab == itemTab,
                                    sizeScale: sizeScale
                                )
                            }
                            .buttonStyle(NavigationOpticalButtonStyle())
                        }
                    }
                    .padding(5)
                }
                .environment(\.colorScheme, colorTheme == .lavender ? .dark : .light)
                .frame(maxWidth: .infinity)
                .frame(height: 60 * sizeScale)
                .glassEffect(.clear, in: Capsule())
                .onAppear { animatedIndex = tabIndex }
                .onChange(of: tab) { _, _ in
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.62, dampingFraction: 0.86)) {
                        animatedIndex = tabIndex
                    }
                }

                // The circular action shares the system Regular glass material.
                Button {
                    navigationSound.play(.settingsTap, enabled: soundEffectsEnabled)
                    onOpenSettings()
                } label: {
                    PrototypeIcon(kind: .settings, isEmphasized: true)
                        .frame(width: 21 * sizeScale, height: 21 * sizeScale)
                        .frame(width: 46 * sizeScale, height: 46 * sizeScale)
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.circle)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: SettingsButtonFrameKey.self, value: geometry.frame(in: .global))
                    }
                }
                .accessibilityLabel(AppLanguage.text("设置"))
            }
        }
        .environment(\.colorScheme, colorTheme == .lavender ? .dark : .light)
    }

    private var tabIndex: Double {
        index(for: tab)
    }

    private func index(for tab: AppTab) -> Double {
        switch tab {
        case .today: 0
        case .garden: 1
        case .review: 2
        case .settings: animatedIndex
        }
    }

    private func switchTab(to newTab: AppTab) {
        guard tab != newTab else { return }
        let soundKind: AppSoundFeedback.Kind = switch newTab {
        case .today: .navigationToday
        case .garden: .navigationGarden
        case .review: .navigationReview
        case .settings: .navigation
        }
        navigationSound.play(soundKind, enabled: soundEffectsEnabled)
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.62, dampingFraction: 0.86)) {
            tab = newTab
        }
    }
}

/// Original navigation capsule geometry and continuous slider deformation.
private struct FluidOpticalSelectionView: View, Animatable {
    var progress: Double
    let itemWidth: CGFloat
    let totalHeight: CGFloat
    let reduceMotion: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        SavedOpticalNavigationSurface()
            .frame(width: itemWidth - 4, height: totalHeight - 4)
            .offset(x: CGFloat(progress) * itemWidth + 2, y: 2)
    }
}

private struct NavigationItem: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectionBounce = false
    let symbol: String
    let title: String
    let selected: Bool
    var sizeScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 3) {
            PrototypeIcon(kind: iconKind, isEmphasized: selected)
                .frame(width: 20 * sizeScale, height: 20 * sizeScale)
                .scaleEffect(selectionBounce ? 0.82 : (selected ? 1.08 : 0.95))
            Text(AppLanguage.text(title))
                .font(.system(size: 11 * sizeScale, weight: selected ? .semibold : .medium))
        }
        .foregroundStyle(selected
            ? colorTheme.selectedNavigationForeground
            : colorTheme.unselectedNavigationForeground
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selected)
        .onChange(of: selected) { _, isSelected in
            guard isSelected, !reduceMotion else { return }
            withAnimation(.spring(response: 0.16, dampingFraction: 0.56)) {
                selectionBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.54)) {
                    selectionBounce = false
                }
            }
        }
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

private struct NavigationOpticalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1 - 0.117 : 1)
            .animation(.spring(duration: 0.65, bounce: 0.143), value: configuration.isPressed)
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
            let color = isEmphasized ? colorTheme.selectedNavigationForeground : colorTheme.unselectedNavigationForeground

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

// Decorative surfaces use the root viewport; content keeps its own safe-area layout.
private struct FullViewportSurface: ViewModifier {
    @Environment(\.habitBackgroundFrame) private var viewport

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let local = proxy.frame(in: .global)
            let bounds = viewport.isEmpty ? local : viewport
            content
                .frame(width: bounds.width, height: bounds.height)
                .offset(x: bounds.minX - local.minX, y: bounds.minY - local.minY)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func fullViewportSurface() -> some View { modifier(FullViewportSurface()) }
}

// 今日、养成物和复盘共用的连续流体背景。
struct TodayAmbientBackground: View {
    let reduceMotion: Bool
    var onViewportChange: ((CGRect) -> Void)? = nil

    var body: some View {
        GeometryReader { viewport in
            LiquidBackgroundView(reduceMotion: reduceMotion)
            .onGeometryChange(for: CGRect.self) { _ in viewport.frame(in: .global) } action: { frame in
                onViewportChange?(frame)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview { ContentView() }

private func supportText(_ zh: String, _ en: String, _ ja: String) -> String {
    switch AppLanguage.current {
    case "zh-Hans": return zh
    case "ja": return ja
    default: return en
    }
}

private enum SettingsSupportEntry: String, CaseIterable, Identifiable {
    case feedback, about, help
    var id: String { rawValue }
    var title: String {
        switch self {
        case .feedback: return supportText("意见反馈", "Feedback", "フィードバック")
        case .about: return supportText("关于", "About", "このアプリについて")
        case .help: return supportText("帮助文档", "Help", "ヘルプ")
        }
    }
    var icon: String {
        switch self {
        case .feedback: return "envelope"
        case .about: return "info.circle"
        case .help: return "questionmark.circle"
        }
    }
}

private struct SettingsInformationView: View {
    @Environment(\.dismiss) private var dismiss
    let isHelp: Bool

    private var aboutItems: [String] {
        [supportText("联系我们", "Contact us", "お問い合わせ"),
         supportText("通义千问", "Qwen", "通義千問"),
         supportText("用户协议", "Terms of use", "利用規約"),
         supportText("隐私政策", "Privacy policy", "プライバシーポリシー"),
         supportText("官网", "Official website", "公式サイト")]
    }

    private var helpItems: [(String, String)] { SettingsHelpContent.items }

    var body: some View {
        NavigationStack {
            List {
                if isHelp {
                    ForEach(helpItems.indices, id: \.self) { index in
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(SettingsHelpContent.paragraphs(helpItems[index].1).enumerated()), id: \.offset) { _, paragraph in
                                    Text(paragraph)
                                        .font(.body)
                                        .tracking(0.3)
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .combine)
                        } header: {
                            Text(helpItems[index].0).font(.headline).textCase(nil)
                        }
                    }
                } else {
                    NavigationLink(aboutItems[0]) {
                        List {
                            Section {
                                Link("deshiru@foxmail.com", destination: URL(string: "mailto:deshiru@foxmail.com")!)
                            } header: { Text(supportText("邮箱", "Email", "メール")) }
                            Section {
                                Link("小红书 · ddream", destination: URL(string: "http://xhslink.com/m/7poXFQmQhhG")!)
                                Link("X · @ddream023", destination: URL(string: "https://x.com/ddream023")!)
                                Link("Reddit · u/That-Wave241oukin", destination: URL(string: "https://www.reddit.com/user/That-Wave241oukin/")!)
                            } header: { Text(supportText("社交媒体", "Social media", "SNS")) }
                        }.navigationTitle(aboutItems[0]).navigationBarTitleDisplayMode(.inline)
                    }
                    NavigationLink(aboutItems[1]) {
                        List {
                            Text(supportText("MAYBII 的 AI 复盘使用阿里云百炼的通义千问模型。", "MAYBII uses Alibaba Cloud Model Studio's Qwen model for AI Review.", "MAYBIIのAI振り返りにはAlibaba Cloud Model Studioの通義千問モデルを使用しています。"))
                            Link(supportText("在维基百科了解通义千问", "Read about Qwen on Wikipedia", "Wikipediaで通義千問を見る"), destination: URL(string: AppLanguage.current == "en-US" ? "https://en.wikipedia.org/wiki/Qwen" : "https://zh.wikipedia.org/wiki/%E9%80%9A%E4%B9%89%E5%8D%83%E9%97%AE")!)
                        }.navigationTitle(aboutItems[1]).navigationBarTitleDisplayMode(.inline)
                    }
                    NavigationLink(aboutItems[2]) {
                        List {
                            Text(supportText("订阅使用条款", "Subscription terms", "サブスクリプション利用条件")).font(.headline)
                            Text(supportText("MAYBII 提供月度和年度自动续订会员。购买费用由 Apple 收取。订阅会自动续订；你可以在 iPhone 设置中的 Apple 账户 → 订阅里管理或取消。取消后，权益持续到当前周期结束。本地记录不会因订阅结束而删除。", "MAYBII offers monthly and annual auto-renewing subscriptions. Apple charges your account. Subscriptions renew automatically; manage or cancel them under your Apple Account → Subscriptions in iPhone Settings. Benefits continue until the current period ends. Local records are not deleted when a subscription ends.", "MAYBIIは月額および年額の自動更新サブスクリプションを提供します。料金はAppleが請求します。iPhoneの設定のAppleアカウント → サブスクリプションから管理・解約できます。特典は現在の期間の終了まで利用でき、解約しても端末内の記録は削除されません。"))
                            Text(supportText("完整用户协议待补充。", "Full terms of use will be added later.", "利用規約の全文は後日追加します。")).foregroundStyle(.secondary)
                        }.navigationTitle(aboutItems[2]).navigationBarTitleDisplayMode(.inline)
                    }
                    NavigationLink(aboutItems[3]) { PrivacyPolicyReadingView(embedded: true) }
                    NavigationLink(aboutItems[4]) {
                        List {
                            Link("maybii.pages.dev", destination: URL(string: "https://maybii.pages.dev/")!)
                        }.navigationTitle(aboutItems[4]).navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .navigationTitle(isHelp ? SettingsSupportEntry.help.title : SettingsSupportEntry.about.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(supportText("完成", "Done", "完了")) { dismiss() } } }
        }
    }
}
