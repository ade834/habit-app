import SwiftUI

struct BadgeUnlockCelebration: View {
    let badge: BadgeDefinition
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.habitBackgroundFrame) private var fullViewport
    @State private var appeared = false
    @State private var flow = false

    var body: some View {
        GeometryReader { geometry in
            let localFrame = geometry.frame(in: .global)
            let screenCenterX = fullViewport.isEmpty ? localFrame.midX : fullViewport.midX
            ZStack {
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                Color(white: 0.10).opacity(0.78).ignoresSafeArea()
                if !reduceMotion {
                    TimelineView(.animation) { context in
                        let time = context.date.timeIntervalSinceReferenceDate
                        Canvas { canvas, size in
                            for index in 0..<9 {
                                let phase = (time / 2.5 + Double(index) / 9).truncatingRemainder(dividingBy: 1)
                                let x = size.width * (0.08 + Double((index * 37) % 84) / 100)
                                let y = size.height + 110 - phase * (size.height + 220)
                                let length = CGFloat(70 + (index % 3) * 22)
                                var streak = Path()
                                streak.move(to: CGPoint(x: x, y: y))
                                streak.addLine(to: CGPoint(x: x, y: y + length))
                                canvas.stroke(streak, with: .linearGradient(Gradient(colors: [.white.opacity(0.96), .white.opacity(0.38), .clear]), startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x, y: y + length)), style: StrokeStyle(lineWidth: index.isMultiple(of: 3) ? 3 : 1.8, lineCap: .round))
                                canvas.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(.white))
                            }
                        }.ignoresSafeArea()
                    }.allowsHitTesting(false).accessibilityHidden(true)
                }
                VStack(spacing: 14) {
                    Spacer(minLength: 30)
                    ZStack {
                        Circle().fill(RadialGradient(colors: [.white.opacity(0.65), .white.opacity(0.15), .clear], center: .center, startRadius: 0, endRadius: 170))
                            .frame(width: 340, height: 340).scaleEffect(flow ? 1.05 : 0.82)
                        ForEach(0..<16, id: \.self) { i in
                            Capsule().fill(LinearGradient(colors: [.white.opacity(0.8), .clear], startPoint: .bottom, endPoint: .top))
                                .frame(width: 2, height: 80).offset(y: -125)
                                .rotationEffect(.degrees(Double(i) * 22.5 + (flow ? 12 : 0)))
                                .opacity(flow ? 0.45 : 0.8)
                        }
                        if let url = Bundle.main.url(forResource: badge.imageResourceName, withExtension: "png"), let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image).resizable().scaledToFit().frame(width: 220, height: 220)
                        }
                    }
                    .offset(y: appeared ? 0 : 150).opacity(appeared ? 1 : 0)
                    Text(AppLanguage.text("恭喜你，解锁新徽章")) .font(.system(size: 19, weight: .medium))
                    Text(AppLanguage.text(badge.name)).font(.system(size: 28, weight: .semibold, design: .serif))
                    Text(AppLanguage.text(badge.requirement)).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.75)).padding(.horizontal, 36)
                    Spacer(minLength: 20)
                    Button(AppLanguage.text("收下徽章"), action: onClose).font(.headline).foregroundStyle(.black.opacity(0.8)).padding(.horizontal, 40).padding(.vertical, 14).background(.white.opacity(0.92), in: Capsule())
                        .padding(.bottom, 45)
                }
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(x: screenCenterX - localFrame.midX)
            }
        }
        .presentationBackground(.clear)
        .task {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { appeared = true }
            if !reduceMotion { withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { flow = true } }
        }
    }
}
