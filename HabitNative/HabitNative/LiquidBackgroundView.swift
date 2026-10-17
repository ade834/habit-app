import SwiftUI

struct LiquidBackgroundView: View {
    @Environment(\.habitColorTheme) private var colorTheme
    let reduceMotion: Bool

    var body: some View {
        CanvasLiquidBackground(reduceMotion: reduceMotion, colorTheme: colorTheme)
            .ignoresSafeArea()
    }
}

struct ColorThemeAtmosphereBase: View {
    let colorTheme: HabitColorTheme

    var body: some View {
        if colorTheme == .lavender {
            GeometryReader { proxy in
                ZStack {
                    let atmosphere = colorTheme.floatingOrbAtmosphere
                    atmosphere.base

                    LinearGradient(
                        colors: atmosphere.gradientStops,
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )

                    RadialGradient(
                        colors: [atmosphere.lowerGlow[0].opacity(0.62), atmosphere.lowerGlow[1].opacity(0.34), .clear],
                        center: UnitPoint(x: 0.30, y: 0.77),
                        startRadius: 12,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.72
                    )

                    RadialGradient(
                        colors: [atmosphere.upperGlow.opacity(0.72), .clear],
                        center: UnitPoint(x: 0.82, y: 0.16),
                        startRadius: 8,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.56
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
        } else {
            colorTheme.canvas
        }
    }
}

// 全屏磨砂玻璃流体光球背景：两个主光球碰撞、融合、交换色位，旁侧有呼吸点缀光球。
private struct CanvasLiquidBackground: View {
    let reduceMotion: Bool
    let colorTheme: HabitColorTheme

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 45)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { proxy in
                ZStack {
                    // 紫色模式使用参考图的深棕到中棕柔焦底色，原色模式维持原底色。
                    ColorThemeAtmosphereBase(colorTheme: colorTheme)

                    // 动态光球流体层
                    Canvas { context, size in
                        drawFluidSpheres(in: &context, size: size, time: time)
                    }

                    // 顶层极度通透的磨砂液态玻璃薄纱，彻底覆盖包括信号栏与时间栏在内的全屏
                    FullFrostedVeil(colorTheme: colorTheme)
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

        // 两个主球在当前尺寸上各缩小 20%；融合后交换色相。
        let pinkRadius = minDim * (0.68 + morph1) * 0.85 * 0.80
        let pinkCenter = CGPoint(
            x: width * (0.20 + 0.31 * collision),
            y: height * (0.80 - 0.30 * collision)
        )
        let peachRadius = minDim * (0.43 + morph2) * 0.80
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
            x: width * 0.78 + cos(time * 0.54) * 24,
            y: height * 0.14 + sin(time * 0.48) * 24
        )
        let floatAccent1Radius = minDim * (0.13 + sin(time * 0.78) * 0.025)

        let floatAccent2Center = CGPoint(
            x: width * 0.20 + sin(time * 0.46) * 22,
            y: height * 0.55 + cos(time * 0.60) * 26
        )
        let floatAccent2Radius = minDim * (0.10 + cos(time * 0.86) * 0.02)

        // 小光球使用独立的柔焦层，保留可辨认的装饰轮廓。
        var accentContext = context
        accentContext.addFilter(.blur(radius: 21.6))

        // 绘制点缀光球 1：右上角晨曦暖杏光
        drawSphere(
            in: &accentContext,
            center: floatAccent1Center,
            radius: floatAccent1Radius,
            time: time,
            phase: 0.8,
            colors: colorTheme == .lavender ? [
                colorTheme.accent.opacity(0.88),
                colorTheme.accent.mix(with: colorTheme.companion, by: 0.20).opacity(0.65),
                colorTheme.accent.mix(with: colorTheme.companion, by: 0.20).opacity(0.0)
            ] : [
                Color(red: 255 / 255, green: 220 / 255, blue: 175 / 255).opacity(0.88),
                Color(red: 252 / 255, green: 180 / 255, blue: 135 / 255).opacity(0.65),
                Color(red: 252 / 255, green: 180 / 255, blue: 135 / 255).opacity(0.0)
            ]
        )

        // 绘制点缀光球 2：左中侧淡丁香粉紫雾
        drawSphere(
            in: &accentContext,
            center: floatAccent2Center,
            radius: floatAccent2Radius,
            time: time,
            phase: 2.1,
            colors: colorTheme == .lavender ? [
                colorTheme.companion.opacity(0.75),
                colorTheme.companion.mix(with: colorTheme.accent, by: 0.18).opacity(0.50),
                colorTheme.companion.mix(with: colorTheme.accent, by: 0.18).opacity(0.0)
            ] : [
                Color(red: 244 / 255, green: 175 / 255, blue: 224 / 255).opacity(0.75),
                Color(red: 222 / 255, green: 140 / 255, blue: 202 / 255).opacity(0.50),
                Color(red: 222 / 255, green: 140 / 255, blue: 202 / 255).opacity(0.0)
            ]
        )

        context.addFilter(.blur(radius: 60))

        let orbStops = colorTheme.floatingOrbSpherePalettes
        let pinkFadeColor = colorTheme == .lavender ? colorTheme.companion : (orbStops.pink.last ?? .clear)
        let peachFadeColor = colorTheme == .lavender ? colorTheme.accent : (orbStops.peach.last ?? .clear)
        let pinkPalette = zip(orbStops.pink, [0.95, 0.88, 0.75]).map { $0.0.opacity($0.1) }
            + [pinkFadeColor.opacity(0)]
        let peachPalette = zip(orbStops.peach, [0.96, 0.85, 0.60]).map { $0.0.opacity($0.1) }
            + [peachFadeColor.opacity(0)]
        let motionPhase = time * 0.42
        let exchangeSignal = sin((motionPhase - .pi / 2) / 2)
        let exchangeProgress = reduceMotion ? 0.0 : 0.5 + 0.5 * tanh(exchangeSignal * 4.2)
        let firstSpherePalette = zip(pinkPalette, peachPalette).map {
            blendedColor(from: $0.0, to: $0.1, progress: exchangeProgress)
        }
        let secondSpherePalette = zip(peachPalette, pinkPalette).map {
            blendedColor(from: $0.0, to: $0.1, progress: exchangeProgress)
        }

        // 交换在碰撞峰值附近用连续曲线完成，分离后保留交换结果，不再跳切整套色板。
        drawSphere(in: &context, center: pinkCenter, radius: pinkRadius, time: time, phase: 0.0,
                   colors: firstSpherePalette)
        drawSphere(in: &context, center: peachCenter, radius: peachRadius, time: time, phase: 3.14,
                   colors: secondSpherePalette)

        // 3. 两主光球碰撞挤压产生的混合熔融过渡发光（Melting Core）
        let dist = hypot(peachCenter.x - pinkCenter.x, peachCenter.y - pinkCenter.y)
        if dist < (pinkRadius + peachRadius) * 1.18 {
            let midPoint = CGPoint(
                x: pinkCenter.x * 0.40 + peachCenter.x * 0.60,
                y: pinkCenter.y * 0.45 + peachCenter.y * 0.55
            )
            let coreRadius = min(pinkRadius, peachRadius) * 0.70
            let pulse = (sin(time * 0.9) + 1.0) * 0.5

            let blendGradient = Gradient(colors: colorTheme == .lavender ? [
                colorTheme.accent.mix(with: colorTheme.companion, by: 0.5).opacity(0.90 + pulse * 0.08),
                colorTheme.companion.mix(with: colorTheme.accent, by: 0.48).opacity(0.62),
                .clear
            ] : [
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

    private func blendedColor(from: Color, to: Color, progress: Double) -> Color {
        from.mix(with: to, by: min(max(progress, 0), 1))
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
                endRadius: radius * 1.50
            )
        )
    }

    // 连续变化的低频波形让轮廓伸展、收缩并形成流体瓣。
    private func organicBlobPath(
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        phase: Double
    ) -> Path {
        let pointCount = 24
        let wobble = 0.24 * sin(time * 0.52 + phase)
        let points = (0..<pointCount).map { i -> CGPoint in
            let angle = Double(i) / Double(pointCount) * .pi * 2
            let harmonic1 = sin(angle * 3 + time * 0.65 + phase) * 0.22
            let harmonic2 = cos(angle * 2 - time * 0.55 + phase) * 0.17
            let harmonic3 = sin(angle * 4 - time * 0.38 + phase) * 0.06
            let r = radius * (1.0 + harmonic1 + harmonic2 + harmonic3)
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
    let colorTheme: HabitColorTheme

    var body: some View {
        ZStack {
            // 超轻薄半透磨砂材质，融合光影
            Rectangle()
                .fill(.ultraThinMaterial.opacity(colorTheme == .lavender ? 0.04 : 0.18))

            // 柔和白色漫射光晕层，强化参考图的高级通透质感
            LinearGradient(
                colors: [
                    .white.opacity(colorTheme == .lavender ? 0.04 : 0.35),
                    Color(red: 252 / 255, green: 242 / 255, blue: 246 / 255).opacity(colorTheme == .lavender ? 0.02 : 0.12),
                    .clear,
                    .white.opacity(colorTheme == .lavender ? 0.03 : 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 顶部信号栏和时间栏区域的极淡柔和光晕，保证文字与图标极致清晰
            VStack {
                LinearGradient(
                    colors: [
                        .white.opacity(colorTheme == .lavender ? 0.06 : 0.42),
                        .white.opacity(colorTheme == .lavender ? 0.02 : 0.15),
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
