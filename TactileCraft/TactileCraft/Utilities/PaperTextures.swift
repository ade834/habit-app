import SwiftUI

// MARK: - 拟物调色板
enum TactilePalette {
    static let typewriterPaper = Color(red: 0.94, green: 0.90, blue: 0.82)
    static let darkDesk = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let metalChrome = Color(white: 0.35)
    static let typewriterOrange = Color(red: 0.95, green: 0.45, blue: 0.18)

    static let rolodexBackground = Color(red: 0.88, green: 0.88, blue: 0.85)
    static let envelopeFront = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let envelopeBack = Color(red: 0.92, green: 0.90, blue: 0.86)
    static let envelopeWax = Color(red: 0.76, green: 0.18, blue: 0.15)

    static let receiptPaper = Color(red: 0.98, green: 0.97, blue: 0.94)
    static let thermalInk = Color(red: 0.15, green: 0.15, blue: 0.18)
}

// MARK: - 纸张微噪点修饰器
struct PaperTextureModifier: ViewModifier {
    var intensity: Double = 0.04

    func body(content: Content) -> some View {
        content.overlay(
            // 高性能程序化微粒纸张质感
            GeometryReader { geo in
                Canvas { context, size in
                    let step: CGFloat = 6
                    var x: CGFloat = 0
                    while x < size.width {
                        var y: CGFloat = 0
                        while y < size.height {
                            let rand = (sin(Double(x * 12.9898 + y * 78.233)) * 43758.5453).truncatingRemainder(dividingBy: 1.0)
                            if rand > 0.65 {
                                let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                                let opacity = (rand - 0.65) * intensity * 2.2
                                context.fill(Path(rect), with: .color(Color.black.opacity(opacity)))
                            }
                            y += step
                        }
                        x += step
                    }
                }
                .allowsHitTesting(false)
                .blendMode(.multiply)
            }
        )
    }
}

extension View {
    func paperTexture(intensity: Double = 0.04) -> some View {
        modifier(PaperTextureModifier(intensity: intensity))
    }
}

// MARK: - 航空信封红蓝斑马斜边
struct AirMailBorder: View {
    var lineWidth: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                path.addRect(CGRect(x: 0, y: 0, width: w, height: h))
            }
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.red.opacity(0.8),
                        Color.blue.opacity(0.8),
                        Color.red.opacity(0.8),
                        Color.blue.opacity(0.8)
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, dash: [14, 10])
            )
        }
    }
}
