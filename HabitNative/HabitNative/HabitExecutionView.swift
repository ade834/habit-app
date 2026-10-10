import SwiftUI

struct ExecutionView: View {
    let goal: Goal?
    @Binding var selectedGoals: [Goal]
    @Binding var state: TodayGoalState
    let selectionTransitionNamespace: Namespace.ID
    @State private var responses: [String: String] = [:]
    @State private var reviewDate = Calendar.current.startOfDay(for: .now)
    @State private var travelPlan: TravelPlanRecord?
    @State private var challenge: HabitChallengeRecord?
    @State private var timerID: Int64?
    @State private var timerStartedAt: Date?
    @State private var timerPausedAt: Date?
    @State private var accumulatedPauseSeconds = 0
    @State private var disconnectMinutes = 15
    @State private var notice = ""
    @State private var showNotice = false
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
                        timerStartedAt: timerStartedAt,
                        timerSessionID: timerID,
                        timerPausedAt: timerPausedAt,
                        accumulatedPauseSeconds: accumulatedPauseSeconds,
                        disconnectMinutes: $disconnectMinutes,
                        startTimer: startTimer,
                        toggleFocusTimer: toggleFocusTimer,
                        swapChallenge: swapChallenge
                    )
                    Button(saving ? "正在保存…" : actionTitle(for: goal)) { submit(goal) }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(.ultraThinMaterial.opacity(0.72), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.72), lineWidth: 1.2))
                        .disabled(saving || !timerReady(for: goal))
                        .opacity(saving || !timerReady(for: goal) ? 0.55 : 1)
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
        .alert("记录结果", isPresented: $showNotice) { Button("知道了", role: .cancel) {} } message: { Text(notice) }
        .task(id: goal?.id) { await loadPersistedTaskState() }
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
        if goal.id == "H11" { return travelPlan == nil ? "保存旅行计划" : "完成旅行" }
        return goal.completionLabel
    }

    private func loadPersistedTaskState() async {
        guard let goal else { return }
        if goal.id == "H11" { travelPlan = try? await SharedHabitRepository().travelPlanForCurrentYear() }
        else { travelPlan = nil }
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

    private func swapChallenge() {
        Task { challenge = try? await SharedHabitRepository().swapChallenge() }
    }

    private func timerReady(for goal: Goal) -> Bool {
        guard goal.id == "H2" || goal.id == "H4" else { return true }
        guard let timerStartedAt else { return false }
        let duration = goal.id == "H2" ? 1800 : disconnectMinutes * 60
        guard timerPausedAt == nil else { return false }
        return Date.now.timeIntervalSince(timerStartedAt) - Double(accumulatedPauseSeconds) >= Double(duration)
    }

    private func submit(_ goal: Goal) {
        let payload: HabitSubmissionPayload
        switch goal.id {
        case "H1":
            payload = .review(decision: value("decision"), result: value("result"), improvement: value("improvement"))
        case "H2":
            guard let timerID else { notice = "请先开始 30 分钟专注计时。"; showNotice = true; return }
            payload = .focus(sessionID: timerID)
        case "H3":
            guard let challenge else { notice = "今日挑战还在载入，请稍等。"; showNotice = true; return }
            payload = .challenge(cardIndex: challenge.cardIndex, primaryText: "", secondaryText: "")
        case "H4":
            guard let timerID else { notice = "请先开始断网计时。"; showNotice = true; return }
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
                    notice = "资产投入和消费消耗只能填写数字。"; showNotice = true; return
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
                    notice = "旅行计划已保存。完成旅行后再回来提交回顾。"
                    travelPlan = try? await SharedHabitRepository().travelPlanForCurrentYear()
                    showNotice = true
                } else {
                    // A successful habit submission returns to the selected-habits
                    // deck so the user can immediately start another task.
                    selectedGoals = (try? await SharedHabitRepository().selectedGoals(for: .now)) ?? selectedGoals
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        state.mode = .homeSelected
                    }
                }
            } catch { notice = error.localizedDescription }
            saving = false
            if state.mode == .executing(goalID: goal.id) { showNotice = true }
        }
    }

    private func value(_ key: String) -> String { responses[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines) }
    private func show(_ error: Error) { notice = error.localizedDescription; showNotice = true }
}

private struct HabitExecutionForm: View {
    let goalID: String
    @Binding var responses: [String: String]
    @Binding var reviewDate: Date
    let travelPlan: TravelPlanRecord?
    let challenge: HabitChallengeRecord?
    let timerStartedAt: Date?
    let timerSessionID: Int64?
    let timerPausedAt: Date?
    let accumulatedPauseSeconds: Int
    @Binding var disconnectMinutes: Int
    let startTimer: (Int, String?) -> Void
    let toggleFocusTimer: () -> Void
    let swapChallenge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch goalID {
            case "H1":
                DatePicker("复盘日期", selection: $reviewDate, in: reviewDateRange, displayedComponents: .date).tint(.white)
                field("今天做了什么决定？", key: "decision")
                field("结果怎么样？", key: "result")
                field("下次想怎么改？", key: "improvement")
                Text("三项合计达到 100 个非空白、非标点字符才记为完成。")
            case "H2":
                Text("选择当天推荐议题，也可以自行填写；完成 30 分钟，暂停累计不超过 5 分钟。")
                ForEach(HabitTaskCatalog.thinkingTopics(for: .now), id: \.self) { topic in
                    Button(topic) { responses["topic"] = topic }.foregroundStyle(.white)
                }
                field("思考主题（也可自定义）", key: "topic")
                timerPanel(title: "专注 30 分钟", duration: 1800, topic: responses["topic"])
            case "H3":
                Text("每日挑战 \((challenge?.cardIndex ?? 0) + 1) / 500").font(.footnote)
                Text(challenge?.title ?? "正在载入今日挑战…").font(.title3.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 100)
                Button("换一张挑战") { swapChallenge() }.foregroundStyle(.white)
            case "H4":
                Text("离开此页面或重新启动 App 会使未完成计时失败；累计连续失败 3 次后冷却 10 小时。")
                Picker("断网时长", selection: $disconnectMinutes) { ForEach([15, 30, 60], id: \.self) { Text("\($0) 分钟").tag($0) } }.tint(.white).disabled(timerStartedAt != nil)
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

    private func field(_ label: String, key: String, limit: Int? = nil) -> some View {
        TextField(label, text: Binding(get: { responses[key, default: ""] }, set: { value in
            responses[key] = limit.map { String(value.prefix($0)) } ?? value
        }))
        .textFieldStyle(.roundedBorder)
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
            }
        } else {
            Button("开始\(title)计时") { startTimer(duration, topic) }.foregroundStyle(.white)
        }
    }
}
