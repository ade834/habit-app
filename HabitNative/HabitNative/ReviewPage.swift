import SwiftUI
import SQLite3
import UIKit

private struct ReviewDay: Identifiable {
    let date: Date
    var completed: [String] = []
    var points = 0
    var note: NativeReviewRecord?
    var activities: [String] = []
    var missed = false

    var id: Date { date }
    var hasRecord: Bool { !completed.isEmpty || note != nil || !activities.isEmpty || missed }
}

private struct ReviewSnapshot {
    var days: [ReviewDay]
    var selectedIDs: Set<String>
    var starredIDs: Set<String>

    var completions: Int { observedDays.reduce(0) { $0 + $1.completed.filter(selectedIDs.contains).count } }
    var points: Int { observedDays.reduce(0) { $0 + $1.points } }
    func count(_ id: String) -> Int { observedDays.reduce(0) { $0 + ($1.completed.contains(id) ? 1 : 0) } }
    private var observedDays: [ReviewDay] { days.filter { $0.date <= Date.now } }
}

private enum ReviewPeriod: String, CaseIterable {
    case week = "本周小结"
    case month = "月度复盘"
}

enum ScrollEdgeVisibility {
    case none
    case top
    case bottom
    case both
}

struct ReviewPage: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let goals: [Goal]
    @State private var period: ReviewPeriod = .week
    @State private var anchor = Date.now
    @State private var snapshot: ReviewSnapshot?
    @State private var error: String?
    @State private var selectedDay: ReviewDay?
    @State private var wheelDays: [ReviewDay] = []
    @Namespace private var periodNamespace
    @Namespace private var weekCalendarNamespace
    @Namespace private var monthCalendarNamespace
    @State private var isWeekCalendarExpanded = false
    @State private var isMonthCalendarExpanded = false
    @State private var pendingAutoExpand: ReviewPeriod? = .week
    @State private var periodControlFrame: CGRect = .zero
    @State private var reviewTitleFrame: CGRect = .zero
    @State private var reviewSubtitleFrame: CGRect = .zero
    @State private var reviewScrollOffset: CGFloat = 0
    @State private var reviewContentFrame: CGRect = .zero
    @State private var daySheetScrollMorphProgress: CGFloat = 0
    @State private var reviewReport: QwenReviewService.MonthlyReports?
    @State private var nextReviewAllowedAt: Date?
    @State private var reviewReportLoading = false
    @State private var analysisStep: MonthlyAnalysisStep = .preparing
    @State private var reportRevealTransition = false
    @AppStorage("review.ai.privacy-consent.v1") private var hasPrivacyConsent = false
    @State private var privacyConsentChecked = false
    @State private var reviewReportError: String?
    @State private var revealedReportCharacters = 0
    @State private var consentSheetPresented = false

    private let ink = Color(red: 0.17, green: 0.15, blue: 0.19)
    private var muted: Color { colorTheme == .lavender ? Color(red: 0.30, green: 0.27, blue: 0.34) : Color(red: 0.43, green: 0.41, blue: 0.46) }
    private var reviewGradient: [Color] { colorTheme == .lavender ? [Color(red: 0.43, green: 0.24, blue: 0.60), Color(red: 0.49, green: 0.30, blue: 0.65), Color(red: 0.38, green: 0.25, blue: 0.51)] : [
        Color(red: 0.77, green: 0.43, blue: 0.80),
        Color(red: 0.91, green: 0.48, blue: 0.63),
        Color(red: 0.98, green: 0.72, blue: 0.61)
    ] }
    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 21) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("复盘")
                            .font(.system(size: 43, weight: .bold, design: .rounded))
                            .foregroundStyle(ink)
                            .opacity(0)
                            .onGeometryChange(for: CGRect.self) { geometry in
                                geometry.frame(in: .global)
                            } action: { reviewTitleFrame = $0 }
                        Text("只读回看每天的习惯完成和记录。")
                            .font(.system(size: 14))
                            .foregroundStyle(muted)
                            .opacity(0)
                            .onGeometryChange(for: CGRect.self) { geometry in
                                geometry.frame(in: .global)
                            } action: { reviewSubtitleFrame = $0 }
                    }
                    .padding(.top, 8)

                    periodControl
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                        action: { periodControlFrame = $0 }

                    if let snapshot {
                        if period == .week {
                            weekHero(snapshot)
                                .task { await autoExpandCalendar(.week) }
                        } else {
                            monthCalendar(snapshot)
                                .task { await autoExpandCalendar(.month) }
                        }
                        summaryCard(snapshot)
                    } else if let error {
                        Text("读取复盘记录失败：\(error)")
                            .font(.subheadline)
                            .foregroundStyle(muted)
                            .padding(22)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(50)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                // Measure actual content, before the trailing navigation clearance.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { reviewContentFrame = $0 }
                .padding(.bottom, 120)
            }
            .frame(width: viewport.size.width, height: viewport.size.height)
            .coordinateSpace(name: "review-scroll")
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                reviewScrollOffset = offset
            }
            .overlay {
                ReviewScrollChrome(
                    titleFrame: reviewTitleFrame,
                    subtitleFrame: reviewSubtitleFrame,
                    bodyFrame: periodControlFrame,
                    contentFrame: reviewContentFrame,
                    scrollOffset: reviewScrollOffset
                )
            }
        }
        .task { load(); loadReviewReport() }
        .task(id: nextReviewAllowedAt) {
            guard let deadline = nextReviewAllowedAt, deadline > .now else { return }
            do {
                try await Task.sleep(for: .seconds(deadline.timeIntervalSinceNow))
                guard !Task.isCancelled else { return }
                nextReviewAllowedAt = .now
            } catch {
                // The task is cancelled when the selected report period changes.
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            load()
            loadReviewReport()
        }
        .onChange(of: period) { _, _ in loadReviewReport() }
        .onChange(of: anchor) { _, _ in loadReviewReport() }
        .sheet(isPresented: $consentSheetPresented) {
            reviewPrivacyConsentSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("复盘分析未完成", isPresented: Binding(
            get: { reviewReportError != nil },
            set: { if !$0 { reviewReportError = nil } }
        )) {
            Button("知道了", role: .cancel) { reviewReportError = nil }
        } message: {
            Text(reviewReportError ?? "请稍后重试")
        }
        .sheet(item: $selectedDay) { day in
            daySheet(day)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedDay?.date) { _, date in
            if date != nil { daySheetScrollMorphProgress = 0 }
        }
    }

    private var periodControl: some View {
        HStack(spacing: 4) {
            ForEach(ReviewPeriod.allCases, id: \.self) { choice in
                Button {
                    let periodChanged = choice != period
                    if periodChanged {
                        isWeekCalendarExpanded = false
                        isMonthCalendarExpanded = false
                        pendingAutoExpand = choice
                        anchor = .now
                        period = choice
                    } else {
                        pendingAutoExpand = nil
                        withAnimation(calendarMorphAnimation) {
                            isWeekCalendarExpanded = choice == .week
                            isMonthCalendarExpanded = choice == .month
                        }
                    }
                    if periodChanged { load() }
                } label: {
                    Text(choice.rawValue)
                        .font(.system(size: 15, weight: period == choice ? .semibold : .medium))
                        .foregroundStyle(period == choice ? ink : muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background {
                            if period == choice {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.92))
                                    .matchedGeometryEffect(id: "review-period-pill", in: periodNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(period == choice ? [.isSelected] : [])
            }
        }
        .padding(5)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white.opacity(0.78), lineWidth: 1))
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.48, dampingFraction: 0.78), value: period)
    }

    private func weekHero(_ data: ReviewSnapshot) -> some View {
        let cornerRadius: CGFloat = isWeekCalendarExpanded ? 28 : 38
        return VStack(alignment: .leading, spacing: isWeekCalendarExpanded ? 25 : 0) {
            weekCalendarHeader
            if isWeekCalendarExpanded {
                weekDateWheel
                weekNavigation
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: reviewGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color(red: 0.80, green: 0.44, blue: 0.68).opacity(0.22), radius: 23, y: 13)
        }
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.66), lineWidth: 1))
        .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    private var weekCalendarHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthName(anchor))
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .matchedGeometryEffect(id: "week-month-title", in: weekCalendarNamespace)
                Text(verbatim: compactWeekRange)
                    .font(.system(size: 17, weight: .semibold))
                    .matchedGeometryEffect(id: "week-range-title", in: weekCalendarNamespace)
            }
            Spacer(minLength: 4)
            Text("\(calendar.component(.day, from: anchor))")
                .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                .padding(.top, 30)
                .matchedGeometryEffect(id: "week-day-title", in: weekCalendarNamespace)
        }
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleWeekCalendar)
        .accessibilityAction(named: isWeekCalendarExpanded ? "收起本周日期" : "展开本周日期", toggleWeekCalendar)
    }

    private var weekDateWheel: some View {
        WeekDateWheel(
            days: wheelDays,
            anchor: anchor,
            onSelect: { date in
                anchor = date
                load()
            },
            onOpen: { selectedDay = $0 }
        )
    }

    private var weekNavigation: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("上一周")
            Spacer()
            Text("点选日期查看当天记录")
                .font(.system(size: 12))
                .opacity(0.84)
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("下一周")
                .disabled(!canMoveForward)
                .opacity(canMoveForward ? 1 : 0.35)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
    }

    private func monthCalendar(_ data: ReviewSnapshot) -> some View {
        let cornerRadius: CGFloat = 28
        return VStack(spacing: isMonthCalendarExpanded ? 15 : 0) {
            if isMonthCalendarExpanded {
                monthCalendarHeader
                monthCalendarGrid(data)
            } else {
                monthCalendarPreview(data)
            }
        }
        .padding(.horizontal, isMonthCalendarExpanded ? 20 : 24)
        .padding(.vertical, isMonthCalendarExpanded ? 20 : 24)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: reviewGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color(red: 0.65, green: 0.31, blue: 0.57).opacity(isMonthCalendarExpanded ? 0.25 : 0), radius: 28, y: 16)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .onTapGesture {
                    if isMonthCalendarExpanded { toggleMonthCalendar() }
                }
        }
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.85), lineWidth: 1))
        .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    private func monthCalendarPreview(_ data: ReviewSnapshot) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 7) {
                Text(monthName(anchor))
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .matchedGeometryEffect(id: "month-name-title", in: monthCalendarNamespace)
                Text(verbatim: "\(calendar.component(.year, from: anchor))年\(calendar.component(.month, from: anchor))月")
                    .font(.system(size: 17, weight: .semibold))
                    .matchedGeometryEffect(id: "month-year-title", in: monthCalendarNamespace)
                Text("本月完成")
                    .font(.system(size: 13, weight: .medium))
                    .opacity(0.82)
            }
            Spacer(minLength: 4)
            Text("\(data.completions)")
                .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                .padding(.top, 30)
                .contentTransition(.numericText())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleMonthCalendar)
        .accessibilityAction(named: "展开月历", toggleMonthCalendar)
    }

    private func monthCalendarGrid(_ data: ReviewSnapshot) -> some View {
        VStack(spacing: 13) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 7) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
                    Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.88)).frame(height: 25)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 42) }
                ForEach(data.days) { day in
                    Button {
                        selectedDay = day
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(.system(size: 14, weight: day.completed.isEmpty ? .medium : .semibold))
                            Text(day.completed.isEmpty ? (day.hasRecord ? "·" : " ") : "\(day.completed.count)项")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            RoundedRectangle(cornerRadius: 13)
                                .fill(LinearGradient(
                                    colors: day.completed.isEmpty
                                        ? [.white.opacity(0.15), .white.opacity(0.09)]
                                        : (colorTheme == .lavender ? [colorTheme.accent, colorTheme.companion] : [Color(red: 0.87, green: 0.16, blue: 0.63), Color(red: 1, green: 0.40, blue: 0.31)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(day.completed.isEmpty ? 0.42 : 0.8), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(dateLabel(day.date))，完成 \(day.completed.count) 项")
                }
            }
        }
    }

    private var monthCalendarHeader: some View {
        HStack(spacing: 0) {
            Button { move(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 32)
            }
            .accessibilityLabel("上个月")
            Spacer()
            VStack(alignment: .center, spacing: 2) {
                Text(monthName(anchor))
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .matchedGeometryEffect(id: "month-name-title", in: monthCalendarNamespace)
                Text(verbatim: "\(calendar.component(.year, from: anchor))年\(calendar.component(.month, from: anchor))月")
                    .font(.system(size: 17, weight: .semibold))
                    .matchedGeometryEffect(id: "month-year-title", in: monthCalendarNamespace)
            }
            Spacer()
            Button { move(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 32)
            }
            .accessibilityLabel("下个月")
            .disabled(!canMoveForward)
            .opacity(canMoveForward ? 1 : 0.35)
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleMonthCalendar)
        .accessibilityAction(named: "收起月历", toggleMonthCalendar)
    }

    private var calendarMorphAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(response: 0.78, dampingFraction: 0.94, blendDuration: 0.28)
    }

    private func autoExpandCalendar(_ choice: ReviewPeriod) async {
        guard pendingAutoExpand == choice else { return }
        do {
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            return
        }
        guard !Task.isCancelled, pendingAutoExpand == choice, period == choice else { return }
        withAnimation(calendarMorphAnimation) {
            isWeekCalendarExpanded = choice == .week
            isMonthCalendarExpanded = choice == .month
        }
        pendingAutoExpand = nil
    }

    private func toggleWeekCalendar() {
        pendingAutoExpand = nil
        withAnimation(calendarMorphAnimation) { isWeekCalendarExpanded.toggle() }
    }

    private func toggleMonthCalendar() {
        pendingAutoExpand = nil
        withAnimation(calendarMorphAnimation) { isMonthCalendarExpanded.toggle() }
    }

    private func summaryCard(_ data: ReviewSnapshot) -> some View {
        let visibleGoals = SharedHabitRepository.catalog.filter { data.selectedIDs.contains($0.id) }
        let leadingCount = visibleGoals.map { data.count($0.id) }.max() ?? 0
        let leaders = visibleGoals.filter { data.count($0.id) == leadingCount && leadingCount > 0 }
        return VStack(alignment: .leading, spacing: 16) {
            Text(period == .week ? (range.start > Date.now ? "这一周尚未开始" : "本周小结") : "本月小结")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(ink)
            Text("完成 \(data.completions) 次 · 获得 \(data.points) 积分")
                .font(.system(size: 15))
                .foregroundStyle(muted)
            Rectangle().fill(ink.opacity(0.09)).frame(height: 1)
            Text("习惯完成次数")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink)
            if visibleGoals.isEmpty {
                Text("先选择一个想照顾的习惯，复盘会从今天开始。")
                    .font(.system(size: 14)).foregroundStyle(muted)
            } else {
                ForEach(visibleGoals) { goal in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.id).font(.system(size: 13, weight: .semibold))
                            Text(goal.title)
                                .font(.system(size: 12))
                                .foregroundStyle(muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if data.starredIDs.contains(goal.id) {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Color.orange)
                        }
                        Text("\(data.count(goal.id))")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(ink)
                    .padding(.vertical, 3)
                }
                Rectangle().fill(ink.opacity(0.09)).frame(height: 1)
                if !leaders.isEmpty {
                    insight("最容易坚持", leaders.map(\.title).joined(separator: "、"))
                }
                if period == .month {
                    let hard = visibleGoals.filter {
                        !data.starredIDs.contains($0.id) &&
                        (!["H5", "H7", "H10", "H11"].contains($0.id) || isClosedMonth)
                    }
                    if let least = hard.map({ data.count($0.id) }).min() {
                        insight("最容易放弃", hard.filter { data.count($0.id) == least }.map(\.title).joined(separator: "、"))
                    }
                    let areas = leaders.compactMap { ["H1": "觉察与决策", "H2": "专注与思考", "H3": "勇气与行动", "H4": "边界与休息"][$0.id] }
                    insight("它正在帮助你", areas.isEmpty ? "慢慢找到自己的节奏" : Array(Set(areas)).sorted().joined(separator: "、"))
                    Text(categoryInsight(data, goals: visibleGoals))
                        .font(.system(size: 13))
                        .foregroundStyle(muted)

                }
            }
            aiReportSection(data)
            Text(encouragement(data.completions))
                .font(.system(size: 13))
                .foregroundStyle(muted)
                .padding(.top, 3)
        }
        .padding(21)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.85), lineWidth: 1))
    }

    @ViewBuilder
    private func aiReportSection(_ data: ReviewSnapshot) -> some View {
        Rectangle().fill(ink.opacity(0.09)).frame(height: 1).padding(.vertical, 3)
        Text(period == .week ? "本周复盘分析" : "月复盘分析")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(ink)

        if !cooldownIsActive || reviewReport == nil {
            reviewRequestButton(data)
        }

        if reviewReportLoading || reportRevealTransition {
            VStack(alignment: .leading, spacing: 10) {
                if reviewReportLoading && analysisStep != .complete {
                    ReviewWaitingMessage(color: muted)
                } else {
                    Text("分析完成")
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                }
                ReviewAIScanningProgress(
                    tint: reviewGradient.first ?? .purple,
                    progress: reviewReportLoading ? analysisStep.progress : 1,
                    progressLimit: reviewReportLoading ? analysisStep.progressLimit : 1,
                    allowsVirtualProgress: reviewReportLoading && analysisStep != .complete
                )
                    .frame(height: 7)
                    .accessibilityLabel("分析步骤：\(analysisStep.title(for: period))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
            .transition(.opacity)
        } else if let reviewReport {
            VStack(alignment: .leading, spacing: 10) {
                Text("分析报告")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ink)
                Text(String(reviewReport.analysis.prefix(revealedReportCharacters)))
                    .font(.system(size: 13))
                    .foregroundStyle(muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeIn(duration: 0.22), value: revealedReportCharacters)
                Text("鼓励与建议")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ink)
                    .padding(.top, 5)
                Text(reviewReport.encouragement)
                    .font(.system(size: 13))
                    .foregroundStyle(muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            .onAppear { revealAnalysis(reviewReport.analysis) }
        }
    }

    private func reviewRequestButton(_ data: ReviewSnapshot) -> some View {
        let cooldownActive = nextReviewAllowedAt.map { Date.now < $0 } ?? false
        let noMonthlyCompletions = period == .month && data.completions == 0
        let hasExistingReport = reviewReport != nil
        return VStack(spacing: 7) {
            Button {
                if hasPrivacyConsent {
                    Task { await requestReviewReport() }
                } else {
                    privacyConsentChecked = false
                    consentSheetPresented = true
                }
            } label: {
                Label(
                    hasExistingReport ? "发送新的报告" : (period == .week ? "获得本周复盘报告" : "获得月度分析报告"),
                    systemImage: "sparkles"
                )
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(LinearGradient(colors: reviewGradient, startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(reviewReportLoading || cooldownActive || noMonthlyCompletions)
            if cooldownActive, let nextReviewAllowedAt {
                Text("可在\(nextReviewAllowedAt.formatted(date: .numeric, time: .omitted))后再次生成")
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
            } else if noMonthlyCompletions && !hasExistingReport {
                Text("本月还没有已完成的任务记录。")
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
            }
        }
    }

    private var cooldownIsActive: Bool {
        nextReviewAllowedAt.map { Date.now < $0 } ?? false
    }

    private func revealAnalysis(_ analysis: String) {
        guard !reduceMotion else {
            revealedReportCharacters = analysis.count
            return
        }
        revealedReportCharacters = 0
        Task { @MainActor in
            // Allow the completion stage to reach and hold at 100% before fading it.
            try? await Task.sleep(for: .milliseconds(550))
            withAnimation(.easeOut(duration: 0.35)) { reportRevealTransition = true }
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(.easeOut(duration: 0.35)) { reportRevealTransition = false }
            try? await Task.sleep(for: .milliseconds(220))
            for count in stride(from: 1, through: analysis.count, by: 5) {
                revealedReportCharacters = min(count, analysis.count)
                try? await Task.sleep(for: .milliseconds(24))
            }
            revealedReportCharacters = analysis.count
        }
    }

    private var reviewPrivacyConsentSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("发送前请阅读").font(.system(size: 23, weight: .semibold)).foregroundStyle(ink)
            ScrollView {
                Text("处理者：本 App 运营者（联系方式请见 App Store 产品页或本政策发布页）。生成周度或月度复盘时，App 会将所选周期内的习惯名称、完成日期、养成物活动与阶段，以及任务卡片中填写的复盘文字发送给阿里云百炼服务，调用 qwen3.7-flash 生成分析和建议。此功能为可选功能；首次勾选同意并点击“发送并生成报告”后，后续周度和月度复盘不再重复征求同意。数据仅在你主动生成报告时发送。拒绝或取消不影响使用其他功能。\n\n阿里云作为服务提供方处理请求内容。阿里云说明，百炼按量付费 API 不会将输入输出用于模型训练；实际处理仍受所用产品方案、地域、服务条款和隐私规则约束。请求会经 App 服务端转发，服务端须按约定仅为完成分析处理，并采取访问控制、传输保护等措施。分析结果保存在本机数据库；本地开发代理地址仅用于开发，正式发布前必须改为受控的生产服务端。\n\n请勿提交身份证件、联系方式、账户信息、健康或其他敏感个人信息，也不要填写他人的个人信息。若复盘文字包含敏感个人信息，提交前请自行删除；依法需要时应另行取得单独同意并说明必要性及对权益的影响。AI 输出可能不准确，不构成医疗、心理、法律或其他专业意见。\n\n你可以在发送前取消。发送后可停止使用此功能；已保存在本机的报告可通过 App 内清除复盘数据的功能删除（若尚未提供该入口，请在正式发布前实现）。如需查询、更正、复制或删除已发送数据，或撤回同意，请通过本政策发布页所列联系方式提出。撤回不影响撤回前基于同意进行的处理。服务端及服务提供方仅在完成请求、保障安全或遵守法律所需期限内保留相关数据，并在期限届满后删除或匿名化；具体留存期限及服务端删除机制须由运营者依据实际部署落实并在上线版本中核实。\n\n本说明适用于周度与月度 AI 复盘。若服务接收方、数据类型、用途或保存方式发生变化，App 会更新说明并在需要时重新征求同意。")
                    .font(.system(size: 14)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
            }
            Toggle(isOn: $privacyConsentChecked) {
                Text("我已阅读，并同意将所选周期的任务与养成物记录发送给阿里云千问进行分析。")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(ink)
            }
            .tint(reviewGradient.first ?? .purple)
            Button {
                consentSheetPresented = false
                hasPrivacyConsent = true
                Task { await requestReviewReport() }
            } label: {
                Text("发送并生成报告")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(LinearGradient(colors: reviewGradient, startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
            .disabled(!privacyConsentChecked || reviewReportLoading)
            .opacity(privacyConsentChecked ? 1 : 0.5)
            Button("取消", role: .cancel) { consentSheetPresented = false }
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationBackground(.regularMaterial)
    }

    @MainActor
    private func requestReviewReport() async {
        reviewReportLoading = true
        analysisStep = .preparing
        reportRevealTransition = false
        reviewReportError = nil
        defer { reviewReportLoading = false }
        do {
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(700)) }
            let content = try period == .week ? weekReportInput(in: range) : monthReportInput(in: range)
            guard !content.isEmpty else {
                reviewReportError = period == .week ? "本周没有可分析的记录。" : "本月没有可分析的任务文字记录。"
                return
            }
            analysisStep = .sending
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(250)) }
            let reports = try await (period == .week ? QwenReviewService.analyzeWeek(content) : QwenReviewService.analyzeMonth(content))
            analysisStep = .organizing
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(300)) }
            if period == .week {
                try NativeDatabase().saveWeeklyAIReport(analysis: reports.analysis, encouragement: reports.encouragement, week: range.start)
            } else {
                try NativeDatabase().saveMonthlyAIReport(analysis: reports.analysis, encouragement: reports.encouragement, month: anchor)
            }
            reviewReport = reports
            let cooldown = period == .week ? 7 : 30
            nextReviewAllowedAt = Calendar.current.date(byAdding: .day, value: cooldown, to: Date.now)
            saveReviewRequestDate(Date.now)
            analysisStep = .complete
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(700)) }
            reviewReportLoading = false
            revealAnalysis(reports.analysis)
        } catch {
            reviewReportError = error.localizedDescription
        }
    }

    private func loadReviewReport() {
        do {
            let database = NativeDatabase()
            let key: String
            let saved: (analysis: String, encouragement: String, updatedAt: Date)?
            if period == .week {
                key = Self.weekKey(range.start)
                saved = try database.reviewReport(table: "weekly_ai_reports", keyColumn: "week_key", key: key)
            } else {
                key = Self.monthKey(anchor)
                saved = try database.reviewReport(table: "monthly_ai_reports", keyColumn: "month_key", key: key)
            }
            reviewReport = saved.map { QwenReviewService.MonthlyReports(analysis: $0.analysis, encouragement: $0.encouragement) }
            revealedReportCharacters = reviewReport?.analysis.count ?? 0
            let storedRequestDate = UserDefaults.standard.object(forKey: reviewRequestDateKey(for: key)) as? Date
            let requestDate = storedRequestDate ?? saved?.updatedAt
            let cooldown = period == .week ? 7 : 30
            nextReviewAllowedAt = requestDate.flatMap { Calendar.current.date(byAdding: .day, value: cooldown, to: $0) }
        } catch {
            reviewReportError = error.localizedDescription
        }
    }

    private func reviewRequestDateKey(for key: String) -> String {
        "review.ai.last-request.\(period == .week ? "week" : "month").\(key)"
    }

    private func saveReviewRequestDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: reviewRequestDateKey(for: period == .week ? Self.weekKey(range.start) : Self.monthKey(anchor)))
    }

    private static func monthKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    private static func weekKey(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: date)
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: calendar.startOfDay(for: date)) ?? date
        let parts = calendar.dateComponents([.year, .month, .day], from: monday)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func weekReportInput(in interval: DateInterval) throws -> String {
        var records = [try monthReportInput(in: interval)]
        do {
            let referenceDate = min(interval.end.addingTimeInterval(-1), Date.now)
            let garden = try HabitGardenLiveSnapshot.read(at: referenceDate)
            let current = SharedHabitRepository.catalog.map { goal -> String in
                let stage = GardenStageLevel(rawValue: max(-3, min(3, garden.growth[goal.id, default: 0])))?.titleZh ?? "未知阶段"
                return "\(goal.id)｜\(goal.title)：养成物当前阶段 \(stage)，累计完成 \(garden.completions[goal.id, default: 0]) 次，累计积分 \(garden.points[goal.id, default: 0])"
            }.joined(separator: "\n")
            records.append("【养成物当前状态；仅作背景，不代表本周变化】\n" + current)
        }
        return records.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private func monthReportInput(in interval: DateInterval) throws -> String {
        let start = dateKey(interval.start)
        let end = dateKey(interval.end)
        var records: [String] = []
        try NativeDatabase().withConnection { db in
            let completions = try NativeDatabase.prepare(
                "SELECT habit_id, local_date, COUNT(*) FROM habit_logs WHERE local_date >= ? AND local_date < ? GROUP BY habit_id, local_date ORDER BY habit_id, local_date",
                in: db
            )
            defer { sqlite3_finalize(completions) }
            try bind([start, end], to: completions)
            var completionRows: [String] = []
            while sqlite3_step(completions) == SQLITE_ROW {
                let id = sqlite3_column_text(completions, 0).map { String(cString: $0) } ?? ""
                let day = sqlite3_column_text(completions, 1).map { String(cString: $0) } ?? ""
                let count = sqlite3_column_int(completions, 2)
                guard let goal = SharedHabitRepository.catalog.first(where: { $0.id == id }) else { continue }
                completionRows.append("\(goal.category)｜\(goal.title)（\(id)）：\(day)，完成\(count)次")
            }
            if !completionRows.isEmpty {
                records.append("【任务标题与完成事实；仅代表记录为完成，不单独证明填写质量或投入程度】\n" + completionRows.joined(separator: "\n"))
            }

            let reviews = try NativeDatabase.prepare(
                "SELECT local_date, decision, result, improvement FROM review_entries WHERE local_date >= ? AND local_date < ? ORDER BY local_date",
                in: db
            )
            defer { sqlite3_finalize(reviews) }
            try bind([start, end], to: reviews)
            while sqlite3_step(reviews) == SQLITE_ROW {
                let day = sqlite3_column_text(reviews, 0).map { String(cString: $0) } ?? ""
                let values = (1...3).map { sqlite3_column_text(reviews, Int32($0)).map { String(cString: $0) } ?? "" }
                records.append("\(day)｜每日百字复盘：决定：\(values[0])；结果：\(values[1])；下次改进：\(values[2])")
            }
            let activities = try NativeDatabase.prepare(
                "SELECT habit_id, primary_text, secondary_text, first_value, second_value, completed_at FROM habit_activity_entries ORDER BY completed_at",
                in: db
            )
            defer { sqlite3_finalize(activities) }
            while sqlite3_step(activities) == SQLITE_ROW {
                let stamp = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(activities, 5)))
                guard stamp >= interval.start, stamp < interval.end else { continue }
                let date = dateKey(stamp)
                let id = sqlite3_column_text(activities, 0).map { String(cString: $0) } ?? ""
                let first = sqlite3_column_text(activities, 1).map { String(cString: $0) } ?? ""
                let second = sqlite3_column_text(activities, 2).map { String(cString: $0) } ?? ""
                let numbers = [3, 4].compactMap { index -> String? in
                    let column = Int32(index)
                    guard sqlite3_column_type(activities, column) != SQLITE_NULL else { return nil }
                    return String(sqlite3_column_double(activities, column))
                }.joined(separator: ", ")
                let title = SharedHabitRepository.catalog.first(where: { $0.id == id })?.title ?? id
                records.append("\(date)｜\(title)：\(first)；\(second)\(numbers.isEmpty ? "" : "；数值：\(numbers)")")
            }
            let timers = try NativeDatabase.prepare(
                "SELECT habit_id, focus_topic, started_at, ended_at, status FROM timer_sessions WHERE status IN ('completed', 'failed') ORDER BY started_at",
                in: db
            )
            defer { sqlite3_finalize(timers) }
            while sqlite3_step(timers) == SQLITE_ROW {
                let timestampColumn: Int32 = sqlite3_column_type(timers, 3) == SQLITE_NULL ? 2 : 3
                let stamp = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(timers, timestampColumn)))
                guard stamp >= interval.start, stamp < interval.end else { continue }
                let date = dateKey(stamp)
                let id = sqlite3_column_text(timers, 0).map { String(cString: $0) } ?? ""
                let topic = sqlite3_column_text(timers, 1).map { String(cString: $0) } ?? ""
                let status = sqlite3_column_text(timers, 4).map { String(cString: $0) } ?? ""
                let state = status == "completed" ? "完成计时" : "计时中断/未完成"
                records.append("\(date)｜\(SharedHabitRepository.catalog.first(where: { $0.id == id })?.title ?? id)：系统记录：\(state)；用户填写议题：\(topic.isEmpty ? "（未填写）" : topic)")
            }
        }
        return records.joined(separator: "\n")
    }

    private func bind(_ values: [String], to statement: OpaquePointer) throws {
        for (index, value) in values.enumerated() {
            let result = value.withCString {
                sqlite3_bind_text(statement, Int32(index + 1), $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            guard result == SQLITE_OK else { throw NativeDatabaseError.unavailable("无法读取月度报告数据。") }
        }
    }

    private func insight(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(muted)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
    }

    private func daySheet(_ day: ReviewDay) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text(dateLabel(day.date)).font(.system(size: 24, weight: .semibold)).opacity(reduceMotion ? 1 : 0)
                Text("完成 \(day.completed.count) 项 · 获得 \(day.points) 积分")
                    .foregroundStyle(muted)
                if day.completed.isEmpty { Text("当天没有有效完成").foregroundStyle(muted) }
                ForEach(day.completed, id: \.self) { id in
                    Text("\(id)  \(SharedHabitRepository.catalog.first(where: { $0.id == id })?.title ?? id)")
                }
                if let note = day.note {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("H1 复盘内容").font(.headline)
                        Text("决定：\(note.decision)\n结果：\(note.result)\n下次：\(note.improvement)")
                    }
                }
                ForEach(day.activities, id: \.self) { text in Text(text) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(25)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            min(1, max(0, (geometry.contentOffset.y + geometry.contentInsets.top) / 140))
        } action: { _, progress in
            daySheetScrollMorphProgress = progress
        }
        .overlay {
            if !reduceMotion {
                ScrollMorphChrome(title: dateLabel(day.date), progress: daySheetScrollMorphProgress, startY: 34, leadingInset: 25, titleColor: ink)
            }
        }
        .foregroundStyle(ink)
    }

    private var range: DateInterval {
        if period == .month { return calendar.dateInterval(of: .month, for: anchor)! }
        let weekday = calendar.component(.weekday, from: anchor)
        let start = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: calendar.startOfDay(for: anchor))!
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
    }

    private var leadingBlanks: Int { (calendar.component(.weekday, from: range.start) + 5) % 7 }
    private var compactWeekRange: String {
        let end = calendar.date(byAdding: .day, value: -1, to: range.end)!
        let startMonth = calendar.component(.month, from: range.start)
        let endMonth = calendar.component(.month, from: end)
        let startDay = calendar.component(.day, from: range.start)
        let endDay = calendar.component(.day, from: end)
        if startMonth == endMonth {
            return "\(startMonth)月\(startDay)—\(endDay)日"
        }
        return "\(startMonth)月\(startDay)日—\(endMonth)月\(endDay)日"
    }
    private var canMoveForward: Bool { period == .week || range.end <= Date.now }
    private var isClosedMonth: Bool { calendar.dateInterval(of: .month, for: .now)!.start > range.start }

    private func move(_ delta: Int) {
        guard delta < 0 || canMoveForward else { return }
        anchor = calendar.date(byAdding: period == .week ? .day : .month, value: period == .week ? delta * 7 : delta, to: anchor) ?? anchor
        load()
    }

    private func load() {
        do {
            snapshot = try Self.read(range: range, calendar: calendar)
            if period == .week {
                let start = calendar.date(byAdding: .day, value: -5, to: calendar.startOfDay(for: anchor))!
                let end = calendar.date(byAdding: .day, value: 11, to: start)!
                wheelDays = try Self.read(range: DateInterval(start: start, end: end), calendar: calendar).days
            }
            error = nil
        } catch {
            snapshot = nil
            self.error = error.localizedDescription
        }
    }

    private static func read(range: DateInterval, calendar: Calendar) throws -> ReviewSnapshot {
        let start = dateKey(range.start)
        let end = dateKey(range.end)
        var days: [ReviewDay] = []
        var cursor = range.start
        while cursor < range.end {
            days.append(ReviewDay(date: cursor))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        let index = Dictionary(uniqueKeysWithValues: days.enumerated().map { (dateKey($0.element.date), $0.offset) })
        var selectedIDs: Set<String> = []
        var starredIDs: Set<String> = []
        try NativeDatabase().withConnection { db in
            let selected = try NativeDatabase.prepare("SELECT habit_id, is_starred FROM habit_selections", in: db)
            defer { sqlite3_finalize(selected) }
            while sqlite3_step(selected) == SQLITE_ROW {
                guard let raw = sqlite3_column_text(selected, 0) else { continue }
                let id = String(cString: raw)
                selectedIDs.insert(id)
                if sqlite3_column_int(selected, 1) != 0 { starredIDs.insert(id) }
            }

            let logs = try NativeDatabase.prepare("SELECT l.habit_id, l.local_date, COALESCE(p.amount, 0) FROM habit_logs l LEFT JOIN point_transactions p ON p.habit_log_id=l.id WHERE l.local_date >= '\(start)' AND l.local_date < '\(end)' ORDER BY l.local_date, l.id", in: db)
            defer { sqlite3_finalize(logs) }
            while sqlite3_step(logs) == SQLITE_ROW {
                guard let rawID = sqlite3_column_text(logs, 0), let rawDate = sqlite3_column_text(logs, 1), let dayIndex = index[String(cString: rawDate)] else { continue }
                days[dayIndex].completed.append(String(cString: rawID))
                days[dayIndex].points += Int(sqlite3_column_int(logs, 2))
            }

            let reviews = try NativeDatabase.prepare("SELECT local_date, decision, result, improvement FROM review_entries WHERE local_date >= '\(start)' AND local_date < '\(end)'", in: db)
            defer { sqlite3_finalize(reviews) }
            while sqlite3_step(reviews) == SQLITE_ROW {
                guard let rawDate = sqlite3_column_text(reviews, 0), let dayIndex = index[String(cString: rawDate)] else { continue }
                func value(_ column: Int32) -> String { sqlite3_column_text(reviews, column).map { String(cString: $0) } ?? "" }
                days[dayIndex].note = NativeReviewRecord(decision: value(1), result: value(2), improvement: value(3))
            }

            let activities = try NativeDatabase.prepare("SELECT habit_id, primary_text, secondary_text, completed_at FROM habit_activity_entries", in: db)
            defer { sqlite3_finalize(activities) }
            while sqlite3_step(activities) == SQLITE_ROW {
                let date = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(activities, 3)))
                guard let dayIndex = index[dateKey(date)] else { continue }
                let id = sqlite3_column_text(activities, 0).map { String(cString: $0) } ?? ""
                let primary = sqlite3_column_text(activities, 1).map { String(cString: $0) } ?? ""
                let secondary = sqlite3_column_text(activities, 2).map { String(cString: $0) } ?? ""
                days[dayIndex].activities.append("\(id)  \(primary)\(secondary.isEmpty ? "" : "\n\(secondary)")")
            }

            let missed = try NativeDatabase.prepare("SELECT local_date FROM missed_habit_records WHERE local_date >= '\(start)' AND local_date < '\(end)'", in: db)
            defer { sqlite3_finalize(missed) }
            while sqlite3_step(missed) == SQLITE_ROW {
                guard let rawDate = sqlite3_column_text(missed, 0), let dayIndex = index[String(cString: rawDate)] else { continue }
                days[dayIndex].missed = true
            }
        }
        return ReviewSnapshot(days: days, selectedIDs: selectedIDs, starredIDs: starredIDs)
    }

    private func weekday(_ date: Date) -> String { ["日", "一", "二", "三", "四", "五", "六"][calendar.component(.weekday, from: date) - 1] }
    private func monthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date)
    }
    private func dateLabel(_ date: Date) -> String { "\(calendar.component(.year, from: date))年\(calendar.component(.month, from: date))月\(calendar.component(.day, from: date))日" }
    private func encouragement(_ count: Int) -> String {
        if period == .week && range.start > Date.now { return "这一周尚未开始，暂无完成记录。" }
        if period == .week { return count == 0 ? "这周还没有完成记录。从一个小动作重新开始。" : "每一次完成，都是本周留下的真实证据。" }
        switch count {
        case 0: return "这个月还没有留下完成记录，不用责怪自己。挑一个最小动作，今天重新开始。"
        case 1...3: return "你已经开始留下证据了。小小的重复，会慢慢变成更稳的自己。"
        case 4...10: return "你正在把坚持变成日常。下个月继续守住最容易做到的那一步。"
        default: return "这份记录很有分量。你不是靠某一天的冲劲，而是在给生活持续加一点复利。"
        }
    }

    private func categoryInsight(_ data: ReviewSnapshot, goals: [Goal]) -> String {
        guard data.completions > 0 else { return "还没有完成记录，先从一个最容易开始的动作建立样本。" }
        let groups: [(String, [Goal])] = [
            ("普通", goals.filter { !data.starredIDs.contains($0.id) && !["H5", "H7", "H10", "H11"].contains($0.id) }),
            ("周期", goals.filter { !data.starredIDs.contains($0.id) && ["H5", "H7", "H10", "H11"].contains($0.id) }),
            ("星标", goals.filter { data.starredIDs.contains($0.id) })
        ]
        let ranked = groups.filter { !$0.1.isEmpty }.map { ($0.0, Double($0.1.reduce(0) { $0 + data.count($1.id) }) / Double($0.1.count)) }
        guard let strongest = ranked.max(by: { $0.1 < $1.1 })?.0 else { return "继续积累记录，才能形成可靠的类型比较。" }
        switch strongest {
        case "普通": return "普通习惯的平均完成次数最高。继续保持稳定的日常节律。"
        case "周期": return "周期习惯的平均完成次数最高。继续提前安排执行时间。"
        default: return "星标习惯的平均完成次数最高。它们不加积分，仍值得长期坚持。"
        }
    }
}

private enum MonthlyAnalysisStep {
    case preparing
    case sending
    case organizing
    case complete

    func title(for period: ReviewPeriod) -> String {
        switch self {
        case .preparing: period == .week ? "正在整理本周记录…" : "正在整理本月记录…"
        case .sending: "正在等待 AI 分析…"
        case .organizing: "正在整理分析结果…"
        case .complete: "分析完成"
        }
    }

    // UI stage weights only; the AI service does not report actual completion progress.
    var progress: CGFloat {
        switch self {
        case .preparing: 0.25
        case .sending: 0.65
        case .organizing: 0.85
        case .complete: 1
        }
    }

    var progressLimit: CGFloat {
        switch self {
        case .preparing: 0.625
        case .sending: 0.825
        case .organizing: 0.975
        case .complete: 1
        }
    }
}

private struct ReviewWaitingMessage: View {
    let color: Color
    @State private var cycleStart = Date.now

    private let messages = [
        "正在分析报告，请耐心等待",
        "正在阅读你的成长",
        "报告正在赶来的路上",
        "一切美好都值得等待",
        "成长的等待是漫长而有意义的"
    ]

    var body: some View {
        TimelineView(.periodic(from: cycleStart, by: 7)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(cycleStart))
            let index = Int(elapsed / 7) % messages.count
            Text(messages[index])
                .font(.system(size: 13))
                .foregroundStyle(color)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: index)
        }
    }
}

private struct ReviewAIScanningProgress: View {
    let tint: Color
    let progress: CGFloat
    let progressLimit: CGFloat
    let allowsVirtualProgress: Bool
    @State private var progressStartedAt = Date.now

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            Capsule()
                .fill(tint.opacity(0.13))
                .overlay(alignment: .leading) {
                    GeometryReader { track in
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                            let shownProgress = virtualProgress(at: timeline.date)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [tint.opacity(0.42), tint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: track.size.width * shownProgress)
                                .overlay {
                                    GeometryReader { fill in
                                        let fillWidth = fill.size.width
                                        let shineWidth = min(fillWidth, max(10, fillWidth * 0.18))
                                        let cycle = timeline.date.timeIntervalSinceReferenceDate
                                            .truncatingRemainder(dividingBy: 1.2) / 1.2
                                        Capsule()
                                            .fill(LinearGradient(
                                                colors: [.clear, .white, .clear],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: shineWidth, height: fill.size.height)
                                            .offset(x: max(0, (fillWidth - shineWidth) * cycle))
                                    }
                                }
                                .clipShape(Capsule())
                        }
                    }
                    .frame(width: width, height: proxy.size.height)
                }
                .clipShape(Capsule())
                .onChange(of: progress) { _, _ in progressStartedAt = .now }
                .onChange(of: progressLimit) { _, _ in progressStartedAt = .now }
        }
    }

    private func virtualProgress(at date: Date) -> CGFloat {
        guard allowsVirtualProgress, progress < progressLimit else { return progress }
        let cycleDuration = 3.2
        let elapsed = max(0, date.timeIntervalSince(progressStartedAt))
        let completedCycles = Int(elapsed / cycleDuration)
        var advance: CGFloat = 0
        for cycle in 0..<completedCycles {
            advance += randomStep(for: cycle)
        }
        let phase = (elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration)
        let easedPhase = phase * phase * (3 - 2 * phase)
        advance += randomStep(for: completedCycles) * CGFloat(easedPhase)
        return min(progress + advance, progressLimit)
    }

    private func randomStep(for cycle: Int) -> CGFloat {
        let value = abs(sin(Double(cycle + 1) * 78.233) * 43_758.5453)
            .truncatingRemainder(dividingBy: 1)
        return 0.025 + CGFloat(value) * 0.04
    }
}

private struct WeekDateWheel: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let days: [ReviewDay]
    let anchor: Date
    let onSelect: (Date) -> Void
    let onOpen: (ReviewDay) -> Void

    @GestureState private var dragOffset: CGFloat = 0
    @State private var settledOffset: CGFloat = 0
    @State private var settleID = UUID()

    private let calendar = Calendar.current
    private var selectedGradient: LinearGradient { LinearGradient(
        colors: colorTheme == .lavender ? [colorTheme.accent, colorTheme.companion] : [Color(red: 0.89, green: 0.00, blue: 0.70), Color(red: 1.00, green: 0.36, blue: 0.16)],
        startPoint: .leading,
        endPoint: .trailing
    ) }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let step = width / 7
            let travel = max(-3 * step, min(3 * step, dragOffset + settledOffset))
            let band = Path { path in
                path.move(to: CGPoint(x: 0, y: 42))
                path.addQuadCurve(to: CGPoint(x: width, y: 42), control: CGPoint(x: width / 2, y: 14))
                path.addLine(to: CGPoint(x: width, y: 102))
                path.addQuadCurve(to: CGPoint(x: 0, y: 102), control: CGPoint(x: width / 2, y: 74))
                path.closeSubpath()
            }
            let edges = Path { path in
                for y: CGFloat in [42, 102] {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addQuadCurve(to: CGPoint(x: width, y: y), control: CGPoint(x: width / 2, y: y - 28))
                }
            }
            let sideFade = LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.16),
                .init(color: .white, location: 0.84),
                .init(color: .clear, location: 1)
            ], startPoint: .leading, endPoint: .trailing)

            ZStack(alignment: .topLeading) {
                band.fill(.ultraThinMaterial).opacity(0.60)
                    .overlay(band.fill(.white.opacity(0.10)))
                    .mask(sideFade)
                    .allowsHitTesting(false)

                edges.stroke(.white.opacity(0.68), lineWidth: 3)
                    .blur(radius: 3.5)
                    .mask(sideFade)
                    .allowsHitTesting(false)
                edges.stroke(
                    LinearGradient(colors: [.white.opacity(0.04), .white.opacity(0.60), .white.opacity(0.04)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 0.8
                )
                .allowsHitTesting(false)

                ForEach(days) { day in
                    let relative = CGFloat(calendar.dateComponents([.day], from: calendar.startOfDay(for: anchor), to: day.date).day ?? 0)
                    let x = width / 2 + relative * step + travel
                    let normalized = (x - width / 2) / (width / 2)
                    let curve = 14 * normalized * normalized
                    let prominence = max(0, 1 - abs(x - width / 2) / step)
                    let visible = x > -step && x < width + step
                    if visible {
                        Text("周\(weekday(day.date))")
                            .font(.system(size: 11, weight: .medium))
                            .position(x: x, y: 14 + curve)
                            .opacity(max(0.25, 1 - abs(normalized) * 0.27))
                            .allowsHitTesting(false)

                        Button {
                            if calendar.isDate(day.date, inSameDayAs: anchor) {
                                onOpen(day)
                            } else {
                                settle(to: day.date, distance: Int(relative), step: step)
                            }
                        } label: {
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(.system(size: 16, weight: prominence > 0.55 ? .semibold : .medium))
                                .frame(width: 36, height: 36)
                                .background {
                                    Circle().fill(selectedGradient).opacity(prominence)
                                        .scaleEffect(0.86 + 0.14 * prominence)
                                }
                                .frame(width: step, height: 60)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: x, y: 58 + curve)
                        .opacity(max(0.40, 1 - abs(normalized) * 0.24))
                        .accessibilityLabel("\(dateKey(day.date))，完成 \(day.completed.count) 项")
                        .zIndex(prominence)

                        Circle()
                            .fill(day.completed.isEmpty ? .clear : .white)
                            .frame(width: 4, height: 4)
                            .position(x: x, y: 82 + curve)
                            .opacity(max(0.25, 1 - abs(normalized) * 0.27))
                            .allowsHitTesting(false)
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(width: width, height: 108)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .updating($dragOffset) { value, state, _ in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            state = value.translation.width
                        }
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                        let proposed = max(-3, min(3, Int(round(-value.predictedEndTranslation.width / step))))
                        guard proposed != 0,
                              let target = calendar.date(byAdding: .day, value: proposed, to: anchor) else {
                            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.38, dampingFraction: 0.75)) {
                                settledOffset = 0
                            }
                            return
                        }
                        settle(to: target, distance: proposed, step: step, startingAt: value.translation.width)
                    }
            )
        }
        .frame(height: 108)
        .accessibilityHint("左右滑动切换日期；点选中间日期查看当天记录")
    }

    private func settle(to date: Date, distance: Int, step: CGFloat, startingAt translation: CGFloat? = nil) {
        let ticket = UUID()
        settleID = ticket
        if let translation { settledOffset = translation }
        let duration = reduceMotion ? 0.12 : 0.50
        withAnimation(reduceMotion ? .easeOut(duration: duration) : .spring(response: 0.48, dampingFraction: 0.70)) {
            settledOffset = -CGFloat(distance) * step
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard settleID == ticket else { return }
            withTransaction(Transaction(animation: nil)) {
                onSelect(date)
                settledOffset = 0
            }
        }
    }

    private func weekday(_ date: Date) -> String {
        ["日", "一", "二", "三", "四", "五", "六"][calendar.component(.weekday, from: date) - 1]
    }
}

private func dateKey(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

// Marked trigger lines stay at 19% / 89%; visual regions are independently 25% / 15%.
// Keep measurements and thresholds in window coordinates, including safe areas.
private struct ReviewScrollChrome: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let titleFrame: CGRect
    let subtitleFrame: CGRect
    let bodyFrame: CGRect
    let contentFrame: CGRect
    let scrollOffset: CGFloat

    @State private var restingTitleFrame: CGRect = .zero
    @State private var restingSubtitleFrame: CGRect = .zero
    @State private var topReveal: CGFloat = 0
    @State private var bottomReveal: CGFloat = 0
    @State private var titleProgress: CGFloat = 0

    private var ink: Color { colorTheme == .lavender ? .white : Color(red: 0.17, green: 0.15, blue: 0.19) }
    private var mutedInk: Color { colorTheme == .lavender ? .white.opacity(0.92) : Color(red: 0.43, green: 0.41, blue: 0.46) }
    private let enter = Animation.timingCurve(0.22, 0.8, 0.25, 1, duration: 0.46)
    private let exit = Animation.timingCurve(0.4, 0, 0.25, 1, duration: 0.42)

    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let screenHeight = geometry.size.height + frame.minY
            let topHeight = (screenHeight * 0.25).rounded()
            let bottomHeight = (screenHeight * 0.15).rounded()
            let topLine = (screenHeight * 0.19).rounded()
            let bottomLine = (screenHeight * 0.89).rounded()
            let hasContent = bodyFrame != .zero && contentFrame != .zero
            let topCovered = hasContent && bodyFrame.minY < topLine && contentFrame.maxY > 0
            let bottomCovered = hasContent && contentFrame.maxY > bottomLine && bodyFrame.minY < screenHeight
            let titleSource = restingTitleFrame == .zero ? titleFrame : restingTitleFrame
            let subtitleSource = restingSubtitleFrame == .zero ? subtitleFrame : restingSubtitleFrame
            let titleX = interpolate(titleSource.midX - frame.minX, geometry.size.width / 2)
            let subtitleX = interpolate(subtitleSource.midX - frame.minX, geometry.size.width / 2)
            // Destination is below the status bar. Never add safeTop twice.
            let titleY = interpolate(titleSource.midY - frame.minY, 20)
            let subtitleY = interpolate(subtitleSource.midY - frame.minY, 44)

            ZStack(alignment: .topLeading) {
                edge(isTop: true, height: topHeight, reveal: topReveal)
                    .position(x: geometry.size.width / 2, y: (topHeight - 32) / 2 - frame.minY)
                edge(isTop: false, height: bottomHeight, reveal: bottomReveal)
                    .position(x: geometry.size.width / 2, y: screenHeight - (bottomHeight - 32) / 2 - frame.minY)

                Text("复盘")
                    .font(.system(size: 43, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .shadow(color: colorTheme == .lavender ? .black.opacity(0.5) : .clear, radius: 1.5, y: 1)
                    .fixedSize()
                    .scaleEffect(1 - titleProgress * (1 - 26.0 / 43.0))
                    .position(x: titleX, y: titleY)
                    .opacity(titleSource == .zero ? 0 : 1)
                Text("只读回看每天的习惯完成和记录。")
                    .font(.system(size: 14))
                    .foregroundStyle(mutedInk)
                    .shadow(color: colorTheme == .lavender ? .black.opacity(0.5) : .clear, radius: 1, y: 1)
                    .fixedSize()
                    .scaleEffect(1 - titleProgress * 0.18)
                    .position(x: subtitleX, y: subtitleY)
                    .opacity(subtitleSource == .zero ? 0 : 1)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task(id: topCovered) { await setTopCovered(topCovered) }
            .task(id: bottomCovered) {
                withAnimation(reduceMotion ? nil : (bottomCovered ? enter : exit)) {
                    bottomReveal = bottomCovered ? 1 : 0
                }
            }
            .onChange(of: titleFrame, initial: true) { _, value in
                if value != .zero && restingTitleFrame == .zero {
                    restingTitleFrame = value.offsetBy(dx: 0, dy: scrollOffset)
                }
            }
            .onChange(of: subtitleFrame, initial: true) { _, value in
                if value != .zero && restingSubtitleFrame == .zero {
                    restingSubtitleFrame = value.offsetBy(dx: 0, dy: scrollOffset)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func interpolate(_ source: CGFloat, _ destination: CGFloat) -> CGFloat {
        source + (destination - source) * titleProgress
    }

    private func edge(isTop: Bool, height: CGFloat, reveal: CGFloat) -> some View {
        ReviewBackdropBlur(intensity: 0.25, whiteOpacity: 0.15, isTop: isTop)
            .frame(height: height + 32)
            .opacity(Double(reveal))
    }

    @MainActor private func setTopCovered(_ covered: Bool) async {
        if reduceMotion {
            topReveal = covered ? 1 : 0
            titleProgress = covered ? 1 : 0
            return
        }
        if covered {
            withAnimation(enter) { topReveal = 1 }
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            withAnimation(enter) { titleProgress = 1 }
        } else {
            withAnimation(exit) { titleProgress = 0 }
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            withAnimation(exit) { topReveal = 0 }
        }
    }
}

// Public UIKit background blur, with a paused animator controlling its strength.
// The outer 40% fades both the blur and the explicit 15% white layer together.
private struct ReviewBackdropBlur: UIViewRepresentable {
    let intensity: CGFloat
    let whiteOpacity: CGFloat
    let isTop: Bool

    func makeUIView(context: Context) -> BackdropView {
        BackdropView(intensity: intensity, whiteOpacity: whiteOpacity, isTop: isTop)
    }

    func updateUIView(_ uiView: BackdropView, context: Context) {}

    final class BackdropView: UIView {
        private let effectView = UIVisualEffectView()
        private let whiteLayer = UIView()
        private let gradient = CAGradientLayer()
        private var animator: UIViewPropertyAnimator?
        private let intensity: CGFloat

        init(intensity: CGFloat, whiteOpacity: CGFloat, isTop: Bool) {
            self.intensity = intensity
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            addSubview(effectView)
            whiteLayer.backgroundColor = UIColor.white.withAlphaComponent(whiteOpacity)
            addSubview(whiteLayer)
            gradient.colors = isTop
                ? [UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
                : [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor]
            gradient.locations = isTop ? [0, 0.6, 1] : [0, 0.4, 1]
            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
            layer.mask = gradient
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil, animator == nil else { return }
            let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in
                self?.effectView.effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
            }
            animator.startAnimation()
            animator.pauseAnimation()
            animator.fractionComplete = intensity
            self.animator = animator
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            effectView.frame = bounds
            whiteLayer.frame = bounds
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradient.frame = bounds
            CATransaction.commit()
        }

        deinit { animator?.stopAnimation(true) }
    }
}

struct ScrollMorphChrome: View {
    let title: String
    var subtitle: String? = nil
    let progress: CGFloat
    let startY: CGFloat
    let leadingInset: CGFloat
    var sourceTitleFrame: CGRect = .zero
    var sourceSubtitleFrame: CGRect = .zero
    var startTitleSize: CGFloat = 43
    var compactTitleSize: CGFloat = 26
    var titleWeight: Font.Weight = .bold
    var titleColor: Color = Color(red: 0.17, green: 0.15, blue: 0.19)
    var edgeVisibility: ScrollEdgeVisibility = .both
    var topEdgeReveal: CGFloat? = nil
    var bottomEdgeReveal: CGFloat? = nil
    var edgeWhiteOpacity: Double = 0.45
    var bottomEdgeWhiteOpacity: Double = 0.45
    var bottomVisibleFraction: CGFloat = 0.25

    var body: some View {
        GeometryReader { geometry in
            let amount = min(1, max(0, progress))
            let titleSize = startTitleSize + (compactTitleSize - startTitleSize) * amount
            let availableWidth = max(1, geometry.size.width - 2 * leadingInset)
            let overlayFrame = geometry.frame(in: .global)
            let safeTop = geometry.safeAreaInsets.top
            let measuredTitleWidth = sourceTitleFrame == .zero ? CGFloat(title.count) * startTitleSize * 0.96 : sourceTitleFrame.width
            let titleWidth = min(availableWidth, measuredTitleWidth)
            let originX = sourceTitleFrame == .zero
                ? leadingInset + titleWidth / 2
                : sourceTitleFrame.midX - overlayFrame.minX
            let titleX = originX + (geometry.size.width / 2 - originX) * amount
            let titleSourceY = sourceTitleFrame == .zero
                ? startY
                : sourceTitleFrame.midY - overlayFrame.minY
            let titleY = titleSourceY + (safeTop + 25 - titleSourceY) * amount
            let measuredSubtitleWidth = sourceSubtitleFrame == .zero
                ? CGFloat(subtitle?.count ?? 0) * 14 * 0.92
                : sourceSubtitleFrame.width
            let subtitleStartWidth = min(availableWidth, measuredSubtitleWidth)
            let subtitleCompactWidth = min(availableWidth, subtitleStartWidth * 0.82)
            let subtitleWidth = subtitleStartWidth + (subtitleCompactWidth - subtitleStartWidth) * amount
            let subtitleStartX = sourceSubtitleFrame == .zero
                ? leadingInset + subtitleStartWidth / 2
                : sourceSubtitleFrame.midX - overlayFrame.minX
            let subtitleX = subtitleStartX + (geometry.size.width / 2 - subtitleStartX) * amount
            let subtitleSourceY = sourceSubtitleFrame == .zero
                ? startY + 37
                : sourceSubtitleFrame.midY - overlayFrame.minY
            let subtitleY = subtitleSourceY + (safeTop + 54 - subtitleSourceY) * amount

            ZStack {
                ScrollEdgeBlurOverlay(
                    progress: amount,
                    visibility: edgeVisibility,
                    topReveal: topEdgeReveal,
                    bottomReveal: bottomEdgeReveal,
                    whiteOpacity: edgeWhiteOpacity,
                    bottomWhiteOpacity: bottomEdgeWhiteOpacity,
                    bottomVisibleFraction: bottomVisibleFraction
                )
                    .ignoresSafeArea(.container, edges: [.top, .bottom])
                    .zIndex(0)

                Text(title)
                    .font(.system(size: titleSize, weight: titleWeight, design: .rounded))
                    .tracking(-1.2 * (1 - amount))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(width: titleWidth)
                    .position(x: titleX, y: titleY)
                    .zIndex(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14 - 4 * amount, weight: .regular))
                        .foregroundStyle(titleColor.opacity(0.66))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: subtitleWidth)
                        .position(x: subtitleX, y: subtitleY)
                        .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

struct ScrollEdgeBlurOverlay: View {
    let progress: CGFloat
    var visibility: ScrollEdgeVisibility = .both
    var topReveal: CGFloat? = nil
    var bottomReveal: CGFloat? = nil
    var whiteOpacity: Double = 0.45
    var bottomWhiteOpacity: Double = 0.45
    var bottomVisibleFraction: CGFloat = 0.25

    var body: some View {
        GeometryReader { geometry in
            let overscan: CGFloat = 80
            let topHeight = geometry.size.height / 4 + overscan
            let bottomHeight = geometry.size.height * bottomVisibleFraction + overscan
            let topProgress = visibility == .top || visibility == .both ? (topReveal ?? progress) : 0
            let bottomProgress = visibility == .bottom || visibility == .both ? (bottomReveal ?? progress) : 0

            VStack(spacing: 0) {
                edgeBlur(isTop: true, height: topHeight, travel: topHeight - overscan, reveal: topProgress, whiteOpacity: whiteOpacity)
                Spacer(minLength: 0)
                edgeBlur(isTop: false, height: bottomHeight, travel: bottomHeight - overscan, reveal: bottomProgress, whiteOpacity: bottomWhiteOpacity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height + overscan * 2)
            .offset(y: -overscan)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func edgeBlur(isTop: Bool, height: CGFloat, travel: CGFloat, reveal: CGFloat, whiteOpacity: Double) -> some View {
        let amount = min(1, max(0, reveal))
        return Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(Color.white.opacity(whiteOpacity))
            .frame(height: height)
            .mask {
                LinearGradient(
                    stops: isTop
                        ? [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.8),
                            .init(color: .clear, location: 1)
                        ]
                        : [
                            .init(color: .clear, location: 0),
                            .init(color: .white, location: 0.2),
                            .init(color: .white, location: 1)
                        ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .opacity(amount)
            .offset(y: (1 - amount) * (isTop ? -travel : travel))
    }
}
