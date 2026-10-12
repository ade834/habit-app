import SwiftUI

struct ExecutionView: View {
    let goal: Goal?
    @Binding var selectedGoals: [Goal]
    @Binding var state: TodayGoalState
    let selectionTransitionNamespace: Namespace.ID
    let onPrompt: (String) -> Void
    @State private var responses: [String: String] = [:]
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(goal?.title ?? "没有可显示的目标")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if let goal {
                    Text(goal.summary).font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.84))
                    HabitExecutionForm(
                        goalID: goal.id,
                        responses: $responses,
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
                        swapChallenge: swapChallenge
                    )
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let canSubmit = !saving && timerReady(for: goal, at: context.date) && formReady(for: goal)
                        Button(saving ? "正在保存…" : actionTitle(for: goal)) { submit(goal) }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(.ultraThinMaterial.opacity(0.72), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.72), lineWidth: 1.2))
                            .disabled(!canSubmit)
                            .opacity(canSubmit ? 1 : 0.55)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.62), .white.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(.white.opacity(0.7), lineWidth: 1.3))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .task(id: goal?.id) { await loadPersistedTaskState() }
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
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                        state.mode = .homeSelected
                    }
                }
        )
        .onDisappear {
            if let goal, goal.id == "H4", let timerID, !timerReady(for: goal) {
                try? NativeDatabase().abandonDisconnectSession(timerID)
            }
        }
    }

    private var tint: Color {
        guard let value = goal?.tint else { return .pink }
        return Color(red: value.red, green: value.green, blue: value.blue)
    }

    private func actionTitle(for goal: Goal) -> String {
        if goal.id == "H1" {
            return reviewCharacterCount >= 100 && Calendar.current.isDateInToday(reviewDate)
                ? goal.completionLabel : "保存复盘"
        }
        if goal.id == "H4" { return "完成断网" }
        if goal.id == "H11" { return travelPlan == nil ? "保存旅行计划" : "完成旅行" }
        return goal.completionLabel
    }

    private func loadPersistedTaskState() async {
        guard let goal else { return }
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
        } catch { show(error) }
    }

    private func startTimer(_ targetSeconds: Int, _ topic: String?) {
        do {
            timerID = try NativeDatabase().startTimer(habitID: goal?.id ?? "", targetSeconds: targetSeconds, focusTopic: topic)
            timerStartedAt = .now
            timerPausedAt = nil
            accumulatedPauseSeconds = 0
        } catch { show(error) }
    }

    private func toggleFocusTimer() {
        guard let sessionID = timerID else { return }
        do {
            if timerPausedAt == nil {
                try NativeDatabase().pauseFocusSession(sessionID)
                timerPausedAt = .now
            } else {
                accumulatedPauseSeconds = try NativeDatabase().resumeFocusSession(sessionID)
                timerPausedAt = nil
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
        let remaining = max(0, disconnectMinutes * 60 - Int(Date.now.timeIntervalSince(startedAt)))
        if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
        guard !Task.isCancelled, timerID == sessionID, timerStartedAt == startedAt else { return }
        submit(goal)
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
                if goal.id == "H11" && travelPlan == nil {
                    // Saving the annual plan is the first step, not task completion.
                    travelPlan = try? await SharedHabitRepository().travelPlanForCurrentYear()
                    notify("旅行计划已保存。完成旅行后再回来提交回顾。")
                } else {
                    // A successful habit submission returns to the selected-habits
                    // deck so the user can immediately start another task.
                    selectedGoals = (try? await SharedHabitRepository().selectedGoals(for: .now)) ?? selectedGoals
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        state.mode = .homeSelected
                    }
                }
            } catch { notify(error.localizedDescription) }
            saving = false
        }
    }

    private func value(_ key: String) -> String { responses[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines) }
    private func show(_ error: Error) { notify(error.localizedDescription) }

    private func notify(_ message: String) {
        onPrompt(message)
    }
}

private struct HabitExecutionForm: View {
    let goalID: String
    @Binding var responses: [String: String]
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch goalID {
            case "H1":
                DatePicker("复盘日期", selection: $reviewDate, in: reviewDateRange, displayedComponents: .date).tint(.white)
                field("今天做了什么决定？", key: "decision")
                field("结果怎么样？", key: "result")
                field("下次想怎么改？", key: "improvement")
                Text("有效字数：\(reviewCharacterCount) / 100（不计标点和空格）")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            case "H2":
                Text("选择当天推荐议题，也可以自行填写；完成 30 分钟，暂停累计不超过 5 分钟。")
                ForEach(HabitTaskCatalog.thinkingTopics(for: .now), id: \.self) { topic in
                    Button { responses["topic"] = topic } label: {
                        HStack(spacing: 12) {
                            Image(systemName: responses["topic"] == topic ? "largecircle.fill.circle" : "circle")
                            Text(topic).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(responses["topic"] == topic ? 0.24 : 0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                timerPanel(title: "专注 30 分钟", duration: 1800, topic: responses["topic"])
            case "H3":
                Text("随机问题 · 题库共 500 条").font(.footnote)
                Text(challenge?.title ?? "正在载入今日挑战…").font(.title3.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 100)
                Button(challenge.map { $0.swapCount < 3 ? "随机换题（还可获取 \(3 - $0.swapCount) 条新问题）" : "在今日抽取的 3 个问题中随机切换" } ?? "正在载入问题…") { swapChallenge() }
                    .foregroundStyle(.white)
                    .disabled(challenge == nil)
            case "H4":
                Text("离开此页面或重新启动 App 会使未完成计时失败；累计连续失败 3 次后冷却 10 小时。")
                if disconnectStatus.consecutiveFailures > 0 {
                    Text(disconnectFailureMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Picker("断网时长", selection: $disconnectMinutes) { ForEach([15, 30, 60], id: \.self) { Text("\($0) 分钟").tag($0) } }.tint(.white).disabled(timerStartedAt != nil || isDisconnectLocked)
                timerPanel(title: "睡前断网", duration: disconnectMinutes * 60, topic: nil)
            case "H5":
                field("联系了谁？（最多 5 字）", key: "primary", limit: 5); field("你们聊了什么？（选填）", key: "secondary")
            case "H6":
                field("清理了哪个信息源？（最多 5 字）", key: "primary", limit: 5); field("为什么它不值得继续占用注意力？（选填）", key: "secondary")
            case "H7":
                field("本周最大的财务发现（最多 5 字）", key: "primary", limit: 5); field("下周想调整什么？（选填）", key: "secondary")
                field("资产投入（选填）", key: "firstValue"); field("消费消耗（选填）", key: "secondValue")
            case "H8":
                field("你拒绝了什么？（最多 5 字）", key: "primary", limit: 5); field("你守住了哪条边界？（选填）", key: "secondary")
            case "H9":
                field("这次输出讲清了什么？（最多 5 字）", key: "primary", limit: 5); field("你能讲给我听听么？", key: "secondary")
            case "H10":
                field("读完了哪本跨界书？（最多 5 字）", key: "primary", limit: 5); field("最重要的一条收获（选填）", key: "secondary")
            case "H11":
                if let travelPlan {
                    Text("本年度计划：\(travelPlan.destination) · \(travelPlan.days) 天\n\(travelPlan.focus)\n\(travelPlan.preparation)")
                    field("旅行结束后的总结", key: "summary")
                } else {
                    field("想去哪里？", key: "destination"); field("计划几天（1–30）", key: "days")
                    field("这趟旅行最想想清楚什么？", key: "focus"); field("准备事项（选填）", key: "preparation")
                }
            case "H12":
                field("今天必须承认的真话（最多 5 字）", key: "primary", limit: 5); field("明天采取什么行动？（选填）", key: "secondary")
            default:
                field("记录内容", key: "primary")
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white.opacity(0.9))
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

    private func field(_ label: String, key: String, limit: Int? = nil) -> some View {
        TextField(
            label,
            text: Binding(get: { responses[key, default: ""] }, set: { value in
                responses[key] = limit.map { String(value.prefix($0)) } ?? value
            }),
            prompt: Text(label).foregroundColor(Color(red: 0.25, green: 0.20, blue: 0.25).opacity(0.48))
        )
        .foregroundColor(Color(red: 0.25, green: 0.20, blue: 0.25).opacity(0.75))
        .tint(Color(red: 0.25, green: 0.20, blue: 0.25).opacity(0.75))
        .textFieldStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.76), lineWidth: 1)
        }
        .keyboardType(key == "days" ? .numberPad : (key.contains("Value") ? .decimalPad : .default))
    }

    @ViewBuilder
    private func timerPanel(title: String, duration: Int, topic: String?) -> some View {
        if let timerStartedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsedTo = timerPausedAt ?? context.date
                let remaining = max(0, duration - Int(elapsedTo.timeIntervalSince(timerStartedAt)) + accumulatedPauseSeconds)
                Text(remaining == 0 ? "计时完成，可以提交" : String(format: "剩余 %02d:%02d", remaining / 60, remaining % 60))
                    .font(.system(.body, design: .monospaced))
            }
            if goalID == "H2", timerSessionID != nil {
                Button(timerPausedAt == nil ? "暂停计时" : "继续计时", action: toggleFocusTimer).foregroundStyle(.white)
                Button("提前结束", action: endFocusTimerEarly)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
            }
        } else {
            let hasRequiredTopic = goalID != "H2" || !(topic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            Button("开始\(title)计时") { startTimer(duration, topic) }
                .foregroundStyle(.white)
                .disabled(!hasRequiredTopic)
                .opacity(hasRequiredTopic ? 1 : 0.55)
                .disabled(goalID == "H4" && disconnectStatus.lockedUntil.map { Date.now < $0 } == true)
        }
    }
}
