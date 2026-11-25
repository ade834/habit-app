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

enum ReviewAICooldown {
    private static let requestDatePrefix = "review.ai.last-request."
    static let didResetNotification = Notification.Name("HabitNativeReviewAICooldownDidReset")

    static func reset() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(requestDatePrefix) }
            .forEach(defaults.removeObject(forKey:))
        NotificationCenter.default.post(name: didResetNotification, object: nil)
    }
}

// Preserve saved appearance values after removing the temporary tuning controls.
private struct ReviewBlurAppearance {
    let topHeight: Double
    let bottomHeight: Double
    let topOpacity: Double
    let bottomOpacity: Double
    let topFade: Double
    let bottomFade: Double
    let intensity: Double

    init(theme: HabitColorTheme) {
        let defaults = UserDefaults.standard
        func saved(_ key: String, fallback: Double) -> Double {
            defaults.object(forKey: "review.blur." + key + "." + theme.rawValue) as? Double ?? fallback
        }
        topHeight = saved("top.height", fallback: 0.25) * (2.0 / 3.0)
        bottomHeight = saved("bottom.height", fallback: 0.15)
        topOpacity = saved("top.opacity", fallback: theme == .lavender ? 0.34 : 0.15)
        bottomOpacity = theme == .original ? 0.65 : saved("bottom.opacity", fallback: 0.95)
        topFade = max(0.40, saved("top.fade", fallback: 0.125))
        bottomFade = saved("bottom.fade", fallback: 0.225)
        intensity = saved("intensity", fallback: 0.25)
    }
}

struct ReviewPage: View {
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSoundSettings.storageKey) private var soundEffectsEnabled = true
    let goals: [Goal]
    let receiptPresentation: ReviewReceiptPresentation
    @State private var reviewRequestTask: Task<Void, Never>?
    @State private var reviewInteractionSound = AppSoundFeedback()
    @State private var didRunReceiptPreview = false
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
    @State private var reportScrollPosition = ScrollPosition(edge: .top)
    @State private var reviewScrollOffset: CGFloat = 0
    @State private var reviewContentFrame: CGRect = .zero
    @State private var daySheetScrollMorphProgress: CGFloat = 0
    @AppStorage(AppLanguage.storageKey) private var reviewLanguagePreference = "system"
    @State private var reviewReport: QwenReviewService.MonthlyReports?
    @State private var nextReviewAllowedAt: Date?
    @State private var reviewReportLoading = false
    @State private var analysisStep: MonthlyAnalysisStep = .preparing
    @AppStorage("review.ai.privacy-consent.v5") private var hasPrivacyConsent = false
    @State private var privacyConsentChecked = false
    @State private var reviewReportError: String?
    @State private var consentSheetPresented = false
    @State private var showingPaywallSheet = false

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
                        Text(AppLanguage.text("复盘"))
                            .font(.system(size: 43, weight: .bold, design: .rounded))
                            .foregroundStyle(ink)
                            .opacity(0)
                            .onGeometryChange(for: CGRect.self) { geometry in
                                geometry.frame(in: .global)
                            } action: { reviewTitleFrame = $0 }
                        Text(AppLanguage.text("只读回看每天的习惯完成和记录。"))
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
                        Text(String(format: AppLanguage.text("读取复盘记录失败：%@"), "\(error)"))
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
                // Limit line length while still following the available window width.
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                // Measure actual content, before the trailing navigation clearance.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { reviewContentFrame = $0 }
                .padding(.bottom, 120)
            }
            .frame(width: viewport.size.width, height: viewport.size.height)
            .scrollDisabled(receiptPresentation.isActive)
            .scrollPosition($reportScrollPosition)
            .onChange(of: receiptPresentation.shouldScrollToReport) { _, shouldScroll in
                guard shouldScroll else { return }
                let landingTop = viewport.frame(in: .global).minY + 148
                let offset = max(0, reviewScrollOffset + receiptPresentation.destinationFrame.minY - landingTop)
                withAnimation(.easeInOut(duration: 0.4)) {
                    reportScrollPosition.scrollTo(y: offset)
                }
            }
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
        .overlay(alignment: .bottom) {
            #if DEBUG
            if DevelopmentLaunch.contains("-review-receipt-preview") && !DevelopmentLaunch.contains("--skip-intro"), !receiptPresentation.isActive {
                Button("重播小票动画（演示）") { previewReceipt() }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 105)
                    .disabled(reviewReportLoading)
            }
            #endif
        }
        .task {
            load()
            loadReviewReport()
            #if DEBUG
            if DevelopmentLaunch.contains("--review-receipt-landed") {
                didRunReceiptPreview = true
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                setupDirectReceiptPreview()
            } else if DevelopmentLaunch.contains("-review-receipt-preview"), !didRunReceiptPreview {
                didRunReceiptPreview = true
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                previewReceipt()
            }
            #endif
        }
        .onDisappear {
            reviewRequestTask?.cancel()
            receiptPresentation.dismiss()
        }
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
            guard phase == .active else {
                receiptPresentation.dismiss()
                return
            }
            load()
            if !reviewReportLoading && !receiptPresentation.isActive { loadReviewReport() }
        }
        .onChange(of: reviewLanguagePreference) { _, _ in
            receiptPresentation.dismiss()
            loadReviewReport()
        }
        .onChange(of: period) { _, _ in
            receiptPresentation.dismiss()
            loadReviewReport()
        }
        .onChange(of: anchor) { _, _ in
            receiptPresentation.dismiss()
            loadReviewReport()
        }
        .onReceive(NotificationCenter.default.publisher(for: ReviewAICooldown.didResetNotification)) { _ in
            reviewReport = nil
            nextReviewAllowedAt = nil
            reviewReportError = nil
            loadReviewReport()
        }
        .sheet(isPresented: $consentSheetPresented) {
            reviewPrivacyConsentSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPaywallSheet) {
            SubscriptionPaywallView()
        }
        .alert(AppLanguage.text("复盘分析未完成"), isPresented: Binding(
            get: { reviewReportError != nil },
            set: { if !$0 { reviewReportError = nil } }
        )) {
            Button(AppLanguage.text("知道了"), role: .cancel) { reviewReportError = nil }
        } message: {
            Text(reviewReportError ?? AppLanguage.text("请稍后重试"))
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
                        reviewInteractionSound.play(.navigation, enabled: soundEffectsEnabled)
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
                    Text(AppLanguage.text(choice.rawValue))
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
        .accessibilityAction(named: isWeekCalendarExpanded ? AppLanguage.text("收起本周日期") : AppLanguage.text("展开本周日期"), toggleWeekCalendar)
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
                .accessibilityLabel(AppLanguage.text("上一周"))
            Spacer()
            Text(AppLanguage.text("点选日期查看当天记录"))
                .font(.system(size: 12))
                .opacity(0.84)
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel(AppLanguage.text("下一周"))
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
                Text(verbatim: AppLanguage.date(anchor, template: "yMMMM"))
                    .font(.system(size: 17, weight: .semibold))
                    .matchedGeometryEffect(id: "month-year-title", in: monthCalendarNamespace)
                Text(AppLanguage.text("本月完成"))
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
        .accessibilityAction(named: AppLanguage.text("展开月历"), toggleMonthCalendar)
    }

    private func monthCalendarGrid(_ data: ReviewSnapshot) -> some View {
        VStack(spacing: 13) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 7) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
                    Text(AppLanguage.text(label)).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.88)).frame(height: 25)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 42) }
                ForEach(data.days) { day in
                    Button {
                        selectedDay = day
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(.system(size: 14, weight: day.completed.isEmpty ? .medium : .semibold))
                            Text(day.completed.isEmpty ? (day.hasRecord ? "·" : " ") : String(format: AppLanguage.text("%lld 项"), day.completed.count))
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
                    .accessibilityLabel(String(format: AppLanguage.text("%@，完成 %lld 项"), dateLabel(day.date), day.completed.count))
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
            .accessibilityLabel(AppLanguage.text("上个月"))
            Spacer()
            VStack(alignment: .center, spacing: 2) {
                Text(monthName(anchor))
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .matchedGeometryEffect(id: "month-name-title", in: monthCalendarNamespace)
                Text(verbatim: AppLanguage.date(anchor, template: "yMMMM"))
                    .font(.system(size: 17, weight: .semibold))
                    .matchedGeometryEffect(id: "month-year-title", in: monthCalendarNamespace)
            }
            Spacer()
            Button { move(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 32)
            }
            .accessibilityLabel(AppLanguage.text("下个月"))
            .disabled(!canMoveForward)
            .opacity(canMoveForward ? 1 : 0.35)
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleMonthCalendar)
        .accessibilityAction(named: AppLanguage.text("收起月历"), toggleMonthCalendar)
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
        let visibleGoals = SharedHabitRepository.historyCatalog().filter { data.selectedIDs.contains($0.id) || data.count($0.id) > 0 }
        let leadingCount = visibleGoals.map { data.count($0.id) }.max() ?? 0
        let leaders = visibleGoals.filter { data.count($0.id) == leadingCount && leadingCount > 0 }
        return VStack(alignment: .leading, spacing: 16) {
            Text(period == .week ? (range.start > Date.now ? AppLanguage.text("这一周尚未开始") : AppLanguage.text("本周小结")) : AppLanguage.text("本月小结"))
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(ink)
            Text(String(format: AppLanguage.text("完成 %lld 次 · 获得 %lld 积分"), data.completions, data.points))
                .font(.system(size: 15))
                .foregroundStyle(muted)
            Rectangle().fill(ink.opacity(0.09)).frame(height: 1)
            Text(AppLanguage.text("习惯完成次数"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink)
            if visibleGoals.isEmpty {
                Text(AppLanguage.text("先选择一个想照顾的习惯，复盘会从今天开始。"))
                    .font(.system(size: 14)).foregroundStyle(muted)
            } else {
                ForEach(visibleGoals) { goal in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.isCustomTask ? AppLanguage.text("自定义卡片") : goal.id).font(.system(size: 13, weight: .semibold))
                            Text(AppLanguage.text(goal.title))
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
                    insight(AppLanguage.text("最容易坚持"), leaders.map { AppLanguage.text($0.title) }.joined(separator: AppLanguage.current == "en-US" ? ", " : "、"))
                }
                if period == .month {
                    let hard = visibleGoals.filter {
                        !data.starredIDs.contains($0.id) &&
                        (!["H5", "H7", "H10", "H11"].contains($0.id) || isClosedMonth)
                    }
                    if let least = hard.map({ data.count($0.id) }).min() {
                        insight(AppLanguage.text("最容易放弃"), hard.filter { data.count($0.id) == least }.map { AppLanguage.text($0.title) }.joined(separator: AppLanguage.current == "en-US" ? ", " : "、"))
                    }
                    let areas = leaders.compactMap { ["H1": "觉察与决策", "H2": "专注与思考", "H3": "勇气与行动", "H4": "边界与休息"][$0.id] }
                    insight(AppLanguage.text("它正在帮助你"), areas.isEmpty ? AppLanguage.text("慢慢找到自己的节奏") : Array(Set(areas)).sorted().map { AppLanguage.text($0) }.joined(separator: AppLanguage.current == "en-US" ? ", " : "、"))
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
        Text(period == .week ? AppLanguage.text("本周复盘分析") : AppLanguage.text("月复盘分析"))
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(ink)

        if !cooldownIsActive || reviewReport == nil {
            reviewRequestButton(data)
        }

        if reviewReportLoading {
            VStack(alignment: .leading, spacing: 10) {
                if reviewReportLoading && analysisStep != .complete {
                    ReviewWaitingMessage(color: muted)
                } else {
                    Text(AppLanguage.text("分析完成"))
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
                    .accessibilityLabel(String(format: AppLanguage.text("分析步骤：%@"), analysisStep.title(for: period)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
            .transition(.opacity)
        } else if let reviewReport {
            ReviewReceiptContent(document: receiptDocument(reviewReport, data: data))
                .id("review-ai-receipt")
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { receiptPresentation.destinationFrame = $0 }
                .opacity(receiptPresentation.isActive ? 0 : 1)
                .accessibilityHidden(receiptPresentation.isActive)
                .padding(.top, 4)
        }
    }

    private func receiptDocument(_ reports: QwenReviewService.MonthlyReports, data: ReviewSnapshot) -> ReviewReceiptDocument {
        ReviewReceiptDocument(
            reports: reports,
            title: period == .week ? AppLanguage.text("本周复盘小票") : AppLanguage.text("月度复盘小票"),
            start: range.start,
            end: range.end.addingTimeInterval(-1),
            completions: data.completions,
            points: data.points
        )
    }

    #if DEBUG
    private func previewReceipt() {
        guard let snapshot, !receiptPresentation.isActive else { return }
        reportScrollPosition.scrollTo(edge: .top)
        let isEn = DevelopmentLaunch.contains("--lang-en") || AppLanguage.current == "en-US"
        let isJa = DevelopmentLaunch.contains("--lang-ja") || AppLanguage.current.hasPrefix("ja")
        let rawAnalysis: String
        let rawEncouragement: String
        if isEn {
            rawAnalysis = "This week's records leave tangible traces of daily care. The plant's current stage reflects your cumulative progress, not necessarily a level-up from this single week. Seeds take time to sprout, and seedlings grow at their own pace.\n\nLooking back at specific dates reveals which habits are easiest to start and which days need a little breathing room. Every check-in is an honest milestone, and pauses offer valuable clues for adjustment.\n\nConsistent logging and reviews help you find cues that work for you. Next week, pick just one habit to nurture and notice when it feels easiest to take that first step."
            rawEncouragement = "Treat every small action as gentle care for your plant. Keep a little patience, let it take root, and look forward to vibrant blooms. Tomorrow, simply begin with one effortless step."
        } else if isJa {
            rawAnalysis = "今週の記録は、日々のケアを振り返る確かな足跡になります。植物の現在の状態はこれまでの累計を反映したものであり、今週の急成長だけを示すわけではありません。種が芽吹き、苗が育つにはそれぞれのペースがあります。\n\n具体的な日付で振り返ると、始めやすい習慣や、少し余裕が必要だった日が見えてきます。1回の達成は確かな実績であり、一時的な中断も次の調整へのヒントになります。\n\n記録と振り返りを続けることで、自分に合ったリズムが見つかります。来週は続けたい習慣をひとつ選び、いつ第一歩を踏み出しやすいかを観察してみましょう。"
            rawEncouragement = "日々の小さな一歩を、植物への水やりだと思ってみてください。焦らず根を張るのを見守り、いつか咲く美しい花を楽しみにしましょう。明日は気負わず、簡単な一歩から始めましょう。"
        } else {
            rawAnalysis = "这周的记录，让日常的照料有了可以回看的痕迹。养成物的当前阶段反映累计记录，不代表这一周发生了升阶。种子等待发芽、幼苗慢慢生长，都有各自的节奏。\n\n把行动放回具体日期，能更清楚地看见哪些习惯容易开始，哪些日子需要留一点余地。一次完成是一条真实记录，暂时中断也可以成为下一次调整的线索。\n\n持续记录与复盘，有助于找到适合自己的提示和反馈。下周可以只挑一个想继续照顾的习惯，观察什么时间最容易迈出第一步。"
            rawEncouragement = "愿你把每一次小小的行动，都当作给植物的一次照料。留一点耐心，陪它慢慢生根，也期待它在你的陪伴下开出惊喜的花朵。明天从一个轻松的小步骤开始就好。"
        }

        let reports = QwenReviewService.MonthlyReports(
            analysis: rawAnalysis,
            encouragement: rawEncouragement
        )
        reviewReport = reports
        if !reduceMotion { receiptPresentation.present(receiptDocument(reports, data: snapshot)) }
    }

    private func setupDirectReceiptPreview() {
        guard let snapshot else { return }
        let isEn = DevelopmentLaunch.contains("--lang-en") || AppLanguage.current == "en-US"
        let isJa = DevelopmentLaunch.contains("--lang-ja") || AppLanguage.current.hasPrefix("ja")
        let rawAnalysis: String
        let rawEncouragement: String
        if isEn {
            rawAnalysis = "This week's records leave tangible traces of daily care. The plant's current stage reflects your cumulative progress, not necessarily a level-up from this single week. Seeds take time to sprout, and seedlings grow at their own pace.\n\nLooking back at specific dates reveals which habits are easiest to start and which days need a little breathing room. Every check-in is an honest milestone, and pauses offer valuable clues for adjustment.\n\nConsistent logging and reviews help you find cues that work for you. Next week, pick just one habit to nurture and notice when it feels easiest to take that first step."
            rawEncouragement = "Treat every small action as gentle care for your plant. Keep a little patience, let it take root, and look forward to vibrant blooms. Tomorrow, simply begin with one effortless step."
        } else if isJa {
            rawAnalysis = "今週の記録は、日々のケアを振り返る確かな足跡になります。植物の現在の状態はこれまでの累計を反映したものであり、今週の急成長だけを示すわけではありません。種が芽吹き、苗が育つにはそれぞれのペースがあります。\n\n具体的な日付で振り返ると、始めやすい習慣や、少し余裕が必要だった日が見えてきます。1回の達成は確かな実績であり、一時的な中断も次の調整へのヒントになります。\n\n記録と振り返りを続けることで、自分に合ったリズムが見つかります。来週は続けたい習慣をひとつ選び、いつ第一歩を踏み出しやすいかを観察してみましょう。"
            rawEncouragement = "日々の小さな一歩を、植物への水やりだと思ってみてください。焦らず根を張るのを見守り、いつか咲く美しい花を楽しみにしましょう。明日は気負わず、簡単な一歩から始めましょう。"
        } else {
            rawAnalysis = "这周的记录，让日常的照料有了可以回看的痕迹。养成物的当前阶段反映累计记录，不代表这一周发生了升阶。种子等待发芽、幼苗慢慢生长，都有各自的节奏。\n\n把行动放回具体日期，能更清楚地看见哪些习惯容易开始，哪些日子需要留一点余地。一次完成是一条真实记录，暂时中断也可以成为下一次调整的线索。\n\n持续记录与复盘，有助于找到适合自己的提示和反馈。下周可以只挑一个想继续照顾的习惯，观察什么时间最容易迈出第一步。"
            rawEncouragement = "愿你把每一次小小的行动，都当作给植物的一次照料。留一点耐心，陪它慢慢生根，也期待它在你的陪伴下开出惊喜的花朵。明天从一个轻松的小步骤开始就好。"
        }

        let reports = QwenReviewService.MonthlyReports(
            analysis: rawAnalysis,
            encouragement: rawEncouragement
        )
        reviewReport = reports
        isWeekCalendarExpanded = false
        pendingAutoExpand = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeInOut(duration: 0.3)) {
                reportScrollPosition.scrollTo(id: "review-ai-receipt", anchor: .top)
            }
        }
    }
    #endif

    private func reviewRequestButton(_ data: ReviewSnapshot) -> some View {
        let cooldownActive = nextReviewAllowedAt.map { Date.now < $0 } ?? false
        let noMonthlyCompletions = period == .month && data.completions == 0
        let hasExistingReport = reviewReport != nil
        let canUseAI = canRequestReview
        return VStack(spacing: 7) {
            Button {
                if !canUseAI {
                    showingPaywallSheet = true
                    return
                }
                if hasPrivacyConsent {
                    startReviewRequest()
                } else {
                    privacyConsentChecked = false
                    consentSheetPresented = true
                }
            } label: {
                Label(
                    hasExistingReport ? AppLanguage.text("重新生成 AI 小结") : AppLanguage.text("AI 生成小结"),
                    systemImage: canUseAI ? "sparkles" : "crown.fill"
                )
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(LinearGradient(colors: reviewGradient, startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(reviewReportLoading || (cooldownActive && canUseAI) || noMonthlyCompletions)
            if !canUseAI {
                Button {
                    showingPaywallSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.90, green: 0.65, blue: 0.28))
                        Text(AppLanguage.text(period == .month && SubscriptionManager.shared.currentTier == .free ? "ai.review.month.membership" : "免费体验已使用 · 升级会员解锁每周深度复盘"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.52, green: 0.36, blue: 0.62))
                    }
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            } else if cooldownActive, let nextReviewAllowedAt {
                Text(String(format: AppLanguage.text("可在 %@ 后再次生成"), nextReviewAllowedAt.formatted(.dateTime.year().month().day().locale(AppLanguage.locale))))
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
            } else if noMonthlyCompletions && !hasExistingReport {
                Text(AppLanguage.text("本月还没有已完成的任务记录。"))
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
            }
        }
    }

    private var cooldownIsActive: Bool {
        nextReviewAllowedAt.map { Date.now < $0 } ?? false
    }

    private var reviewPrivacyConsentSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(AppLanguage.text("发送前请阅读")).font(.system(size: 23, weight: .semibold)).foregroundStyle(ink)
            ScrollView {
                Text(AppLanguage.text("privacy.ai.notice"))
                    .font(.system(size: 14)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
            }
            Toggle(isOn: $privacyConsentChecked) {
                Text(AppLanguage.text("privacy.ai.consent.checkbox"))
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(ink)
            }
            .tint(reviewGradient.first ?? .purple)
            Button {
                consentSheetPresented = false
                hasPrivacyConsent = true
                startReviewRequest()
            } label: {
                Text(AppLanguage.text("发送并生成报告"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(LinearGradient(colors: reviewGradient, startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
            .disabled(!privacyConsentChecked || reviewReportLoading)
            .opacity(privacyConsentChecked ? 1 : 0.5)
            Button(AppLanguage.text("取消"), role: .cancel) { consentSheetPresented = false }
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationBackground(.regularMaterial)
        .environment(\.colorScheme, .light)
    }

    private var canRequestReview: Bool {
        let subscription = SubscriptionManager.shared
        return subscription.canUseAIWeeklyReview && (period == .week || subscription.currentTier != .free)
    }

    private func startReviewRequest() {
        guard canRequestReview else {
            showingPaywallSheet = true
            return
        }
        guard hasPrivacyConsent, !reviewReportLoading else { return }
        reviewRequestTask = Task { await requestReviewReport() }
    }

    @MainActor
    private func requestReviewReport() async {
        guard !reviewReportLoading else { return }
        // Freeze all request context before the first suspension point.
        let requestedPeriod = period
        let requestedLanguage = AppLanguage.current
        let requestedAnchor = anchor
        let requestedRange = range
        let requestedKey = requestedPeriod == .week ? Self.weekKey(requestedRange.start) : Self.monthKey(requestedAnchor)
        let requestDateKey = reviewRequestDateKey(for: requestedKey)
        let requestedSnapshot = snapshot
        reviewReportLoading = true
        analysisStep = .preparing
        reviewReportError = nil
        defer { reviewReportLoading = false }
        do {
            let content = try requestedPeriod == .week ? weekReportInput(in: requestedRange) : monthReportInput(in: requestedRange)
            guard !content.isEmpty else {
                reviewReportError = requestedPeriod == .week ? AppLanguage.text("本周没有可分析的记录。") : AppLanguage.text("本月没有可分析的任务文字记录。")
                return
            }
            analysisStep = .sending
            let reports = try await (requestedPeriod == .week ? QwenReviewService.analyzeWeek(content, language: requestedLanguage) : QwenReviewService.analyzeMonth(content, language: requestedLanguage))
            try Task.checkCancellation()
            analysisStep = .organizing
            if requestedPeriod == .week {
                try NativeDatabase().saveWeeklyAIReport(analysis: reports.analysis, encouragement: reports.encouragement, week: requestedRange.start, language: requestedLanguage)
            } else {
                try NativeDatabase().saveMonthlyAIReport(analysis: reports.analysis, encouragement: reports.encouragement, month: requestedAnchor, language: requestedLanguage)
            }
            let savedAt = Date.now
            UserDefaults.standard.set(savedAt, forKey: requestDateKey)
            SubscriptionManager.shared.recordAIWeeklyReviewSuccess()
            // The saved result belongs to the original period even if the user moved elsewhere.
            let currentKey = period == .week ? Self.weekKey(range.start) : Self.monthKey(anchor)
            guard period == requestedPeriod, currentKey == requestedKey, AppLanguage.current == requestedLanguage, scenePhase == .active else { return }
            analysisStep = .complete
            if !reduceMotion { try await Task.sleep(for: .milliseconds(350)) }
            let visibleKey = period == .week ? Self.weekKey(range.start) : Self.monthKey(anchor)
            guard period == requestedPeriod, visibleKey == requestedKey, AppLanguage.current == requestedLanguage, scenePhase == .active else { return }
            reviewReport = reports
            let cooldown = requestedPeriod == .week ? 7 : 30
            nextReviewAllowedAt = Calendar.current.date(byAdding: .day, value: cooldown, to: savedAt)
            reviewReportLoading = false
            if !reduceMotion, let data = requestedSnapshot {
                receiptPresentation.present(ReviewReceiptDocument(
                    reports: reports,
                    title: requestedPeriod == .week ? AppLanguage.text("本周复盘小票") : AppLanguage.text("月度复盘小票"),
                    start: requestedRange.start,
                    end: requestedRange.end.addingTimeInterval(-1),
                    completions: data.completions,
                    points: data.points
                ))
            }
        } catch is CancellationError {
            // Leaving the page cancels the request and any pending presentation.
        } catch {
            guard !Task.isCancelled else { return }
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
                saved = try database.reviewReport(table: "weekly_ai_reports", keyColumn: "week_key", key: key + "|" + AppLanguage.current)
            } else {
                key = Self.monthKey(anchor)
                saved = try database.reviewReport(table: "monthly_ai_reports", keyColumn: "month_key", key: key + "|" + AppLanguage.current)
            }
            reviewReport = saved.map { QwenReviewService.MonthlyReports(analysis: $0.analysis, encouragement: $0.encouragement) }
            let sharedKey = reviewRequestDateKey(for: key)
            let defaults = UserDefaults.standard
            var requestDates = ([sharedKey] + ["zh-Hans", "en-US", "ja"].map { sharedKey + "." + $0 })
                .compactMap { defaults.object(forKey: $0) as? Date }
            let table = period == .week ? "weekly_ai_reports" : "monthly_ai_reports"
            let keyColumn = period == .week ? "week_key" : "month_key"
            for reportKey in [key] + ["zh-Hans", "en-US", "ja"].map({ key + "|" + $0 }) {
                if let report = try database.reviewReport(table: table, keyColumn: keyColumn, key: reportKey) {
                    requestDates.append(report.updatedAt)
                }
            }
            let requestDate = requestDates.max()
            let cooldown = period == .week ? 7 : 30
            nextReviewAllowedAt = requestDate.flatMap { Calendar.current.date(byAdding: .day, value: cooldown, to: $0) }
        } catch {
            reviewReportError = error.localizedDescription
        }
    }

    private func reviewRequestDateKey(for key: String) -> String {
        "review.ai.last-request.\(period == .week ? "week" : "month").\(key)"
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
        try monthReportInput(in: interval)
    }

    private func monthReportInput(in interval: DateInterval) throws -> String {
        let start = dateKey(interval.start)
        let end = dateKey(interval.end)
        var records: [String] = []
        let goals = SharedHabitRepository.historyCatalog()
        let referenceDate = min(interval.end.addingTimeInterval(-1), Date.now)
        let garden = try HabitGardenLiveSnapshot.read(at: referenceDate)
        let plantRows = goals.map { goal -> String in
            let progress = max(0, garden.growth[goal.id, default: 0])
            let stage = HabitGrowthRules.stage(for: progress)
            let flowering = progress >= HabitGrowthRules.floweringThreshold
                ? "已达到开花阶段"
                : "距离开花阈值还差 \(HabitGrowthRules.floweringThreshold - progress) 成长值；不是剩余天数，后续成长值可能变化"
            return "\(goal.id)｜\(goal.title)：阶段 \(stage)，当前成长值 \(progress)；\(flowering)"
        }.joined(separator: "\n")
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
                guard let goal = goals.first(where: { $0.id == id }) else { continue }
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
                let title = goals.first(where: { $0.id == id })?.title ?? id
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
                records.append("\(date)｜\(goals.first(where: { $0.id == id })?.title ?? id)：系统记录：\(state)；用户填写议题：\(topic.isEmpty ? "（未填写）" : topic)")
            }
        }
        if !records.isEmpty && !plantRows.isEmpty {
            records.append("【周期结束时或当前的植物成长快照；不是本周期增长，不能预测开花日期】\n" + plantRows)
        }
        return records.joined(separator: "\n")
    }

    private func bind(_ values: [String], to statement: OpaquePointer) throws {
        for (index, value) in values.enumerated() {
            let result = value.withCString {
                sqlite3_bind_text(statement, Int32(index + 1), $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            guard result == SQLITE_OK else { throw NativeDatabaseError.unavailable(AppLanguage.text("无法读取月度报告数据。")) }
        }
    }

    private func insight(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(AppLanguage.text(title)).foregroundStyle(muted)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
    }

    private func daySheet(_ day: ReviewDay) -> some View {
        let goals = SharedHabitRepository.historyCatalog()
        return ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text(dateLabel(day.date)).font(.system(size: 24, weight: .semibold)).opacity(reduceMotion ? 1 : 0)
                Text(String(format: AppLanguage.text("完成 %lld 项 · 获得 %lld 积分"), day.completed.count, day.points))
                    .foregroundStyle(muted)
                if day.completed.isEmpty { Text(AppLanguage.text("当天没有有效完成")).foregroundStyle(muted) }
                ForEach(day.completed, id: \.self) { id in
                    Text(AppLanguage.text(goals.first(where: { $0.id == id })?.title ?? id))
                }
                if let note = day.note {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLanguage.text("H1 复盘内容")).font(.headline)
                        Text(String(format: AppLanguage.text("决定：%@\n结果：%@\n下次：%@"), note.decision, note.result, note.improvement))
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
        return AppLanguage.date(range.start, template: "MMMd") + " — " + AppLanguage.date(end, template: "MMMd")
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

    private func weekday(_ date: Date) -> String { AppLanguage.date(date, template: "EEEEE") }
    private func monthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date)
    }
    private func dateLabel(_ date: Date) -> String { AppLanguage.date(date, template: "yMMMd") }
    private func encouragement(_ count: Int) -> String {
        if period == .week && range.start > Date.now { return AppLanguage.text("这一周尚未开始，暂无完成记录。") }
        if period == .week { return count == 0 ? AppLanguage.text("这周还没有完成记录。从一个小动作重新开始。") : AppLanguage.text("每一次完成，都是本周留下的真实证据。") }
        switch count {
        case 0: return AppLanguage.text("这个月还没有留下完成记录，不用责怪自己。挑一个最小动作，今天重新开始。")
        case 1...3: return AppLanguage.text("你已经开始留下证据了。小小的重复，会慢慢变成更稳的自己。")
        case 4...10: return AppLanguage.text("你正在把坚持变成日常。下个月继续守住最容易做到的那一步。")
        default: return AppLanguage.text("这份记录很有分量。你不是靠某一天的冲劲，而是在给生活持续加一点复利。")
        }
    }

    private func categoryInsight(_ data: ReviewSnapshot, goals: [Goal]) -> String {
        guard data.completions > 0 else { return AppLanguage.text("还没有完成记录，先从一个最容易开始的动作建立样本。") }
        let groups: [(String, [Goal])] = [
            ("普通", goals.filter { !data.starredIDs.contains($0.id) && !["H5", "H7", "H10", "H11"].contains($0.id) }),
            ("周期", goals.filter { !data.starredIDs.contains($0.id) && ["H5", "H7", "H10", "H11"].contains($0.id) }),
            ("星标", goals.filter { data.starredIDs.contains($0.id) })
        ]
        let ranked = groups.filter { !$0.1.isEmpty }.map { ($0.0, Double($0.1.reduce(0) { $0 + data.count($1.id) }) / Double($0.1.count)) }
        guard let strongest = ranked.max(by: { $0.1 < $1.1 })?.0 else { return AppLanguage.text("继续积累记录，才能形成可靠的类型比较。") }
        switch strongest {
        case "普通": return AppLanguage.text("普通习惯的平均完成次数最高。继续保持稳定的日常节律。")
        case "周期": return AppLanguage.text("周期习惯的平均完成次数最高。继续提前安排执行时间。")
        default: return AppLanguage.text("星标习惯的平均完成次数最高。它们不加积分，仍值得长期坚持。")
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
        case .preparing: period == .week ? AppLanguage.text("正在整理本周记录…") : AppLanguage.text("正在整理本月记录…")
        case .sending: AppLanguage.text("正在等待 AI 分析…")
        case .organizing: AppLanguage.text("正在整理分析结果…")
        case .complete: AppLanguage.text("分析完成")
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
            Text(AppLanguage.text(messages[index]))
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
    @Environment(\.locale) private var locale
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
                        Text(verbatim: AppLanguage.date(day.date, template: "EEE"))
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
                        .accessibilityLabel(String(format: AppLanguage.text("%@，完成 %lld 项"), dateKey(day.date), day.completed.count))
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
        .accessibilityHint(AppLanguage.text("左右滑动切换日期；点选中间日期查看当天记录"))
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
        AppLanguage.date(date, template: "EEEEE")
    }
}

private func dateKey(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

// Trigger lines stay at 19% / 89%; the top visual region is reduced by one third.
// Keep measurements and thresholds in window coordinates, including safe areas.
private struct ReviewScrollChrome: View {
    @Environment(\.habitBackgroundFrame) private var fullViewport
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

    private var blurAppearance: ReviewBlurAppearance { ReviewBlurAppearance(theme: colorTheme) }
    private var ink: Color { colorTheme == .lavender ? .white : Color(red: 0.17, green: 0.15, blue: 0.19) }
    private var mutedInk: Color { colorTheme == .lavender ? .white.opacity(0.92) : Color(red: 0.43, green: 0.41, blue: 0.46) }
    private let enter = Animation.timingCurve(0.22, 0.8, 0.25, 1, duration: 0.46)
    private let exit = Animation.timingCurve(0.4, 0, 0.25, 1, duration: 0.42)

    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let screenHeight = geometry.size.height + frame.minY
            let windowWidth = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows).first(where: \.isKeyWindow)?.bounds.width ?? geometry.size.width
            let coverageMinX = min(frame.minX, fullViewport.isEmpty ? frame.minX : fullViewport.minX)
            let coverageMaxX = max(frame.maxX, max(windowWidth, fullViewport.maxX))
            let coverageWidth = coverageMaxX - coverageMinX
            let coverageCenterX = (coverageMinX + coverageMaxX) / 2 - frame.minX
            let topHeight = (screenHeight * blurAppearance.topHeight).rounded()
            let bottomHeight = (screenHeight * blurAppearance.bottomHeight).rounded()
            let topLine = (screenHeight * 0.19).rounded()
            let bottomLine = (screenHeight * 0.89).rounded()
            let hasContent = bodyFrame != .zero && contentFrame != .zero
            let topCovered = hasContent && scrollOffset > 1 && bodyFrame.minY < topLine && contentFrame.maxY > 0
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
                    .frame(width: coverageWidth)
                    .position(x: coverageCenterX, y: (topHeight - 32) / 2 - frame.minY)
                edge(isTop: false, height: bottomHeight, reveal: bottomReveal)
                    .frame(width: coverageWidth)
                    .position(x: coverageCenterX, y: screenHeight - (bottomHeight - 32) / 2 - frame.minY)

                Text(AppLanguage.text("复盘"))
                    .font(.system(size: 43, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .shadow(color: colorTheme == .lavender ? .black.opacity(0.5) : .clear, radius: 1.5, y: 1)
                    .fixedSize()
                    .scaleEffect(1 - titleProgress * (1 - 26.0 / 43.0))
                    .position(x: titleX, y: titleY)
                    .opacity(titleSource == .zero ? 0 : 1)
                Text(AppLanguage.text("只读回看每天的习惯完成和记录。"))
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
        ReviewBackdropBlur(
            intensity: isTop ? CGFloat(blurAppearance.intensity) : 0.65,
            whiteOpacity: CGFloat(isTop ? blurAppearance.topOpacity : blurAppearance.bottomOpacity),
            fadeFraction: CGFloat(isTop ? blurAppearance.topFade : blurAppearance.bottomFade),
            isTop: isTop,
            isDark: colorTheme == .lavender
        )
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
// The outer 40% fades the blur and theme tint together.
private struct ReviewBackdropBlur: UIViewRepresentable {
    let intensity: CGFloat
    let whiteOpacity: CGFloat
    let fadeFraction: CGFloat
    let isTop: Bool
    let isDark: Bool

    func makeUIView(context: Context) -> BackdropView {
        BackdropView(intensity: intensity, whiteOpacity: whiteOpacity, fadeFraction: fadeFraction, isTop: isTop, isDark: isDark)
    }

    func updateUIView(_ uiView: BackdropView, context: Context) {
        uiView.updateAppearance(isDark: isDark, tintOpacity: whiteOpacity, intensity: intensity, fadeFraction: fadeFraction)
    }

    final class BackdropView: UIView {
        private let effectView = UIVisualEffectView()
        private let whiteLayer = UIView()
        private let gradient = CAGradientLayer()
        private var animator: UIViewPropertyAnimator?
        private var intensity: CGFloat
        private let isTop: Bool
        private var isDark: Bool
        private var fadeFraction: CGFloat

        init(intensity: CGFloat, whiteOpacity: CGFloat, fadeFraction: CGFloat, isTop: Bool, isDark: Bool) {
            self.intensity = intensity
            self.fadeFraction = fadeFraction
            self.isTop = isTop
            self.isDark = isDark
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            addSubview(effectView)
            whiteLayer.backgroundColor = UIColor(white: isDark ? (isTop ? 0.025 : 0.0) : (isTop ? 0.90 : 1.0), alpha: whiteOpacity)
            addSubview(whiteLayer)
            updateGradient()
            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
            layer.mask = gradient
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            rebuildBlurIfNeeded()
        }

        func updateAppearance(isDark: Bool, tintOpacity: CGFloat, intensity: CGFloat, fadeFraction: CGFloat) {
            whiteLayer.backgroundColor = UIColor(white: isDark ? (isTop ? 0.025 : 0.0) : (isTop ? 0.90 : 1.0), alpha: tintOpacity)
            self.fadeFraction = fadeFraction
            self.intensity = intensity
            let themeChanged = self.isDark != isDark
            self.isDark = isDark
            updateGradient()
            guard themeChanged else {
                if let animator, animator.state == .active { animator.fractionComplete = intensity }
                return
            }
            self.isDark = isDark
            animator?.stopAnimation(true)
            animator = nil
            effectView.effect = nil
            rebuildBlurIfNeeded()
        }

        private func updateGradient() {
            let fadeStart = max(0, min(0.95, 1 - fadeFraction))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if isDark && !isTop {
                // Fade the blur and black tint together. Zero alpha at the upper
                // edge and a smooth slope avoid a visible band above the lens.
                let samples = (0...8).map { CGFloat($0) / 8 }
                gradient.colors = [UIColor.clear.cgColor] + samples.map { t in
                    UIColor(white: 1, alpha: t * t * (3 - 2 * t)).cgColor
                }
                gradient.locations = [0] + samples.map { t in
                    NSNumber(value: Double(fadeStart + (1 - fadeStart) * t))
                }
            } else {
                gradient.colors = isTop
                    ? [UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
                    : [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.white.cgColor]
                gradient.locations = [0, NSNumber(value: Double(fadeStart)), 1]
            }
            CATransaction.commit()
            setNeedsLayout()
        }

        private func rebuildBlurIfNeeded() {
            guard window != nil, animator == nil else { return }
            let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in
                guard let self else { return }
                self.effectView.effect = UIBlurEffect(style: self.isDark ? (self.isTop ? .systemUltraThinMaterialDark : .systemThinMaterialDark) : .systemUltraThinMaterialLight)
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
                    .ignoresSafeArea(.container, edges: [.top, .bottom, .trailing])
                    .zIndex(0)

                Text(AppLanguage.text(title))
                    .font(.system(size: titleSize, weight: titleWeight, design: .rounded))
                    .tracking(-1.2 * (1 - amount))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(width: titleWidth)
                    .position(x: titleX, y: titleY)
                    .zIndex(1)

                if let subtitle {
                    Text(AppLanguage.text(subtitle))
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
    @Environment(\.habitBackgroundFrame) private var fullViewport
    @Environment(\.habitColorTheme) private var colorTheme
    let progress: CGFloat
    var visibility: ScrollEdgeVisibility = .both
    var topReveal: CGFloat? = nil
    var bottomReveal: CGFloat? = nil
    var whiteOpacity: Double = 0.45
    var bottomWhiteOpacity: Double = 0.45
    var bottomVisibleFraction: CGFloat = 0.25
    var softBottomFade = false

    var body: some View {
        GeometryReader { geometry in
            let overscan: CGFloat = 80
            // Background effects cover the window, including the Duo system rail.
            let windowWidth = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows).first(where: \.isKeyWindow)?.bounds.width ?? geometry.size.width
            let coverageWidth = max(geometry.size.width, max(windowWidth, fullViewport.maxX) - geometry.frame(in: .global).minX)
            let topHeight = geometry.size.height / 4 + overscan
            let bottomHeight = geometry.size.height * bottomVisibleFraction + overscan
            let topProgress = visibility == .top || visibility == .both ? (topReveal ?? progress) : 0
            let bottomProgress = visibility == .bottom || visibility == .both ? (bottomReveal ?? progress) : 0

            VStack(spacing: 0) {
                edgeBlur(isTop: true, height: topHeight, travel: topHeight - overscan, reveal: topProgress, whiteOpacity: whiteOpacity)
                Spacer(minLength: 0)
                edgeBlur(isTop: false, height: bottomHeight, travel: bottomHeight - overscan, reveal: bottomProgress, whiteOpacity: bottomWhiteOpacity)
            }
            .frame(width: coverageWidth, height: geometry.size.height + overscan * 2)
            .offset(y: -overscan)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func edgeBlur(isTop: Bool, height: CGFloat, travel: CGFloat, reveal: CGFloat, whiteOpacity: Double) -> some View {
        let amount = min(1, max(0, reveal))
        return Rectangle()
            .fill(AnyShapeStyle(.ultraThinMaterial))
            .environment(\.colorScheme, colorTheme == .lavender ? .dark : .light)
            .overlay(
                (colorTheme == .lavender ? Color(white: isTop ? 0.025 : 0) : Color(white: isTop ? 0.90 : 1))
                    .opacity(colorTheme == .lavender ? (isTop ? 0.34 : 0.95) : (isTop ? whiteOpacity : min(whiteOpacity, 0.32)))
            )
            .frame(height: height)
            .mask {
                LinearGradient(
                    stops: isTop
                        ? [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.94),
                            .init(color: .clear, location: 1)
                        ]
                        : (softBottomFade ? [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.12), location: 0.20),
                            .init(color: .white.opacity(0.5), location: 0.48),
                            .init(color: .white, location: 0.82),
                            .init(color: .white, location: 1)
                        ] : colorTheme == .lavender ? [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.14),
                            .init(color: .white.opacity(0.15625), location: 0.175),
                            .init(color: .white.opacity(0.5), location: 0.21),
                            .init(color: .white.opacity(0.84375), location: 0.245),
                            .init(color: .white, location: 0.28),
                            .init(color: .white, location: 1)
                        ] : [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.14),
                            .init(color: .white, location: 0.28),
                            .init(color: .white, location: 1)
                        ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .opacity(amount)
            .offset(y: (1 - amount) * (isTop ? -travel : travel))
    }
}
