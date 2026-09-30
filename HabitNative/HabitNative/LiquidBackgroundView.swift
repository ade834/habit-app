import SwiftUI

struct LiquidBackgroundView: View {
    let reduceMotion: Bool

    var body: some View {
        CanvasLiquidBackground(reduceMotion: reduceMotion)
            .ignoresSafeArea()
    }
}

// 全屏磨砂玻璃流体光球背景：包含底部两个 6:4 比例挤压融合的主光球 + 侧边两个飘逸点缀光球
private struct CanvasLiquidBackground: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 45)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { proxy in
                ZStack {
                    // 底层淡雅米桃暖光底色
                    Color(red: 0.85, green: 0.85, blue: 0.87)

                    // 动态光球流体层
                    Canvas { context, size in
                        drawFluidSpheres(in: &context, size: size, time: time)
                    }

                    // 顶层极度通透的磨砂液态玻璃薄纱，彻底覆盖包括信号栏与时间栏在内的全屏
                    FullFrostedVeil()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .ignoresSafeArea(.all)
        .accessibilityHidden(true)
    }

    private func drawFluidSpheres(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let width = size.width
        let height = size.height
        let minDim = min(width, height)

        // ----------------------------------------------------
        // 1. 两个主光球沿左下—右上对角线相向运动：靠近、碰撞融合、再分离。
        // ----------------------------------------------------
        let morph1 = sin(time * 0.72) * 0.10 + cos(time * 0.48) * 0.05
        let morph2 = cos(time * 0.65) * 0.08 + sin(time * 0.82) * 0.05
        let collision = reduceMotion ? 0.72 : (sin(time * 0.42) + 1) * 0.5

        // 玫红球从左下向画面中心上移；橙色球从右上向中心下移。
        let pinkRadius = minDim * (0.62 + morph1)
        let pinkCenter = CGPoint(
            x: width * (0.20 + 0.31 * collision),
            y: height * (0.80 - 0.30 * collision)
        )
        let peachRadius = minDim * (0.52 + morph2)
        let peachCenter = CGPoint(
            x: width * (0.84 - 0.31 * collision),
            y: height * (0.20 + 0.32 * collision)
        )

        // ----------------------------------------------------
        // 2. 旁边漂浮的两个点缀小光球
        // 点缀光球1：右上侧浅杏晨曦暖光
        // 点缀光球2：左中上侧淡丁香粉雾
        // ----------------------------------------------------
        let floatAccent1Center = CGPoint(
            x: width * 0.86 + cos(time * 0.55) * 25,
            y: height * 0.18 + sin(time * 0.46) * 28
        )
        let floatAccent1Radius = minDim * (0.34 + sin(time * 0.65) * 0.05)

        let floatAccent2Center = CGPoint(
            x: width * 0.14 + sin(time * 0.50) * 22,
            y: height * 0.40 + cos(time * 0.42) * 24
        )
        let floatAccent2Radius = minDim * (0.28 + cos(time * 0.58) * 0.04)

        // 柔和渲染模式与漫反射模糊（模糊度 50，色彩更富饱满层次感）
        context.addFilter(.blur(radius: 50))

        // 绘制点缀光球 1：右上角晨曦暖杏光
        drawSphere(
            in: &context,
            center: floatAccent1Center,
            radius: floatAccent1Radius,
            time: time,
            phase: 0.8,
            colors: [
                Color(red: 255 / 255, green: 220 / 255, blue: 175 / 255).opacity(0.88),
                Color(red: 252 / 255, green: 180 / 255, blue: 135 / 255).opacity(0.65),
                Color(red: 252 / 255, green: 180 / 255, blue: 135 / 255).opacity(0.0)
            ]
        )

        // 绘制点缀光球 2：左中侧淡丁香粉紫雾
        drawSphere(
            in: &context,
            center: floatAccent2Center,
            radius: floatAccent2Radius,
            time: time,
            phase: 2.1,
            colors: [
                Color(red: 244 / 255, green: 175 / 255, blue: 224 / 255).opacity(0.75),
                Color(red: 222 / 255, green: 140 / 255, blue: 202 / 255).opacity(0.50),
                Color(red: 222 / 255, green: 140 / 255, blue: 202 / 255).opacity(0.0)
            ]
        )

        // 绘制底部主光球 1 (6成体量，深玫粉/紫丁香主调，扩大覆盖，高饱和通透度)
        drawSphere(
            in: &context,
            center: pinkCenter,
            radius: pinkRadius,
            time: time,
            phase: 0.0,
            colors: [
                Color(red: 240 / 255, green: 75 / 255, blue: 175 / 255).opacity(0.95),
                Color(red: 208 / 255, green: 60 / 255, blue: 165 / 255).opacity(0.88),
                Color(red: 175 / 255, green: 65 / 255, blue: 178 / 255).opacity(0.75),
                Color(red: 175 / 255, green: 65 / 255, blue: 178 / 255).opacity(0.0)
            ]
        )

        // 绘制底部主光球 2 (4成体量，暖橙金黄蜜桃调，明亮温暖光斑)
        drawSphere(
            in: &context,
            center: peachCenter,
            radius: peachRadius,
            time: time,
            phase: 3.14,
            colors: [
                Color(red: 255 / 255, green: 202 / 255, blue: 130 / 255).opacity(0.96),
                Color(red: 255 / 255, green: 150 / 255, blue: 95 / 255).opacity(0.85),
                Color(red: 242 / 255, green: 100 / 255, blue: 125 / 255).opacity(0.60),
                Color(red: 242 / 255, green: 100 / 255, blue: 125 / 255).opacity(0.0)
            ]
        )

        // 3. 两主光球碰撞挤压产生的混合熔融过渡发光（Melting Core）
        let dist = hypot(peachCenter.x - pinkCenter.x, peachCenter.y - pinkCenter.y)
        if dist < (pinkRadius + peachRadius) * 1.18 {
            let midPoint = CGPoint(
                x: pinkCenter.x * 0.40 + peachCenter.x * 0.60,
                y: pinkCenter.y * 0.45 + peachCenter.y * 0.55
            )
            let coreRadius = min(pinkRadius, peachRadius) * 0.70
            let pulse = (sin(time * 0.9) + 1.0) * 0.5

            let blendGradient = Gradient(colors: [
                Color(red: 255 / 255, green: 175 / 255, blue: 165 / 255).opacity(0.90 + pulse * 0.08),
                Color(red: 245 / 255, green: 110 / 255, blue: 185 / 255).opacity(0.62),
                .clear
            ])
            context.fill(
                Path(ellipseIn: CGRect(
                    x: midPoint.x - coreRadius,
                    y: midPoint.y - coreRadius,
                    width: coreRadius * 2,
                    height: coreRadius * 2
                )),
                with: .radialGradient(
                    blendGradient,
                    center: midPoint,
                    startRadius: 8,
                    endRadius: coreRadius
                )
            )
        }
    }

    // 绘制具有自然表面波形扰动（Fluid Morphing）的球体
    private func drawSphere(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        phase: Double,
        colors: [Color]
    ) {
        let path = organicBlobPath(center: center, radius: radius, time: time, phase: phase)
        let gradientStops: [Gradient.Stop]
        if colors.count == 3 {
            gradientStops = [
                .init(color: colors[0], location: 0.0),
                .init(color: colors[1], location: 0.55),
                .init(color: colors[2], location: 1.0)
            ]
        } else {
            gradientStops = [
                .init(color: colors[0], location: 0.0),
                .init(color: colors[1], location: 0.42),
                .init(color: colors[2], location: 0.78),
                .init(color: colors[3], location: 1.0)
            ]
        }
        let gradient = Gradient(stops: gradientStops)
        context.fill(
            path,
            with: .radialGradient(
                gradient,
                center: CGPoint(x: center.x - radius * 0.12, y: center.y - radius * 0.15),
                startRadius: radius * 0.05,
                endRadius: radius * 1.25
            )
        )
    }

    // 动态多段贝塞尔曲线模拟液体光球蠕动挤压形态（明显增大幅度与速度）
    private func organicBlobPath(
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        phase: Double
    ) -> Path {
        let pointCount = 12
        let wobble = 0.16 * sin(time * 0.72 + phase)
        let points = (0..<pointCount).map { i -> CGPoint in
            let angle = Double(i) / Double(pointCount) * .pi * 2
            let harmonic1 = sin(angle * 3 + time * 0.65 + phase) * 0.12
            let harmonic2 = cos(angle * 2 - time * 0.55 + phase) * 0.10
            let r = radius * (1.0 + harmonic1 + harmonic2)
            return CGPoint(
                x: center.x + cos(angle) * r * (1.0 + wobble),
                y: center.y + sin(angle) * r * (1.0 - wobble * 0.65)
            )
        }

        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for i in points.indices {
            let current = points[i]
            let next = points[(i + 1) % points.count]
            let mid = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: current)
        }
        path.closeSubpath()
        return path
    }
}

// 顶层全屏通透高质感磨砂玻璃罩 (iOS 27 Fluid Frost Veil)
private struct FullFrostedVeil: View {
    var body: some View {
        ZStack {
            // 超轻薄半透磨砂材质，融合光影
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.18))

            // 柔和白色漫射光晕层，强化参考图的高级通透质感
            LinearGradient(
                colors: [
                    .white.opacity(0.35),
                    Color(red: 252 / 255, green: 242 / 255, blue: 246 / 255).opacity(0.12),
                    .clear,
                    .white.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 顶部信号栏和时间栏区域的极淡柔和光晕，保证文字与图标极致清晰
            VStack {
                LinearGradient(
                    colors: [
                        .white.opacity(0.42),
                        .white.opacity(0.15),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                Spacer()
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(.all)
    }
}
