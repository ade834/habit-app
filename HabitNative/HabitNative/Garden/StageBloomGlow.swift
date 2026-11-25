import SwiftUI

struct FlowerHeadPositionsKey: PreferenceKey {
    static var defaultValue: [String: CGPoint] = [:]
    static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

/// Four stages share the flower-head origin but have distinct colour and geometry.
struct StageBloomGlow: View {
    let level: Int
    let expansion: CGFloat
    let opacity: Double
    private var tint: Color {
        switch level {
        case 1: Color(red: 0.57, green: 0.86, blue: 0.68)
        case 2: Color(red: 0.63, green: 0.76, blue: 0.96)
        case 3: Color(red: 0.97, green: 0.68, blue: 0.78)
        default: Color(red: 1.0, green: 0.79, blue: 0.39)
        }
    }
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.white.opacity(0.72), tint.opacity(0.40), tint.opacity(0.10), .clear], center: .center, startRadius: 0, endRadius: 200))
            if level == 1 {
                Circle().stroke(tint.opacity(0.52), lineWidth: 2).padding(88)
                Circle().stroke(.white.opacity(0.28), lineWidth: 1).padding(62)
            } else if level == 2 {
                ForEach(0..<6, id: \.self) { i in
                    Ellipse().fill(LinearGradient(colors: [tint.opacity(0.3), .clear], startPoint: .bottom, endPoint: .top))
                        .frame(width: 28, height: 125).offset(y: -66).rotationEffect(.degrees(Double(i) * 60))
                }
                Circle().stroke(.white.opacity(0.30), lineWidth: 1).padding(70)
            } else if level == 3 {
                ForEach(0..<10, id: \.self) { i in
                    Capsule().fill(LinearGradient(colors: [.white.opacity(0.65), tint.opacity(0.22), .clear], startPoint: .bottom, endPoint: .top))
                        .frame(width: 5, height: 125).offset(y: -78).rotationEffect(.degrees(Double(i) * 36))
                }
                Circle().stroke(tint.opacity(0.42), lineWidth: 1.5).padding(65)
            } else {
                ForEach(0..<20, id: \.self) { i in
                    Capsule().fill(LinearGradient(colors: [.white.opacity(0.72), tint.opacity(0.25), .clear], startPoint: .bottom, endPoint: .top))
                        .frame(width: i.isMultiple(of: 4) ? 5 : 2, height: i.isMultiple(of: 4) ? 155 : 105)
                        .offset(y: -105).rotationEffect(.degrees(Double(i) * 18))
                }
                Circle().stroke(.white.opacity(0.32), lineWidth: 1).padding(60)
                Circle().stroke(tint.opacity(0.25), lineWidth: 1).padding(35)
            }
        }
        .frame(width: 400, height: 400).scaleEffect(expansion).opacity(opacity)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
