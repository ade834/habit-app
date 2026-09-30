import SwiftUI

// MARK: - Main Garden View (Echoing POSY reference photo & Garden Spec)
struct GardenView: View {
    @StateObject private var viewModel: GardenHabitViewModel
    @State private var showCatalogSheet: Bool = false
    @State private var showMeaningsModal: Bool = false
    @State private var showQuickAffirmationToast: String? = nil

    init(goals: [Goal] = []) {
        _viewModel = StateObject(wrappedValue: GardenHabitViewModel(goals: goals))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // 1. Unified Liquid Background (Directly sharing "今日" page's dynamic liquid canvas)
                UnifiedLiquidGardenBackground()
                    .ignoresSafeArea()

                // 2. Main Content Flow
                VStack(spacing: 0) {
                    // Top App Bar
                    GardenTopBar(
                        onSeePosyTapped: {
                            showCatalogSheet = true
                        },
                        onHelpTapped: {
                            showCatalogSheet = true
                        }
                    )
                    .padding(.horizontal, 22)
                    .padding(.top, proxy.safeAreaInsets.top > 0 ? 6 : 14)

                    // 3. Central Living Garden Stage with Procedural Flowers & Floating Vessel
                    GardenStageView(
                        viewModel: viewModel,
                        stageSize: CGSize(width: proxy.size.width, height: proxy.size.height * 0.42)
                    )
                    .frame(height: proxy.size.height * 0.42)

                    // 4. Over-vessel Segmented Capsule: "Flowers" & "Meanings"
                    GardenSegmentedCapsule(activeTab: $viewModel.activeTabPill)
                        .padding(.top, -16)

                    // 5. Horizontal Habit Flower Progress Carousel Strip (实时进程走马灯栏)
                    HabitFlowerProgressCarouselStrip(
                        viewModel: viewModel,
                        onNurture: { habitId in
                            if let item = viewModel.items.first(where: { $0.id == habitId }) {
                                viewModel.nurture(habitId: habitId)
                                triggerQuickAffirmation("💧 已为「\(item.habit.title)」浇水培育！")
                            }
                        }
                    )
                    .padding(.top, 6)

                    // 6. "Quick send" / Habit Affirmation Pills
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quick send")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .italic()
                            .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.42).opacity(0.75))
                            .padding(.leading, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 9) {
                                QuickSendPill(title: "soon", meaning: "静待萌芽") {
                                    triggerQuickAffirmation("🌱 保持节奏，静待萌芽")
                                }
                                QuickSendPill(title: "I'm sorry", meaning: "今天漏卡") {
                                    triggerQuickAffirmation("💧 没关系，今天重新开始浇水")
                                }
                                QuickSendPill(title: "Good luck", meaning: "迎接挑战") {
                                    triggerQuickAffirmation("✨ 祝你顺利突破舒适区")
                                }
                                QuickSendPill(title: "Well done", meaning: "盛开达成") {
                                    triggerQuickAffirmation("🌸 坚持完成，繁花盛开！")
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 4)
                }

                // Toast Feedback
                if let toast = showQuickAffirmationToast {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.72))
                                    .shadow(radius: 8)
                            )
                            .padding(.bottom, 100)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        // Detail sheet for individual tapped flower
        .sheet(item: $viewModel.selectedItem) { item in
            FlowerDetailSheetView(item: item) {
                viewModel.nurture(habitId: item.id)
            }
        }
        // Catalog & Rules sheet
        .sheet(isPresented: $showCatalogSheet) {
            GardenCatalogAndRulesSheet()
        }
        // Meanings explanation sheet
        .sheet(isPresented: $showMeaningsModal) {
            GardenMeaningsSheet(items: viewModel.items)
        }
    }

    private func triggerQuickAffirmation(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showQuickAffirmationToast = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut) {
                if showQuickAffirmationToast == text {
                    showQuickAffirmationToast = nil
                }
            }
        }
    }
}

// MARK: - Unified Liquid Garden Background (Identical to "今日" Page)
private struct UnifiedLiquidGardenBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // 1. Direct incorporation of "今日" Liquid Canvas Background
            LiquidBackgroundView(reduceMotion: reduceMotion)
                .ignoresSafeArea()

            // 2. Subtle translucent garden bloom radiance so liquid spheres remain completely visible
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.90, blue: 0.86).opacity(0.18),
                    Color(red: 0.95, green: 0.86, blue: 0.94).opacity(0.12),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Habit Flower Progress Carousel Strip (横滑交互习惯花卉进程栏)
private struct HabitFlowerProgressCarouselStrip: View {
    @ObservedObject var viewModel: GardenHabitViewModel
    let onNurture: (String) -> Void
    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(spacing: 8) {
            // Horizontal Paged Cards (横滑交互切换各习惯进程)
            TabView(selection: $currentIndex) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    HabitProgressGlassCard(item: item) {
                        onNurture(item.id)
                    }
                    .tag(index)
                    .padding(.horizontal, 18)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 104)
            .onChange(of: currentIndex) { newIdx in
                if newIdx >= 0 && newIdx < viewModel.items.count {
                    let item = viewModel.items[newIdx]
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.focusedHabitId = item.id
                    }
                }
            }

            // Paging Indicator Dots (7个习惯的微型流体指示胶囊)
            HStack(spacing: 5) {
                ForEach(0..<viewModel.items.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentIndex ? Color(red: 0.38, green: 0.30, blue: 0.36) : Color(red: 0.38, green: 0.30, blue: 0.36).opacity(0.22))
                        .frame(width: idx == currentIndex ? 16 : 5, height: 4.5)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentIndex = idx
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Single Habit Progress Glass Card
private struct HabitProgressGlassCard: View {
    let item: HabitGardenItem
    let onNurture: () -> Void

    var body: some View {
        let req = item.nextLevelRequirement
        let tint = item.habit.tint
        let cardAccent = Color(red: tint.red, green: tint.green, blue: tint.blue)

        VStack(alignment: .leading, spacing: 6) {
            // Top Row: Habit Name, Flower Tag & Water Action
            HStack(alignment: .center, spacing: 10) {
                // Mini Flower Icon Badge
                ZStack {
                    Circle()
                        .fill(cardAccent.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.speciesIconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(cardAccent)
                }

                // Habit Title & Species Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.habit.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.22, green: 0.18, blue: 0.22))
                            .lineLimit(1)

                        // Stage Badge Pill
                        Text("Lv.\(item.targetLevel) \(item.speciesChineseName)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(cardAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(cardAccent.opacity(0.14))
                            )
                    }

                    Text("\(item.stageTitle) · \(req.description)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.40, green: 0.34, blue: 0.38).opacity(0.85))
                        .lineLimit(1)
                }

                Spacer()

                // "💧 浇水培育" Quick Action Pill
                Button(action: onNurture) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 10))
                        Text("浇水")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5.5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [cardAccent, cardAccent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: cardAccent.opacity(0.35), radius: 3, x: 0, y: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            // Bottom Row: Dynamic Progress Track & Numerical Ratio
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 6)

                        // Progress Fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [cardAccent.opacity(0.65), cardAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(req.progress)), height: 6)
                            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: req.progress)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("累计打卡 \(item.completions) 次 · \(item.points) 养成值")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(red: 0.45, green: 0.40, blue: 0.44).opacity(0.8))

                    Spacer()

                    Text("\(Int(req.progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(cardAccent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.75), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }
}

// MARK: - Top Bar
private struct GardenTopBar: View {
    let onSeePosyTapped: () -> Void
    let onHelpTapped: () -> Void

    var body: some View {
        HStack {
            Text("POSY")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .tracking(3)
                .foregroundStyle(Color(red: 0.35, green: 0.28, blue: 0.34))

            Spacer()

            // Glowing frosted capsule button: "See your posy →"
            Button(action: onSeePosyTapped) {
                HStack(spacing: 6) {
                    Text("See your posy")
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .italic()
                    Text("→")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.92, green: 0.50, blue: 0.66).opacity(0.85),
                                    Color(red: 0.96, green: 0.68, blue: 0.75).opacity(0.85)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                        )
                        .shadow(color: Color(red: 0.92, green: 0.45, blue: 0.62).opacity(0.35), radius: 12, x: 0, y: 5)
                )
            }

            Spacer()

            // Circular frosted glass "?" button
            Button(action: onHelpTapped) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.42))
                        .frame(width: 38, height: 38)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)

                    Text("?")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(Color(red: 0.38, green: 0.30, blue: 0.36))
                }
            }
        }
    }
}

// MARK: - Segmented Capsule Pill: "Flowers" & "Meanings"
private struct GardenSegmentedCapsule: View {
    @Binding var activeTab: GardenHabitViewModel.GardenTabPill

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    activeTab = .flowers
                }
            } label: {
                Text("Flowers")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(activeTab == .flowers ? Color.white : Color(red: 0.45, green: 0.38, blue: 0.42))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if activeTab == .flowers {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.94, green: 0.42, blue: 0.62), Color(red: 0.96, green: 0.58, blue: 0.70)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color(red: 0.94, green: 0.42, blue: 0.62).opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                        }
                    )
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    activeTab = .meanings
                }
            } label: {
                Text("Meanings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(activeTab == .meanings ? Color.white : Color(red: 0.45, green: 0.38, blue: 0.42))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if activeTab == .meanings {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.94, green: 0.42, blue: 0.62), Color(red: 0.96, green: 0.58, blue: 0.70)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color(red: 0.94, green: 0.42, blue: 0.62).opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                        }
                    )
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.55))
                .overlay(Capsule().stroke(Color.white.opacity(0.75), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }
}

// MARK: - Quick Send Pill Chip
private struct QuickSendPill: View {
    let title: String
    let meaning: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(Color.white)
                Text(meaning)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.96, green: 0.65, blue: 0.72).opacity(0.68), Color(red: 0.98, green: 0.78, blue: 0.82).opacity(0.68)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.85), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.94, green: 0.55, blue: 0.65).opacity(0.2), radius: 6, x: 0, y: 3)
            )
        }
    }
}

// MARK: - Bottom Controls Bar (Dismiss, Heart, Remix, Chat, More)
private struct GardenBottomControlsBar: View {
    let onRemixTapped: () -> Void
    let onHeartTapped: () -> Void
    let onChatTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Dismiss Circle Button
            GlassCircleButton(iconName: "xmark", action: {})

            // Heart Circle Button
            GlassCircleButton(iconName: "heart.fill", iconColor: Color(red: 0.92, green: 0.35, blue: 0.42), action: onHeartTapped)

            // Wide "Remix" Capsule Button
            Button(action: onRemixTapped) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Remix")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.38, green: 0.22, blue: 0.36))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.92, blue: 0.88),
                                    Color(red: 0.98, green: 0.78, blue: 0.86),
                                    Color(red: 0.95, green: 0.72, blue: 0.84)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
                        .shadow(color: Color(red: 0.94, green: 0.62, blue: 0.72).opacity(0.35), radius: 10, x: 0, y: 4)
                )
            }

            // Chat Circle Button
            GlassCircleButton(iconName: "message", action: onChatTapped)

            // More Circle Button
            GlassCircleButton(iconName: "ellipsis", action: {})
        }
    }
}

private struct GlassCircleButton: View {
    let iconName: String
    var iconColor: Color = Color(red: 0.35, green: 0.28, blue: 0.34)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.48))
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
        }
    }
}

// MARK: - Detail Sheet For Single Habit Flower
private struct FlowerDetailSheetView: View {
    let item: HabitGardenItem
    let onNurture: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let recipe = GardenRecipeRegistry.shared.recipe(for: item.record.species)

        VStack(spacing: 20) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(recipe.nameZh)
                            .font(.system(size: 24, weight: .bold))
                        Text(recipe.tier.displayName)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.95, green: 0.85, blue: 0.90), in: Capsule())
                    }
                    Text("对应习惯: \(item.habit.title) · \(item.habit.category)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            // Flower stage status
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("当前阶段")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(item.stageTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.88, green: 0.28, blue: 0.54))
                }

                Text(item.stageDescription)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)

                Divider()

                HStack {
                    Label("\(item.points) 培育积分", systemImage: "sparkles")
                    Spacer()
                    Label("累计完成 \(item.completions) 次", systemImage: "checkmark.circle.fill")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.38, green: 0.32, blue: 0.36))
            }
            .padding(18)
            .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 24)

            // Nurture Button
            Button {
                onNurture()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                    Text("浇水培育 (推进等级)")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.92, green: 0.42, blue: 0.60), Color(red: 0.96, green: 0.60, blue: 0.72)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(color: Color(red: 0.92, green: 0.42, blue: 0.60).opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            Spacer()
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Catalog & Rules Sheet
private struct GardenCatalogAndRulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("7 阶段生命历程 (Garden Levels)")) {
                    StageRow(level: "3", name: "开花 blooming", desc: "100% 盛开，S档分层绽放、瓣缘发光、冲击波")
                    StageRow(level: "2", name: "花苞 budding", desc: "70% 茎高，苞衣包紧缓缓鼓胀，呼吸脉动")
                    StageRow(level: "1", name: "发芽 sprouting", desc: "30% 茎高，两片真叶顶出，轻微晃动")
                    StageRow(level: "0", name: "埋种 seeded", desc: "6% 茎高，一小撮松土与初生芽尖")
                    StageRow(level: "-1", name: "枯萎 wilting", desc: "88% 茎高，褪色 45%，垂头 28°")
                    StageRow(level: "-2", name: "凋谢 faded", desc: "70% 茎高，余瓣落尽，只剩干茎花萼")
                    StageRow(level: "-3", name: "休眠 gone", desc: "不画花，保留花位，等级回升时原地复活")
                }

                Section(header: Text("12 种程序化花卉配方 (Species)")) {
                    ForEach(GardenRecipeRegistry.shared.allSpecies) { recipe in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(recipe.nameZh)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(recipe.tier.displayName)
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.pink.opacity(0.12), in: Capsule())
                                }
                                Text("结构: \(recipe.archetype.rawValue) · 招牌: \(recipe.signature)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 3) {
                                ForEach(recipe.palette, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hexString: hex))
                                        .frame(width: 14, height: 14)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("花园规格与图鉴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct StageRow: View {
    let level: String
    let name: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(level)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .frame(width: 24)
                .foregroundStyle(Color(red: 0.88, green: 0.28, blue: 0.54))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Meanings Sheet
private struct GardenMeaningsSheet: View {
    let items: [HabitGardenItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(items) { item in
                let recipe = GardenRecipeRegistry.shared.recipe(for: item.record.species)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.habit.title)
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text(recipe.nameZh)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.88, green: 0.28, blue: 0.54))
                    }
                    Text(item.habit.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("当前生命状态: \(item.stageTitle)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.35, green: 0.55, blue: 0.38))
                        Spacer()
                        Text("拖拽可重新编排花束位置")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("花语与习惯寄托")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
