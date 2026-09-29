import SwiftUI

private struct PerspectiveCardShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var bottomInset: CGFloat

    func path(in rect: CGRect) -> Path {
        let topR = min(topRadius, min(rect.width, rect.height) / 2)
        let bottomR = min(bottomRadius, min(rect.width - bottomInset * 2, rect.height) / 2)
        let inset = min(bottomInset, rect.width * 0.12)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topR, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + topR), control1: CGPoint(x: rect.maxX - topR * 0.42, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.minY + topR * 0.42))
        path.addCurve(to: CGPoint(x: rect.maxX - inset - bottomR, y: rect.maxY - bottomR), control1: CGPoint(x: rect.maxX - inset * 0.10, y: rect.minY + rect.height * 0.46), control2: CGPoint(x: rect.maxX - inset - bottomR * 0.20, y: rect.maxY - bottomR * 0.18))
        path.addCurve(to: CGPoint(x: rect.maxX - inset - bottomR, y: rect.maxY), control1: CGPoint(x: rect.maxX - inset - bottomR * 0.55, y: rect.maxY), control2: CGPoint(x: rect.maxX - inset - bottomR * 0.30, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + inset + bottomR, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX + inset + bottomR, y: rect.maxY - bottomR), control1: CGPoint(x: rect.minX + inset + bottomR * 0.30, y: rect.maxY), control2: CGPoint(x: rect.minX + inset + bottomR * 0.55, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + topR), control1: CGPoint(x: rect.minX + inset + bottomR * 0.20, y: rect.maxY - bottomR * 0.18), control2: CGPoint(x: rect.minX + inset * 0.10, y: rect.minY + rect.height * 0.46))
        path.addCurve(to: CGPoint(x: rect.minX + topR, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.minY + topR * 0.42), control2: CGPoint(x: rect.minX + topR * 0.42, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// A bounded, perspective card stack with a large third card.
struct TodayStackDeckView: View {
    let goals: [Goal]
    @Binding var state: TodayGoalState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0
    @GestureState private var horizontalDrag: CGFloat = 0
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
                Text("选择今天的目标")
                    .font(.system(size: 27, weight: .medium))
                    .tracking(-0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Text("\(state.selectedGoalIDs.count)").fontWeight(.semibold)
                    Text("/ 3").foregroundStyle(.secondary)
                }
                .font(.system(size: 17))
                .padding(.horizontal, 15).padding(.vertical, 9)
                .background(.white.opacity(0.78), in: Capsule())
            }
            .foregroundStyle(Color(red: 0.27, green: 0.23, blue: 0.29))
            .padding(.horizontal, 4)
            .padding(.top, 20)

            GeometryReader { geometry in
                let cardHeight = min(geometry.size.height * 0.56, 390)
                let step = max(37, geometry.size.height * 0.105)
                let visibleSlots = min(goals.count, max(1, Int(geometry.size.height / step)))
                ZStack(alignment: .top) {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        let slot = (index - focus + 2 + goals.count) % max(1, goals.count)
                        if slot < visibleSlots {
                        let isHero = slot == min(2, visibleSlots - 1)
                        let isSelected = state.selectedGoalIDs.contains(goal.id)
                        goalCard(goal, index: index, isHero: isHero, selected: isSelected)
                            .frame(height: cardHeight, alignment: .top)
                            .frame(maxWidth: .infinity)
                            .background {
                                PerspectiveCardShape(topRadius: 28, bottomRadius: 22, bottomInset: 6)
                                    .fill(Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue).opacity(isHero ? 0.82 : 0.69))
                            }
                            .overlay {
                                PerspectiveCardShape(topRadius: 28, bottomRadius: 22, bottomInset: 6)
                                    .stroke(.white.opacity(isHero ? 0.78 : 0.52), lineWidth: 1)
                            }
                            .clipShape(PerspectiveCardShape(topRadius: 28, bottomRadius: 22, bottomInset: 6))
                            .shadow(color: .black.opacity(0.22), radius: 12, y: -4)
                            .shadow(color: Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue).opacity(0.22), radius: 9, y: 4)
                            .padding(.horizontal, CGFloat(slot) * 6)
                            .offset(y: CGFloat(slot) * step + dragOffset(slot: slot))
                            .offset(x: slot == focus ? max(0, horizontalDrag) : 0)
                            .scaleEffect(bounceID == goal.id && !reduceMotion ? 1.025 : 1, anchor: .center)
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : drag / 42), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                            .zIndex(Double(slot))
                            .contentShape(Rectangle())
                            .simultaneousGesture(DragGesture(minimumDistance: 12)
                                .updating($horizontalDrag) { value, current, _ in
                                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                    current = min(80, max(0, value.translation.width))
                                }
                                .onEnded { value in
                                    guard abs(value.translation.width) > abs(value.translation.height), value.translation.width > 55 else { return }
                                    toggle(goal)
                                })
                            .onTapGesture { toggle(goal) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(goal.previewTitle)，\(isSelected ? "已选择" : "未选择")")
                            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                            .accessibilityHint("轻点切换选择状态")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 12)
                    .updating($drag) { value, current, _ in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        current = max(-90, min(90, value.translation.height))
                    }
                    .onEnded { value in
                        guard abs(value.translation.height) > abs(value.translation.width), abs(value.translation.height) > 48 else { return }
                        let next = min(max(0, focus + (value.predictedEndTranslation.height < 0 ? 1 : -1)), max(0, goals.count - visibleSlots + 1))
                        guard goals.indices.contains(next) else { return }
                        withAnimation(spring) { state.focusedGoalID = goals[next].id }
                    })
                .animation(spring, value: drag == 0)
                .animation(spring, value: horizontalDrag == 0)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 154)
        .animation(spring, value: state.focusedGoalID)
        .animation(spring, value: state.selectedGoalIDs)
    }

    private func goalCard(_ goal: Goal, index: Int, isHero: Bool, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isHero {
                HStack(spacing: 12) {
                    Text(String(format: "%02d", goal.order))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.16), in: Circle())
                    Text("\(goal.id) · \(goal.category)")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    selectionMark(goal, selected: selected, size: 30)
                }
                .padding(.horizontal, 20).padding(.top, 9)
                .foregroundStyle(.white)
                Text(goal.title)
                    .font(.system(size: 30, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.top, 12)
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
                Text(goal.summary)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                Text("\(goal.growthStage) · 已完成 \(goal.completionCount) 次")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                Text("\(goal.growthStage) · 已完成 \(goal.completionCount) 次")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                Text("\(goal.growthStage) · 已完成 \(goal.completionCount) 次")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                Text("\(goal.growthStage) · 已完成 \(goal.completionCount) 次")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                Spacer(minLength: 12)
            } else {
                HStack(spacing: 12) {
                    Text(String(format: "%02d", goal.order))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.16), in: Circle())
                    Text(goal.previewTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    selectionMark(goal, selected: selected, size: 25)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.top, 9)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue)
                .opacity(isHero ? 0.78 : 0.58)
        }
    }

    private func selectionMark(_ goal: Goal, selected: Bool, size: CGFloat) -> some View {
        ZStack {
            Circle().strokeBorder(.white.opacity(0.92), lineWidth: 1.4)
            if selected {
                Circle().fill(.white.opacity(0.94))
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func dragOffset(slot: Int) -> CGFloat {
        guard !reduceMotion else { return 0 }
        let fraction = CGFloat(slot + 1) / CGFloat(max(1, goals.count))
        return drag * fraction * 0.46
    }

    private func toggle(_ goal: Goal) {
        let wasSelected = state.selectedGoalIDs.contains(goal.id)
        guard wasSelected || state.selectedGoalIDs.count < 3 else { return }
        withAnimation(spring) {
            if wasSelected { state.selectedGoalIDs.remove(goal.id) }
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
