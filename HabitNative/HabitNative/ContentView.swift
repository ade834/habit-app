import SwiftUI

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state = TodayGoalState()
    @State private var goals: [Goal] = []
    @State private var databaseError: String?
    @State private var dashboard: HabitDashboardSnapshot?
    @State private var tuning = UITuningState.load()

    private let repository: any GoalRepository = SharedHabitRepository()

    var body: some View {
        ZStack {
            TodayAmbientBackground(reduceMotion: reduceMotion)
                .ignoresSafeArea()
            TodayRootView(goals: goals, state: $state, tuning: $tuning, reduceMotion: reduceMotion, dashboard: dashboard, onConfirm: confirmSelection)
        }
        .alert("无法保存今日选择", isPresented: Binding(get: { databaseError != nil }, set: { if !$0 { databaseError = nil } })) {
            Button("知道了", role: .cancel) { databaseError = nil }
        } message: {
            Text(databaseError ?? "请稍后重试")
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
                }
                if state.mode != .browsingDeck,
                   let selected = try? await repository.selectedGoalIDs(for: .now) {
                    state.selectedGoalIDs = selected
                    if let selectionSnapshot { state.starredGoalIDs = selectionSnapshot.starredIDs }
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

    private func confirmSelection() {
        Task {
            do {
                let date = Date()
                let requestedIDs = state.selectedGoalIDs
                let requestedStars = state.starredGoalIDs
                try await repository.saveSelectedGoalIDs(requestedIDs, starredIDs: requestedStars, for: date)
                let persisted = try SharedHabitSelectionStore().snapshot(at: date)
                guard persisted.activeIDs.union(persisted.starredIDs) == requestedIDs,
                      persisted.starredIDs == requestedStars else {
                    throw HabitSelectionError.databaseFailure("保存后重新读取的选择与页面不一致，请重试。")
                }
                goals = try await repository.availableGoals(for: date)
                state.selectedGoalIDs = persisted.activeIDs.union(persisted.starredIDs)
                state.starredGoalIDs = persisted.starredIDs
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
}

private struct TodayRootView: View {
    let goals: [Goal]
    @Binding var state: TodayGoalState
    @Binding var tuning: UITuningState
    let reduceMotion: Bool
    let dashboard: HabitDashboardSnapshot?
    let onConfirm: () -> Void
    @Namespace private var navMorphNamespace
    @Namespace private var selectionTransitionNamespace

    // 设置弹窗形变的高阻尼流体弹簧曲线 (Fluid Morph)
    private let fluidMorphAnimation = Animation.spring(response: 0.52, dampingFraction: 0.84, blendDuration: 0.2)

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域（包含顶部和卡片/页面）
            VStack(spacing: 0) {
                if state.tab == .today && !isExecuting && state.mode != .browsingDeck {
                    TodayHeaderView(selectedCount: state.selectedGoalIDs.count, mode: state.mode, tuning: tuning, dashboard: dashboard)
                        .transition(.asymmetric(
                            insertion: .offset(y: -220).combined(with: .opacity),
                            removal: .offset(y: -150).combined(with: .scale(scale: 0.94, anchor: .topLeading)).combined(with: .opacity)
                        ))
                }
                if state.mode != .browsingDeck { Spacer(minLength: 16) }

                if state.tab == .today {
                    switch state.mode {
                    case .homeUnselected:
                        VStack(spacing: 12) {
                            HomePreviewDeckView(tuning: tuning, reduceMotion: reduceMotion)
                                .offset(y: tuning.cardOffsetY)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                        state.mode = .browsingDeck
                                        state.focusedGoalID = goals.first?.id ?? "H6"
                                    }
                                }

                            // 三个卡片下方提示
                            HomeSelectionHint()
                                .offset(y: tuning.cardOffsetY + 28)
                        }
                    case .browsingDeck:
                        VStack(spacing: 10) {
                            Button("‹ 返回") { withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) { state.mode = .homeUnselected } }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 0.27, green: 0.23, blue: 0.29))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 28)
                            TodayStackDeckView(goals: goals, state: $state, selectionTransitionNamespace: selectionTransitionNamespace)
                        }
                    case .homeSelected:
                        SelectedGoalView(goals: goals, state: $state, selectionTransitionNamespace: selectionTransitionNamespace)
                    case .executing(let id):
                        ExecutionView(
                            goal: goals.first(where: { $0.id == id }) ?? goals.first,
                            state: $state,
                            selectionTransitionNamespace: selectionTransitionNamespace
                        )
                    }
                } else if state.tab == .garden {
                    GrowthView(goals: goals)
                        .padding(.bottom, 84)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        ))
                } else if state.tab == .review {
                    AppTabPage(tab: state.tab, goals: goals, state: $state)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        ))
                }

                if state.mode != .browsingDeck { Spacer(minLength: 16) }

                // 底部占位高度，确保主内容不被底部胶囊栏遮挡
                Color.clear.frame(height: state.mode == .browsingDeck ? 154 : 94)
            }
            // 目标页内容超过可用高度时仍从安全区顶部开始排版，不能因居中布局向上侵入状态栏。
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(x: tuning.contentOffsetX, y: tuning.contentOffsetY)

            // 底部确认栏（选卡片时）
            if state.mode == .browsingDeck && state.tab == .today {
                ConfirmSelectionBar(goals: goals, state: state, action: onConfirm)
                    .padding(.bottom, 99)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 常驻底部液态导航栏（设置打开时淡化或收纳，其余时刻常驻）
            if state.tab != .settings {
                TodayBottomNavigationView(
                    tab: $state.tab,
                    fluidMorphAnimation: fluidMorphAnimation,
                    namespace: navMorphNamespace
                )
                .scaleEffect(tuning.navigationScale, anchor: .bottom)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                    removal: .opacity
                ))
            } else {
                // 仅点击「设置」时，从右下角圆形按钮流体展开为全屏浮层面板
                FluidSettingsExpandedPanel(
                    tab: $state.tab,
                    fluidMorphAnimation: fluidMorphAnimation,
                    namespace: navMorphNamespace
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92, anchor: .bottomTrailing).combined(with: .opacity),
                    removal: .scale(scale: 0.90, anchor: .bottomTrailing).combined(with: .opacity)
                ))
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.62, dampingFraction: 0.82, blendDuration: 0.14), value: state.mode)
    }

    private var isExecuting: Bool {
        if case .executing = state.mode { return true }
        return false
    }
}

// MARK: - 设置专属流体形变展开面板 (Fluid Settings Panel with Interactive Pull-Down Dismiss)
private struct FluidSettingsExpandedPanel: View {
    @Binding var tab: AppTab
    let fluidMorphAnimation: Animation
    let namespace: Namespace.ID

    @State private var dragOffsetY: CGFloat = 0

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
            // 顶端下拉指示胶囊条 & 关闭按钮
            HStack {
                Capsule()
                    .fill(Color(red: 0.30, green: 0.26, blue: 0.31).opacity(0.28))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Button {
                    withAnimation(fluidMorphAnimation) {
                        tab = .today
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(red: 0.30, green: 0.26, blue: 0.31).opacity(0.65))
                }
                .padding(.trailing, 20)
                .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 20) {
                Text("设置")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))

                Text("管理你的习惯应用偏好与系统选项。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 0.32, green: 0.28, blue: 0.33).opacity(0.72))

                VStack(spacing: 12) {
                    HStack {
                        Label("通知与提醒", systemImage: "bell.badge")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).opacity(0.4)
                    }
                    .padding(18)
                    .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))

                    HStack {
                        Label("触感反馈与音效", systemImage: "waveform")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).opacity(0.4)
                    }
                    .padding(18)
                    .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))

                    HStack {
                        Label("数据与 iCloud 备份", systemImage: "icloud")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).opacity(0.4)
                    }
                    .padding(18)
                    .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.26, green: 0.22, blue: 0.27))


                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // 底部关闭返回胶囊（与原胶囊位置呼应）
            Button {
                withAnimation(fluidMorphAnimation) { tab = .today }
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
        .background {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.92),
                                    .white.opacity(0.4),
                                    .white.opacity(0.15),
                                    .white.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.14), radius: 24, y: -6)
        }
        .scaleEffect(interactiveScale, anchor: .bottom)
        .offset(y: effectiveDragOffset)
        .matchedGeometryEffect(id: "settingsMorphButton", in: namespace)
        .padding(.horizontal, 10)
        .padding(.top, 54)
        .padding(.bottom, 12)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    dragOffsetY = value.translation.height
                }
                .onEnded { value in
                    // 速度较快或下拉超过 110pt 时执行随拉随放弹回收起
                    let shouldDismiss = value.translation.height > 110 || (value.velocity.height > 300 && value.translation.height > 40)
                    if shouldDismiss {
                        withAnimation(fluidMorphAnimation) {
                            tab = .today
                        }
                    } else {
                        // 未达到阈值，随拉随放平滑弹回原位
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 24)) {
                            dragOffsetY = 0
                        }
                    }
                }
        )
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
                    DeckCard(goal: goal, index: index + 1, expanded: distance == 0, selected: state.selectedGoalIDs.contains(goal.id))
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
    let goal: Goal; let index: Int; let expanded: Bool; let selected: Bool
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
        .background(RoundedRectangle(cornerRadius: 26).fill(Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue).opacity(goal.tint.opacity + (expanded ? 0.18 : 0.05))))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.62)))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
    }
}

private struct ConfirmSelectionBar: View {
    let goals: [Goal]
    let state: TodayGoalState
    let action: () -> Void
    private var regularCount: Int {
        goals.filter { state.selectedGoalIDs.contains($0.id) && !state.starredGoalIDs.contains($0.id) && $0.countsTowardQuota }.count
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

private struct SelectedGoalView: View {
    let goals: [Goal]
    @Binding var state: TodayGoalState
    let selectionTransitionNamespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragX: CGFloat = 0
    @State private var departingGoal: Goal?
    @State private var departingOffsetX: CGFloat = 0
    @State private var departingOpacity: Double = 1

    private var selected: [Goal] { goals.filter { state.selectedGoalIDs.contains($0.id) } }
    private var activeIndex: Int { selected.isEmpty ? 0 : state.homeSelectedIndex % selected.count }
    private var deckSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.46, dampingFraction: 0.72, blendDuration: 0.12)
    }

    var body: some View {
        Group {
            if !selected.isEmpty {
                selectedDeck
            }
        }
        .padding(.horizontal, 24)
    }

    private var selectedDeck: some View {
        GeometryReader { proxy in
            let visibleCount = min(3, selected.count)
            let progress = min(1, abs(dragX) / 170)

            ZStack {
                ForEach(Array((0..<visibleCount).reversed()), id: \.self) { depth in
                    let goal = selected[(activeIndex + depth) % selected.count]
                    let isFront = depth == 0
                    let direction: CGFloat = dragX < 0 ? -1 : 1

                    PreviewGoalCard(
                        goal: goal,
                        index: (activeIndex + depth) % selected.count + 1,
                        surfaceOpacity: 1,
                        isPrimary: isFront,
                        textScale: 1.68,
                        // 下一张卡片在被前卡让出时，立即带出自己的标题、说明和按钮。
                        showsContent: depth <= 1
                    )
                    .frame(width: proxy.size.width - CGFloat(depth) * 20, height: 316 - CGFloat(depth) * 8)
                    .matchedGeometryEffect(
                        id: "selected-goal-card-\(goal.id)",
                        in: selectionTransitionNamespace,
                        properties: .frame,
                        anchor: .center,
                        isSource: false
                    )
                    // 按钮必须先成为卡片本体的一部分，再接受卡片的位移和旋转。
                    .overlay(alignment: .bottom) {
                        Button("开始目标") {
                            state.mode = .executing(goalID: goal.id)
                        }
                        .buttonStyle(LiquidGlassGoalButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .accessibilityHint("开始当前目标")
                    }
                    .matchedGeometryEffect(
                        id: "execution-card-\(goal.id)",
                        in: selectionTransitionNamespace,
                        properties: .frame,
                        anchor: .center,
                        isSource: isFront
                    )
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
                    .rotationEffect(.degrees(isFront ? Double(-dragX / 42) : Double(depth) * 1.8))
                    .offset(
                        x: isFront ? dragX : (CGFloat(depth) * 7 - direction * progress * CGFloat(depth) * 17),
                        y: isFront ? progress * 11 : CGFloat(depth) * 17 - progress * CGFloat(depth) * 8
                    )
                    .shadow(
                        color: .black.opacity(isFront ? 0.20 : 0.12),
                        radius: isFront ? 18 : 11,
                        y: isFront ? 12 : 8
                    )
                    .zIndex(Double(visibleCount - depth))
                    .allowsHitTesting(isFront)
                    .accessibilityHidden(!isFront)
                }

                // 手指松开后，刚才的前景卡片才沿滑动方向线性淡出。
                // 拖动期间不改变透明度，让卡片与其中的按钮完整地跟随手指。
                if let departingGoal {
                    PreviewGoalCard(
                        goal: departingGoal,
                        index: departingIndex(for: departingGoal),
                        surfaceOpacity: 1,
                        isPrimary: true,
                        textScale: 1.68,
                        showsContent: true
                    )
                    .frame(width: proxy.size.width, height: 316)
                    .matchedGeometryEffect(
                        id: "selected-goal-card-\(departingGoal.id)",
                        in: selectionTransitionNamespace,
                        properties: .frame,
                        anchor: .center,
                        isSource: false
                    )
                    .overlay(alignment: .bottom) {
                        Button("开始目标") {}
                            .buttonStyle(LiquidGlassGoalButtonStyle())
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            .allowsHitTesting(false)
                    }
                    .rotation3DEffect(
                        .degrees(Double(-departingOffsetX / 22)),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.72
                    )
                    .rotationEffect(.degrees(Double(-departingOffsetX / 42)))
                    .offset(x: departingOffsetX, y: 11)
                    .opacity(departingOpacity)
                    .shadow(color: .black.opacity(0.20), radius: 18, y: 12)
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
        .frame(height: 332)
        .animation(deckSpring, value: state.homeSelectedIndex)
        .animation(reduceMotion ? .none : .linear(duration: 0.06), value: dragX)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($dragX) { value, state, _ in
                state = rubberBand(value.translation.width, limit: 170)
            }
            .onEnded { value in
                finishDrag(value)
            }
    }

    private func finishDrag(_ value: DragGesture.Value) {
        let projected = value.predictedEndTranslation.width
        guard abs(projected) > 82 || abs(value.translation.width) > 58,
              selected.count > 1,
              departingGoal == nil else { return }

        let outgoing = selected[activeIndex]
        let direction = projected < 0 ? 1 : -1
        departingGoal = outgoing
        departingOffsetX = rubberBand(value.translation.width, limit: 170)
        departingOpacity = 1

        withAnimation(deckSpring) {
            state.homeSelectedIndex = (activeIndex + direction + selected.count) % selected.count
        }
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .linear(duration: 0.20)) {
                departingOffsetX = direction > 0 ? -420 : 420
                departingOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            departingGoal = nil
            departingOffsetX = 0
            departingOpacity = 1
        }
    }

    private func shift(by direction: Int) {
        guard selected.count > 1 else { return }
        let next = (activeIndex + direction + selected.count) % selected.count
        withAnimation(deckSpring) { state.homeSelectedIndex = next }
    }

    private func departingIndex(for goal: Goal) -> Int {
        (selected.firstIndex(where: { $0.id == goal.id }) ?? 0) + 1
    }

    private func rubberBand(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        let magnitude = abs(value)
        guard magnitude > limit else { return value }
        let resisted = limit + (magnitude - limit) * 0.28
        return value.sign == .minus ? -resisted : resisted
    }
}

private struct LiquidGlassGoalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.white.opacity(configuration.isPressed ? 0.18 : 0.12), in: Capsule())
            .background(.ultraThinMaterial.opacity(configuration.isPressed ? 0.78 : 0.62), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.95), .white.opacity(0.25), .white.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .overlay {
                LiquidGlassIdleHighlight()
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
            }
            .shadow(color: .white.opacity(configuration.isPressed ? 0.08 : 0.30), radius: 7, y: -2)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.12 : 0.22), radius: configuration.isPressed ? 3 : 8, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.linear(duration: 0.14), value: configuration.isPressed)
    }
}

private struct LiquidGlassIdleHighlight: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, .white.opacity(0.06), .white.opacity(0.52), .white.opacity(0.06), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width * 0.58)
            .offset(x: phase ? proxy.size.width * 1.08 : -proxy.size.width * 0.58)
            .blur(radius: 2)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                phase = true
            }
        }
    }
}


private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct TodayHeaderView: View {
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
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))
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
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: true, vertical: false)
            }

            // 中间行：副标题与右侧积分胶囊垂直居中对齐
            HStack(alignment: .center, spacing: 10) {
                Text("把注意力留给想变好的自己。")
                    .font(.system(size: 17, weight: .medium)) // 13.5 * 1.25 ≈ 17
                    .foregroundStyle(Color.white.opacity(0.72))
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
        .padding(.top, 64)
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
                .fill(Color(red: 0.99, green: 0.88, blue: 0.88).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.95, green: 0.78, blue: 0.78), lineWidth: 1)
        )
    }
}

private struct HomeSelectionHint: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerEnd: CGFloat = 0

    private let title = "轻触卡片，选择今日目标"
    private let ink = Color.white

    var body: some View {
        Text(title)
            .font(.system(size: 18.7, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: ink.opacity(0.62), location: 0),
                        .init(color: ink.opacity(0.62), location: 0.39),
                        .init(color: ink.opacity(0.95), location: 0.47),
                        .init(color: ink, location: 0.50),
                        .init(color: ink.opacity(0.95), location: 0.53),
                        .init(color: ink.opacity(0.62), location: 0.61),
                        .init(color: ink.opacity(0.62), location: 1)
                    ],
                    startPoint: UnitPoint(x: reduceMotion ? 0 : shimmerEnd - 1, y: 0),
                    endPoint: UnitPoint(x: reduceMotion ? 1 : shimmerEnd, y: 0)
                )
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 2.45).repeatForever(autoreverses: false)) {
                    shimmerEnd = 2
                }
            }
    }
}

private struct HomePreviewDeckView: View {
    let tuning: UITuningState
    let reduceMotion: Bool

    // 首页是固定的引导画面，不读取当日可选习惯，也不写入任何选择状态。
    private let cards: [HomePreviewCard] = [
        HomePreviewCard(id: "preview-knowledge", title: "建立知识输出", summary: "把一个概念讲成别人能听懂的话", tint: GoalTint(red: 0.77, green: 0.29, blue: 0.58, opacity: 1)),
        HomePreviewCard(id: "preview-attention", title: "管理信息摄入", summary: "选择值得关注的内容", tint: GoalTint(red: 0.82, green: 0.26, blue: 0.53, opacity: 1)),
        HomePreviewCard(id: "preview-sleep", title: "睡前断网", summary: "给今天一个安静收尾", tint: GoalTint(red: 0.88, green: 0.40, blue: 0.47, opacity: 1))
    ]
    @State private var animateBreathing = false

    private var poses: [PreviewPose] {
        [
            PreviewPose(x: -tuning.cardWidth * 0.32, y: 20, width: tuning.cardWidth * 0.94, rotation: -7, opacity: 0.75),
            PreviewPose(x: 0, y: 0, width: tuning.cardWidth, rotation: 0, opacity: 0.75),
            PreviewPose(x: tuning.cardWidth * 0.32, y: 18, width: tuning.cardWidth * 0.94, rotation: 7, opacity: 0.75)
        ]
    }

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let pose = poses[index]
                let dynamicFloat: CGFloat = animateBreathing ? (index == 1 ? -11 : (index == 0 ? 8 : -7)) : 0

                PreviewGoalCard(card: card, index: index + 1, surfaceOpacity: pose.opacity, isPrimary: index == 1)
                    .frame(width: pose.width, height: tuning.cardHeight)
                    .rotationEffect(.degrees(pose.rotation))
                    .offset(x: pose.x, y: pose.y + dynamicFloat)
                    .zIndex(Double(index == 1 ? 3 : (index == 2 ? 2 : 1)))
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
    let tint: GoalTint
}

private struct PreviewPose {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let rotation: Double
    let opacity: Double
}

private struct PreviewGoalCard: View {
    let title: String
    let summary: String
    let tint: GoalTint
    let index: Int
    var surfaceOpacity: Double = 0.9
    var isPrimary = true
    var textScale: CGFloat = 1
    var showsContent = true

    init(card: HomePreviewCard, index: Int, surfaceOpacity: Double = 0.9, isPrimary: Bool = true, textScale: CGFloat = 1, showsContent: Bool = true) {
        self.title = card.title
        self.summary = card.summary
        self.tint = card.tint
        self.index = index
        self.surfaceOpacity = surfaceOpacity
        self.isPrimary = isPrimary
        self.textScale = textScale
        self.showsContent = showsContent
    }

    init(goal: Goal, index: Int, surfaceOpacity: Double = 0.9, isPrimary: Bool = true, textScale: CGFloat = 1, showsContent: Bool = true) {
        self.title = goal.previewTitle
        self.summary = goal.previewSummary
        self.tint = goal.tint
        self.index = index
        self.surfaceOpacity = surfaceOpacity
        self.isPrimary = isPrimary
        self.textScale = textScale
        self.showsContent = showsContent
    }

    private var textColor: Color {
        .white
    }

    private var baseTintOpacity: Double {
        // 已选目标页不透出后方叠卡；首页预览继续沿用原有透明度。
        surfaceOpacity >= 0.99 ? 1 : min(tint.opacity + 0.18, 1)
    }

    private var usesSelectedDeckLayout: Bool {
        textScale > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: usesSelectedDeckLayout ? 10 : 14) {
            Text(String(format: "%02d", index))
                .font(.system(size: 11 * textScale, weight: .medium))
                .tracking(1.32)
                .foregroundStyle(textColor.opacity(isPrimary ? 0.85 : 0.45))
            Text(title)
                    .font(.system(size: (isPrimary ? 25 : 21) * textScale, weight: .semibold))
                    .tracking(-0.77)
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .frame(maxWidth: .infinity, minHeight: usesSelectedDeckLayout ? 88 : 0, alignment: .topLeading)
            Text(summary)
                    .font(.system(size: (isPrimary ? 12 : 11) * textScale, weight: .medium))
                    .foregroundStyle(textColor.opacity(0.86))
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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                // 已选卡片直接使用卡片集里相同的习惯色作为底色，再叠加磨砂高光。
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: tint.red, green: tint.green, blue: tint.blue).opacity(baseTintOpacity),
                            Color(red: tint.red, green: tint.green, blue: tint.blue).opacity(baseTintOpacity * 0.92),
                            Color(red: tint.red, green: tint.green, blue: tint.blue).opacity(baseTintOpacity * 0.80)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        // 已选页不能让真实材质采样后方叠卡，改用不透底的仿磨砂高光层。
                        .fill(
                            surfaceOpacity >= 0.99
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.white.opacity(0.20), .white.opacity(0.055), .white.opacity(0.12)],
                                        startPoint: .topTrailing,
                                        endPoint: .bottomLeading
                                    )
                                )
                                : AnyShapeStyle(.ultraThinMaterial.opacity(0.75))
                        )
                }
                // 右上角主光，沿对角线衰减，不将卡面照成一整片白色。
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.56), .white.opacity(0.17), .clear],
                                center: .topTrailing,
                                startRadius: 2,
                                endRadius: 155
                            )
                        )
                        .blendMode(.screen)
                }
                .overlay {
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
        .overlay {
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
        .shadow(color: Color(red: tint.red, green: tint.green, blue: tint.blue).opacity(0.20), radius: 16, y: 10)
        .shadow(color: Color.black.opacity(0.12), radius: 18, y: 12)
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
    @Binding var tab: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let fluidMorphAnimation: Animation
    let namespace: Namespace.ID

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
                    .fill(.white.opacity(0.012))
                    .glassEffect(.clear.tint(.white.opacity(0.025)), in: Capsule())
                    .overlay(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.14),
                                        .white.opacity(0.025),
                                        .clear,
                                        .white.opacity(0.05)
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
                                    colors: [
                                        .white.opacity(0.78),
                                        .white.opacity(0.22),
                                        .black.opacity(0.08),
                                        .white.opacity(0.42)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 14, y: 7)

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
                Capsule().strokeBorder(.white.opacity(0.58), lineWidth: 1.1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60) // 恢复舒适大气的底层导航栏高度
            .onAppear {
                animatedIndex = tabTargetIndex(for: tab)
            }

            // 右侧设置按钮（晶莹透亮圆形液态玻璃球，尺寸适配底层导航高度 60x60）
            Button {
                withAnimation(fluidMorphAnimation) { tab = .settings }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.012))
                        .glassEffect(.clear.tint(.white.opacity(0.025)), in: Circle())
                        .overlay(
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.white.opacity(0.18), .white.opacity(0.035), .clear],
                                        center: .topLeading,
                                        startRadius: 3,
                                        endRadius: 30
                                    )
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.82),
                                            .white.opacity(0.24),
                                            .black.opacity(0.08),
                                            .white.opacity(0.48)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: Color.black.opacity(0.07), radius: 12, y: 5)

                    PrototypeIcon(kind: .settings)
                        .frame(width: 21, height: 21)
                }
                .frame(width: 60, height: 60)
            }
            .matchedGeometryEffect(id: "settingsMorphButton", in: namespace)
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
                .fill(.white.opacity(0.018))
                .glassEffect(.clear.tint(.white.opacity(0.025)).interactive(), in: Capsule())

            Capsule()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.30), .white.opacity(0.08), .clear],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 42
                    )
                )

            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
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
            color: Color(red: 0.88, green: 0.65, blue: 0.75).opacity(0.20 + Double(transitFactor) * 0.14),
            radius: 7 + transitFactor * 3,
            y: 2.5 - transitFactor * 1.5
        )
        .shadow(color: Color.black.opacity(0.09), radius: 7, y: 3)
    }
}

private struct NavigationItem: View {
    let symbol: String
    let title: String
    var selected = false

    var body: some View {
        VStack(spacing: 3) {
            PrototypeIcon(kind: iconKind)
                .frame(width: 20, height: 20)
                .scaleEffect(selected ? 1.08 : 0.95)
            Text(title)
                .font(.system(size: 11, weight: selected ? .semibold : .medium))
        }
        .foregroundStyle(
            selected ? Color(red: 0.18, green: 0.14, blue: 0.20) : Color(red: 0.32, green: 0.28, blue: 0.34).opacity(0.75)
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
    enum Kind { case home, leaf, review, settings }

    let kind: Kind

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            var context = context
            context.scaleBy(x: scale, y: scale)
            let color = Color(red: 0.31, green: 0.27, blue: 0.32)

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

// 今日页专用连续流体背景。独立于 Garden 使用的背景组件，避免跨模块改变养成物页面。
private struct TodayAmbientBackground: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 45)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                draw(in: &context, size: size, time: time)
            }
            .background(Color(red: 0.34, green: 0.34, blue: 0.37))
            .overlay {
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.16))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let minDim = min(size.width, size.height)
        let travel = reduceMotion ? 0.48 : 0.5 + 0.5 * sin(time * 0.34)
        let collision = smoothstep(0.08, 0.92, travel)
        let exchange = smoothstep(0.38, 0.62, collision)

        let largeRadius = minDim * (0.70 + 0.025 * sin(time * 0.47))
        let smallRadius = minDim * (0.35 + 0.014 * cos(time * 0.53))
        let largeCenter = CGPoint(
            x: size.width * (0.17 + 0.36 * collision),
            y: size.height * (0.82 - 0.35 * collision)
        )
        let smallCenter = CGPoint(
            x: size.width * (0.86 - 0.34 * collision),
            y: size.height * (0.18 + 0.35 * collision)
        )

        let magenta = Color(red: 0.93, green: 0.22, blue: 0.65)
        let orange = Color(red: 1.00, green: 0.57, blue: 0.34)
        let largeColor = magenta.mix(with: orange, by: exchange)
        let smallColor = orange.mix(with: magenta, by: exchange)

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
                Gradient(colors: [orange.mix(with: magenta, by: 0.5).opacity(0.9), .clear]),
                center: midpoint,
                startRadius: 4,
                endRadius: coreRadius
            )
        )
        context.opacity = 1

        drawAccent(in: &context, center: CGPoint(x: size.width * 0.88 + cos(time * 0.9) * 22, y: size.height * 0.26 + sin(time * 0.82) * 24), radius: minDim * 0.17, color: orange.opacity(0.42))
        drawAccent(in: &context, center: CGPoint(x: size.width * 0.12 + sin(time * 0.84) * 20, y: size.height * 0.48 + cos(time * 0.92) * 22), radius: minDim * 0.13, color: magenta.opacity(0.36))
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
