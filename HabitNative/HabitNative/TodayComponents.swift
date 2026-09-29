import SwiftUI

/// A single stack retains card order while opening, stretching and settling.
struct TodayStackDeckView: View {
    let goals: [Goal]
    @Binding var state: TodayGoalState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = false
    @State private var closing = false
    @GestureState private var drag: CGFloat = 0

    private var focus: Int {
        goals.firstIndex { $0.id == state.focusedGoalID } ?? 0
    }

    private var spring: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.48, dampingFraction: 0.82)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("返回今天")
                Spacer()
                Text("今日目标").font(.system(size: 22, weight: .medium))
                Spacer()
                Text("\(state.selectedGoalIDs.count) / 3")
                    .font(.system(size: 14, weight: .medium)).frame(width: 44)
            }
            .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.29))

            GeometryReader { geometry in
                let cardHeight = min(210.0, geometry.size.height * 0.45)
                let step = min(62.0, max(28.0, (geometry.size.height - cardHeight - 24) / CGFloat(max(1, goals.count - 1))))
                ZStack(alignment: .top) {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        card(goal, index: index)
                            .frame(height: cardHeight)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(.white.opacity(0.65), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.14), radius: 12, y: 8)
                            .scaleEffect(opened || reduceMotion ? 1 - Double(abs(index - focus)) * 0.012 : 0.80, anchor: .bottom)
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : (opened ? -7 : -24) + Double(drag / 24)), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
                            .offset(y: offset(index: index, step: step, height: geometry.size.height, cardHeight: cardHeight))
                            .zIndex(Double(index))
                            .onTapGesture {
                                withAnimation(spring) { state.focusedGoalID = goal.id }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 10)
                    .updating($drag) { value, position, _ in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        position = max(-100, min(100, value.translation.height))
                    }
                    .onEnded { value in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        let projected = value.predictedEndTranslation.height
                        if abs(projected) > 45 {
                            let next = min(goals.count - 1, max(0, focus + (projected < 0 ? 1 : -1)))
                            guard goals.indices.contains(next) else { return }
                            withAnimation(spring) { state.focusedGoalID = goals[next].id }
                        }
                    })
                .animation(spring, value: drag == 0)
            }
        }
        .padding(.horizontal, 24)
        .onAppear { withAnimation(spring) { opened = true } }
    }

    private func offset(index: Int, step: CGFloat, height: CGFloat, cardHeight: CGFloat) -> CGFloat {
        guard opened || reduceMotion else { return height - cardHeight + CGFloat(index - goals.count + 1) * 5 }
        // The focused card exposes its body; following cards compress toward the bottom.
        let base = CGFloat(index) * step
        let reveal = index > focus ? min(80, step * 1.4) : 0
        let compensation = CGFloat(index) / CGFloat(max(1, goals.count - 1)) * min(80, step * 1.4)
        let stretch = reduceMotion ? 0 : drag * (CGFloat(index + 1) / CGFloat(max(1, goals.count))) * 0.55
        return base + reveal - compensation + stretch
    }

    private func card(_ goal: Goal, index: Int) -> some View {
        let selected = state.selectedGoalIDs.contains(goal.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: "%02d", index + 1)).font(.system(size: 12, weight: .medium))
                Text(goal.previewTitle).font(.system(size: 18, weight: .semibold))
                Spacer()
                Button {
                    withAnimation(spring) {
                        state.focusedGoalID = goal.id
                        if selected { state.selectedGoalIDs.remove(goal.id) }
                        else if state.selectedGoalIDs.count < 3 { state.selectedGoalIDs.insert(goal.id) }
                    }
                } label: {
                    Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 24)).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(!selected && state.selectedGoalIDs.count >= 3)
                .accessibilityLabel("\(selected ? "取消" : "选择")\(goal.previewTitle)")
            }
            Text(goal.summary).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text(goal.category).font(.system(size: 12, weight: .medium)).opacity(0.7)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .foregroundStyle(Color(red: 0.25, green: 0.20, blue: 0.25))
        .background {
            Color(red: 0.98, green: 0.95, blue: 0.96)
            Color(red: goal.tint.red, green: goal.tint.green, blue: goal.tint.blue)
                .opacity(selected ? 0.30 : 0.12)
        }
    }

    private func close() {
        guard !closing else { return }
        closing = true
        withAnimation(spring, completionCriteria: .logicallyComplete) {
            opened = false
        } completion: {
            state.mode = .homeUnselected
        }
    }
}
