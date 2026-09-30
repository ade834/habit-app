import SwiftUI

// MARK: - 页面视觉固定布局配置
struct UITuningState {
    var titleSize: CGFloat = 46         // 标题字号
    var dateSize: CGFloat = 75          // 26 AUG 日期字号
    var cardOffsetY: CGFloat = -13      // 中间卡片上下偏移
    var cardHeight: CGFloat = 232       // 卡片高度
    var cardWidth: CGFloat = 216        // 卡片基准宽度
    var bannerPaddingTop: CGFloat = 6   // 昨日回顾提示位上边距
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state = TodayGoalState()
    @State private var goals: [Goal] = []
    @State private var databaseError: String?
    @State private var dashboard: HabitDashboardSnapshot?
    private let tuning = UITuningState()

    private let repository: any GoalRepository = SharedHabitRepository()

    var body: some View {
        ZStack {
            LiquidBackgroundView(reduceMotion: reduceMotion)
                .ignoresSafeArea()
            TodayRootView(goals: goals, state: $state, tuning: tuning, reduceMotion: reduceMotion, dashboard: dashboard, onConfirm: confirmSelection)
        }
        .alert("无法保存今日选择", isPresented: Binding(get: { databaseError != nil }, set: { if !$0 { databaseError = nil } })) {
            Button("知道了", role: .cancel) { databaseError = nil }
        } message: {
            Text(databaseError ?? "请稍后重试")
        }
        .task {
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
    let tuning: UITuningState
    let reduceMotion: Bool
    let dashboard: HabitDashboardSnapshot?
    let onConfirm: () -> Void
    @Namespace private var navMorphNamespace

    // 设置弹窗形变的高阻尼流体弹簧曲线 (Fluid Morph)
    private let fluidMorphAnimation = Animation.spring(response: 0.52, dampingFraction: 0.84, blendDuration: 0.2)

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域（包含顶部和卡片/页面）
            VStack(spacing: 0) {
                if state.tab == .today && !isExecuting && state.mode != .browsingDeck {
                    TodayHeaderView(selectedCount: state.selectedGoalIDs.count, mode: state.mode, tuning: tuning, dashboard: dashboard)
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
                                .offset(y: tuning.cardOffsetY + 10)
                        }
                    case .browsingDeck:
                        VStack(spacing: 10) {
                            Button("‹ 返回") { withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) { state.mode = .homeUnselected } }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 0.27, green: 0.23, blue: 0.29))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 28)
                            TodayStackDeckView(goals: goals, state: $state)
                        }
                    case .homeSelected:
                        SelectedGoalView(goals: goals, state: $state)
                    case .executing(let id):
                        ExecutionView(goal: goals.first(where: { $0.id == id }) ?? goals.first, state: $state)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 底部确认栏（选卡片时）
            if state.mode == .browsingDeck && state.tab == .today {
                ConfirmSelectionBar(goals: goals, state: state, action: onConfirm)
                    .padding(.bottom, 84)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 常驻底部液态导航栏（设置打开时淡化或收纳，其余时刻常驻）
            if state.tab != .settings {
                TodayBottomNavigationView(
                    tab: $state.tab,
                    fluidMorphAnimation: fluidMorphAnimation,
                    namespace: navMorphNamespace
                )
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
                withAnimation(fluidMorphAnimation) {
                    tab = .today
                }
            } label: {
                HStack(spacing: 8) {
                    PrototypeIcon(kind: .settings)
                        .frame(width: 18, height: 18)
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
    let goals: [Goal]; @Binding var state: TodayGoalState
    private var selected: [Goal] { goals.filter { state.selectedGoalIDs.contains($0.id) } }
    var body: some View {
        VStack(spacing: 16) {
            Text("今天的目标").font(.system(size: 18, weight: .semibold))
            if let goal = selected[safe: state.homeSelectedIndex] ?? selected.first {
                PreviewGoalCard(goal: goal, index: state.homeSelectedIndex + 1).frame(width: 286, height: 330)
                HStack(spacing: 28) {
                    Button("‹") { state.homeSelectedIndex = max(0, state.homeSelectedIndex - 1) }
                    Text("\(state.homeSelectedIndex + 1) / \(selected.count)").font(.system(size: 13, weight: .semibold))
                    Button("›") { state.homeSelectedIndex = min(max(0, selected.count - 1), state.homeSelectedIndex + 1) }
                }.buttonStyle(.bordered)
                Button("开始目标") { state.mode = .executing(goalID: goal.id) }.buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct ExecutionView: View {
    let goal: Goal?; @Binding var state: TodayGoalState
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(goal?.title ?? "今天的目标").font(.system(size: 30, weight: .medium))
            Text(goal?.summary ?? "").font(.system(size: 15, weight: .medium)).opacity(0.78)
            if let goal, !goal.inputPrimary.isEmpty {
                Text(goal.inputPrimary).font(.system(size: 14, weight: .semibold)).padding(.top, 12)
                TextEditor(text: .constant("")).scrollContentBackground(.hidden).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading).padding(10).background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
                Text(goal.inputSecondary).font(.system(size: 14, weight: .semibold)).padding(.top, 4)
                TextEditor(text: .constant("")).scrollContentBackground(.hidden).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading).padding(10).background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
            }
            Button(goal?.completionLabel ?? "提交") { state.mode = .homeSelected }.buttonStyle(.borderedProminent)
        }.padding(.horizontal, 24)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部艺术化排版：大号换行标题 + 右侧大号艺术日期
            HStack(alignment: .top, spacing: 8) {
                // 左侧主标题
                Text("选择\n今天的\n目标")
                    .font(.system(size: tuning.titleSize, weight: .medium))
                    .tracking(-0.6)
                    .lineSpacing(-8)
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                // 右侧大号艺术日期 (实时同步当前日期，调大字号使上下跨度与左侧标题等高)
                VStack(alignment: .trailing, spacing: -8) {
                    Text(dayString)
                        .font(.system(size: tuning.dateSize, weight: .regular))
                        .tracking(-3.0)
                    Text(monthString)
                        .font(.system(size: tuning.dateSize, weight: .regular))
                        .tracking(-4.5)
                }
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: true, vertical: false)
            }

            // 中间行：副标题与右侧积分胶囊垂直居中对齐
            HStack(alignment: .center, spacing: 10) {
                Text("把注意力留给想变好的自己。")
                    .font(.system(size: 17, weight: .medium)) // 13.5 * 1.25 ≈ 17
                    .foregroundStyle(Color(red: 0.30, green: 0.28, blue: 0.32).opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

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
        .padding(.top, 14)
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
                        .init(color: ink.opacity(0.88), location: 0),
                        .init(color: ink.opacity(0.88), location: 0.42),
                        .init(color: ink, location: 0.5),
                        .init(color: ink.opacity(0.88), location: 0.58),
                        .init(color: ink.opacity(0.88), location: 1)
                    ],
                    startPoint: UnitPoint(x: reduceMotion ? 0 : shimmerEnd - 1, y: 0),
                    endPoint: UnitPoint(x: reduceMotion ? 1 : shimmerEnd, y: 0)
                )
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 3.1).repeatForever(autoreverses: false)) {
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

    init(card: HomePreviewCard, index: Int, surfaceOpacity: Double = 0.9, isPrimary: Bool = true) {
        self.title = card.title
        self.summary = card.summary
        self.tint = card.tint
        self.index = index
        self.surfaceOpacity = surfaceOpacity
        self.isPrimary = isPrimary
    }

    init(goal: Goal, index: Int, surfaceOpacity: Double = 0.9, isPrimary: Bool = true) {
        self.title = goal.previewTitle
        self.summary = goal.previewSummary
        self.tint = goal.tint
        self.index = index
        self.surfaceOpacity = surfaceOpacity
        self.isPrimary = isPrimary
    }

    private var textColor: Color {
        .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(format: "%02d", index))
                .font(.system(size: 11, weight: .medium))
                .tracking(1.32)
                .foregroundStyle(textColor.opacity(isPrimary ? 0.85 : 0.45))
            Text(title)
                    .font(.system(size: isPrimary ? 25 : 21, weight: .semibold))
                    .tracking(-0.77)
                    .foregroundStyle(textColor)
            Text(summary)
                    .font(.system(size: isPrimary ? 12 : 11, weight: .medium))
                    .foregroundStyle(textColor.opacity(0.86))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(red: tint.red, green: tint.green, blue: tint.blue).opacity(surfaceOpacity))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.68), lineWidth: 1.2)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 12)
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
                    .fill(.ultraThinMaterial.opacity(0.32))
                    .overlay(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.35),
                                        .white.opacity(0.06),
                                        .clear,
                                        .white.opacity(0.12)
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
                                        .white.opacity(0.95),
                                        .white.opacity(0.40),
                                        .white.opacity(0.10),
                                        .white.opacity(0.70)
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
                Capsule().strokeBorder(.white.opacity(0.86), lineWidth: 1.2)
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
                        .fill(.ultraThinMaterial.opacity(0.38))
                        .overlay(
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.white.opacity(0.40), .white.opacity(0.05), .clear],
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
                                            .white.opacity(0.98),
                                            .white.opacity(0.45),
                                            .white.opacity(0.12),
                                            .white.opacity(0.80)
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
            // 水滴通透主体（完全使用 Capsule，与外层导航栏胶囊曲率 100% 绝对一致）
            Capsule()
                .fill(.white.opacity(0.08))
                .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: Capsule())

            // 水滴内部凸透镜光泽
            Capsule()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.42), .clear],
                        center: .top,
                        startRadius: 2,
                        endRadius: 20
                    )
                )

            // 边缘高光保持在形状内部，避免顶部出现悬空亮条。
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.98),
                            .white.opacity(0.50),
                            .white.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
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
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
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

#Preview { ContentView() }
