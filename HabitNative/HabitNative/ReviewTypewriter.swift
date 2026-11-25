import SwiftUI
import UIKit
import AVFoundation
import Observation

struct ReviewWritingField: Identifiable {
    let key: String
    let title: String
    var id: String { key }
}

struct ReviewFieldBounds: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// A saved editor draft is separate from submitting/completing a habit.
enum ReviewWritingDrafts {
    static func key(goal: String, date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        return "review.typewriter.draft.\(goal).\(Int(day))"
    }
    static func load(goal: String, date: Date) -> [String: String] {
        UserDefaults.standard.dictionary(forKey: key(goal: goal, date: date)) as? [String: String] ?? [:]
    }
    static func save(_ values: [String: String], goal: String, date: Date) {
        UserDefaults.standard.set(values, forKey: key(goal: goal, date: date))
    }
    static func removeAll() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("review.typewriter.draft.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    static func remove(goal: String, date: Date) {
        UserDefaults.standard.removeObject(forKey: key(goal: goal, date: date))
    }
}

enum AppSoundSettings {
    static let storageKey = "app.sound.effects.enabled"
    private static let legacyStorageKey = "review.typewriter.sound"

    static func migrateLegacyPreference() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: storageKey) == nil,
              let legacyValue = defaults.object(forKey: legacyStorageKey) as? Bool else { return }
        defaults.set(legacyValue, forKey: storageKey)
    }
}

struct ReviewTypewriter: View {
    let field: ReviewWritingField
    let initialText: String
    var sideSystemInset: CGFloat = 0
    let source: CGRect
    let onSave: (String) -> Void
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.habitBackgroundFrame) private var fullViewport
    @AppStorage("review.typewriter.night") private var night = false
    @AppStorage(AppSoundSettings.storageKey) private var sound = true
    @State private var text = ""
    @State private var composing = false
    @State private var expanded = false
    @State private var paperVisible = false
    @State private var machineVisible = false
    @State private var paperLightVisible = false
    @State private var saveFoldProgress: CGFloat = 0
    @State private var closing = false
    @State private var strike = 0
    @State private var caret = CGPoint(x: 54, y: 180)
    @State private var input = TypewriterInputControl()
    @State private var feedback = AppSoundFeedback()

    var body: some View {
        GeometryReader { geometry in
            let hasSideSystemArea = sideSystemInset >= 30
            let localFrame = geometry.frame(in: .global)
            let backgroundBounds = fullViewport.isEmpty ? localFrame : localFrame.union(fullViewport)
            let fullWidth = hasSideSystemArea ? max(geometry.size.width, fullViewport.width) : geometry.size.width
            let fullHeight = max(geometry.size.height, fullViewport.height)
            let origin = hasSideSystemArea ? CGPoint(x: fullViewport.minX - localFrame.minX, y: fullViewport.minY - localFrame.minY) : .zero
            let target = CGRect(x: origin.x, y: origin.y, width: max(1, fullWidth - (hasSideSystemArea ? sideSystemInset : 0)), height: fullHeight)
            let rect = expanded ? target : source
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(night ? 0.40 : 0.24))
                    .frame(width: backgroundBounds.width, height: backgroundBounds.height)
                    .offset(x: backgroundBounds.minX - localFrame.minX, y: backgroundBounds.minY - localFrame.minY)
                    .opacity(expanded ? 1 : 0)
                    .accessibilityHidden(true)
                editor(hasSideSystemArea: hasSideSystemArea)
                    .frame(width: target.width, height: target.height)
                    .scaleEffect(x: rect.width / target.width, y: rect.height / target.height)
                    .frame(width: rect.width, height: rect.height)
                    .clipShape(RoundedRectangle(cornerRadius: expanded ? 0 : 16))
                    .position(x: rect.midX, y: rect.midY)
                    .shadow(color: .black.opacity(0.35), radius: 28, y: 18)
                if hasSideSystemArea && expanded {
                    VStack(spacing: 12) {
                        Button { finish(save: false) } label: { Image(systemName: "xmark").frame(width: 38, height: 48) }
                            .accessibilityLabel(AppLanguage.text("取消编辑"))
                        Button {
                            if night { Task { await switchToDaylight() } }
                            else { night = true; paperLightVisible = false; Task { await revealPaperLightAfterMechanism() } }
                        } label: { Image(systemName: night ? "moon.fill" : "sun.max.fill").frame(width: 38, height: 48) }
                            .accessibilityLabel(night ? AppLanguage.text("切换到白昼") : AppLanguage.text("切换到夜晚"))
                        Button { sound.toggle(); if sound { feedback.play(.key, enabled: true) } else { feedback.stop() } } label: {
                            Image(systemName: sound ? "speaker.fill" : "speaker.slash.fill").frame(width: 38, height: 48)
                        }.accessibilityLabel(sound ? AppLanguage.text("关闭音效") : AppLanguage.text("开启音效"))
                        Button { finish(save: true) } label: { Image(systemName: "checkmark").frame(width: 38, height: 48) }
                            .accessibilityLabel(AppLanguage.text("保存"))
                    }
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(night ? .white : .primary)
                    .padding(3)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .position(x: origin.x + fullWidth - sideSystemInset / 2 - 6, y: origin.y + max(145, fullHeight - 140))
                    .disabled(closing)
                }
            }
        }
        .task {
            #if DEBUG
            if DevelopmentLaunch.contains("--typewriter-night") || DevelopmentLaunch.contains("--open-typewriter") {
                night = true
            }
            #endif
            text = initialText
            input.visibleText = initialText
            input.selection = NSRange(location: (initialText as NSString).length, length: 0)
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.26)) { expanded = true }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(170)) }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .none : .spring(response: 0.52, dampingFraction: 0.88)) { paperVisible = true }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(260)) }
            guard !Task.isCancelled else { return }
            input.focus()
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(220)) }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .none : .spring(response: 0.40, dampingFraction: 0.82)) { machineVisible = true }
            if night { await revealPaperLightAfterMechanism() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            input.keyboardHidden = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            input.keyboardHidden = false
        }
        .ignoresSafeArea(.keyboard)
        .accessibilityAddTraits(.isModal)
    }

    private func editor(hasSideSystemArea: Bool) -> some View {
        VStack(spacing: 0) {
            if !hasSideSystemArea { HStack(spacing: 8) {
                if !hasSideSystemArea { Button { finish(save: false) } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel(AppLanguage.text("取消编辑"))
                }
                Spacer(minLength: 0)
                Button {
                    if night {
                        Task { await switchToDaylight() }
                    } else {
                        night = true
                        paperLightVisible = false
                        Task { await revealPaperLightAfterMechanism() }
                    }
                } label: { Label(night ? AppLanguage.text("夜晚") : AppLanguage.text("白昼"), systemImage: night ? "moon.fill" : "sun.max.fill").font(.system(size: 13, weight: .medium)).frame(height: 44) }
                Button {
                    sound.toggle()
                    if sound { feedback.play(.key, enabled: true) }
                    else { feedback.stop() }
                } label: {
                    Image(systemName: sound ? "speaker.fill" : "speaker.slash")
                        .font(.system(size: 14, weight: .regular))
                        .frame(width: 38, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityValue(sound ? AppLanguage.text("已开启") : AppLanguage.text("已关闭"))
                .accessibilityLabel(sound ? AppLanguage.text("关闭音效") : AppLanguage.text("开启音效"))
                .accessibilityIdentifier("typewriter.sound")
                Spacer(minLength: 0)
                Button(AppLanguage.text("保存")) { finish(save: true) }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 52, height: 44)
                    .accessibilityIdentifier("typewriter.save")
            }
            .padding(.horizontal, 12)
            .foregroundStyle(night ? Color.white.opacity(0.88) : Color.primary.opacity(0.84))
            .opacity(paperVisible ? 1 : 0)
            }
            GeometryReader { stage in
                let inset: CGFloat = 20
                let paperWidth = max(140, stage.size.width - inset * 2)
                let paperTopInset: CGFloat = hasSideSystemArea ? 20 : 0
                let line = max(245, min(stage.size.height * 0.35, stage.size.height - stage.size.width * 0.29 - 12))
                let writingLine = max(86, line - 88)
                let textInset = max(22, stage.size.width * 0.22 - inset)
                let headX = min(max(caret.x, inset + textInset), stage.size.width - inset - textInset)
                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        paper
                        TypewriterPaperEditor(
                            text: $text,
                            composing: $composing,
                            control: input,
                            baseline: writingLine - paperTopInset,
                            horizontalInset: textInset,
                            reduceMotion: reduceMotion,
                            onCaret: { point in
                                let next = CGPoint(x: point.x + inset, y: point.y)
                                if caret != next { caret = next }
                            },
                            onStrike: { kind in
                                strike += 1
                                feedback.play(kind, enabled: sound)
                            }
                        )
                        .accessibilityLabel(AppLanguage.text(field.title))
                        .accessibilityIdentifier("typewriter.input")
                        .mask(alignment: .top) {
                            paperCurlFade
                        }
                        VStack(spacing: 8) {
                            Text(AppLanguage.text(field.title))
                                .font(.system(size: 20, weight: .bold, design: .serif))
                                .foregroundStyle(Color(white: 0.12))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            Text(String(format: AppLanguage.text("%lld 字"), text.count))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(white: 0.48))
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 1)
                                .overlay {
                                    UnevenReceiptRule().stroke(Color(white: 0.42).opacity(0.45), style: StrokeStyle(lineWidth: 0.65, dash: [3, 4]))
                                }
                                .padding(.top, 8)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 76)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: 1, y: 1 - headerCurl * 0.42, anchor: .top)
                        .rotation3DEffect(.degrees(-Double(headerCurl) * 38), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.3)
                        .offset(y: -input.paperFeed)
                        .mask(alignment: .top) { paperCurlFade.frame(height: stage.size.height) }
                        .animation(reduceMotion || input.isPaperDragging ? .none : .easeOut(duration: 0.17), value: input.paperFeed)
                        .allowsHitTesting(false)
                        if input.visibleText.isEmpty {
                            Text(AppLanguage.text("把此刻的想法，留在纸上。"))
                                .font(.custom("Songti SC", size: 16))
                                .foregroundStyle(Color.gray.opacity(0.50))
                                .position(x: paperWidth / 2, y: writingLine - paperTopInset - 16)
                                .allowsHitTesting(false)
                        }
                        if night {
                            TypewriterNightLighting(headX: headX - inset, baseline: writingLine - paperTopInset + 5, illumination: paperLightVisible ? 1 : 0)
                                .animation(reduceMotion ? .none : .easeInOut(duration: 1.15), value: paperLightVisible)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: paperWidth, height: max(0, stage.size.height - paperTopInset))
                    .clipShape(TypewriterPaperShape())
                    .position(x: stage.size.width / 2, y: (stage.size.height + paperTopInset) / 2)
                    .shadow(color: .black.opacity(0.24), radius: 10, y: 4)
                    .opacity(paperVisible ? 1 : 0)
                    .offset(y: paperVisible ? 0 : 48)
                    .scaleEffect(paperVisible ? 1 : 0.98, anchor: .bottom)
                    // Keep the sheet as one connected surface while it folds
                    // edge-on, then let the editor shrink into its source field.
                    .scaleEffect(x: 1 - saveFoldProgress * 0.035, y: 1 - saveFoldProgress * 0.92, anchor: .top)
                    .rotation3DEffect(.degrees(-Double(saveFoldProgress) * 78), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.20)
                    .animation(reduceMotion ? .none : .interactiveSpring(response: 0.24, dampingFraction: 0.84), value: headX)

                    TypewriterMechanism(headX: headX, baseline: writingLine + 5, strike: strike, activeBar: input.activeTypebar, keyEnergy: input.keyEnergy, night: night, reduceMotion: reduceMotion)
                        .frame(width: stage.size.width, height: stage.size.height)
                        .offset(y: machineVisible ? 0 : 140)
                        .opacity(machineVisible ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { input.focus() })
            }
        }
        .background(.clear)
        .disabled(closing)
    }

    // The header, ink and fibre pattern share the TextKit feed distance.
    private var headerCurl: CGFloat { min(1, max(0, (input.paperFeed - 28) / 74)) }

    private var paperCurlFade: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .black.opacity(0.12), location: 0.018),
            .init(color: .black.opacity(0.65), location: 0.055),
            .init(color: .black, location: 0.105),
            .init(color: .black, location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    private var paper: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let feed = input.paperFeed.truncatingRemainder(dividingBy: max(size.height, 1))
            ZStack(alignment: .top) {
                Color(white: 0.96)
                VStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { (index: Int) in
                        Image("ReviewPaperTexture")
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .scaleEffect(x: 1, y: index.isMultiple(of: 2) ? 1 : -1)
                            .clipped()
                            .opacity(0.76)
                    }
                }
                .offset(y: -feed)
                TypewriterPaperGrain(feed: input.paperFeed).opacity(0.14)
                    .animation(reduceMotion || input.isPaperDragging ? .none : .easeOut(duration: 0.17), value: input.paperFeed)
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.08), location: 0),
                    .init(color: .white.opacity(0.22), location: 0.035),
                    .init(color: .clear, location: 0.12),
                    .init(color: .clear, location: 0.92),
                    .init(color: .black.opacity(0.045), location: 1)
                ], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [.white.opacity(0.14), .clear, Color(white: 0.82).opacity(0.06)], startPoint: .leading, endPoint: .trailing)
                // Soft shade behind the moving curl makes the lifted edge read
                // against the paper without drawing a hard, artificial seam.
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.18 * headerCurl), location: 0),
                    .init(color: .black.opacity(0.10 * headerCurl), location: 0.42),
                    .init(color: .black.opacity(0.025 * headerCurl), location: 0.78),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .frame(height: min(size.height, 36 + headerCurl * 72))
                .frame(maxHeight: .infinity, alignment: .top)
                .animation(reduceMotion || input.isPaperDragging ? .none : .easeOut(duration: 0.17), value: input.paperFeed)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .allowsHitTesting(false)
    }

    @MainActor
    private func revealPaperLightAfterMechanism() async {
        guard night, !closing else { return }
        // Let the paper, carriage, type head and type bars settle before the lamp fires.
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled, night, machineVisible, !closing else { return }
        feedback.play(.lampIgnition, enabled: sound)
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.475)) {
            paperLightVisible = true
        }
    }

    @MainActor
    private func switchToDaylight() async {
        guard night else { return }
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled, !closing, night else { return }
        feedback.play(.lampOff, enabled: sound)
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 1.15)) {
            paperLightVisible = false
        }
        // The light layer has a 1.15s easing of its own. Keep the paper and
        // carriage in place until that full fade has finished.
        if !reduceMotion { try? await Task.sleep(for: .milliseconds(1200)) }
        guard !Task.isCancelled, !closing else { return }
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.19)) {
            night = false
        }
    }

    private func finish(save: Bool) {
        guard !closing else { return }
        // Finish Chinese composition before reading the value; do not save stale bindings.
        let committed = input.commit()
        closing = true
        input.blur()
        Task { @MainActor in
            if night {
                try? await Task.sleep(for: .milliseconds(500))
                feedback.play(.lampOff, enabled: sound)
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 1.15)) { paperLightVisible = false }
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(1200)) }
            }
            // Retract the carriage on the reverse path first. Keep the paper
            // still until the full mechanism has cleared it.
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.42)) { machineVisible = false }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(440)) }
            if save {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.72)) { saveFoldProgress = 1 }
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(780)) }
                onSave(committed ?? text)
            }
            withAnimation(reduceMotion ? .none : .spring(response: 0.48, dampingFraction: 0.88)) { expanded = false }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(480)) }
            onClose()
        }
    }
}

private struct UnevenReceiptRule: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// Rebuild the small missing centre of the stationary shaft, independently of
/// carriage travel. The ruler keeps continuous spacing and never repeats ticks.
private struct HybridAxleRepair: View {
    nonisolated init() {}
    private static let shaft: UIImage = {
        let source = UIImage(named: "TypewriterHybridBase")!.cgImage!
        return UIImage(cgImage: source.cropping(to: CGRect(x: 550, y: 133, width: 300, height: 82))!)
    }()

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 2048
            Image(uiImage: Self.shaft).resizable()
                .frame(width: 312 * scale, height: 82 * scale)
                .position(x: 1057 * scale, y: 174 * scale)
            Canvas { context, size in
                var drawing = context
                drawing.scaleBy(x: size.width / 2048, y: size.height / 682)
                let ruler = CGRect(x: 901, y: 244, width: 312, height: 66)
                drawing.fill(Path(ruler), with: .linearGradient(Gradient(stops: [.init(color: Color(white: 0.27), location: 0), .init(color: Color(white: 0.255), location: 0.65), .init(color: Color(white: 0.25), location: 0.86), .init(color: Color(white: 0.49), location: 0.94), .init(color: Color(white: 0.20), location: 1)]), startPoint: CGPoint(x: 0, y: 244), endPoint: CGPoint(x: 0, y: 310)))
                for index in 32...49 {
                    let x = 318 + CGFloat(index) * 18.5
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: 247))
                    tick.addLine(to: CGPoint(x: x, y: index.isMultiple(of: 5) ? 267 : 257))
                    drawing.stroke(tick, with: .color(Color(white: 0.61)), lineWidth: 1)
                    if index.isMultiple(of: 10) {
                        drawing.draw(Text("\(index)").font(.system(size: 17)).foregroundStyle(Color(white: 0.68)), at: CGPoint(x: x, y: 286))
                    }
                }
            }
        }
    }
}

private struct TypewriterNightLighting: View {
    let headX: CGFloat
    let baseline: CGFloat
    let illumination: CGFloat

    var body: some View {
        GeometryReader { paper in
            let height = max(320, (baseline + 30) * 1.62 + 36)
            let width = min(680, paper.size.width * 1.80)
            let sourceY = baseline + 42
            let center = CGPoint(x: headX, y: sourceY - height / 2)
            let ambientHeight = height * 1.08
            let ambientCenter = CGPoint(x: headX, y: sourceY - ambientHeight / 2)
            let fold = min(38, paper.size.height * 0.10) / max(paper.size.height, 1)
            let bendFade = LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: fold * 0.24),
                .init(color: .white.opacity(0.15), location: fold * 0.48),
                .init(color: .white.opacity(0.60), location: fold * 0.76),
                .init(color: .white, location: fold),
                .init(color: .white, location: 1)
            ], startPoint: .top, endPoint: .bottom)
            ZStack {
                Rectangle().fill(.black.opacity(0.556))
                    .mask {
                        Rectangle().overlay {
                            TypewriterScatteredBeam()
                                .fill(RadialGradient(colors: [.black.opacity(0.55), .black.opacity(0.22), .clear], center: .bottom, startRadius: 0, endRadius: ambientHeight * 1.15))
                                .frame(width: width * 1.48, height: ambientHeight)
                                .blur(radius: 42)
                                .position(ambientCenter)
                                .mask(bendFade)
                                .opacity(illumination * 0.45)
                                .blendMode(.destinationOut)
                            TypewriterScatteredBeam()
                                .fill(RadialGradient(stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.96), location: 0.18), .init(color: .black.opacity(0.65), location: 0.52), .init(color: .black.opacity(0.16), location: 0.85), .init(color: .clear, location: 1)], center: .bottom, startRadius: 0, endRadius: height * 1.08))
                                .frame(width: width, height: height)
                                .blur(radius: 18)
                                .position(center)
                                .mask(bendFade)
                                .opacity(illumination)
                                .blendMode(.destinationOut)
                        }.compositingGroup()
                    }
                TypewriterScatteredBeam()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.92, blue: 0.80).opacity(0.18), Color(red: 1, green: 0.94, blue: 0.86).opacity(0.06), .clear], center: .bottom, startRadius: 0, endRadius: ambientHeight * 1.15))
                    .frame(width: width * 1.48, height: ambientHeight)
                    .blur(radius: 42)
                    .position(ambientCenter)
                    .mask(bendFade)
                    .opacity(illumination)
                    .blendMode(.screen)
                TypewriterScatteredBeam()
                    .fill(RadialGradient(gradient: Gradient(stops: [
                        .init(color: Color(red: 1, green: 0.88, blue: 0.66).opacity(0.40), location: 0),
                        .init(color: Color(red: 1, green: 0.92, blue: 0.78).opacity(0.22), location: 0.38),
                        .init(color: Color(red: 1, green: 0.94, blue: 0.84).opacity(0.08), location: 0.72),
                        .init(color: .clear, location: 1)
                    ]), center: .bottom, startRadius: 4, endRadius: height * 1.08))
                    .frame(width: width, height: height)
                    .blur(radius: 18)
                    .position(center)
                    .mask(bendFade)
                    .opacity(illumination)
                    .blendMode(.screen)
                // A faint, focused rim stays near the lamp head, then dissolves
                // as the beam travels across the paper.
                TypewriterScatteredBeam()
                    .stroke(Color(red: 1, green: 0.92, blue: 0.76).opacity(0.22 * illumination), lineWidth: 1.1)
                    .frame(width: width, height: height)
                    .position(center)
                    .mask(LinearGradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white.opacity(0.78), location: 0.16),
                        .init(color: .white.opacity(0.20), location: 0.42),
                        .init(color: .clear, location: 0.64),
                        .init(color: .clear, location: 1)
                    ], startPoint: .bottom, endPoint: .top))
                    .mask(bendFade)
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.12), location: 0),
                    .init(color: .black.opacity(0.045), location: 0.10),
                    .init(color: .clear, location: 0.24),
                    .init(color: .clear, location: 0.76),
                    .init(color: .black.opacity(0.045), location: 0.90),
                    .init(color: .black.opacity(0.12), location: 1)
                ], startPoint: .leading, endPoint: .trailing)
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.20), location: 0),
                    .init(color: .black.opacity(0.13), location: fold * 0.55),
                    .init(color: .black.opacity(0.035), location: fold * 1.25),
                    .init(color: .clear, location: fold * 2.1),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

private struct TypewriterScatteredBeam: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - 5, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.height * 0.10), control1: CGPoint(x: r.width * 0.39, y: r.height * 0.82), control2: CGPoint(x: r.width * 0.08, y: r.height * 0.35))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.height * 0.10), control: CGPoint(x: r.midX, y: -r.height * 0.10))
        p.addCurve(to: CGPoint(x: r.midX + 5, y: r.maxY), control1: CGPoint(x: r.width * 0.92, y: r.height * 0.35), control2: CGPoint(x: r.width * 0.61, y: r.height * 0.82))
        p.closeSubpath()
        return p
    }
}

private struct TypewriterPaperShape: Shape {
    func path(in r: CGRect) -> Path {
        // Native continuous corners, stretched vertically to form the paper curl.
        let horizontalScale: CGFloat = 32.0 / 74.0
        return UnevenRoundedRectangle(
            topLeadingRadius: 74, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 74,
            style: .continuous
        )
        .path(in: CGRect(x: 0, y: 0, width: r.width / horizontalScale, height: r.height))
        .applying(CGAffineTransform(scaleX: horizontalScale, y: 1))
    }
}

private struct TypewriterPaperGrain: View, Animatable {
    var feed: CGFloat = 0
    var animatableData: CGFloat {
        get { feed }
        set { feed = newValue }
    }

    var body: some View {
        Canvas { context, size in
            // Stable seed: fibres never shimmer or regenerate during typing.
            var seed: UInt64 = 73921
            func random() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / Double(UInt32.max >> 1)
            }
            func paperY(_ value: Double) -> Double {
                let height = max(size.height, 1)
                return (value - Double(feed).truncatingRemainder(dividingBy: height) + height).truncatingRemainder(dividingBy: height)
            }
            var stainContext = context
            stainContext.addFilter(.blur(radius: 3))
            for _ in 0..<46 {
                let x = random() * size.width
                let y = paperY(random() * size.height)
                let radius = 1.5 + random() * 8
                stainContext.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 1.8, height: radius)), with: .color(Color(red: 0.47, green: 0.45, blue: 0.40).opacity(0.018 + random() * 0.035)))
            }
            for _ in 0..<4600 {
                let x = random() * size.width, y = paperY(random() * size.height)
                let width = 0.25 + random() * 1.0
                let rect = CGRect(x: x, y: y, width: width, height: width * (0.5 + random() * 1.9))
                context.fill(Path(ellipseIn: rect), with: .color(Color.gray.opacity(0.04 + random() * 0.12)))
            }
            for index in 0..<900 {
                let start = CGPoint(x: random() * size.width, y: paperY(random() * size.height))
                var fibre = Path()
                fibre.move(to: start)
                fibre.addLine(to: CGPoint(x: start.x + random() * 3.5 - 1.75, y: start.y + random() * 1.5 + 0.5))
                context.stroke(fibre, with: .color(index.isMultiple(of: 3) ? .white.opacity(0.35) : .gray.opacity(0.045)), lineWidth: 0.25)
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

private struct TypewriterStrikePose {
    var needleLift: CGFloat = 0
    var barPressure: CGFloat = 0
    var lampIntensity: CGFloat = 0
}

@MainActor private struct TypewriterMechanism: View {
    let headX: CGFloat
    let baseline: CGFloat
    let strike: Int
    let activeBar: Int
    let keyEnergy: CGFloat
    let night: Bool
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            // Align the outside of both black knobs with the screen edges.
            let scale = geometry.size.width / 1994
            let width = scale * 2048
            let edgeOffset = -45 * scale
            let height = scale * 682
            let travel = headX - edgeOffset - 1055 * scale
            Color.clear.frame(width: width, height: height)
                .keyframeAnimator(initialValue: TypewriterStrikePose(), trigger: strike) { _, pose in
                    ZStack(alignment: .topLeading) {
                        HybridAxleRepair()
                            .frame(width: width, height: height)
                        layer("TypewriterHybridBase", width: width, height: height)
                            .mask(HybridPartMask(part: .stationary).fill(style: FillStyle(eoFill: true)))
                        layer("TypewriterHybridBase", width: width, height: height)
                            .mask(HybridPartMask(part: .lever))
                            .rotationEffect(.degrees(-2), anchor: UnitPoint(x: 193.0 / 2048, y: 220.0 / 682))
                        ZStack(alignment: .topLeading) {
                            layer("TypewriterHybridMechanism", width: width, height: height)
                                .mask(HybridPartMask(part: .fan))
                                .mask(HybridPartMask(part: .unselectedBar(activeBar)).fill(style: FillStyle(eoFill: true)))
                            layer("TypewriterHybridMechanism", width: width, height: height)
                                .mask(HybridPartMask(part: .fan))
                                .mask(HybridPartMask(part: .selectedBar(activeBar)))
                                .scaleEffect(x: 1, y: 1 - 0.14 * pose.barPressure, anchor: UnitPoint(x: 1055.0 / 2048, y: 180.0 / 682))
                            layer("TypewriterHybridMechanism", width: width, height: height)
                                .mask(HybridPartMask(part: .body))
                                .mask(HybridPartMask(part: .notFan).fill(style: FillStyle(eoFill: true)))
                            HybridNeedleStem(lift: pose.needleLift / scale)
                                .frame(width: width, height: height)
                            layer("TypewriterHybridMechanism", width: width, height: height)
                                .mask(HybridPartMask(part: .needleCap))
                                .offset(y: -pose.needleLift)
                            HybridActivityLamps(intensity: pose.lampIntensity)
                                .frame(width: width, height: height)
                                .opacity(night ? 1 : 0)
                        }
                        .scaleEffect(1.25, anchor: UnitPoint(x: 1055.0 / 2048, y: 49.0 / 682))
                        .offset(x: travel)
                    }
                    .frame(width: width, height: height)
                    .offset(x: edgeOffset)
                    .brightness(night ? -0.15 : 0)
                } keyframes: { _ in
                    KeyframeTrack(\.needleLift) {
                        CubicKeyframe(reduceMotion ? 0 : 7, duration: 0.035)
                        SpringKeyframe(0, duration: 0.20, spring: .bouncy)
                    }
                    KeyframeTrack(\.barPressure) {
                        CubicKeyframe(reduceMotion ? 0 : 1, duration: 0.045)
                        SpringKeyframe(0, duration: 0.20, spring: .bouncy)
                    }
                    KeyframeTrack(\.lampIntensity) {
                        CubicKeyframe(keyEnergy, duration: 0.025)
                        CubicKeyframe(keyEnergy * 0.22, duration: 0.095)
                        CubicKeyframe(0, duration: 0.23)
                    }
                }
                .offset(y: baseline - 49 * scale)
                .animation(reduceMotion ? .none : .interactiveSpring(response: 0.16, dampingFraction: 0.82), value: travel)
        }
        .accessibilityHidden(true)
    }

    nonisolated private func layer(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        Image(name).resizable().scaledToFit().frame(width: width, height: height)
    }
}

/// Masks keep the original photographic surface. A single narrow typebar
/// sector lifts while the remaining rods retain their exact source pixels.
private struct HybridPartMask: Shape {
    enum Part { case body, fan, notFan, needleCap, stationary, lever, carriage, support, selectedBar(Int), unselectedBar(Int) }
    let part: Part

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch part {
        case .fan: path = fan()
        case .body:
            path.addRect(CGRect(x: 925, y: 114, width: 267, height: 116))
            path.addRect(CGRect(x: 570, y: 315, width: 970, height: 367))
            path.addRect(CGRect(x: 1036, y: 229, width: 40, height: 152))
            for points: [CGPoint] in [
                [CGPoint(x: 996, y: 224), CGPoint(x: 1034, y: 224), CGPoint(x: 1015, y: 345), CGPoint(x: 943, y: 345), CGPoint(x: 943, y: 315)],
                [CGPoint(x: 1077, y: 224), CGPoint(x: 1115, y: 224), CGPoint(x: 1170, y: 315), CGPoint(x: 1170, y: 345), CGPoint(x: 1095, y: 345)]
            ] {
                path.addLines(points)
                path.closeSubpath()
            }
        case .notFan:
            path.addRect(CGRect(x: 0, y: 0, width: 2048, height: 682))
            path.addPath(fan())
        case .needleCap: path.addRect(CGRect(x: 997, y: 44, width: 130, height: 36))
        case .carriage: path.addRoundedRect(in: CGRect(x: 925, y: 114, width: 267, height: 116), cornerSize: CGSize(width: 15, height: 15))
        case .support: path.addRoundedRect(in: CGRect(x: 1036, y: 229, width: 40, height: 152), cornerSize: CGSize(width: 5, height: 5))
        case .stationary:
            path.addRect(CGRect(x: 0, y: 0, width: 2048, height: 682))
            path.addPath(lever())
        case .lever: path = lever()
        case .selectedBar(let index): path = wedge(index)
        case .unselectedBar(let index):
            path.addRect(CGRect(x: 0, y: 0, width: 2048, height: 682))
            path.addPath(wedge(index))
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / 2048, y: rect.height / 682))
    }

    private func lever() -> Path {
        var path = Path()
        path.addLines([
            CGPoint(x: 174, y: 220), CGPoint(x: 215, y: 230),
            CGPoint(x: 88, y: 545), CGPoint(x: 22, y: 545),
            CGPoint(x: 22, y: 500), CGPoint(x: 147, y: 250)
        ])
        path.closeSubpath()
        return path
    }

    private func fan() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 620, y: 345))
        path.addCurve(to: CGPoint(x: 1490, y: 345), control1: CGPoint(x: 830, y: 505), control2: CGPoint(x: 1280, y: 505))
        path.addLine(to: CGPoint(x: 1530, y: 682))
        path.addLine(to: CGPoint(x: 580, y: 682))
        path.closeSubpath()
        return path
    }

    private func wedge(_ index: Int) -> Path {
        let center = CGPoint(x: 1055, y: 180)
        let a = (-62 + 124 * Double(index) / 45) * .pi / 180
        let b = (-62 + 124 * Double(index + 1) / 45) * .pi / 180
        var path = Path()
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x + sin(a) * 750, y: center.y + cos(a) * 750))
        path.addLine(to: CGPoint(x: center.x + sin(b) * 750, y: center.y + cos(b) * 750))
        path.closeSubpath()
        return path
    }
}

private struct HybridNeedleStem: View {
    let lift: CGFloat
    var body: some View {
        Canvas { context, size in
            var drawing = context
            drawing.scaleBy(x: size.width / 2048, y: size.height / 682)
            // Bottom remains attached to the photo carriage at y=117.
            let rect = CGRect(x: 1037, y: 75 - lift, width: 40, height: 42 + lift)
            let stem = Path(roundedRect: rect, cornerRadius: 2)
            drawing.fill(stem, with: .linearGradient(Gradient(colors: [Color(white: 0.33), Color(red: 0.88, green: 0.86, blue: 0.82), Color(white: 0.56), Color(white: 0.30)]), startPoint: CGPoint(x: rect.minX, y: 0), endPoint: CGPoint(x: rect.maxX, y: 0)))
        }
    }
}

private struct HybridActivityLamps: View {
    let intensity: CGFloat
    var body: some View {
        Canvas { context, size in
            var drawing = context
            drawing.scaleBy(x: size.width / 2048, y: size.height / 682)
            for (index, x) in [969.0, 992.0, 1015.0].enumerated() {
                let level = max(0, min(1, intensity - CGFloat(index) * 0.13))
                let center = CGPoint(x: x, y: 203)
                let glow = Path(ellipseIn: CGRect(x: x - 25, y: 178, width: 50, height: 50))
                drawing.fill(glow, with: .radialGradient(Gradient(stops: [
                    .init(color: Color.orange.opacity(0.82 * level), location: 0),
                    .init(color: Color.orange.opacity(0.30 * level), location: 0.42),
                    .init(color: Color.orange.opacity(0), location: 1)
                ]), center: center, startRadius: 1, endRadius: 25))
                let bulb = Path(ellipseIn: CGRect(x: x - 7, y: 196, width: 14, height: 14))
                drawing.fill(bulb, with: .color(Color(red: 0.50 + 0.50 * level, green: 0.20 + 0.43 * level, blue: 0.015 + 0.055 * level)))
                drawing.stroke(bulb, with: .color(Color(red: 1.0, green: 0.46, blue: 0.06).opacity(0.48 + 0.50 * level)), lineWidth: 1.35)
            }
        }
    }
}

@MainActor
@Observable
final class TypewriterInputControl {
    @ObservationIgnored weak var view: UITextView?
    var visibleText = ""
    var selection = NSRange(location: 0, length: 0)
    var markedRange: NSRange?
    var paperFeed: CGFloat = 0
    var isPaperDragging = false
    var activeTypebar = 22
    var keyEnergy: CGFloat = 0.6
    @ObservationIgnored var keyboardHidden = false
    @ObservationIgnored private var lastStrokeTime = CFAbsoluteTimeGetCurrent()
    func registerStroke() {
        let now = CFAbsoluteTimeGetCurrent()
        let interval = now - lastStrokeTime
        keyEnergy = CGFloat(0.55 + 0.45 * (1 - min(interval, 0.30) / 0.30))
        lastStrokeTime = now
    }
    var compositionText: String {
        guard let markedRange, NSMaxRange(markedRange) <= (visibleText as NSString).length else { return "" }
        return (visibleText as NSString).substring(with: markedRange)
    }
    func synchronize(_ view: UITextView) {
        if visibleText != view.text { visibleText = view.text ?? "" }
        if selection != view.selectedRange { selection = view.selectedRange }
        if let range = view.markedTextRange {
            let start = view.offset(from: view.beginningOfDocument, to: range.start)
            markedRange = NSRange(location: start, length: view.offset(from: range.start, to: range.end))
        } else { markedRange = nil }
    }
    func focus() {
        guard let view else { return }
        #if DEBUG
        if DevelopmentLaunch.contains("--open-typewriter") {
            return
        }
        #endif
        if keyboardHidden && view.isFirstResponder && view.markedTextRange == nil {
            keyboardHidden = false
            view.resignFirstResponder()
            DispatchQueue.main.async { [weak view] in view?.becomeFirstResponder() }
        } else if !view.isFirstResponder {
            view.becomeFirstResponder()
        }
    }
    func blur() { view?.resignFirstResponder() }
    func toggleKeyboard() { if view?.isFirstResponder == true { blur() } else { focus() } }
    func deleteBackward() { view?.deleteBackward() }
    func clear() {
        guard let view else { return }
        view.unmarkText()
        view.selectedRange = NSRange(location: 0, length: (view.text as NSString).length)
        view.insertText("")
    }
    func commit() -> String? {
        view?.unmarkText()
        if let view { view.delegate?.textViewDidChange?(view) }
        return view?.text
    }
}

private final class TypewriterTextView: UITextView {
    var onMarkedTextChange: (() -> Void)?
    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        if markedText != nil { onMarkedTextChange?() }
        super.setMarkedText(markedText, selectedRange: selectedRange)
    }
}

/// Real editable UITextView directly on the paper so native iOS long-press
/// loupe, selection handles, and system Copy/Cut/Paste edit menus work cleanly.
struct TypewriterPaperEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var composing: Bool
    let control: TypewriterInputControl
    let baseline: CGFloat
    var horizontalInset: CGFloat = 22
    let reduceMotion: Bool
    let onCaret: (CGPoint) -> Void
    let onStrike: (AppSoundFeedback.Kind) -> Void

    private static let inkColor = UIColor(red: 0.17, green: 0.16, blue: 0.13, alpha: 0.94)
    private static let caretTintColor = UIColor(red: 0.36, green: 0.25, blue: 0.16, alpha: 0.92)
    private static let englishFont = UIFont(name: "AmericanTypewriter", size: 20) ?? .monospacedSystemFont(ofSize: 20, weight: .regular)
    private static let chineseFont = UIFont(name: "STSongti-SC-Regular", size: 21) ?? .systemFont(ofSize: 21)
    private static let allowedAttributeKeys: Set<NSAttributedString.Key> = [.font, .foregroundColor, .paragraphStyle]

    private static func makeParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        return paragraph
    }

    private static func baseTypingAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: chineseFont,
            .foregroundColor: inkColor,
            .paragraphStyle: makeParagraphStyle()
        ]
    }

    private static func isCJK(_ substring: String) -> Bool {
        substring.unicodeScalars.contains(where: { $0.value >= 0x2e80 && $0.value <= 0x9fff })
    }

    private static func needsPaperStyling(_ storage: NSTextStorage, text: String) -> Bool {
        let fullRange = NSRange(location: 0, length: storage.length)
        var dirty = false
        storage.enumerateAttributes(in: fullRange, options: []) { attrs, _, stop in
            if !Set(attrs.keys).isSubset(of: allowedAttributeKeys) {
                dirty = true
                stop.pointee = true
                return
            }
            if (attrs[.foregroundColor] as? UIColor) != inkColor {
                dirty = true
                stop.pointee = true
                return
            }
            if (attrs[.paragraphStyle] as? NSParagraphStyle)?.lineSpacing != 7 {
                dirty = true
                stop.pointee = true
                return
            }
        }
        if dirty { return true }
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byComposedCharacterSequences) { substring, range, _, stop in
            guard let substring else { return }
            let nsRange = NSRange(range, in: text)
            guard nsRange.location < storage.length else { return }
            let expectedFont = isCJK(substring) ? chineseFont : englishFont
            if (storage.attribute(.font, at: nsRange.location, effectiveRange: nil) as? UIFont) != expectedFont {
                dirty = true
                stop = true
            }
        }
        return dirty
    }

    @MainActor
    static func applyPaperStyling(to view: UITextView) {
        let typing = baseTypingAttributes()
        guard view.markedTextRange == nil else {
            view.typingAttributes = typing
            return
        }
        let currentText = view.text ?? ""
        let storage = view.textStorage
        if storage.length > 0 && needsPaperStyling(storage, text: currentText) {
            let savedSelection = view.selectedRange
            let fullRange = NSRange(location: 0, length: storage.length)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: englishFont,
                .foregroundColor: inkColor,
                .paragraphStyle: makeParagraphStyle()
            ]
            storage.beginEditing()
            storage.setAttributes(baseAttributes, range: fullRange)
            currentText.enumerateSubstrings(in: currentText.startIndex..<currentText.endIndex, options: .byComposedCharacterSequences) { substring, range, _, _ in
                guard let substring, isCJK(substring) else { return }
                let nsRange = NSRange(range, in: currentText)
                if NSMaxRange(nsRange) <= storage.length {
                    storage.addAttribute(.font, value: chineseFont, range: nsRange)
                }
            }
            storage.endEditing()
            if view.selectedRange != savedSelection && NSMaxRange(savedSelection) <= storage.length {
                view.selectedRange = savedSelection
            }
        }
        view.typingAttributes = typing
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = TypewriterTextView()
        view.onMarkedTextChange = { [weak coordinator = context.coordinator] in coordinator?.markedTextChanged() }
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isEditable = true
        view.isSelectable = true
        view.isScrollEnabled = true
        view.allowsEditingTextAttributes = false
        view.dataDetectorTypes = []
        view.textColor = Self.inkColor
        view.tintColor = Self.caretTintColor
        view.font = Self.chineseFont
        view.typingAttributes = Self.baseTypingAttributes()
        view.markedTextStyle = [
            .foregroundColor: Self.inkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.brown.withAlphaComponent(0.5)
        ]
        view.textContentType = nil
        view.spellCheckingType = .no
        view.inlinePredictionType = .no
        view.autocorrectionType = .no
        view.smartQuotesType = .no
        view.keyboardAppearance = .dark
        view.keyboardDismissMode = .none
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.textContainer.lineFragmentPadding = 0
        view.inputAssistantItem.leadingBarButtonGroups = []
        view.inputAssistantItem.trailingBarButtonGroups = []
        #if DEBUG
        if DevelopmentLaunch.contains("--open-typewriter") {
            view.inputView = UIView(frame: .zero)
        }
        #endif
        view.delegate = context.coordinator
        view.text = text
        Self.applyPaperStyling(to: view)
        control.view = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        var insetChanged = false
        if view.bounds.height > 1 {
            let targetInset = UIEdgeInsets(
                top: max(10, baseline - 27),
                left: horizontalInset,
                bottom: max(120, view.bounds.height - baseline + 40),
                right: horizontalInset
            )
            let current = view.textContainerInset
            if abs(current.top - targetInset.top) > 0.5 ||
                abs(current.left - targetInset.left) > 0.5 ||
                abs(current.bottom - targetInset.bottom) > 0.5 ||
                abs(current.right - targetInset.right) > 0.5 {
                view.textContainerInset = targetInset
                insetChanged = true
            }
        }
        // Never overwrite marked text: UIKit owns the pinyin candidate transaction.
        if view.markedTextRange == nil, view.text != text {
            let wasEmpty = view.text.isEmpty
            let previousSelection = view.selectedRange
            view.text = text
            Self.applyPaperStyling(to: view)
            context.coordinator.lastVisible = text
            let length = (text as NSString).length
            let targetLocation = wasEmpty ? length : min(previousSelection.location, length)
            view.selectedRange = NSRange(location: targetLocation, length: 0)
            control.synchronize(view)
            DispatchQueue.main.async {
                context.coordinator.align(view, feedPaper: true, animated: false)
            }
        } else if insetChanged, !context.coordinator.isUserInteracting(view) {
            DispatchQueue.main.async {
                context.coordinator.align(view, feedPaper: view.selectedRange.length == 0, animated: false)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TypewriterPaperEditor
        var lastVisible = ""
        private var lastDelegateStroke = CFAbsoluteTimeGetCurrent() - 1

        init(_ parent: TypewriterPaperEditor) {
            self.parent = parent
            self.lastVisible = parent.text
        }

        func isUserInteracting(_ view: UITextView) -> Bool {
            if view.isDragging || view.isDecelerating || view.isTracking { return true }
            if let recognizers = view.gestureRecognizers {
                for recognizer in recognizers where recognizer.state == .began || recognizer.state == .changed {
                    return true
                }
            }
            return false
        }

        func markedTextChanged() {
            // Some third-party keyboards update marked text without shouldChangeTextIn.
            guard CFAbsoluteTimeGetCurrent() - lastDelegateStroke > 0.04 else { return }
            lastDelegateStroke = CFAbsoluteTimeGetCurrent()
            parent.control.registerStroke()
            parent.onStrike(.key)
        }

        func textViewDidChange(_ view: UITextView) {
            let next = view.text ?? ""
            if view.markedTextRange != nil {
                // The IME owns provisional pinyin. Keep saved text committed;
                // physical-key feedback comes from shouldChangeTextIn.
                parent.composing = true
                align(view, feedPaper: true, animated: !parent.reduceMotion)
                return
            }
            parent.composing = false
            TypewriterPaperEditor.applyPaperStyling(to: view)
            if next != lastVisible {
                lastVisible = next
            }
            if parent.text != next {
                parent.text = next
            }
            align(view, feedPaper: true, animated: !parent.reduceMotion)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            lastDelegateStroke = CFAbsoluteTimeGetCurrent()
            let kind: AppSoundFeedback.Kind
            if replacement.isEmpty {
                kind = .delete
            } else if replacement == "\n" {
                kind = .returnCarriage
            } else if textView.markedTextRange != nil && !replacement.unicodeScalars.allSatisfy({
                CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'").contains($0)
            }) {
                // Pinyin stays a key sound. Confirming a Han character, emoji,
                // or a space from the candidate bar gets its own sound.
                kind = .candidate
            } else {
                kind = .key
            }
            if replacement.isEmpty { parent.control.activeTypebar = 44 }
            else if replacement == "\n" { parent.control.activeTypebar = 22 }
            else { parent.control.activeTypebar = Int(replacement.unicodeScalars.reduce(UInt32(0)) { ($0 &* 31 &+ $1.value) % 45 }) }
            parent.control.registerStroke()
            parent.onStrike(kind)
            return true
        }

        func textViewDidBeginEditing(_ view: UITextView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.align(view, feedPaper: true, animated: false)
            }
        }

        func textViewDidChangeSelection(_ view: UITextView) {
            parent.control.synchronize(view)
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                // Never force paper scroll while user is selecting or dragging the loupe.
                self.align(view, feedPaper: false, animated: false)
            }
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            parent.control.isPaperDragging = true
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { parent.control.isPaperDragging = false }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            parent.control.isPaperDragging = false
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let feed = max(0, scrollView.contentOffset.y)
            if abs(parent.control.paperFeed - feed) > 0.5 {
                parent.control.paperFeed = feed
            }
        }

        func align(_ view: UITextView, feedPaper: Bool, animated: Bool) {
            parent.control.synchronize(view)
            view.layoutIfNeeded()
            let length = (view.text as NSString).length
            let offset = min(NSMaxRange(view.selectedRange), length)
            guard let position = view.position(from: view.beginningOfDocument, offset: offset) else { return }
            let rect = view.caretRect(for: position)
            guard !rect.isNull, !rect.isInfinite, rect.midX.isFinite, rect.maxY.isFinite else { return }
            parent.onCaret(CGPoint(x: rect.midX, y: parent.baseline))
            guard feedPaper, view.selectedRange.length == 0, !isUserInteracting(view) else { return }
            let paperOffset = max(0, rect.maxY - parent.baseline)
            if abs(parent.control.paperFeed - paperOffset) > 0.5 {
                parent.control.paperFeed = paperOffset
            }
            if abs(view.contentOffset.y - paperOffset) > 0.5 {
                if animated && !parent.reduceMotion {
                    UIView.animate(withDuration: 0.17, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
                        view.contentOffset = CGPoint(x: 0, y: paperOffset)
                    }
                } else {
                    view.contentOffset = CGPoint(x: 0, y: paperOffset)
                }
            }
        }
    }
}

@MainActor
final class AppSoundFeedback {
    enum Kind: Int { case key, candidate, delete, returnCarriage, lampIgnition, lampOff, completion, selection, navigation, navigationToday, navigationGarden, navigationReview, goalStartClick, settingsTap, timerStart, timerPause, timerResume, gardenSelect, flowerTouch, flowerInfo, pageTurn, starMarked, waterDrop, stageSprout, stageGrow, stageBloom, stageFlourish, nurture, wind }
    private var players: [Int: [AVAudioPlayer]] = [:]
    private var windPlayer: AVAudioPlayer?
    private var windStopTask: Task<Void, Never>?
    private let haptic = UIImpactFeedbackGenerator(style: .soft)
    private var lastHit = CFAbsoluteTimeGetCurrent()
    func play(_ kind: Kind, enabled: Bool) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastHit > 0.025 else { return }
        lastHit = now
        let isQuietFeedback = kind == .navigation || kind == .navigationToday || kind == .navigationGarden || kind == .navigationReview || kind == .goalStartClick || kind == .settingsTap
        haptic.impactOccurred(intensity: kind == .key ? 0.45 : (isQuietFeedback ? 0.14 : 0.3))
        guard enabled else { return }
        if players[kind.rawValue] == nil {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            if let soundURL = Self.recordedSoundURL(for: kind),
               let player = try? AVAudioPlayer(contentsOf: soundURL) {
                players[kind.rawValue] = [player]
            } else {
                players[kind.rawValue] = (0..<4).compactMap { _ in try? AVAudioPlayer(data: Self.wave(kind)) }
            }
            players[kind.rawValue]?.forEach { $0.prepareToPlay(); $0.volume = Self.volume(for: kind) }
        }
        guard let pool = players[kind.rawValue], let player = pool.first(where: { !$0.isPlaying }) ?? pool.first else { return }
        player.currentTime = 0
        player.play()
    }
    func stop() {
        players.values.flatMap { $0 }.forEach { $0.stop(); $0.currentTime = 0 }
        stopWindLoop()
    }

    func startWindLoop(enabled: Bool) {
        guard enabled else { return }
        windStopTask?.cancel()
        windStopTask = nil
        if let player = windPlayer, player.isPlaying {
            // A quick re-press during the tail of the fade restores the loop
            // smoothly instead of leaving it nearly silent.
            player.setVolume(0.12, fadeDuration: 0.65)
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        guard let player = try? AVAudioPlayer(data: Self.wave(.wind)) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        guard player.play() else { return }
        windPlayer = player
        player.setVolume(0.12, fadeDuration: 0.65)
    }

    func stopWindLoop() {
        guard let player = windPlayer else { return }
        windStopTask?.cancel()
        player.setVolume(0, fadeDuration: 0.75)
        windStopTask = Task { @MainActor [weak self, weak player] in
            try? await Task.sleep(for: .milliseconds(820))
            guard !Task.isCancelled else { return }
            player?.stop()
            self?.windPlayer = nil
            self?.windStopTask = nil
        }
    }
    // Bundle real lamp-switch recordings and synthesize short interface sounds locally.
    private static func recordedSoundURL(for kind: Kind) -> URL? {
        let resource: String
        switch kind {
        case .lampIgnition: resource = "light_switch_turn_on"
        case .lampOff: resource = "light_switch_turn_off"
        default: return nil
        }
        return Bundle.main.url(forResource: resource, withExtension: "mp3")
    }

    private static func volume(for kind: Kind) -> Float {
        switch kind {
        case .key, .candidate, .delete, .returnCarriage: 0.14
        case .lampIgnition, .lampOff: 0.78
        case .completion: 0.72
        case .navigation: 0.07
        case .navigationToday, .navigationGarden, .navigationReview: 0.07
        case .goalStartClick: 0.085
        case .settingsTap: 0.065
        case .pageTurn: 0.09
        case .starMarked, .flowerTouch, .flowerInfo: 0.14
        case .waterDrop: 0.16
        case .stageSprout, .stageGrow, .stageBloom, .stageFlourish: 0.22
        case .selection, .gardenSelect: 0.14
        case .timerPause: 0.18
        case .timerStart, .timerResume: 0.24
        case .nurture: 0.28
        default: 0.32
        }
    }

    private static func wave(_ kind: Kind) -> Data {
        let rate = 22050
        let count: Int = switch kind {
        case .completion: 14_336
        case .lampIgnition, .lampOff: 9000
        case .nurture: 8600
        case .stageSprout, .stageGrow, .stageBloom, .stageFlourish: 16000
        case .timerStart, .timerResume: 5200
        case .gardenSelect, .flowerInfo, .starMarked: 3800
        case .flowerTouch, .waterDrop: 2400
        case .pageTurn: 3200
        case .navigation, .navigationToday, .navigationGarden, .navigationReview: 2100
        case .goalStartClick: 1800
        case .settingsTap: 1600
        case .timerPause: 3200
        case .returnCarriage: 5000
        case .candidate: 2600
        case .wind: Int.random(in: 4...7) * rate
        default: 1800
        }
        var pcm = Data()
        var seed: UInt32 = kind == .wind ? UInt32.random(in: UInt32.min...UInt32.max) : 19273
        var filteredWind = 0.0
        let windBreathRate = Double.random(in: 0.22...0.42)
        let windBreathPhase = Double.random(in: 0..<(2 * .pi))
        let windBody = Double.random(in: 0.62...0.82)
        let windTexture = Double.random(in: 0.012...0.026)
        for i in 0..<count {
            seed = seed &* 1664525 &+ 1013904223
            let noise = Double(seed) / Double(UInt32.max) * 2 - 1
            let t = Double(i) / Double(rate)
            let frequency = kind == .delete ? 720.0 : (kind == .candidate ? 920.0 : (kind == .lampIgnition ? 440.0 : (kind == .lampOff ? 620.0 : (kind == .completion ? 1568.0 : (kind == .selection ? 960.0 : 1180.0)))))
            var sample = noise * exp(-t * 95) * 0.62 + sin(t * frequency * 2 * .pi) * exp(-t * 65) * 0.22
            if kind == .wind {
                // Soft, slowly moving filtered air. A little broadband detail
                // keeps it audible without competing with garden interaction.
                filteredWind += (noise - filteredWind) * 0.055
                let swell = 0.70 + 0.30 * sin(2 * .pi * t * windBreathRate + windBreathPhase)
                let drift = 0.94 + 0.06 * sin(2 * .pi * t * 0.11 + windBreathPhase * 0.7)
                sample = (filteredWind * windBody + noise * windTexture) * swell * drift
            } else if kind == .navigation {
                // A restrained, rounded tap. Keep it short and low so tab
                // changes feel quiet and tactile rather than playful.
                sample = sin(t * 540 * 2 * .pi) * exp(-t * 58) * 0.20
                    + noise * exp(-t * 88) * 0.035
            } else if kind == .navigationToday {
                let envelope = exp(-t * 56)
                sample = (sin(t * 520 * 2 * .pi) * 0.18 + sin(t * 1040 * 2 * .pi) * 0.035) * envelope
                    + noise * exp(-t * 95) * 0.025
            } else if kind == .navigationGarden {
                let envelope = exp(-t * 52)
                sample = (sin(t * 640 * 2 * .pi) * 0.15 + sin(t * 960 * 2 * .pi) * 0.045) * envelope
                    + noise * exp(-t * 92) * 0.022
            } else if kind == .navigationReview {
                let envelope = exp(-t * 60)
                sample = (sin(t * 460 * 2 * .pi) * 0.19 + sin(t * 1380 * 2 * .pi) * 0.025) * envelope
                    + noise * exp(-t * 100) * 0.024
            } else if kind == .goalStartClick {
                sample = noise * exp(-t * 120) * 0.28
                    + sin(t * 760 * 2 * .pi) * exp(-t * 58) * 0.16
                    + sin(t * 1520 * 2 * .pi + 0.18) * exp(-t * 92) * 0.045
            } else if kind == .settingsTap {
                sample = noise * exp(-t * 138) * 0.20
                    + sin(t * 610 * 2 * .pi) * exp(-t * 66) * 0.12
            } else if kind == .timerStart {
                let envelope = min(1, t * 90) * exp(-t * 6.5)
                sample = (sin(t * 784 * 2 * .pi) * 0.32 + sin(t * 1175 * 2 * .pi) * 0.18) * envelope
            } else if kind == .timerPause {
                sample = sin(t * 235 * 2 * .pi) * exp(-t * 58) * 0.24
                    + sin(t * 880 * 2 * .pi) * exp(-t * 105) * 0.12
                    + noise * exp(-t * 120) * 0.06
            } else if kind == .timerResume {
                let progress = min(1, t / 0.22)
                let pitch = 440 + 520 * progress
                sample = (sin(t * pitch * 2 * .pi) * 0.38 + sin(t * pitch * 1.5 * 2 * .pi) * 0.12)
                    * min(1, t * 80) * exp(-t * 5.8)
            } else if kind == .pageTurn {
                let envelope = min(1, t * 70) * exp(-t * 24)
                sample = noise * envelope * 0.12 + sin(t * 380 * 2 * .pi) * exp(-t * 65) * 0.08
            } else if [.stageSprout, .stageGrow, .stageBloom, .stageFlourish].contains(kind) {
                let stage = kind.rawValue - Kind.stageSprout.rawValue
                let base = [523.25, 659.25, 783.99, 987.77][stage]
                let envelope = min(1, t * 12) * exp(-t * 4.5)
                sample = (sin(t * base * 2 * .pi) * 0.20 + sin(t * base * 1.5 * 2 * .pi) * (0.07 + Double(stage) * 0.025)) * envelope
            } else if kind == .waterDrop {
                let pitch = 1450 - 520 * min(1, t / 0.10)
                let phase = 2 * .pi * (1450 * t - 2600 * min(t, 0.10) * min(t, 0.10))
                sample = sin(phase + (pitch - 930) * t * 0.02) * min(1, t * 160) * exp(-t * 32) * 0.38
            } else if kind == .flowerTouch {
                sample = sin(t * 690 * 2 * .pi) * min(1, t * 90) * exp(-t * 23) * 0.22
                    + sin(t * 1035 * 2 * .pi) * exp(-t * 30) * 0.08
            } else if kind == .flowerInfo || kind == .starMarked {
                let delay = max(0, t - 0.055)
                sample = sin(t * 880 * 2 * .pi) * min(1, t * 100) * exp(-t * 22) * 0.23
                    + sin(delay * 1320 * 2 * .pi) * min(1, delay * 100) * exp(-delay * 24) * 0.18
            } else if kind == .gardenSelect {
                sample = (sin(t * 1760 * 2 * .pi) * 0.38 + sin(t * 2640 * 2 * .pi) * 0.14)
                    * min(1, t * 100) * exp(-t * 15)
            } else if kind == .nurture {
                let secondTime = max(0, t - 0.105)
                let first = sin(t * 1046.5 * 2 * .pi) * min(1, t * 90) * exp(-t * 13) * 0.34
                let second = sin(secondTime * 1568 * 2 * .pi) * min(1, secondTime * 90) * exp(-secondTime * 12) * 0.28
                sample = first + second
            } else if kind == .completion {
                let attack = min(1, t * 180)
                let fundamental = sin(t * 1568 * 2 * .pi) * exp(-t * 6.4)
                let brightPartial = sin(t * 3136 * 2 * .pi + 0.14) * exp(-t * 8.2) * 0.32
                let glassPartial = sin(t * 4520 * 2 * .pi + 0.31) * exp(-t * 10.5) * 0.10
                let shimmer = sin(t * 2093 * 2 * .pi) * exp(-t * 7.4) * 0.22
                sample = attack * (fundamental * 0.56 + brightPartial + glassPartial + shimmer)
            } else if kind == .selection {
                sample = sin(t * 215 * 2 * .pi) * exp(-t * 72) * 0.22
                    + sin(t * 1240 * 2 * .pi) * exp(-t * 135) * 0.12
                    + noise * exp(-t * 125) * 0.08
            } else if kind == .lampIgnition {
                let envelope = min(1, t * 8) * exp(-t * 2.2)
                sample = (sin(t * 880 * 2 * .pi) * 0.45 + sin(t * 1320 * 2 * .pi) * 0.22) * envelope
            } else if kind == .lampOff {
                let envelope = min(1, t * 10) * exp(-t * 3.8)
                let pitch = 920 - min(1, t / 0.36) * 430
                sample = (sin(t * pitch * 2 * .pi) * 0.42 + sin(t * pitch * 1.5 * 2 * .pi) * 0.16) * envelope
            }
            if kind == .returnCarriage { sample += sin(t * 2400 * 2 * .pi) * exp(-t * 20) * 0.16 }
            if t > 0.024 { sample += noise * exp(-(t - 0.024) * 150) * 0.18 }
            var value = Int16(max(-1, min(1, sample)) * 24000).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }
        var data = Data()
        func ascii(_ s: String) { data.append(contentsOf: s.utf8) }
        func u32(_ n: UInt32) { var n = n.littleEndian; withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        func u16(_ n: UInt16) { var n = n.littleEndian; withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(pcm.count + 36)); ascii("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16); ascii("data"); u32(UInt32(pcm.count)); data.append(pcm)
        return data
    }
}
