import SwiftUI

private struct PerspectiveCardShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var bottomInset: CGFloat

    func path(in rect: CGRect) -> Path {
        let topR = min(topRadius, min(rect.width, rect.height) / 2)
        let inset = min(bottomInset, rect.width * 0.12)
        let bottomR = min(bottomRadius, min(rect.width - inset * 2, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topR, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + topR), control1: CGPoint(x: rect.maxX - topR * 0.42, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.minY + topR * 0.42))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - bottomR))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - inset - bottomR, y: rect.maxY), control: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + inset + bottomR, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + inset, y: rect.maxY - bottomR), control: CGPoint(x: rect.minX + inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topR))
        path.addCurve(to: CGPoint(x: rect.minX + topR, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.minY + topR * 0.42), control2: CGPoint(x: rect.minX + topR * 0.42, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// A looping perspective card stack with a large third card.
struct TodayStackDeckView: View {
    let goals: [Goal]
    @Binding var state: TodayGoalState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0
    @GestureState private var horizontalDrag: CGFloat = 0
    @State private var draggedGoalID: String?
    @State private var bounceID: String?

    private var focus: Int {
        goals.firstIndex { $0.id == state.focusedGoalID } ?? 0
    }

    private var spring: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.46, dampingFraction: 0.72)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                Text("右滑/取消选择今天的目标")
                    .font(.system(size: 23, weight: .semibold))
                    .tracking(-0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Text("\(goals.filter { state.selectedGoalIDs.contains($0.id) && !state.starredGoalIDs.contains($0.id) && $0.countsTowardQuota }.count)").fontWeight(.semibold)
                    Text("/ 3").foregroundStyle(.secondary)
                }
                .font(.system(size: 17))
                .padding(.horizontal, 15).padding(.vertical, 9)
                .background(.white.opacity(0.78), in: Capsule())
            }
            .foregroundStyle(Color(red: 0.27, green: 0.23, blue: 0.29))
            .padding(.horizontal, 4)
            .padding(.top, 20)

            HStack(spacing: 12) {
                legend("普通", color: Color(red: 0.769, green: 0.820, blue: 0.733))
                legend("周期", color: Color(red: 0.725, green: 0.800, blue: 0.831))
                legend("星标", color: Color(red: 0.878, green: 0.816, blue: 0.659))
                Spacer(minLength: 0)
                Text("上下滑动浏览").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 5)

            GeometryReader { geometry in
                let cardHeight = min(geometry.size.height * 0.56, 390)
                // 让前两张的露出高度增加约 1.25 倍，同时整体把后续卡片下移。
                let step = max(45, geometry.size.height * 0.094)
                let visibleSlots = min(goals.count, 5)
                ZStack(alignment: .top) {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        let slot = (index - focus + 2 + goals.count) % max(1, goals.count)
                        if slot < visibleSlots {
                        let isHero = slot == min(2, visibleSlots - 1)
                        let isSelected = state.selectedGoalIDs.contains(goal.id)
                        let reveal = contentReveal(
                            slot: slot,
                            step: step,
                            height: cardHeight,
                            visibleSlots: visibleSlots,
                            viewportHeight: geometry.size.height - 15
                        )
                        goalCard(goal, isHero: isHero, selected: isSelected, contentReveal: reveal)
                            .frame(height: cardHeight, alignment: .top)
                            .frame(maxWidth: .infinity)
                            .background { cardSurface(goal, isHero: isHero) }
                            .clipShape(PerspectiveCardShape(topRadius: 29, bottomRadius: 18, bottomInset: 19))
                            .overlay {
                                PerspectiveCardShape(topRadius: 29, bottomRadius: 18, bottomInset: 19)
                                    .stroke(LinearGradient(colors: [.white.opacity(0.88), .white.opacity(0.25), .white.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.25)
                                    .allowsHitTesting(false)
                            }
                            .mask(cardVisibilityMask(isLastVisible: slot == visibleSlots - 1, height: cardHeight))
                            .offset(y: cardTop(slot: slot, step: step, height: cardHeight) + dragOffset(slot: slot))
                            .offset(x: draggedGoalID == goal.id ? max(0, horizontalDrag) : 0)
                            .scaleEffect(bounceID == goal.id && !reduceMotion ? 1.025 : 1, anchor: .center)
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : drag / 42), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                            .zIndex(Double(slot))
                            .contentShape(PerspectiveCardShape(topRadius: 29, bottomRadius: 18, bottomInset: 19))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: max(0, geometry.size.height - 15), alignment: .top)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height), draggedGoalID == nil else { return }
                        draggedGoalID = goalAt(value.startLocation.y, step: step, height: cardHeight, count: visibleSlots)?.id
                    }
                    .updating($horizontalDrag) { value, current, _ in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        current = min(90, max(0, value.translation.width))
                    }
                    .updating($drag) { value, current, _ in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        current = max(-90, min(90, value.translation.height))
                    }
                    .onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            if value.translation.width > 55,
                               let goal = goalAt(value.startLocation.y, step: step, height: cardHeight, count: visibleSlots) {
                                toggle(goal)
                            }
                            draggedGoalID = nil
                            return
                        }
                        guard abs(value.translation.height) > abs(value.translation.width), abs(value.translation.height) > 48 else { return }
                        guard !goals.isEmpty else { return }
                        let next = (focus + (value.predictedEndTranslation.height < 0 ? 1 : -1) + goals.count) % goals.count
                        withAnimation(spring) { state.focusedGoalID = goals[next].id }
                    })
                .animation(spring, value: drag == 0)
                .animation(spring, value: horizontalDrag == 0)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .animation(spring, value: state.focusedGoalID)
        .animation(spring, value: state.selectedGoalIDs)
        .animation(spring, value: state.starredGoalIDs)
        .onAppear {
            // 数据库排序第一张固定落在 slot 2（第三张、主展示位）。
            if let firstGoal = goals.first {
                state.focusedGoalID = firstGoal.id
            }
        }
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.system(size: 11, weight: .medium))
        }.foregroundStyle(Color(red: 0.31, green: 0.25, blue: 0.33))
    }

    private func cardSurface(_ goal: Goal, isHero: Bool) -> some View {
        let tint = Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue)
        let accent: Color = state.starredGoalIDs.contains(goal.id) ? Color(red: 0.878, green: 0.816, blue: 0.659) : goal.isPeriodic ? Color(red: 0.725, green: 0.800, blue: 0.831) : tint
        return PerspectiveCardShape(topRadius: 29, bottomRadius: 18, bottomInset: 19)
            .fill(LinearGradient(stops: [
                .init(color: accent.opacity(0.99), location: 0),
                .init(color: tint.opacity(0.98), location: 0.47),
                .init(color: tint.opacity(0.94), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .top) {
                PerspectiveCardShape(topRadius: 29, bottomRadius: 18, bottomInset: 19)
                    .fill(LinearGradient(colors: [.white.opacity(0.28), .clear, .black.opacity(0.12)], startPoint: .top, endPoint: .bottom))
            }
    }

    private func goalCard(_ goal: Goal, isHero: Bool, selected: Bool, contentReveal: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(String(format: "%02d", goal.order))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.16), in: Circle())
                if isHero {
                    Text(taskTypeTitle(for: goal))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .foregroundStyle(Color(red: 0.25, green: 0.22, blue: 0.27))
                        .background(taskTypeColor(for: goal), in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                }
                Spacer(minLength: 4)
                starButton(goal)
            }
            .padding(.horizontal, 20).padding(.top, 9)
            .foregroundStyle(.white)

            if contentReveal > 0.01 {
                Text(goal.title)
                    .font(.system(size: isHero ? 30 : 22, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.top, 12)
                    .opacity(contentReveal)
                    .offset(y: (1 - contentReveal) * 10)

                if contentReveal > 0.45 {
                    Spacer(minLength: 8)
                    ZStack {
                        Circle().fill(.white.opacity(0.18)).frame(width: 118, height: 118)
                        Circle().stroke(.white.opacity(0.55), lineWidth: 1.3).frame(width: 64, height: 64)
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white.opacity(0.94))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(contentReveal)
                    Text(state.starredGoalIDs.contains(goal.id) ? "星标：完成不加积分，但增加养成进度" : goal.isPeriodic ? "周期习惯：次日起作为额外名额保留" : goal.summary)
                        .font(.system(size: 16, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.94))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                        .opacity(contentReveal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func starButton(_ goal: Goal) -> some View {
        let starred = state.starredGoalIDs.contains(goal.id)
        let regularCount = goals.filter { state.selectedGoalIDs.contains($0.id) && !state.starredGoalIDs.contains($0.id) && $0.countsTowardQuota }.count
        let canStar = !state.isFirstSelection && state.starredGoalIDs.count < state.starLimit
        return Button {
            withAnimation(spring) {
                if starred {
                    state.starredGoalIDs.remove(goal.id)
                    if goal.countsTowardQuota && regularCount >= 3 { state.selectedGoalIDs.remove(goal.id) }
                } else if canStar {
                    state.starredGoalIDs.insert(goal.id)
                    state.selectedGoalIDs.insert(goal.id)
                }
            }
        } label: {
            Image(systemName: starred ? "star.fill" : "star")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(starred ? Color(red: 1, green: 0.87, blue: 0.44) : .white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(StarPressStyle())
        .contentShape(Circle())
        .disabled(!starred && !canStar)
        .accessibilityLabel(starred ? "取消星标" : "设为星标")
        .accessibilityHint(starred ? "取消星标；普通名额已满时会同时取消选择" : "设为星标并加入今日选择，不占普通名额")
    }

    private func taskTypeTitle(for goal: Goal) -> String {
        state.starredGoalIDs.contains(goal.id) ? "星标" : goal.isPeriodic ? "周期" : "普通"
    }

    private func taskTypeColor(for goal: Goal) -> Color {
        if state.starredGoalIDs.contains(goal.id) {
            return Color(red: 0.878, green: 0.816, blue: 0.659)
        }
        if goal.isPeriodic {
            return Color(red: 0.725, green: 0.800, blue: 0.831)
        }
        return Color(red: 0.769, green: 0.820, blue: 0.733)
    }

    private func cardVisibilityMask(isLastVisible: Bool, height: CGFloat) -> LinearGradient {
        let fadeStart = max(0, 1 - 18 / max(1, height))
        return LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: isLastVisible ? fadeStart : 1),
                .init(color: isLastVisible ? .clear : .white, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func contentReveal(slot: Int, step: CGFloat, height: CGFloat, visibleSlots: Int, viewportHeight: CGFloat) -> CGFloat {
        let currentTop = cardTop(slot: slot, step: step, height: height)
        let nextTop = slot + 1 < visibleSlots
            ? cardTop(slot: slot + 1, step: step, height: height)
            : viewportHeight
        let exposedHeight = min(height, max(0, nextTop - currentTop))
        return min(1, max(0, (exposedHeight - 46) / max(1, height * 0.46)))
    }

    private func dragOffset(slot: Int) -> CGFloat {
        guard !reduceMotion else { return 0 }
        let fraction = CGFloat(slot + 1) / CGFloat(max(1, goals.count))
        return drag * fraction * 0.46
    }

    private func cardTop(slot: Int, step: CGFloat, height: CGFloat) -> CGFloat {
        switch slot {
        case 0...2: CGFloat(slot) * step
        case 3: 2 * step + height * 0.80
        default: 2 * step + height * 0.80 + CGFloat(slot - 3) * max(64, height * 0.27)
        }
    }

    private func goalAt(_ y: CGFloat, step: CGFloat, height: CGFloat, count: Int) -> Goal? {
        guard !goals.isEmpty else { return nil }
        for slot in (0..<count).reversed() {
            let top = cardTop(slot: slot, step: step, height: height)
            if y >= top && y <= top + height {
                let index = (focus - 2 + slot + goals.count) % goals.count
                return goals[index]
            }
        }
        return nil
    }

    private func toggle(_ goal: Goal) {
        let wasSelected = state.selectedGoalIDs.contains(goal.id)
        let regularCount = goals.filter { state.selectedGoalIDs.contains($0.id) && !state.starredGoalIDs.contains($0.id) && $0.countsTowardQuota }.count
        guard wasSelected || !goal.countsTowardQuota || regularCount < 3 else { return }
        withAnimation(spring) {
            if wasSelected { state.selectedGoalIDs.remove(goal.id); state.starredGoalIDs.remove(goal.id) }
            else { state.selectedGoalIDs.insert(goal.id) }
            bounceID = goal.id
        }
        guard !reduceMotion else { bounceID = nil; return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) { bounceID = nil }
        }
    }
}

private struct StarPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle()
                    .fill(.black.opacity(configuration.isPressed ? 0.16 : 0))
                    .overlay {
                        Circle()
                            .stroke(.black.opacity(configuration.isPressed ? 0.26 : 0), lineWidth: 3)
                            .blur(radius: configuration.isPressed ? 2 : 0)
                            .offset(y: configuration.isPressed ? 1.5 : 0)
                    }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.34, dampingFraction: 0.55),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}
