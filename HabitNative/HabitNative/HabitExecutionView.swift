import SwiftUI
import UIKit

private enum ExecutionPageStyle {
    static let headerTopInset: CGFloat = 28
    static let headerHeightAllowance: CGFloat = 132
    static let panelMinimumGap: CGFloat = 25
    static let titleSize: CGFloat = 60
    static let titleInk = Color.white.opacity(0.75)
    static let bodyInk = Color(white: 0.23)
}
struct ExecutionView: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSoundSettings.storageKey) private var completionSoundEnabled = true
    let goal: Goal?
    let allGoals: [Goal]
    @Binding var selectedGoals: [Goal]
    @Binding var state: TodayGoalState
    let onPrompt: (String) -> Void
    let onExit: (Goal) -> Void
    @State private var responses: [String: String] = [:]
    @State private var completionSound = AppSoundFeedback()
    @State private var timerSound = AppSoundFeedback()
    @State private var reviewDate = Calendar.current.startOfDay(for: .now)
    @State private var travelPlan: TravelPlanRecord?
    @State private var challenge: HabitChallengeRecord?
    @State private var disconnectStatus = NativeDisconnectStatus(consecutiveFailures: 0, lockedUntil: nil)
    @State private var timerID: Int64?
    @State private var timerStartedAt: Date?
    @State private var timerPausedAt: Date?
    @State private var accumulatedPauseSeconds = 0
    @State private var disconnectMinutes = 30
    @State private var saving = false
    @State private var isCelebrating = false
    @State private var completionButtonPressed = false
    @State private var completionButtonCollapsed = false
    @State private var completionButtonShowsCheck = false
    @State private var completionButtonTitleFaded = false
    @State private var completionButtonHighlighted = false
    @State private var completionButtonTitleCount: Int?
    @State private var completionBurstProgress: CGFloat = 0
    @State private var completionExitProgress: CGFloat = 0
    @State private var contentRevealed = false
    @State private var isClosing = false
    @State private var writingField: ReviewWritingField?
    @State private var foldedRevealFieldKey: String?
    @State private var foldedRevealProgress: CGFloat = 1
    @State private var revealedResponseTextKey: String?

    var body: some View {
        ZStack {
            if goal != nil {
                executionBackdrop
                    .ignoresSafeArea()
                    .opacity(1 - completionExitProgress)
            }
            GeometryReader { viewport in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: closeExecution) {
                            VStack(alignment: .leading, spacing: 0) {
                                Color.clear.frame(height: ExecutionPageStyle.headerTopInset)

                                if let goal {
                                    Text(goal.previewTitle)
                                        .font(.system(size: ExecutionPageStyle.titleSize, weight: .semibold, design: .rounded))
                                        .tracking(-1.8)
                                        .foregroundStyle(colorTheme == .lavender ? .white : ExecutionPageStyle.titleInk)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, -2)
                                    Text(goal.previewSummary)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(.white.opacity(colorTheme == .lavender ? 1 : 0.75))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 10)
                                } else {
                                    Text("没有可显示的目标")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .padding(.top, 52)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isClosing || goal == nil)
                        .accessibilityLabel("收起当前目标，返回已选择的目标")

                        if let goal {
                            Spacer(minLength: ExecutionPageStyle.panelMinimumGap)

                            executionGlassPanel(
                                for: goal,
                                panelHeight: max(
                                    320,
                                    viewport.size.height
                                        - ExecutionPageStyle.headerHeightAllowance
                                        - ExecutionPageStyle.panelMinimumGap * 2
                                )
                            )
                                .opacity(contentRevealed ? 1 : 0)
                                .offset(y: isClosing ? viewport.size.height : (contentRevealed ? 0 : 18))

                            Spacer(minLength: ExecutionPageStyle.panelMinimumGap)
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .scaleEffect(
                    x: 1 - completionExitProgress * 0.55,
                    y: 1 - completionExitProgress * 0.85,
                    anchor: .bottom
                )
                .offset(y: viewport.size.height * 0.88 * completionExitProgress)
            }
        }
        .blur(radius: writingField == nil ? 0 : 12)
        .allowsHitTesting(writingField == nil)
        .accessibilityHidden(writingField != nil)
        .overlayPreferenceValue(ReviewFieldBounds.self) { anchors in
            GeometryReader { geometry in
                if let field = writingField {
                    ReviewTypewriter(
                        field: field,
                        initialText: responses[field.key, default: ""],
                        source: anchors[field.key].map { geometry[$0] } ?? CGRect(x: 36, y: 220, width: geometry.size.width - 72, height: 110),
                        onSave: { value in
                            withAnimation(reduceMotion ? .none : .spring(response: 0.52, dampingFraction: 0.82)) {
                                responses[field.key] = value
                                foldedRevealFieldKey = field.key
                                foldedRevealProgress = 0
                                revealedResponseTextKey = nil
                            }
                            if let goal {
                                ReviewWritingDrafts.save(responses, goal: goal.id, date: goal.id == "H1" ? reviewDate : .now)
                            }
                        },
                        onClose: {
                            withAnimation(.none) { writingField = nil }
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(140))
                                withAnimation(reduceMotion ? .none : .spring(response: 0.82, dampingFraction: 0.68)) {
                                    foldedRevealProgress = 1
                                }
                                if !reduceMotion { try? await Task.sleep(for: .milliseconds(820)) }
                                withAnimation(reduceMotion ? .none : .easeIn(duration: 0.30)) {
                                    revealedResponseTextKey = field.key
                                }
                            }
                        }
                    )
                    .id(field.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(190)) }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .none : .spring(response: 0.52, dampingFraction: 0.84)) {
                contentRevealed = true
            }
        }
        .task(id: goal?.id) {
            await loadPersistedTaskState()
            if goal?.id == "H1" { await loadReviewForSelectedDate() }
        }
        .task(id: reviewDate) { await loadReviewForSelectedDate() }
        .task(id: timerPausedAt) { await monitorFocusPauseLimit() }
        .task(id: timerStartedAt) { await monitorDisconnectCompletion() }
        .task(id: disconnectStatus.lockedUntil) { await refreshDisconnectStatusAfterCooldown() }
        // Native interactive-pop behavior for this state-driven screen: begin at the
        // left edge, then drag right. Vertical scrolling remains available.
        .simultaneousGesture(
            DragGesture(minimumDistance: 16, coordinateSpace: .local)
                .onEnded { value in
                    let translation = value.translation
                    guard value.startLocation.x <= 32,
                          translation.width >= 88,
                          abs(translation.height) < 90 else { return }
                    closeExecution()
                }
        )
        .onDisappear {
            if let goal, goal.id == "H4", let timerID {
                try? NativeDatabase().abandonDisconnectSession(timerID)
            }
        }
    }

    private func closeExecution() {
        guard !isClosing, writingField == nil, let goal else { return }
        if reduceMotion {
            onExit(goal)
            return
        }
        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
            isClosing = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(340))
            guard !Task.isCancelled else { return }
            onExit(goal)
        }
    }

    @ViewBuilder
    private var executionBackdrop: some View {
        if let goal {
            let cardColor = GoalCardAppearance(goal: goal, goals: allGoals, theme: colorTheme).baseColor
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Keep the expanded card in the upper third. Fade into the
                    // live ambient background instead of an opaque canvas.
                    LinearGradient(stops: [
                        .init(color: cardColor, location: 0),
                        .init(color: cardColor, location: 0.62),
                        .init(color: cardColor.opacity(0.62), location: 0.82),
                        .init(color: .clear, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                    .frame(height: geometry.size.height / 3 + 88)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .blur(radius: 14)

                    if goal.cardArtworkAsset != nil {
                        GoalCardArtwork(goal: goal, widthScale: 2.10)
                            .frame(width: geometry.size.width, height: geometry.size.height / 3)
                            .mask {
                                LinearGradient(stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.88),
                                    .init(color: .black.opacity(0.52), location: 0.96),
                                    .init(color: .clear, location: 1)
                                ], startPoint: .top, endPoint: .bottom)
                            }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private func executionGlassPanel(for goal: Goal, panelHeight: CGFloat) -> some View {
        let form = HabitExecutionForm(
            goalID: goal.id,
            responses: $responses,
            foldedRevealFieldKey: $foldedRevealFieldKey,
            foldedRevealProgress: $foldedRevealProgress,
            revealedResponseTextKey: $revealedResponseTextKey,
            reviewDate: $reviewDate,
            travelPlan: travelPlan,
            challenge: challenge,
            disconnectStatus: disconnectStatus,
            timerStartedAt: timerStartedAt,
            timerSessionID: timerID,
            timerPausedAt: timerPausedAt,
            accumulatedPauseSeconds: accumulatedPauseSeconds,
            reviewCharacterCount: reviewCharacterCount,
            disconnectMinutes: $disconnectMinutes,
            startTimer: startTimer,
            toggleFocusTimer: toggleFocusTimer,
            endFocusTimerEarly: endFocusTimerEarly,
            swapChallenge: swapChallenge,
            openWriter: { writingField = $0 }
        )
        let content = VStack(alignment: .leading, spacing: goal.id == "H4" ? 20 : 12) {
            if goal.id == "H4" || goal.id == "H3" {
                form
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: goal.id == "H3" ? .center : .topLeading)
            } else {
                ScrollView(showsIndicators: false) {
                    form
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }

            if goal.id != "H4" {
                Spacer(minLength: 8)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let isDisconnect = goal.id == "H4"
                let disconnectStarted = isDisconnect && timerID != nil
                let disconnectLocked = disconnectStatus.lockedUntil.map { context.date < $0 } ?? false
                let disconnectFailed = isDisconnect && disconnectLocked
                let canSubmit = !saving && timerReady(for: goal, at: context.date) && formReady(for: goal)
                let canTap = isDisconnect ? !disconnectStarted && !disconnectLocked && !saving : canSubmit
                let buttonTitle = isDisconnect
                    ? (disconnectStarted ? "完成断网" : (disconnectFailed ? "明日更美好，晚安 zzZZ" : "开始睡前断网计时"))
                    : (saving && !isCelebrating ? "正在保存…" : actionTitle(for: goal))
                let displayedButtonTitle = completionButtonTitleCount.map { String(buttonTitle.prefix($0)) } ?? buttonTitle
                ZStack {
                    CompletionConfetti(progress: completionBurstProgress)
                        .frame(height: 54)
                        .allowsHitTesting(false)

                    Button {
                        if isDisconnect {
                            startTimer(disconnectMinutes * 60, nil)
                        } else {
                            submit(goal)
                        }
                    } label: {
                        ZStack {
                            Text(displayedButtonTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.08)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(completionButtonTitleFaded ? 0 : 1)
                                .scaleEffect(completionButtonTitleFaded ? 0.94 : 1)
                                .animation(.easeOut(duration: 0.18), value: completionButtonTitleFaded)
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .opacity(completionButtonShowsCheck ? 1 : 0)
                                .scaleEffect(completionButtonShowsCheck ? 1 : 0.55)
                                .animation(.easeOut(duration: 0.20), value: completionButtonShowsCheck)
                        }
                        .frame(maxWidth: completionButtonCollapsed ? 54 : .infinity, minHeight: 54)
                        .background(colorTheme.selectedNavigationBackground, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(colorTheme.selectedNavigationBorder, lineWidth: 1)
                        }
                        .shadow(color: colorTheme.selectedNavigationForeground.opacity(completionButtonHighlighted ? 0.24 : 0), radius: 14, y: 2)
                    }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(colorTheme.selectedNavigationForeground)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
                        .scaleEffect(completionButtonPressed ? 0.94 : (completionButtonHighlighted ? 1.04 : 1))
                        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: completionButtonCollapsed)
                        .animation(.spring(response: 0.40, dampingFraction: 0.70), value: completionButtonHighlighted)
                        .disabled(!canTap)
                        .opacity(disconnectStarted ? 0.68 : 1)
                        .overlay {
                            if !canTap && !isCelebrating && !disconnectStarted && !disconnectFailed {
                                Capsule()
                                    .fill(colorTheme.selectedNavigationBackground.opacity(0.45))
                                    .allowsHitTesting(false)
                            }
                        }
                        .overlay {
                            Text(displayedButtonTitle)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(colorTheme.selectedNavigationForeground.opacity(0.25))
                                .lineLimit(1)
                                .minimumScaleFactor(0.08)
                                .opacity(!canTap && !isCelebrating && !disconnectStarted && !disconnectFailed && !completionButtonTitleFaded ? 1 : 0)
                                .allowsHitTesting(false)
                        }
                        .accessibilityLabel(completionButtonShowsCheck ? "已完成" : buttonTitle)
                }
                .frame(maxWidth: .infinity, minHeight: 54)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: panelHeight, alignment: .topLeading)

        return content
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.20)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.white.opacity(0.08))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.56), lineWidth: 1)
        }
        .padding(.horizontal, timerStartedAt == nil ? 0 : -12)
        .animation(reduceMotion ? .none : .spring(response: 0.62, dampingFraction: 0.86), value: timerStartedAt != nil)
    }

    private func actionTitle(for goal: Goal) -> String {
        if goal.id == "H1" {
            return reviewCharacterCount >= 100 && Calendar.current.isDateInToday(reviewDate)
                ? goal.completionLabel : "保存草稿"
        }
        if goal.id == "H4" { return "完成断网" }
        if goal.id == "H11" { return travelPlan == nil ? "保存旅行计划" : "完成旅行" }
        return goal.completionLabel
    }

    private func loadPersistedTaskState() async {
        guard let goal else { return }
        if goal.id != "H1" {
            responses.merge(ReviewWritingDrafts.load(goal: goal.id, date: .now), uniquingKeysWith: { _, saved in saved })
        }
        if goal.id == "H11" { travelPlan = try? await SharedHabitRepository().travelPlanForCurrentYear() }
        else { travelPlan = nil }
        if goal.id == "H4" { disconnectStatus = (try? NativeDatabase().disconnectStatus()) ?? disconnectStatus }
        if goal.id == "H3" { challenge = try? await SharedHabitRepository().challengeForToday() }
        else { challenge = nil }
        if goal.id == "H2", let timer = try? NativeDatabase().activeTimer(habitID: "H2") {
            timerID = timer.id
            timerStartedAt = timer.startedAt
            timerPausedAt = timer.pausedAt
            accumulatedPauseSeconds = timer.accumulatedPauseSeconds
        } else {
            timerID = nil
            timerStartedAt = nil
            timerPausedAt = nil
            accumulatedPauseSeconds = 0
        }
    }

    private func loadReviewForSelectedDate() async {
        guard goal?.id == "H1" else { return }
        do {
            let entry = try NativeDatabase().reviewEntry(on: reviewDate)
            guard !Task.isCancelled else { return }
            responses["decision"] = entry?.decision ?? ""
            responses["result"] = entry?.result ?? ""
            responses["improvement"] = entry?.improvement ?? ""
            responses.merge(ReviewWritingDrafts.load(goal: "H1", date: reviewDate), uniquingKeysWith: { _, saved in saved })
        } catch { show(error) }
    }

    private func startTimer(_ targetSeconds: Int, _ topic: String?) {
        do {
            let sessionID = try NativeDatabase().startTimer(habitID: goal?.id ?? "", targetSeconds: targetSeconds, focusTopic: topic)
            withAnimation(reduceMotion ? .none : .spring(response: 0.62, dampingFraction: 0.86)) {
                timerID = sessionID
                timerStartedAt = .now
                timerPausedAt = nil
                accumulatedPauseSeconds = 0
            }
            timerSound.play(.timerStart, enabled: completionSoundEnabled)
        } catch { show(error) }
    }

    private func toggleFocusTimer() {
        guard let sessionID = timerID else { return }
        do {
            if timerPausedAt == nil {
                try NativeDatabase().pauseFocusSession(sessionID)
                timerPausedAt = .now
                timerSound.play(.timerPause, enabled: completionSoundEnabled)
            } else {
                accumulatedPauseSeconds = try NativeDatabase().resumeFocusSession(sessionID)
                timerPausedAt = nil
                timerSound.play(.timerResume, enabled: completionSoundEnabled)
            }
        } catch {
            show(error)
            timerID = nil
            timerStartedAt = nil
            timerPausedAt = nil
            accumulatedPauseSeconds = 0
        }
    }

    private func endFocusTimerEarly() {
        guard goal?.id == "H2", let sessionID = timerID else { return }
        do {
            try NativeDatabase().endFocusSessionEarly(sessionID)
            timerID = nil
            timerStartedAt = nil
            timerPausedAt = nil
            accumulatedPauseSeconds = 0
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                state.mode = .homeSelected
            }
        } catch { show(error) }
    }

    private func monitorFocusPauseLimit() async {
        guard goal?.id == "H2", let sessionID = timerID, let pausedAt = timerPausedAt else { return }
        let elapsedPause = max(0, Int(Date.now.timeIntervalSince(pausedAt)))
        let secondsUntilFailure = max(1, 301 - accumulatedPauseSeconds - elapsedPause)
        try? await Task.sleep(for: .seconds(secondsUntilFailure))
        guard !Task.isCancelled, timerID == sessionID, timerPausedAt == pausedAt else { return }

        do {
            guard try NativeDatabase().failExpiredFocusPause(sessionID) else { return }
            timerID = nil
            timerStartedAt = nil
            timerPausedAt = nil
            accumulatedPauseSeconds = 0
            notify("暂停累计超过 5 分钟，本次专注没有完成。")
        } catch {
            show(error)
        }
    }

    private func monitorDisconnectCompletion() async {
        guard let goal, goal.id == "H4", let sessionID = timerID, let startedAt = timerStartedAt else { return }
        let remaining = max(0, Double(disconnectMinutes * 60) - Date.now.timeIntervalSince(startedAt))
        if remaining > 0 { try? await Task.sleep(for: .milliseconds(Int(ceil(remaining * 1_000)) + 1_000)) }
        guard !Task.isCancelled, timerID == sessionID, timerStartedAt == startedAt else { return }
        do {
            guard let active = try NativeDatabase().activeTimer(habitID: "H4"), active.id == sessionID else {
                timerID = nil
                timerStartedAt = nil
                disconnectStatus = try NativeDatabase().disconnectStatus()
                return
            }
        } catch {
            show(error)
            return
        }
        submit(goal)
    }

    private func interruptDisconnectTimer() {
        guard goal?.id == "H4", let sessionID = timerID, !saving else { return }
        do {
            try NativeDatabase().abandonDisconnectSession(sessionID)
            timerID = nil
            timerStartedAt = nil
            disconnectStatus = try NativeDatabase().disconnectStatus()
        } catch { show(error) }
    }

    private func refreshDisconnectStatusAfterCooldown() async {
        guard goal?.id == "H4", let lockedUntil = disconnectStatus.lockedUntil else { return }
        let remaining = lockedUntil.timeIntervalSinceNow
        if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
        guard !Task.isCancelled else { return }
        do { disconnectStatus = try NativeDatabase().disconnectStatus() }
        catch { show(error) }
    }

    private func swapChallenge() {
        Task {
            do {
                let updated = try await SharedHabitRepository().swapChallenge()
                challenge = updated
                notify(updated.swapCount <= 3 ? "已抽取第 \(updated.swapCount) 条今日新问题" : "已在今日抽取的 3 个问题中随机切换")
            } catch { show(error) }
        }
    }

    private func timerReady(for goal: Goal, at date: Date = .now) -> Bool {
        guard goal.id == "H2" || goal.id == "H4" else { return true }
        guard let timerStartedAt else { return false }
        let duration = goal.id == "H2" ? 1800 : disconnectMinutes * 60
        guard timerPausedAt == nil else { return false }
        return date.timeIntervalSince(timerStartedAt) - Double(accumulatedPauseSeconds) >= Double(duration)
    }

    private var reviewCharacterCount: Int {
        (responses["decision", default: ""] + responses["result", default: ""] + responses["improvement", default: ""])
            .unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).contains($0) }
            .count
    }

    private func formReady(for goal: Goal) -> Bool {
        switch goal.id {
        case "H1": return reviewCharacterCount > 0
        case "H2": return timerID != nil || !value("topic").isEmpty
        case "H3": return challenge != nil
        case "H5", "H6", "H7", "H8", "H9", "H10", "H12": return !value("primary").isEmpty
        case "H11":
            let destination = travelPlan?.destination ?? value("destination")
            let focus = travelPlan?.focus ?? value("focus")
            let days = travelPlan?.days ?? Int(value("days")) ?? 0
            return !destination.isEmpty && !focus.isEmpty && (1...30).contains(days)
                && (travelPlan == nil || !value("summary").isEmpty)
        default: return true
        }
    }

    private func submit(_ goal: Goal) {
        let payload: HabitSubmissionPayload
        switch goal.id {
        case "H1":
            payload = .review(decision: value("decision"), result: value("result"), improvement: value("improvement"))
        case "H2":
            guard let timerID else { notify("请先开始 30 分钟专注计时。"); return }
            payload = .focus(sessionID: timerID)
        case "H3":
            guard let challenge else { notify("今日挑战还在载入，请稍等。"); return }
            payload = .challenge(cardIndex: challenge.cardIndex, primaryText: "", secondaryText: "")
        case "H4":
            guard let timerID else { notify("请先开始断网计时。"); return }
            guard timerReady(for: goal) else { return }
            payload = .disconnect(sessionID: timerID)
        case "H11":
            payload = .travelPlan(
                destination: travelPlan?.destination ?? value("destination"),
                days: travelPlan?.days ?? Int(value("days")) ?? 0,
                focus: travelPlan?.focus ?? value("focus"),
                preparation: travelPlan?.preparation ?? value("preparation"),
                summary: value("summary"), completed: travelPlan != nil
            )
        default:
            if goal.id == "H7" {
                for key in ["firstValue", "secondValue"] where !value(key).isEmpty && Double(value(key)) == nil {
                    notify("资产投入和消费消耗只能填写数字。"); return
                }
            }
            payload = .activity(primaryText: value("primary"), secondaryText: value("secondary"), firstValue: Double(value("firstValue")), secondValue: Double(value("secondValue")))
        }
        saving = true
        Task {
            do {
                let date = goal.id == "H1" ? reviewDate : Date.now
                try await SharedHabitRepository().submit(GoalEntry(goalID: goal.id, date: date, payload: payload))
                ReviewWritingDrafts.remove(goal: goal.id, date: date)
                if goal.id == "H11" && travelPlan == nil {
                    // Saving the annual plan is the first step, not task completion.
                    travelPlan = try? await SharedHabitRepository().travelPlanForCurrentYear()
                    notify("旅行计划已保存。完成旅行后再回来提交回顾。")
                } else {
                    // A successful habit submission returns to the selected-habits
                    // deck so the user can immediately start another task.
                    if Calendar.current.isDate(date, inSameDayAs: .now) {
                        state.completedSelectedGoalIDs.insert(goal.id)
                        state.selectedGoalIDs.insert(goal.id)
                    }
                    selectedGoals = (try? await SharedHabitRepository().selectedGoals(for: .now)) ?? selectedGoals
                    if !isClosing {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        await celebrateCompletion()
                        if !isClosing {
                            await collapseCompletedPage()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                state.mode = .homeSelected
                            }
                        }
                    }
                }
            } catch { notify(error.localizedDescription) }
            saving = false
        }
    }

    private func value(_ key: String) -> String { responses[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines) }
    private func show(_ error: Error) { notify(error.localizedDescription) }

    private func celebrateCompletion() async {
        if reduceMotion {
            completionSound.play(.completion, enabled: completionSoundEnabled)
            return
        }
        withAnimation(.easeOut(duration: 0.12)) {
            isCelebrating = true
            completionButtonPressed = true
        }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
            completionButtonPressed = false
            completionButtonCollapsed = true
            completionButtonTitleCount = goal.map { actionTitle(for: $0).count } ?? 1
        }
        while let count = completionButtonTitleCount, count > 1 {
            try? await Task.sleep(for: .milliseconds(42))
            withAnimation(.easeOut(duration: 0.06)) {
                completionButtonTitleCount = count - 1
            }
        }
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.easeOut(duration: 0.18)) {
            completionButtonTitleFaded = true
        }
        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
            completionButtonShowsCheck = true
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.40, dampingFraction: 0.68)) {
            completionButtonHighlighted = true
            completionBurstProgress = 1
        }
        completionSound.play(.completion, enabled: completionSoundEnabled)
        try? await Task.sleep(for: .milliseconds(420))
        withAnimation(.easeIn(duration: 0.62)) {
            completionBurstProgress = 2
        }
        try? await Task.sleep(for: .milliseconds(620))
    }

    private func collapseCompletedPage() async {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.46)) {
            completionExitProgress = 1
        }
        try? await Task.sleep(for: .milliseconds(460))
    }

    private func notify(_ message: String) {
        onPrompt(message)
    }
}

private struct CompletionConfetti: View {
    let progress: CGFloat

    private let colors: [Color] = [
        Color(red: 1.00, green: 0.37, blue: 0.65),
        Color(red: 1.00, green: 0.69, blue: 0.34),
        Color(red: 0.55, green: 0.79, blue: 0.57),
        Color(red: 0.58, green: 0.55, blue: 0.94),
        Color(red: 0.46, green: 0.76, blue: 0.94)
    ]

    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<42, id: \.self) { index in
                let angle = Double(index) * .pi * 2 / 42 - .pi / 2
                let radius = CGFloat(82 + index * 43 % 150)
                let burst = min(progress, 1)
                let fall = max(0, progress - 1)
                let x = CGFloat(cos(angle)) * radius * burst + CGFloat(index % 5 - 2) * 22 * fall
                let y = CGFloat(sin(angle)) * radius * burst + CGFloat(210 + index * 19 % 110) * fall

                Circle()
                    .fill(colors[index % colors.count])
                    .frame(width: CGFloat(9 + index % 6 * 2), height: CGFloat(9 + index % 6 * 2))
                    .opacity(min(progress * 8, 1) * (1 - fall))
                    .position(x: geometry.size.width / 2 + x, y: geometry.size.height / 2 + y)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct VerticalRevealRoundedRect: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let amount = min(1, max(0, progress))
        let revealedHeight = rect.height * amount
        guard revealedHeight > 0.5 else { return Path() }
        let radius = min(16, revealedHeight / 2, rect.width / 2)
        return UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: radius
            ),
            style: .continuous
        ).path(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: revealedHeight))
    }
}

private struct HabitExecutionForm: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let goalID: String
    @Binding var responses: [String: String]
    @Binding var foldedRevealFieldKey: String?
    @Binding var foldedRevealProgress: CGFloat
    @Binding var revealedResponseTextKey: String?
    @Binding var reviewDate: Date
    let travelPlan: TravelPlanRecord?
    let challenge: HabitChallengeRecord?
    let disconnectStatus: NativeDisconnectStatus
    let timerStartedAt: Date?
    let timerSessionID: Int64?
    let timerPausedAt: Date?
    let accumulatedPauseSeconds: Int
    let reviewCharacterCount: Int
    @Binding var disconnectMinutes: Int
    let startTimer: (Int, String?) -> Void
    let toggleFocusTimer: () -> Void
    let endFocusTimerEarly: () -> Void
    let swapChallenge: () -> Void
    let openWriter: (ReviewWritingField) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch goalID {
            case "H1":
                DatePicker("复盘日期", selection: $reviewDate, in: reviewDateRange, displayedComponents: .date)
                    .tint(ExecutionPageStyle.bodyInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.62), lineWidth: 1))
                field("今天做了什么决定？", key: "decision")
                field("结果怎么样？", key: "result")
                field("下次想怎么改？", key: "improvement")
                Text("有效字数：\(reviewCharacterCount) / 100（不计标点和空格）")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            case "H2":
                if timerStartedAt == nil {
                    Text("选择当天推荐议题，也可以自行填写；完成 30 分钟，暂停累计不超过 5 分钟。")
                    ForEach(HabitTaskCatalog.thinkingTopics(for: .now), id: \.self) { topic in
                        Button { responses["topic"] = topic } label: {
                            HStack(spacing: 12) {
                                Image(systemName: responses["topic"] == topic ? "largecircle.fill.circle" : "circle")
                                Text(topic).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(ExecutionPageStyle.bodyInk)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(responses["topic"] == topic ? 0.95 : 0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(responses["topic"] == topic ? 0.8 : 0.32), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    field("我有自己重要、值得想想的事", key: "topic")
                    if !responses["topic", default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("今天我为你推荐的思考是“\(responses["topic", default: ""].trimmingCharacters(in: .whitespacesAndNewlines))”。当然，你也可以有自己重要、值得想想的事。现在让我们开始吧。")
                            .font(.system(size: 15, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                timerPanel(title: "专注 30 分钟", duration: 1800, topic: responses["topic"])
            case "H3":
                Text("随机问题")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                Text(challenge?.title ?? "正在载入今日挑战…")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .shadow(color: .white.opacity(0.22), radius: 12, y: 2)
                Button(challenge.map { $0.swapCount < 3 ? "随机换题（还可获取 \(3 - $0.swapCount) 条新问题）" : "在今日抽取的 3 个问题中随机切换" } ?? "正在载入问题…") { swapChallenge() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.58))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 33)
                    .disabled(challenge == nil)
                Spacer(minLength: 0)
            case "H4":
                VStack(alignment: .leading, spacing: 8) {
                    Text("离开页面或重启 App 计时失败")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color(white: 0.17))
                    Text("累计失败 3 次后冷却 10 小时")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(white: 0.34))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                if disconnectStatus.consecutiveFailures > 0 {
                    Text(disconnectFailureMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(white: 0.26))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Spacer(minLength: 0)
                if timerStartedAt == nil {
                    DisconnectDurationWheel(selection: $disconnectMinutes)
                    .disabled(isDisconnectLocked)
                }
                if timerStartedAt != nil {
                    timerPanel(title: "睡前断网", duration: disconnectMinutes * 60, topic: nil)
                }
                Spacer(minLength: 0)
            case "H5":
                field("联系了谁？", key: "primary"); field("你们聊了什么？（选填）", key: "secondary")
            case "H6":
                field("清理了哪个信息源？", key: "primary"); field("为什么它不值得继续占用注意力？（选填）", key: "secondary")
            case "H7":
                field("本周最大的财务发现", key: "primary"); field("下周想调整什么？（选填）", key: "secondary")
                field("资产投入（选填）", key: "firstValue"); field("消费消耗（选填）", key: "secondValue")
            case "H8":
                field("你拒绝了什么？", key: "primary"); field("你守住了哪条边界？（选填）", key: "secondary")
            case "H9":
                field("这次输出讲清了什么？", key: "primary"); field("你能讲给我听听么？", key: "secondary")
            case "H10":
                field("读完了哪本跨界书？", key: "primary"); field("最重要的一条收获（选填）", key: "secondary")
            case "H11":
                if let travelPlan {
                    Text("本年度计划：\(travelPlan.destination) · \(travelPlan.days) 天\n\(travelPlan.focus)\n\(travelPlan.preparation)")
                    field("旅行结束后的总结", key: "summary")
                } else {
                    field("想去哪里？", key: "destination"); field("计划几天（1–30）", key: "days")
                    field("这趟旅行最想想清楚什么？", key: "focus"); field("准备事项（选填）", key: "preparation")
                }
            case "H12":
                field("今天必须承认的真话", key: "primary"); field("明天采取什么行动？（选填）", key: "secondary")
            default:
                field("记录内容", key: "primary")
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(ExecutionPageStyle.bodyInk)
    }

    private var reviewDateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: .now)
        return (Calendar.current.date(byAdding: .day, value: -3, to: today) ?? today)...today
    }

    private var disconnectFailureMessage: String {
        let count = disconnectStatus.consecutiveFailures
        let time = disconnectStatus.lockedUntil?.formatted(date: .omitted, time: .shortened) ?? "冷却结束"
        return switch count {
        case 1: "手机只是想再陪你一下，可睡前该让它先休息啦。倒计时已重置，你还有2次机会。"
        case 2: "又被手机抓回来一次啦。睡前就别再碰它了，这是最后1次机会；再离开，今晚的任务就失败。"
        default: "手机赢了三回合，今晚的断网任务失败啦。先把它放远一点，\(time)后再来认真挑战。"
        }
    }

    private var isDisconnectLocked: Bool {
        disconnectStatus.lockedUntil.map { Date.now < $0 } ?? false
    }

    private func field(_ label: String, key: String) -> some View {
        let expands = ["secondary", "summary", "preparation", "focus", "decision", "result", "improvement"].contains(key)
        let expandedHeight: CGFloat = goalID == "H1" ? 95 : (goalID == "H11" ? 180 : 140)
        let glassOpacity = expands ? 0.82 : 0.68
        let backgroundReveal = foldedRevealFieldKey == key ? foldedRevealProgress : 1
        let responseTextOpacity = foldedRevealFieldKey == key && revealedResponseTextKey != key ? 0.0 : 1.0

        let savedText = responses[key, default: ""]
        return VStack(alignment: .leading, spacing: 10) {
            Button { openWriter(ReviewWritingField(key: key, title: label)) } label: {
                HStack {
                    Text(label).font(.system(size: 14, weight: .medium))
                    Spacer(minLength: 0)
                    Image(systemName: "pencil.line").font(.system(size: 13))
                }
                .foregroundStyle(Color(white: 0.38))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label)，\(savedText.isEmpty ? "开始输入" : "编辑内容")")
            .accessibilityIdentifier("review.field.\(key)")

            if savedText.isEmpty {
                Button { openWriter(ReviewWritingField(key: key, title: label)) } label: {
                    Text("轻点输入")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.vertical) {
                    Text(savedText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 8)
                }
                .scrollIndicators(.visible)
                .defaultScrollAnchor(.top)
                .opacity(responseTextOpacity)
                .transition(.asymmetric(insertion: .scale(scale: 0.82, anchor: .top).combined(with: .opacity), removal: .opacity))
                .accessibilityLabel("\(label)的已保存内容")
                .accessibilityHint("上下滑动查看全文，轻点上方标题或铅笔编辑")
                .accessibilityIdentifier("review.content.\(key)")
            }
        }
        .font(.custom("Songti SC", size: 18))
        .foregroundStyle(Color(white: 0.18))
        .frame(height: expands ? expandedHeight : 76, alignment: .topLeading)
        .foregroundColor(Color(white: 0.18))
        .tint(ExecutionPageStyle.bodyInk)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background {
            VerticalRevealRoundedRect(progress: backgroundReveal)
                .fill(.ultraThinMaterial)
                .opacity(glassOpacity)
                .overlay {
                    VerticalRevealRoundedRect(progress: backgroundReveal)
                        .fill(.white.opacity(expands ? 0.24 : 0.18))
                }
        }
        .overlay {
            VerticalRevealRoundedRect(progress: backgroundReveal)
                .stroke(.white.opacity(0.52), lineWidth: 1)
        }
        .anchorPreference(key: ReviewFieldBounds.self, value: .bounds) { [key: $0] }
    }

    private func timerPanel(title: String, duration: Int, topic: String?) -> some View {
        let active = timerStartedAt != nil
        return VStack(spacing: 0) {
            if let timerStartedAt {
                if goalID == "H2", let topic = topic?.trimmingCharacters(in: .whitespacesAndNewlines), !topic.isEmpty {
                    Text("本次专注 · \(topic)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.22), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.72), lineWidth: 1))
                        .shadow(color: .white.opacity(0.30), radius: 12, y: 2)
                        .padding(.bottom, 8)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsedTo = timerPausedAt ?? context.date
                    let remaining = max(0, duration - Int(elapsedTo.timeIntervalSince(timerStartedAt)) + accumulatedPauseSeconds)
                    GeometryReader { geometry in
                        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                            .font(.system(size: min(86, geometry.size.width * 0.26), weight: .light, design: .rounded).monospacedDigit())
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .contentTransition(.numericText(countsDown: true))
                            .frame(width: geometry.size.width * 0.64, height: 70)
                            .scaleEffect(x: 2, y: 2.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 240)
                    .accessibilityLabel("剩余 \(remaining / 60) 分 \(remaining % 60) 秒")
                }

                if goalID == "H2", timerSessionID != nil {
                    Button(timerPausedAt == nil ? "暂停计时" : "继续计时", action: toggleFocusTimer)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ExecutionPageStyle.bodyInk)
                        .padding(.horizontal, 30)
                        .frame(height: 48)
                        .glassEffect(.clear.tint(.white.opacity(0.12)).interactive(), in: Capsule())
                        .frame(maxWidth: .infinity)
                    Button("提前结束", action: endFocusTimerEarly)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ExecutionPageStyle.bodyInk.opacity(0.8))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            } else {
                let hasRequiredTopic = goalID != "H2" || !(topic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                Button("开始\(title)计时") { startTimer(duration, topic) }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ExecutionPageStyle.bodyInk)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .disabled(!hasRequiredTopic || isDisconnectLocked)
                    .opacity(hasRequiredTopic && !isDisconnectLocked ? 1 : 0.55)
            }
        }
        .frame(maxWidth: .infinity, minHeight: active ? 340 : 58)
        .background {
            if !active {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.52), lineWidth: 1))
            }
        }
    }
}

private struct DisconnectDurationWheel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: Int
    @GestureState private var dragY: CGFloat = 0

    private let options = [15, 30, 60]
    private let rowSpacing: CGFloat = 72
    private let dividerColor = Color(red: 0.78, green: 0.72, blue: 0.75)

    var body: some View {
        let selectedIndex = options.firstIndex(of: selection) ?? 1

        ZStack {
            divider
                .offset(y: -rowSpacing / 2 + dragY)
            divider
                .offset(y: rowSpacing / 2 + dragY)

            ForEach(-2...2, id: \.self) { position in
                let index = wrapped(selectedIndex + position)
                let distance = CGFloat(position) + dragY / rowSpacing
                let depth = min(2, abs(distance))

                Button("\(options[index]) 分钟") {
                    withAnimation(wheelAnimation) { selection = options[index] }
                }
                .font(.system(size: 50, weight: .semibold, design: .rounded))
                .foregroundStyle(labelColor(for: depth))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 64)
                .scaleEffect(
                    max(0.48, 1 - 0.26 * depth)
                        * (1 + 0.15 * min(1, depth))
                )
                .rotation3DEffect(.degrees(Double(distance) * -17), axis: (x: 1, y: 0, z: 0), perspective: 0.65)
                .opacity(max(0.60, 1 - 0.18 * Double(depth)))
                .offset(y: distance * rowSpacing)
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 238)
        .contentShape(Rectangle())
        .clipped()
        .highPriorityGesture(
            DragGesture(minimumDistance: 10)
                .updating($dragY) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let shift = value.translation.height
                    guard abs(shift) >= 24 else { return }
                    withAnimation(wheelAnimation) {
                        selection = options[wrapped(selectedIndex + (shift < 0 ? 1 : -1))]
                    }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("断网时长")
        .accessibilityValue("\(selection) 分钟")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selection = options[wrapped(selectedIndex + 1)]
            case .decrement: selection = options[wrapped(selectedIndex - 1)]
            @unknown default: break
            }
        }
    }

    private var wheelAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.48, dampingFraction: 0.76)
    }

    private func wrapped(_ index: Int) -> Int {
        (index % options.count + options.count) % options.count
    }

    private func labelColor(for depth: CGFloat) -> Color {
        let clampedDepth = min(1, Double(depth))
        let red = 1 - 0.30 * clampedDepth
        let green = 0.84 - 0.14 * clampedDepth
        let blue = 0.92 - 0.22 * clampedDepth
        let previousBrightnessIncrease = 0.25
        let additionalBrightnessIncrease = 0.15 * clampedDepth
        let brightenedRed = red + (1 - red) * previousBrightnessIncrease
        let brightenedGreen = green + (1 - green) * previousBrightnessIncrease
        let brightenedBlue = blue + (1 - blue) * previousBrightnessIncrease
        return Color(
            red: brightenedRed + (1 - brightenedRed) * additionalBrightnessIncrease,
            green: brightenedGreen + (1 - brightenedGreen) * additionalBrightnessIncrease,
            blue: brightenedBlue + (1 - brightenedBlue) * additionalBrightnessIncrease
        )
    }

    private var divider: some View {
        Circle()
            .fill(dividerColor)
            .frame(width: 5, height: 5)
            .allowsHitTesting(false)
    }
}
