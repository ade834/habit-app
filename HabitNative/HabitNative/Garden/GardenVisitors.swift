import SwiftUI

// MARK: - Visitor Types
enum VisitorKind: CaseIterable, Sendable {
    case bee
    case butterfly
    case firefly
    case ladybug
}

struct VisitorState: Identifiable, Sendable {
    let id: UUID
    let kind: VisitorKind
    var x: CGFloat
    var y: CGFloat
    var targetFlowerId: String?
    var wingPhase: Double
    var isFleeing: Bool

    init(
        id: UUID = UUID(),
        kind: VisitorKind,
        x: CGFloat,
        y: CGFloat,
        targetFlowerId: String? = nil,
        wingPhase: Double = 0,
        isFleeing: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
        self.targetFlowerId = targetFlowerId
        self.wingPhase = wingPhase
        self.isFleeing = isFleeing
    }
}

// MARK: - Companion Foliage (Grass, Vines, Twigs for Tier B)
struct CompanionFoliageView: View {
    let swayOffset: CGFloat

    init(swayOffset: CGFloat = 0) {
        self.swayOffset = swayOffset
    }

    var body: some View {
        Canvas { context, size in
            // Delicate grass blades
            let grassBlades: [(x: CGFloat, h: CGFloat, bend: CGFloat)] = [
                (size.width * 0.18, 55, -8),
                (size.width * 0.22, 42, 6),
                (size.width * 0.48, 62, -10),
                (size.width * 0.53, 48, 8),
                (size.width * 0.78, 58, 12),
                (size.width * 0.83, 38, -6)
            ]

            let grassColor = Color(red: 0.35, green: 0.58, blue: 0.40).opacity(0.65)

            for blade in grassBlades {
                var p = Path()
                let base = CGPoint(x: blade.x, y: size.height)
                let tip = CGPoint(x: blade.x + blade.bend + swayOffset * 4, y: size.height - blade.h)
                let control = CGPoint(x: blade.x + blade.bend * 0.5 + swayOffset * 2, y: size.height - blade.h * 0.5)

                p.move(to: base)
                p.addQuadCurve(to: tip, control: control)
                context.stroke(p, with: .color(grassColor), lineWidth: 1.4)
            }
        }
    }
}

// MARK: - Visitor Sprites
struct BeeSpriteView: View {
    let wingPhase: Double

    var body: some View {
        ZStack {
            // Wings
            HStack(spacing: 2) {
                Capsule()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 5, height: 9)
                    .rotationEffect(.degrees(-25 + sin(wingPhase) * 20), anchor: .bottomTrailing)
                Capsule()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 5, height: 9)
                    .rotationEffect(.degrees(25 - sin(wingPhase) * 20), anchor: .bottomLeading)
            }
            .offset(y: -5)

            // Striped Bee Body
            ZStack {
                Capsule()
                    .fill(Color(red: 0.98, green: 0.82, blue: 0.24))
                    .frame(width: 14, height: 9)

                // Stripes
                HStack(spacing: 2.5) {
                    Rectangle()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 1.8, height: 8)
                    Rectangle()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 1.8, height: 8)
                }
            }
        }
    }
}

struct ButterflySpriteView: View {
    let wingPhase: Double

    var body: some View {
        HStack(spacing: 1) {
            // Left wing
            Path { p in
                p.addEllipse(in: CGRect(x: -8, y: -12, width: 14, height: 18))
            }
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.94, green: 0.55, blue: 0.68), Color(red: 0.62, green: 0.45, blue: 0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 12, height: 16)
            .scaleEffect(x: max(0.2, cos(wingPhase)), y: 1.0, anchor: .trailing)

            // Right wing
            Path { p in
                p.addEllipse(in: CGRect(x: -4, y: -12, width: 14, height: 18))
            }
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.62, green: 0.45, blue: 0.88), Color(red: 0.94, green: 0.55, blue: 0.68)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 12, height: 16)
            .scaleEffect(x: max(0.2, cos(wingPhase)), y: 1.0, anchor: .leading)
        }
    }
}

struct LadybugSpriteView: View {
    var body: some View {
        ZStack {
            // Red shell
            Circle()
                .fill(Color(red: 0.88, green: 0.18, blue: 0.22))
                .frame(width: 10, height: 10)

            // Black center line
            Rectangle()
                .fill(Color.black)
                .frame(width: 0.8, height: 8)

            // Head
            Circle()
                .fill(Color.black)
                .frame(width: 4, height: 4)
                .offset(y: -4)

            // Tiny spots
            HStack(spacing: 3) {
                Circle().fill(Color.black).frame(width: 1.5, height: 1.5)
                Circle().fill(Color.black).frame(width: 1.5, height: 1.5)
            }
        }
    }
}

struct FireflySpriteView: View {
    let pulsePhase: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.85, green: 0.98, blue: 0.45).opacity(0.35 + sin(pulsePhase) * 0.25))
                .frame(width: 16, height: 16)
                .blur(radius: 4)

            Circle()
                .fill(Color(red: 0.95, green: 1.0, blue: 0.7))
                .frame(width: 5, height: 5)
        }
    }
}
