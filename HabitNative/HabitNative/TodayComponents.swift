import SwiftUI

/// A seven-card fan with the active goal fixed in the third display slot.
struct TodayStackDeckView: View {
    let goals: [Goal]
    @Binding var state: TodayGoalState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0
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

            GeometryReader { geometry in
                let proportions: [CGFloat] = [0.075, 0.085, 0.47, 0.12, 0.095, 0.08, 0.075]
                let heights = proportions.map { geometry.size.height * $0 }
                let heroHeight = heights[2]
                ZStack(alignment: .top) {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        let slot = (index - focus + 2 + goals.count) % max(1, goals.count)
                        let isHero = slot == 2
                        let isSelected = state.selectedGoalIDs.contains(goal.id)
                        goalCard(goal, index: index, isHero: isHero, selected: isSelected)
                            .frame(height: heroHeight, alignment: .top)
                            .frame(maxWidth: .infinity)
                            .frame(height: heights[min(slot, heights.count - 1)], alignment: .top)
                            .clipped()
                            .background {
                                RoundedRectangle(cornerRadius: isHero ? 30 : 28, style: .continuous)
                                    .fill(Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue)
                                        .opacity(isHero ? 0.76 : 0.54))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: isHero ? 30 : 28, style: .continuous)
                                    .stroke(.white.opacity(isHero ? 0.78 : 0.48), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: isHero ? 30 : 28, style: .continuous))
                            .shadow(color: Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue).opacity(0.16), radius: isHero ? 15 : 8, y: 5)
                            .offset(y: heights.prefix(slot).reduce(0, +) + dragOffset(slot: slot))
                            .scaleEffect(bounceID == goal.id && !reduceMotion ? 1.025 : 1, anchor: .center)
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : drag / 32), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                            .zIndex(Double(slot))
                            .contentShape(Rectangle())
                            .onTapGesture { toggle(goal) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(goal.previewTitle)，\(isSelected ? "已选择" : "未选择")")
                            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                            .accessibilityHint("轻点切换选择状态")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 12)
                    .updating($drag) { value, current, _ in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        current = max(-90, min(90, value.translation.height))
                    }
                    .onEnded { value in
                        guard abs(value.translation.height) > abs(value.translation.width), abs(value.translation.height) > 48 else { return }
                        let next = (focus + (value.predictedEndTranslation.height < 0 ? 1 : -1) + goals.count) % goals.count
                        guard goals.indices.contains(next) else { return }
                        withAnimation(spring) { state.focusedGoalID = goals[next].id }
                    })
                .animation(spring, value: drag == 0)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .onAppear {
            // The reference composition opens with the first goal in the center slot.
            if let first = goals.first, state.focusedGoalID != first.id {
                withAnimation(spring) { state.focusedGoalID = first.id }
            }
        }
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
