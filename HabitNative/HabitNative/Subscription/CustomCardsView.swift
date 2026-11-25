import SwiftUI

struct AddCardButtonSourceFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0 { value = next }
    }
}

// MARK: - 增加卡片快捷按钮 (Placed beside the task completion/points badge)
struct AddCustomCardButton: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let tint: Color
    var scale: CGFloat = 1.0
    var fontSize: CGFloat? = nil
    var horizontalPadding: CGFloat? = nil
    var verticalPadding: CGFloat? = nil
    var fixedHeight: CGFloat? = nil
    var isSelected: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: fontSize ?? (14 * scale), weight: .bold))
                Text(AppLanguage.text("增加卡片"))
                    .font(.system(size: fontSize ?? (14 * scale), weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, horizontalPadding ?? (14 * scale))
            .padding(.vertical, fixedHeight != nil ? 0 : (verticalPadding ?? (8 * scale)))
            .frame(height: fixedHeight)
            .background(
                Capsule()
                    .fill(isSelected ? .white.opacity(0.95) : .white.opacity(0.90))
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? tint.opacity(0.35) : .white.opacity(0.40), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AddCardButtonSourceFrameKey.self,
                    value: proxy.frame(in: .global)
                )
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(AppLanguage.text("增加卡片"))
    }
}

// MARK: - 展开动效阶段
enum LiquidModalPhase: Equatable {
    case closed
    case expandingWidth   // 第一阶段：先横向展开
    case expandedFull     // 第二阶段：再纵向展开
}

// MARK: - 半透高斯模糊磨砂液态玻璃弹窗
struct LiquidGlassCustomCardsModal: View {
    @Binding var isPresented: Bool
    var sourceFrame: CGRect = .zero
    let onCardsChanged: () -> Void

    @Environment(\.habitColorTheme) private var colorTheme
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var cards: [CustomCard] = []
    @State private var usedCreations = 0
    @State private var editorItem: CardEditorTarget?
    @State private var showingPlans = false
    @State private var errorMessage: String?
    @State private var taskToArchive: CustomTaskItem?

    // 两段展开动画状态
    @State private var phase: LiquidModalPhase = .closed

    private let store = CustomCardStore()
    private var limit: Int { subscription.currentTier.maxCustomCards }
    private var activeIDs: Set<String> { CustomCard.activeIDs(in: cards, limit: limit) }
    private var remaining: Int? { subscription.customTaskQuota.limit.map { max(0, $0 - usedCreations) } }

    var body: some View {
        ZStack {
            // 背景遮罩撑满全屏 (无论折叠/展开均完全覆盖全部屏幕区域)
            Color.black.opacity(phase == .expandedFull ? 0.40 : (phase == .expandingWidth ? 0.12 : 0))
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissAnimated()
                }

            GeometryReader { geometry in
                // 页面边界严格约束：展开最高达全屏约 2/3，绝不与底部确认栏、底部导航栏或右侧导航栏重合
                let isLandscapeMode = geometry.size.width > geometry.size.height
                let rightMargin: CGFloat = isLandscapeMode ? 76 : 16
                let targetWidth = min(max(320, geometry.size.width - (isLandscapeMode ? 120 : 32)), isLandscapeMode ? 520 : 440)

                let buttonFrame = (sourceFrame.width > 0 && sourceFrame.height > 0)
                    ? sourceFrame
                    : CGRect(x: geometry.size.width - 160, y: 64, width: 110, height: 42)

                let targetRight = min(geometry.size.width - rightMargin, max(buttonFrame.maxX, targetWidth + 16))
                let targetLeft = max(16, targetRight - targetWidth)
                let targetActualWidth = targetRight - targetLeft
                let initialHeight = max(buttonFrame.height, 40)

                // 限制底部边界，最高占到全屏高度的 2/3，并与底部椭圆形按钮保持充分安全间距
                let bottomClearance: CGFloat = isLandscapeMode ? 76 : 110
                let maxTopAllowed = max(16, geometry.size.height - bottomClearance - 260)
                let targetTop = min(max(16, buttonFrame.minY), maxTopAllowed)
                let availableHeight = max(260, geometry.size.height - targetTop - bottomClearance)
                let maxTargetHeight = min(geometry.size.height * 0.66, availableHeight)
                let targetHeight = maxTargetHeight

                let currentX: CGFloat = {
                    switch phase {
                    case .closed: return buttonFrame.minX
                    case .expandingWidth, .expandedFull: return targetLeft
                    }
                }()

                let currentWidth: CGFloat = {
                    switch phase {
                    case .closed: return buttonFrame.width
                    case .expandingWidth, .expandedFull: return targetActualWidth
                    }
                }()

                let currentHeight: CGFloat = {
                    switch phase {
                    case .closed, .expandingWidth: return initialHeight
                    case .expandedFull: return targetHeight
                    }
                }()

                // 核心液态玻璃卡片容器：从按钮原始位置先横着展开，再向下展开；收回原路返回
                VStack(spacing: 0) {
                    if phase == .expandedFull {
                        modalContent
                            .transition(.opacity)
                    }
                }
                .frame(width: currentWidth, height: currentHeight)
                .background {
                    liquidGlassBackground
                }
                .clipShape(RoundedRectangle(cornerRadius: phase == .expandedFull ? 24 : initialHeight / 2, style: .continuous))
                .overlay {
                    liquidGlassBorder
                }
                .shadow(color: .black.opacity(phase == .closed ? 0 : 0.22), radius: 24, y: 10)
                .position(x: currentX + currentWidth / 2, y: targetTop + currentHeight / 2)
            }
        }
        .ignoresSafeArea(.all)
        .task {
            reload()
            startTwoStageExpansion()
        }
        .onChange(of: subscription.currentTier) { reload() }
        .sheet(isPresented: $showingPlans) { SubscriptionPaywallView() }
        .alert(AppLanguage.text("操作未完成"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(AppLanguage.text("知道了"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 液态玻璃磨砂质感背景
    private var liquidGlassBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                // 柔和光晕渐变
                LinearGradient(
                    colors: [
                        .white.opacity(0.38),
                        .white.opacity(0.12),
                        .clear,
                        .white.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }

    // MARK: - 液态玻璃边缘反光高光线条
    private var liquidGlassBorder: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.85),
                        .white.opacity(0.30),
                        .white.opacity(0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.25
            )
            .allowsHitTesting(false)
    }

    // MARK: - 弹窗内主要内容
    private var modalContent: some View {
        VStack(spacing: 0) {
            // 顶栏 Header
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(colorTheme.accent)
                    Text(AppLanguage.text("自定义卡片"))
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))
                }

                Spacer(minLength: 8)

                // 配额角标
                HStack(spacing: 4) {
                    Text("\(cards.count)/\(limit)")
                        .font(.system(size: 12, weight: .semibold))
                    Text(AppLanguage.text("张"))
                        .font(.system(size: 11))
                }
                .foregroundStyle(colorTheme.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.white.opacity(0.65), in: Capsule())
                .overlay(Capsule().stroke(colorTheme.accent.opacity(0.25), lineWidth: 0.8))
                .fixedSize()

                // 关闭按钮
                Button {
                    dismissAnimated()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.33, blue: 0.37))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.65), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider().opacity(0.2)

            // 中间可滚动卡片列表
            ScrollView {
                VStack(spacing: 14) {
                    // 已有卡片列表
                    ForEach(cards) { card in
                        customCardRow(card)
                    }

                    // 新建卡片区域
                    if editorItem == nil {
                        if cards.count < limit {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    editorItem = .card(nil)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(AppLanguage.text("新建卡片"))
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(colorTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.white.opacity(0.55))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                                                .foregroundStyle(colorTheme.accent.opacity(0.45))
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            // 上限提示
                            VStack(spacing: 6) {
                                Text(AppLanguage.text("已达到当前方案的卡片上限。"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                if subscription.currentTier != .yearly {
                                    Button(AppLanguage.text("解锁更多卡片位")) {
                                        showingPlans = true
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(colorTheme.accent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    } else if let target = editorItem {
                        // 内嵌卡片编辑器
                        embeddedEditorView(target)
                    }
                }
                .padding(18)
            }
        }
    }

    // MARK: - 单张卡片组件
    @ViewBuilder
    private func customCardRow(_ card: CustomCard) -> some View {
        let active = activeIDs.contains(card.id)
        let floraType = PosyFloraType(rawValue: card.plantSpecies) ?? .iris

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // 植物花头第 4 阶段预览微图
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.75))
                    PosyFlowerBloomCanvas(
                        type: floraType,
                        progress: 1.0,
                        breathingPhase: 0,
                        windAngle: 0,
                        seed: 42
                    )
                    .frame(width: 40, height: 40)
                }
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.20))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(AppLanguage.text("custom.plant." + card.plantSpecies))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(colorTheme.accent)
                            .lineLimit(1)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(active ? AppLanguage.text("已激活") : AppLanguage.text("custom.paused"))
                            .font(.system(size: 12))
                            .foregroundStyle(active ? Color(red: 0.20, green: 0.65, blue: 0.40) : .secondary)
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                Spacer()

                // 添加子任务按钮
                if active {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            editorItem = .task(card.id, nil)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                            Text(AppLanguage.text("任务"))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colorTheme.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.75), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // 卡片包含的任务
            let tasks = card.tasks.filter { $0.archived != true }
            if !tasks.isEmpty {
                VStack(spacing: 6) {
                    ForEach(tasks) { task in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(colorTheme.accent.opacity(0.8))
                            Text(task.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.24))
                            Spacer()
                            Button {
                                archiveTask(task)
                            } label: {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.85), lineWidth: 1)
                )
        )
    }

    // MARK: - 内嵌编辑器组件
    @ViewBuilder
    private func embeddedEditorView(_ target: CardEditorTarget) -> some View {
        EmbeddedCardEditor(
            target: target,
            cards: cards,
            colorTheme: colorTheme,
            onCancel: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    editorItem = nil
                }
            },
            onSave: { title, detail in
                save(target: target, title: title, detail: detail)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    editorItem = nil
                }
            }
        )
    }

    // MARK: - 展开与关闭动效逻辑
    private func startTwoStageExpansion() {
        // 第一阶段：先横向展开
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            phase = .expandingWidth
        }
        // 第二阶段：延时 0.18s 后竖向展开
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                phase = .expandedFull
            }
        }
    }

    private func dismissAnimated() {
        // 第一阶段：先纵向收缩
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            phase = .expandingWidth
        }
        // 第二阶段：横向收缩并关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                phase = .closed
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                isPresented = false
            }
        }
    }

    // MARK: - 数据操作
    private func reload() {
        do {
            cards = try store.read()
            usedCreations = try store.usedCreations(in: subscription.customTaskQuota.bucket)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(target: CardEditorTarget, title: String, detail: String) {
        do {
            switch target {
            case let .card(card):
                try store.saveCard(id: card?.id, title: title, species: detail, limit: limit)
            case let .task(cardID, task):
                let quota = subscription.customTaskQuota
                try store.saveTask(
                    cardID: cardID,
                    id: task?.id,
                    title: title,
                    prompt: detail,
                    cardLimit: limit,
                    bucket: quota.bucket,
                    taskLimit: quota.limit
                )
            }
            reload()
            onCardsChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archiveTask(_ task: CustomTaskItem) {
        do {
            try store.archiveTask(task, cardLimit: limit)
            reload()
            onCardsChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 编辑器目标
enum CardEditorTarget: Identifiable, Equatable {
    case card(CustomCard?)
    case task(String, CustomTaskItem?)

    var id: String {
        switch self {
        case let .card(card): return "card:" + (card?.id ?? "new")
        case let .task(card, task): return "task:" + (task?.id ?? card)
        }
    }
}

// MARK: - 内嵌式磨砂玻璃卡片编辑器
private struct EmbeddedCardEditor: View {
    let target: CardEditorTarget
    let cards: [CustomCard]
    let colorTheme: HabitColorTheme
    let onCancel: () -> Void
    let onSave: (String, String) -> Void

    @State private var title: String = ""
    @State private var detail: String = ""
    private let availableSpecies: [String]

    init(target: CardEditorTarget, cards: [CustomCard], colorTheme: HabitColorTheme, onCancel: @escaping () -> Void, onSave: @escaping (String, String) -> Void) {
        self.target = target
        self.cards = cards
        self.colorTheme = colorTheme
        self.onCancel = onCancel
        self.onSave = onSave

        switch target {
        case let .card(card):
            let used = Set(cards.filter { $0.id != card?.id }.map(\.plantSpecies))
            let filtered = CustomCard.species.filter { !used.contains($0) || $0 == card?.plantSpecies }
            self.availableSpecies = filtered.isEmpty ? CustomCard.species : filtered
            _title = State(initialValue: card?.title ?? "")
            _detail = State(initialValue: card?.plantSpecies ?? filtered.first ?? "iris")
        case let .task(_, task):
            self.availableSpecies = []
            _title = State(initialValue: task?.title ?? "")
            _detail = State(initialValue: task?.promptQuestion ?? "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isCard ? AppLanguage.text("新建自定义卡片") : AppLanguage.text("添加任务"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.22))

            // 名称输入框
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLanguage.text(isCard ? "卡片名称" : "任务名称"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(AppLanguage.text(isCard ? "例如：每日晨跑 / 英语阅读" : "写下具体任务"), text: $title)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            }

            // 选择养成植物（仅卡片模式）
            if isCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLanguage.text("选择养成花卉（打卡时绽放第四阶段花头）"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(availableSpecies, id: \.self) { species in
                                let isSelected = detail == species
                                let floraType = PosyFloraType(rawValue: species) ?? .iris

                                Button {
                                    detail = species
                                } label: {
                                    VStack(spacing: 4) {
                                        PosyFlowerBloomCanvas(
                                            type: floraType,
                                            progress: 1.0,
                                            breathingPhase: 0,
                                            windAngle: 0,
                                            seed: 42
                                        )
                                        .frame(width: 38, height: 38)

                                        Text(AppLanguage.text("custom.plant." + species))
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                            .foregroundStyle(isSelected ? colorTheme.accent : .secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(isSelected ? .white : .white.opacity(0.45))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(isSelected ? colorTheme.accent : .white.opacity(0.6), lineWidth: isSelected ? 1.5 : 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else {
                // 打卡引导提示语
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLanguage.text("打卡提示问题（选填）"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField(AppLanguage.text("例如：今天坚持了多少分钟？"), text: $detail)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            // 底部操作按钮
            HStack(spacing: 12) {
                Button(AppLanguage.text("取消")) {
                    onCancel()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))

                Button(AppLanguage.text("保存")) {
                    onSave(title, detail)
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [colorTheme.accent, colorTheme.companion],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            .padding(.top, 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.70))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white, lineWidth: 1.25)
                )
        )
    }

    private var isCard: Bool {
        if case .card = target { return true }
        return false
    }
}
