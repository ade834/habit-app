import SwiftUI
import UIKit
import Observation

struct ReviewReceiptDocument {
    let reports: QwenReviewService.MonthlyReports
    let title: String
    let start: Date
    let end: Date
    let completions: Int
    let points: Int
}

/// Owned by the page's parent so the paper and scrim also cover the bottom navigation.
@MainActor @Observable
final class ReviewReceiptPresentation {
    struct Session: Identifiable {
        let id = UUID()
        let document: ReviewReceiptDocument
    }

    var session: Session?
    var destinationFrame: CGRect = .zero
    var shouldScrollToReport = false
    var isActive: Bool { session != nil }

    func present(_ document: ReviewReceiptDocument) {
        shouldScrollToReport = false
        session = Session(document: document)
    }

    func dismiss() {
        session = nil
        shouldScrollToReport = false
    }
}

/// The holes remain transparent. As the tear advances, the upper strip separates
/// one paper bridge at a time instead of switching to a different silhouette.
struct ReviewReceiptPaper: Shape {
    var tearProgress: CGFloat = 1

    var animatableData: CGFloat {
        get { tearProgress }
        set { tearProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let count = max(1, Int(rect.width / 10))
        let step = rect.width / CGFloat(count)
        let perforationY: CGFloat = 11
        let radius: CGFloat = 1.8
        var path = Path()
        path.move(to: CGPoint(x: 0, y: perforationY * min(1, max(0, tearProgress * CGFloat(count)))))
        for index in 0..<count {
            let local = min(1, max(0, tearProgress * CGFloat(count) - CGFloat(index)))
            let y = perforationY * local
            path.addLine(to: CGPoint(x: CGFloat(index) * step, y: y))
            path.addLine(to: CGPoint(x: CGFloat(index + 1) * step, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - 3))
        for index in (0..<count).reversed() {
            let x = CGFloat(index) * step
            path.addLine(to: CGPoint(x: x + step / 2, y: rect.height))
            path.addLine(to: CGPoint(x: x, y: rect.height - 3))
        }
        path.closeSubpath()
        var holes = Path()
        for index in 0..<count {
            let center = (CGFloat(index) + 0.5) * step
            holes.addEllipse(in: CGRect(x: center - radius, y: perforationY - radius, width: radius * 2, height: radius * 2))
        }
        return path.subtracting(holes)
    }
}

/// A small matching strip stays in the printer while the lower sheet peels away.
private struct ReceiptRetainedStrip: Shape {
    func path(in rect: CGRect) -> Path {
        let path = Path(rect)
        var holes = Path()
        let count = max(1, Int(rect.width / 10))
        let step = rect.width / CGFloat(count)
        for index in 0..<count {
            let center = (CGFloat(index) + 0.5) * step
            holes.addEllipse(in: CGRect(x: center - 1.8, y: rect.height - 1.8, width: 3.6, height: 3.6))
        }
        return path.subtracting(holes)
    }
}

/// The floating paper and the saved report use identical text, width and spacing.
struct ReviewReceiptContent: View {
    let document: ReviewReceiptDocument
    var tearProgress: CGFloat = 1
    private let ink = Color(red: 0.23, green: 0.22, blue: 0.20)

    private var paragraphs: [String] {
        document.reports.analysis.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf")
                    Text("HABIT · REVIEW").tracking(2)
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                Text(document.title)
                    .font(.system(size: 23, weight: .bold))
                Text("每一次照料，都留下痕迹")
                    .font(.system(size: 11))
                    .foregroundStyle(ink.opacity(0.65))
            }
            .frame(maxWidth: .infinity)
            receiptRule
            VStack(spacing: 9) {
                metadataRow("记录编号", value: "RV–" + document.start.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_CN"))).filter(\.isNumber))
                metadataRow("记录周期", value: "\(document.start.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))) — \(document.end.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN"))))")
            }
            receiptRule
            HStack(alignment: .center, spacing: 0) {
                receiptMetric("完成行动", value: document.completions, unit: "次")
                Rectangle().fill(ink.opacity(0.13)).frame(width: 1, height: 36)
                receiptMetric("获得积分", value: document.points, unit: "分")
            }
            .padding(.vertical, 3)
            receiptRule
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("分析报告", symbol: "chart.xyaxis.line", index: "01")
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(ink.opacity(0.42))
                            .frame(width: 14, alignment: .leading)
                        Text(paragraph)
                            .font(.system(size: 14))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            receiptRule
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("鼓励与建议", symbol: "heart", index: "02")
                Text(document.reports.encouragement)
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            receiptRule
            VStack(spacing: 7) {
                Text("—  慢慢来，让习惯生根。  —")
                    .font(.system(size: 11))
                Text("留下一份记录 · 带走一点力量")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(ink.opacity(0.46))
            }
            .foregroundStyle(ink.opacity(0.65))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 3)
            HStack(spacing: 10) {
                ReviewReceiptQRCode(document: document)
                    .frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 4) {
                    Text("本期复盘存档")
                        .font(.system(size: 10, weight: .semibold))
                    Text("扫码查看行动摘要")
                        .font(.system(size: 9))
                        .foregroundStyle(ink.opacity(0.58))
                    Text("RV–\(document.completions.formatted()) · \(document.points) PTS")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.48))
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ink.opacity(0.4))
            }
            .padding(.top, 1)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .padding(.bottom, 25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ReviewReceiptPaper(tearProgress: tearProgress)
                .fill(Color(red: 0.985, green: 0.976, blue: 0.945), style: FillStyle(eoFill: true))
                .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
        }
        .accessibilityElement(children: .contain)
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(ink.opacity(0.65))
            Spacer(minLength: 8)
            Text(value).monospacedDigit()
        }
        .font(.system(size: 10, design: .monospaced))
    }

    private func receiptMetric(_ label: String, value: Int, unit: String) -> some View {
        VStack(spacing: 5) {
            Text(label).font(.system(size: 10)).foregroundStyle(ink.opacity(0.65))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)").font(.system(size: 31, weight: .semibold, design: .monospaced))
                Text(unit).font(.system(size: 10))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ title: String, symbol: String, index: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium))
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(index).font(.system(size: 10, design: .monospaced)).foregroundStyle(ink.opacity(0.45))
        }
    }

    private var receiptRule: some View {
        ReceiptDashedRule()
            .stroke(ink.opacity(0.32), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct ReceiptDashedRule: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        }
    }
}

struct ReviewReceiptOverlay: View {
    let presentation: ReviewReceiptPresentation

    var body: some View {
        GeometryReader { geometry in
            if let session = presentation.session {
                ReviewReceiptAnimation(
                    session: session,
                    presentation: presentation,
                    viewport: geometry
                )
                .id(session.id)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(presentation.isActive)
    }
}

private struct ReviewReceiptAnimation: View {
    enum Phase { case preparing, expanding, printing, ready, tearing, landing, settled }
    let session: ReviewReceiptPresentation.Session
    let presentation: ReviewReceiptPresentation
    let viewport: GeometryProxy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var phase: Phase = .preparing
    @State private var expanded = false
    @State private var dimming: Double = 0
    @State private var feed: CGFloat = 0
    @State private var paperHeight: CGFloat = 0
    @State private var tear: CGFloat = 0
    @State private var release: CGFloat = 0
    @State private var pull: CGFloat = 0
    @State private var landing: CGFloat = 0
    @State private var destination: CGRect = .zero
    @AppStorage(AppSoundSettings.storageKey) private var soundEnabled = true
    @State private var receiptSound = ReviewReceiptSound()

    private var paperWidth: CGFloat {
        // Keep the natural text wrapping identical to the destination throughout the flight.
        max(1, presentation.destinationFrame.width > 0 ? presentation.destinationFrame.width : viewport.size.width - 90)
    }
    private var printingScale: CGFloat { min(1.18, min(viewport.size.width - 40, 380) / paperWidth) }
    private var islandTop: CGFloat { max(11, viewport.safeAreaInsets.top - 51) }
    private var slotY: CGFloat { islandTop + 64 }
    private var isDetached: Bool { phase == .tearing || phase == .landing || phase == .settled }
    private var origin: CGPoint { viewport.frame(in: .global).origin }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(dimming)
                .contentShape(Rectangle())
                .accessibilityHidden(true)

            if phase == .ready || phase == .tearing {
                ReceiptRetainedStrip()
                    .fill(Color(red: 0.985, green: 0.976, blue: 0.945), style: FillStyle(eoFill: true))
                    .frame(width: paperWidth, height: 11)
                    .scaleEffect(printingScale, anchor: .topLeading)
                    .offset(x: (viewport.size.width - paperWidth * printingScale) / 2, y: slotY)
                    .opacity(1 - landing)
                    .accessibilityHidden(true)
            }

            paper
                // Once torn, paper can move freely outside the feed slot's mask.
                .mask(alignment: .top) {
                    Rectangle()
                        .padding(.top, isDetached ? 0 : slotY)
                }
                .accessibilityHidden(true)

            printerHousing

            if phase == .ready {
                Text("正在收好这份复盘…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .offset(y: viewport.size.height - max(viewport.safeAreaInsets.bottom, 24) - 48)
                    .transition(.opacity)
                    .accessibilityLabel("复盘打印完成，正在归位")
            }
        }
        .frame(width: viewport.size.width, height: viewport.size.height)
        .clipped()
        .task { await run() }
        .onChange(of: scenePhase) { _, value in
            if value != .active { presentation.dismiss() }
        }
        .onChange(of: reduceMotion) { _, value in
            if value { presentation.dismiss() }
        }
    }

    private var printerHousing: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: expanded ? 30 : 18.5,
            bottomLeadingRadius: expanded ? 19 : 18.5,
            bottomTrailingRadius: expanded ? 19 : 18.5,
            topTrailingRadius: expanded ? 30 : 18.5
        )
        .fill(.black)
        .overlay(alignment: .bottom) {
            ZStack {
                Capsule().fill(.white.opacity(0.10)).frame(height: 3)
                Capsule().fill(.black).frame(height: 1)
                Capsule().fill(.white.opacity(0.18)).frame(height: 0.5).offset(y: 1.5)
            }
            .frame(width: expanded ? paperWidth * printingScale + 5 : 86, height: 4)
            .padding(.bottom, expanded ? 2 : 7)
            .opacity(expanded ? 1 : 0)
        }
        .frame(width: expanded ? min(viewport.size.width - 20, 410) : 126,
               height: expanded ? 68 : 37)
        .position(x: viewport.size.width / 2, y: islandTop + (expanded ? 34 : 18.5))
        .accessibilityHidden(true)
    }

    private var paper: some View {
        let scale = printingScale + (1 - printingScale) * landing
        let startX = (viewport.size.width - paperWidth * printingScale) / 2
        let startY = slotY - paperHeight * printingScale * (1 - feed)
        let endX = destination.minX - origin.x
        let endY = destination.minY - origin.y
        return ReviewReceiptContent(document: session.document, tearProgress: tear)
            .frame(width: paperWidth)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { paperHeight = $0 }
            // Keep the right edge attached while the perforation opens from the left.
            .rotationEffect(.degrees(-(2.8 * tear + 2 * release + 1.6 * pull) * (1 - landing)), anchor: .topTrailing)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(
                x: startX + (endX - startX) * landing + 8 * release * (1 - landing),
                y: startY + (endY - startY) * landing + (14 * release + 11 * pull) * (1 - landing)
            )
            .frame(width: viewport.size.width, height: viewport.size.height, alignment: .topLeading)
            .opacity(phase == .preparing ? 0 : 1)
    }

    @MainActor
    private func run() async {
        do {
            // Scroll and layout finish before taking the landing coordinates.
            for _ in 0..<60 {
                try await Task.sleep(for: .milliseconds(20))
                if presentation.destinationFrame.width > 0 && paperHeight > 0 { break }
            }
            try await Task.sleep(for: .milliseconds(380))
            guard !reduceMotion, presentation.destinationFrame.width > 0, paperHeight > 0 else {
                presentation.dismiss()
                return
            }
            destination = presentation.destinationFrame
            phase = .expanding
            withAnimation(.easeInOut(duration: 0.25)) { dimming = 0.25 }
            withAnimation(.spring(response: 0.78, dampingFraction: 0.94)) { expanded = true }
            try await Task.sleep(for: .milliseconds(850))
            phase = .printing
            let generator = UIImpactFeedbackGenerator(style: .soft)
            let advanceDuration = min(0.34, max(0.20, Double(paperHeight) / 2500))
            let advances: [CGFloat] = [0.06, 0.13, 0.20, 0.28, 0.35, 0.44, 0.53, 0.61, 0.70, 0.80, 0.90, 1]
            for (index, progress) in advances.enumerated() {
                try Task.checkCancellation()
                generator.impactOccurred(intensity: 0.17)
                receiptSound.play(.printerTick, intensity: 0.12, enabled: soundEnabled)
                withAnimation(.linear(duration: advanceDuration)) { feed = progress }
                try await Task.sleep(for: .seconds(advanceDuration))
                // Every third advance rests longer; the paper is completely still here.
                try await Task.sleep(for: .milliseconds(index % 3 == 2 ? 220 : 90))
                generator.prepare()
            }
            withAnimation(.easeOut(duration: 0.15)) { phase = .ready }
            presentation.shouldScrollToReport = true
            try await Task.sleep(for: .milliseconds(550))
            phase = .tearing
            receiptSound.play(.perforation, intensity: 0.18, enabled: soundEnabled)
            let tearDuration = 0.42
            let tearStepDuration = tearDuration / 18
            for step in 1...18 {
                try Task.checkCancellation()
                // Build tension before each short rip, then let the paper relax.
                withAnimation(.easeOut(duration: tearStepDuration * 0.35)) { pull = step % 3 == 1 ? 1 : 0.38 }
                try await Task.sleep(for: .seconds(tearStepDuration * 0.35))
                withAnimation(.easeInOut(duration: tearStepDuration * 0.65)) {
                    tear = CGFloat(step) / 18
                    pull = 0
                }
                if step.isMultiple(of: 6) {
                    generator.impactOccurred(intensity: 0.24)
                }
                try await Task.sleep(for: .seconds(tearStepDuration * 0.65))
            }
            // Only after the final paper bridge breaks does the sheet leave the printer.
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
            receiptSound.play(.separation, intensity: 0.19, enabled: soundEnabled)
            withAnimation(.easeOut(duration: 0.08)) { release = 1 }
            try await Task.sleep(for: .milliseconds(80))
            phase = .landing
            // Refresh after the content has settled; do not assume a fixed screen position.
            destination = presentation.destinationFrame
            withAnimation(.spring(response: 0.64, dampingFraction: 0.92)) { landing = 1 }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { expanded = false }
            withAnimation(.easeInOut(duration: 0.55)) { dimming = 0 }
            try await Task.sleep(for: .milliseconds(760))
            phase = .settled
            presentation.dismiss()
        } catch {
            // Cancellation leaves the already saved report readable in the page.
        }
    }

}
