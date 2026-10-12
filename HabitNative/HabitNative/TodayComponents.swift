import SwiftUI

private struct PerspectiveCardShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var bottomInset: CGFloat

    func path(in rect: CGRect) -> Path {
        let topR = min(topRadius, min(rect.width, rect.height) / 2)
        let inset = min(bottomInset, rect.width * 0.12)
        let bottomR = min(bottomRadius, min(rect.width - inset * 2, rect.height) / 2)
        let safeHeight = max(1, rect.height)
        let topSideInset = inset * topR / safeHeight
        let bottomSideInset = inset * bottomR / safeHeight
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topR, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topSideInset, y: rect.minY + topR),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset + bottomSideInset, y: rect.maxY - bottomR))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - inset - bottomR, y: rect.maxY), control: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + inset + bottomR, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset - bottomSideInset, y: rect.maxY - bottomR),
            control: CGPoint(x: rect.minX + inset, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topSideInset, y: rect.minY + topR))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

/// A looping perspective card stack with a large third card.
struct TodayStackDeckView: View {
    let goals: [Goal]
    @Binding var state: TodayGoalState
    let selectionTransitionNamespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0
    @GestureState private var horizontalDrag: CGFloat = 0
    @State private var draggedGoalID: String?
    @State private var bounceID: String?
    @State private var ruleNotice: String?
    @State private var ruleNoticeID = UUID()
    @Namespace private var noticeMorph

    private var focus: Int {
        goals.firstIndex { $0.id == state.focusedGoalID } ?? 0
    }

    private var spring: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.46, dampingFraction: 0.72)
    }

    // 第三张主卡的轮廓是整组卡片唯一的斜边与圆角基准。
    private var deckCardShape: PerspectiveCardShape {
        PerspectiveCardShape(topRadius: 29, bottomRadius: 18, bottomInset: 19)
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
                if ruleNotice == nil {
                    HStack(spacing: 5) {
                        Text("\(regularCount)").fontWeight(.semibold)
                        Text("/ 3").foregroundStyle(.secondary)
                    }
                    .font(.system(size: 17))
                    .padding(.horizontal, 15).padding(.vertical, 9)
                    .background(.white.opacity(0.78), in: Capsule())
                    .matchedGeometryEffect(id: "rule-notice", in: noticeMorph)
                } else {
                    Color.clear.frame(width: 68, height: 40)
                }
            }
            .foregroundStyle(Color(red: 0.27, green: 0.23, blue: 0.29))
            .padding(.horizontal, 4)
            .padding(.top, 20)

            HStack(spacing: 12) {
                legend("普通", color: normalColor)
                legend("周期", color: periodicColor)
                legend("星标", color: starredColor)
                Spacer(minLength: 0)
                Text("上下滑动浏览").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 5)

            GeometryReader { geometry in
                let cardHeight = min(geometry.size.height * 0.56, 390)
                // 第三张作为主展示位，保留原第二张的露出高度；顶部增加一张。
                let step = max(45, geometry.size.height * 0.094)
                let visibleSlots = min(goals.count, 6)
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
                            .frame(width: geometry.size.width, height: cardHeight, alignment: .top)
                            .background { cardSurface(goal, isHero: isHero) }
                            .overlay(alignment: .topTrailing) {
                                HStack(spacing: 7) {
                                    if isSelected {
                                        selectedBadge
                                            .transition(.scale(scale: 0.72).combined(with: .opacity))
                                    }
                                }
                                .frame(height: 52)
                                .padding(.top, 5)
                                .padding(.trailing, 59)
                            }
                            .clipShape(deckCardShape)
                            .matchedGeometryEffect(
                                id: "selected-goal-card-\(goal.id)",
                                in: selectionTransitionNamespace,
                                properties: .frame,
                                anchor: .center,
                                isSource: state.selectedGoalIDs.contains(goal.id)
                            )
                            .overlay {
                                deckCardShape
                                    .stroke(LinearGradient(colors: [.white.opacity(0.88), .white.opacity(0.25), .white.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.25)
                                    .allowsHitTesting(false)
                            }
                            .scaleEffect(
                                cardScale(slot: slot, visibleSlots: visibleSlots)
                                    * (bounceID == goal.id && !reduceMotion ? 1.025 : 1),
                                anchor: .top
                            )
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : drag / 42), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                            .offset(y: cardTop(slot: slot, step: step, height: cardHeight) + dragOffset(slot: slot))
                            .offset(x: draggedGoalID == goal.id ? max(0, horizontalDrag) : 0)
                            .zIndex(Double(slot))
                            .contentShape(deckCardShape)
                        }
                    }
                    // Keep the interactive star targets above the transformed cards. A button
                    // inside a scaled and offset card can have a different hit area from its icon.
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        let slot = (index - focus + 2 + goals.count) % max(1, goals.count)
                        if slot < visibleSlots {
                            let scale = cardScale(slot: slot, visibleSlots: visibleSlots)
                                * (bounceID == goal.id && !reduceMotion ? 1.025 : 1)
                            starButton(goal)
                                .scaleEffect(scale)
                                .position(
                                    x: geometry.size.width / 2 + (geometry.size.width / 2 - 27) * scale
                                        + (draggedGoalID == goal.id ? max(0, horizontalDrag) : 0),
                                    y: cardTop(slot: slot, step: step, height: cardHeight)
                                        + dragOffset(slot: slot) + 31 * scale
                                )
                                .zIndex(100 + Double(slot))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: max(0, geometry.size.height - 15), alignment: .top)
                .mask(deckBottomFadeMask)
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
        .overlay(alignment: .topTrailing) {
            if let ruleNotice {
                RuleNoticeBanner(message: ruleNotice)
                    .matchedGeometryEffect(id: "rule-notice", in: noticeMorph)
                    .padding(.top, 84)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
                    .zIndex(500)
            }
        }
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

    private var selectedBadge: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().stroke(.white.opacity(0.88), lineWidth: 1.2)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 25, height: 25)
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cardSurface(_ goal: Goal, isHero: Bool) -> some View {
        let tint = Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue)
        return deckCardShape
            .fill(LinearGradient(stops: [
                .init(color: tint.opacity(0.99), location: 0),
                .init(color: tint.opacity(0.97), location: 0.48),
                .init(color: tint.opacity(0.92), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .top) {
                deckCardShape
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

                Text(goal.title)
                    .font(.system(size: isHero ? 17 : 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if isHero {
                    Text(taskTypeTitle(for: goal))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.22))
                        .background(taskTypeColor(for: goal), in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                }
                Spacer(minLength: 4)
                Image(systemName: state.starredGoalIDs.contains(goal.id) ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(state.starredGoalIDs.contains(goal.id) ? Color(red: 1, green: 0.87, blue: 0.44) : .white)
                    .frame(width: 52, height: 52)
                    .hidden()
            }
            .padding(.leading, 20).padding(.trailing, 12).padding(.top, 5)
            .foregroundStyle(.white)
            .zIndex(2)

            if isHero {
                // 主展示位的选择图标前置，避免被下一层卡片遮住。
                ZStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 104, height: 104)
                    Circle().stroke(.white.opacity(0.58), lineWidth: 1.3).frame(width: 58, height: 58)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white.opacity(0.94))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .opacity(contentReveal)

                Text(goal.summary)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .opacity(contentReveal)
            } else {
                Text(goal.summary)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .opacity(contentReveal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func starButton(_ goal: Goal) -> some View {
        let starred = state.starredGoalIDs.contains(goal.id)
        let canStar = !state.isFirstSelection && state.starredGoalIDs.count < state.starLimit
        return StarTapControl(starred: starred, available: starred || canStar) {
            toggleStar(goal)
        }
    }

    private func toggleStar(_ goal: Goal) {
        let starred = state.starredGoalIDs.contains(goal.id)
        let canStar = !state.isFirstSelection && state.starredGoalIDs.count < state.starLimit

        guard starred || canStar else {
            showRuleNotice(
                state.isFirstSelection
                    ? "首次选择需要先完成今日目标，之后才能设置星标。"
                    : "星标习惯最多选择 \(state.starLimit) 个，请先取消一个已有星标。"
            )
            return
        }

        withAnimation(spring) {
            if starred {
                state.starredGoalIDs.remove(goal.id)
                if goal.countsTowardQuota && regularCount >= 3 {
                    state.selectedGoalIDs.remove(goal.id)
                }
            } else if canStar {
                state.starredGoalIDs.insert(goal.id)
                state.selectedGoalIDs.insert(goal.id)
            }
        }
    }

    private func taskTypeTitle(for goal: Goal) -> String {
        state.starredGoalIDs.contains(goal.id) ? "星标" : goal.isPeriodic ? "周期" : "普通"
    }

    private func taskTypeColor(for goal: Goal) -> Color {
        if state.starredGoalIDs.contains(goal.id) {
            return starredColor
        }
        if goal.isPeriodic {
            return periodicColor
        }
        return normalColor
    }

    private var normalColor: Color { Color(red: 0.17, green: 0.72, blue: 0.67) }
    private var periodicColor: Color { Color(red: 0.70, green: 0.58, blue: 0.91) }
    private var starredColor: Color { Color(red: 0.96, green: 0.36, blue: 0.24) }

    private var deckBottomFadeMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.95),
                .init(color: .white.opacity(0.72), location: 0.98),
                .init(color: .clear, location: 1)
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
        return drag * (0.46 + CGFloat(slot) * 0.07)
    }

    private func cardWidthRatio(slot: Int, visibleSlots: Int) -> CGFloat {
        guard visibleSlots >= 3 else { return 1 }
        return switch slot {
        case 0: 0.81
        case 1: 0.9
        default: 1
        }
    }

    private func cardScale(slot: Int, visibleSlots: Int) -> CGFloat {
        let current = cardWidthRatio(slot: slot, visibleSlots: visibleSlots)
        guard !reduceMotion, drag != 0 else { return current }
        let nextSlot = drag < 0 ? max(0, slot - 1) : min(visibleSlots - 1, slot + 1)
        let next = cardWidthRatio(slot: nextSlot, visibleSlots: visibleSlots)
        let progress = min(1, abs(drag) / 90)
        return current + (next - current) * progress
    }

    private func cardTop(slot: Int, step: CGFloat, height: CGFloat) -> CGFloat {
        let fourthTop = step * 2 + height * 0.75
        let fifthTop = fourthTop + height * 0.28
        let sixthTop = fifthTop + height * 0.19
        return switch slot {
        case 0: 0
        case 1: step
        case 2: step * 2
        case 3: fourthTop
        case 4: fifthTop
        default: sixthTop + CGFloat(slot - 5) * max(48, height * 0.18)
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
        guard wasSelected || !goal.countsTowardQuota || state.completedRegularGoalIDs.contains(goal.id) || regularCount < 3 else {
            showRuleNotice("当天最多选择 3 个普通或周期目标，请先取消一个再选择。")
            return
        }
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

    private var regularCount: Int {
        let current = Set(goals.filter {
            state.selectedGoalIDs.contains($0.id) && !state.starredGoalIDs.contains($0.id) && $0.countsTowardQuota
        }.map(\.id))
        return current.union(state.completedRegularGoalIDs).count
    }

    private func showRuleNotice(_ message: String) {
        let id = UUID()
        ruleNoticeID = id
        withAnimation(.spring(response: 1.04, dampingFraction: 0.90, blendDuration: 0.32)) {
            ruleNotice = message
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard ruleNoticeID == id else { return }
            withAnimation(.spring(response: 0.92, dampingFraction: 0.92)) { ruleNotice = nil }
        }
    }
}

private struct StarTapControl: View {
    let starred: Bool
    let available: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: starred ? "star.fill" : "star")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(starred ? Color(red: 1, green: 0.87, blue: 0.44) : .white)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(available ? 1 : 0.42)
            .accessibilityLabel(starred ? "取消星标" : "设为星标")
            .accessibilityHint(starred ? "取消星标；普通名额已满时会同时取消选择" : "设为星标并加入今日选择，不占普通名额")
    }
}

private struct RuleNoticeBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(red: 0.28, green: 0.20, blue: 0.24))
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            LinearGradient(
                colors: [.white.opacity(0.34), .white.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 14, y: 7)
        .accessibilityAddTraits(.isStaticText)
    }
}
