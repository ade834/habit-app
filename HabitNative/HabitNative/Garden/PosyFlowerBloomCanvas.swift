import SwiftUI

// MARK: - POSY 矢量程序化花朵生成器 (Canvas 渲染)
/// 创意代码 / 生成艺术拓扑美学 (Generative Code & Algorithmic Topology Aesthetic)
/// 本轮升级重点：
/// 1. 随机选取 4 种特异植物（蓝金星芒、经纬金晕葱、金晕绯瑰、几何风车）放大至 2 倍尺度；
/// 2. 为 2 倍大特异植物注入外围独立伴生小光团（Floating Satellite Luminous Orbs）与多层星尘闪烁小粒子（Stardust Swarm）；
/// 3. 线条保持发丝级锐利（0.50pt - 0.70pt），大尺度下展现出如同宏伟星象图般密实精巧的微观细节；
/// 4. 100% 纯数学矢量渲染，绝对锚定茎秆顶端，零位图切片依赖。
public struct PosyFlowerBloomCanvas: View {
    public let type: PosyFloraType
    public let progress: Double
    public let breathingPhase: Double
    public let windAngle: Double
    public let seed: Int

    public init(
        type: PosyFloraType,
        progress: Double,
        breathingPhase: Double = 0,
        windAngle: Double = 0,
        seed: Int = 42
    ) {
        self.type = type
        self.progress = max(0.0, min(1.0, progress))
        self.breathingPhase = breathingPhase
        self.windAngle = windAngle
        self.seed = seed
    }

    public var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let palette = type.palette
            let breath = sin(breathingPhase) * 0.035 + 1.0
            let p = progress
            let phase = breathingPhase
            let baseScale: CGFloat = type.isGiantFlora ? 2.0 : 1.0
            let s: CGFloat = baseScale * type.headScaleFactor

            // 若为 2 倍大特异植物，在底层外围绘制伴生小光团与星尘粒子群
            if type.isGiantFlora {
                let auraScale: CGFloat = (type == .hawthorn && p >= 0.75) ? s * 0.75 : s
                drawSurroundingAuraAndParticles(ctx: context, c: center, pal: palette, type: type, s: auraScale, phase: phase)
            }

            switch type {
            case .hawthorn:      renderSpecies1(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .dandelion:     renderSpecies2(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .bayWreath:     renderSpecies3(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .cornflower:    renderSpecies4(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .redBerries:    renderSpecies5(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .mimosa:        renderSpecies6(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .hydrangea:     renderSpecies7(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .allium:        renderSpecies8(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .lotusPod:      renderSpecies9(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .cherryBlossom: renderSpecies10(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .cosmos:        renderSpecies11(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            case .nightJasmine:  renderSpecies12(ctx: context, c: center, pal: palette, p: p, b: breath, phase: phase, s: s)
            }
        }
    }

    // =========================================================================
    // MARK: - 3-4 花瓣 1-2 倍顺次放大与复原算法 (Sequential Petal Bloom Wave)
    // =========================================================================
    /// 1. 作用范围：针对植物 3、植物 4 以及阶段 3-4 的开放花瓣；
    /// 2. 空间波宽：行进波每次同时覆盖 3-4 枚邻近花瓣；
    /// 3. 动态倍率：波峰处花瓣按顺序平滑放大 1-2 倍 (1.0x -> 1.85x)，随后顺滑复原至 1.0x 基准；
    /// 4. 阶段门控：阶段 1-2 保持原初状态，阶段 3-4 全量呈现涟漪顺次绽放。
    private func computeSequentialPetalScale(
        index: Int,
        total: Int,
        phase: Double,
        progress: Double,
        isCircular: Bool = true,
        period: Double = 2.4,
        maxBoost: Double = 0.85
    ) -> CGFloat {
        guard total > 1 else { return 1.0 }

        // 阶段 3-4 门控：阶段 1-2 (progress < 0.45) 尚未形成完整花瓣，基准 1.0；阶段 3-4 充分激发
        let stageGate: Double
        if progress < 0.45 {
            return 1.0
        } else if progress < 0.72 {
            stageGate = 0.45 + (progress - 0.45) / 0.27 * 0.35 // 0.45 ~ 0.80
        } else {
            stageGate = 0.80 + (progress - 0.72) / 0.28 * 0.20 // 0.80 ~ 1.00
        }

        let iD = Double(index)
        let totalD = Double(total)

        if isCircular {
            // 环形顺时针顺次扫描
            let thetaI = (2.0 * .pi * iD) / totalD
            let waveSpeed = (2.0 * .pi) / period
            let thetaWave = (phase * waveSpeed).truncatingRemainder(dividingBy: 2.0 * .pi)

            var diff = (thetaI - thetaWave).truncatingRemainder(dividingBy: 2.0 * .pi)
            if diff > .pi { diff -= 2.0 * .pi }
            if diff < -.pi { diff += 2.0 * .pi }

            // 波宽覆盖 3-4 枚花瓣：设置 halfWidth = (3.4 / total) * pi
            let halfWidth = max(0.45, (3.4 / totalD) * .pi)
            if abs(diff) < halfWidth {
                let u = abs(diff) / halfWidth
                let env = 0.5 * (1.0 + cos(.pi * u))
                return CGFloat(1.0 + env * maxBoost * stageGate)
            }
            return 1.0
        } else {
            // 扇形 / 弧形顺次扫描 (从一侧顺次推移至另一侧并平滑循环)
            let normI = iD / max(1.0, totalD - 1.0)
            let waveProg = (sin(phase * (2.0 * .pi / period)) * 0.5 + 0.5)
            let diff = abs(normI - waveProg)
            let widthNorm = max(0.35, 3.4 / totalD)
            if diff < widthNorm {
                let u = diff / widthNorm
                let env = 0.5 * (1.0 + cos(.pi * u))
                return CGFloat(1.0 + env * maxBoost * stageGate)
            }
            return 1.0
        }
    }

    // =========================================================================
    // MARK: - 基础矢量绘图原语 (Graphic Primitives)
    // =========================================================================

    /// 环绕卫星小光团与星尘微粒系统 (Surrounding Satellite Luminous Orbs & Stardust Swarm)
    private func drawSurroundingAuraAndParticles(
        ctx: GraphicsContext,
        c: CGPoint,
        pal: PosyPalette,
        type: PosyFloraType,
        s: CGFloat,
        phase: Double
    ) {
        guard s > 1.2 else { return }

        // 1. 周围伴生浮动小光团 (3-4 个紧邻花朵边缘偏心水彩光斑，呼吸微浮动)
        let clampedS = min(s, 1.25)
        let orbs: [(angleOff: Double, dist: CGFloat, rx: CGFloat, ry: CGFloat, color: Color, speed: Double)]
        switch type {
        case .hawthorn:
            orbs = [
                (-0.4, 34.0 * clampedS, 11.0 * clampedS, 9.5 * clampedS, Color(red: 0.95, green: 0.78, blue: 0.35), 0.18),
                (1.8, 32.0 * clampedS, 10.0 * clampedS, 8.5 * clampedS, Color(red: 0.45, green: 0.55, blue: 0.75), -0.22),
                (3.6, 36.0 * clampedS, 12.0 * clampedS, 10.5 * clampedS, Color(red: 0.92, green: 0.65, blue: 0.40), 0.15)
            ]
        case .cosmos:
            orbs = [
                (0.6, 36.0 * clampedS, 11.5 * clampedS, 10.0 * clampedS, Color(red: 0.82, green: 0.92, blue: 0.45), 0.20),
                (2.4, 38.0 * clampedS, 12.5 * clampedS, 11.0 * clampedS, Color(red: 0.65, green: 0.40, blue: 0.75), -0.16),
                (4.2, 34.0 * clampedS, 10.5 * clampedS, 9.0 * clampedS, Color(red: 0.95, green: 0.70, blue: 0.50), 0.22)
            ]
        case .lotusPod:
            orbs = [
                (-0.8, 36.0 * clampedS, 12.0 * clampedS, 10.0 * clampedS, Color(red: 0.92, green: 0.45, blue: 0.55), 0.16),
                (1.2, 34.0 * clampedS, 10.5 * clampedS, 9.0 * clampedS, Color(red: 0.95, green: 0.80, blue: 0.40), -0.20),
                (3.0, 37.0 * clampedS, 11.5 * clampedS, 10.0 * clampedS, Color(red: 0.60, green: 0.38, blue: 0.70), 0.18),
                (4.8, 33.0 * clampedS, 10.0 * clampedS, 8.5 * clampedS, Color(red: 0.90, green: 0.55, blue: 0.45), -0.14)
            ]
        case .cornflower:
            orbs = [
                (0.2, 35.0 * clampedS, 11.0 * clampedS, 9.5 * clampedS, Color(red: 0.28, green: 0.75, blue: 0.78), 0.19),
                (2.1, 34.0 * clampedS, 11.5 * clampedS, 10.0 * clampedS, Color(red: 0.68, green: 0.48, blue: 0.82), -0.21),
                (3.9, 37.0 * clampedS, 10.5 * clampedS, 9.0 * clampedS, Color(red: 0.95, green: 0.78, blue: 0.40), 0.15)
            ]
        default:
            orbs = []
        }

        for orb in orbs {
            let curA = orb.angleOff + phase * orb.speed
            let drift = sin(phase * 1.5 + orb.angleOff) * 2.5
            let rDist = orb.dist + CGFloat(drift)
            let orbCenter = CGPoint(x: c.x + CGFloat(cos(curA)) * rDist, y: c.y + CGFloat(sin(curA)) * rDist)
            drawGlowBlob(ctx: ctx, c: orbCenter, color: orb.color, rx: orb.rx, ry: orb.ry, opacity: 0.40)
        }

        // 2. 周围紧邻星尘小粒子群 (24 颗双层星尘轨道粒子，紧贴花朵轮廓微距轨道旋转)
        let particleCount = 24
        var particlePts: [CGPoint] = []
        for i in 0..<particleCount {
            let isOuter = (i % 2 == 0)
            let baseAngle = Double(i) / Double(particleCount) * Double.pi * 2.0
            let speed = isOuter ? 0.12 : -0.15
            let a = baseAngle + phase * speed
            let baseR: CGFloat = isOuter ? (40.0 * clampedS) : (33.0 * clampedS)
            let wobble = sin(phase * 2.0 + Double(i) * 1.4) * 2.0
            let rCur = baseR + CGFloat(wobble)
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rCur, y: c.y + CGFloat(sin(a)) * rCur)
            particlePts.append(pt)

            let twinkle = 0.35 + 0.55 * abs(sin(phase * 2.6 + Double(i) * 1.7))
            let dotR: CGFloat = isOuter ? 1.5 : 1.1
            var dot = Path()
            dot.addEllipse(in: CGRect(x: pt.x - dotR, y: pt.y - dotR, width: dotR * 2, height: dotR * 2))
            let col = pal.pollens[i % pal.pollens.count]
            ctx.fill(dot, with: .color(col.opacity(twinkle)))
        }

        // 3. 微弱的发丝星轨连线 (Constellation Trace Links)
        for i in stride(from: 0, to: particleCount, by: 3) {
            var line = Path()
            line.move(to: particlePts[i])
            line.addLine(to: particlePts[(i + 1) % particleCount])
            ctx.stroke(line, with: .color(pal.glow.opacity(0.28)), lineWidth: 0.45)
        }
    }

    /// 局部多核偏心水彩柔光团
    private func drawGlowBlob(
        ctx: GraphicsContext,
        c: CGPoint,
        color: Color,
        rx: CGFloat,
        ry: CGFloat,
        opacity: Double
    ) {
        let steps = 6
        for i in (1...steps).reversed() {
            let f = CGFloat(i) / CGFloat(steps)
            let curRx = rx * f
            let curRy = ry * f
            let op = opacity * (1.0 - Double(f) * 0.70) / Double(steps) * 2.3
            var circle = Path()
            circle.addEllipse(in: CGRect(x: c.x - curRx, y: c.y - curRy, width: curRx * 2, height: curRy * 2))
            ctx.fill(circle, with: .color(color.opacity(op)))
        }
    }

    /// 发丝级动态涟漪等高环
    private func drawHaloRings(
        ctx: GraphicsContext,
        c: CGPoint,
        maxR: CGFloat,
        count: Int,
        color: Color = Color(red: 0.68, green: 0.65, blue: 0.72).opacity(0.30),
        lineWidth: CGFloat = 0.5,
        phase: Double = 0.0
    ) {
        guard count > 0 else { return }
        let step = maxR / CGFloat(count)
        for i in 1...count {
            let wave = sin(phase * 1.5 - Double(i) * 0.7) * 1.2
            let r = max(3.0, step * CGFloat(i) + CGFloat(wave))
            var ring = Path()
            ring.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.stroke(ring, with: .color(color), lineWidth: lineWidth)
        }
    }

    /// 渐变多层次分色光晕系统 (Layered Chromatic Glow Aura)
    private func drawLayeredChromaticHalo(
        ctx: GraphicsContext,
        c: CGPoint,
        tiers: [(color: Color, rx: CGFloat, ry: CGFloat, opacity: Double)],
        rings: [(color: Color, r: CGFloat, lineWidth: CGFloat)] = [],
        phase: Double = 0.0
    ) {
        // 由外向内层叠渲染，实现纯净色相渐变与水彩景深过渡
        for tier in tiers.reversed() {
            drawGlowBlob(
                ctx: ctx,
                c: c,
                color: tier.color,
                rx: tier.rx,
                ry: tier.ry,
                opacity: tier.opacity
            )
        }
        // 发丝级同心涟漪等高线环 (多色阶渐变)
        for (idx, ring) in rings.enumerated() {
            let wave = sin(phase * 1.5 - Double(idx) * 0.7) * 1.2
            let r = max(3.0, ring.r + CGFloat(wave))
            var path = Path()
            path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.stroke(path, with: .color(ring.color), lineWidth: ring.lineWidth)
        }
    }

    /// 双层生成式拓扑节点
    private func drawTopologicalNode(
        ctx: GraphicsContext,
        pt: CGPoint,
        ringColor: Color,
        coreColor: Color,
        r: CGFloat = 2.6,
        lineWidth: CGFloat = 0.65
    ) {
        var outer = Path()
        outer.addEllipse(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
        ctx.fill(outer, with: .color(ringColor.opacity(0.92)))
        ctx.stroke(outer, with: .color(coreColor.opacity(0.85)), lineWidth: lineWidth)

        let innerR = r * 0.42
        var inner = Path()
        inner.addEllipse(in: CGRect(x: pt.x - innerR, y: pt.y - innerR, width: innerR * 2, height: innerR * 2))
        ctx.fill(inner, with: .color(coreColor))
    }

    /// 露珠浆果生成式晶莹矢量节点 (Glistening Jewel Dewdrop Berry Node)
    private func drawJewelBerry(
        ctx: GraphicsContext,
        pt: CGPoint,
        r: CGFloat,
        outerColor: Color,
        coreColor: Color,
        gleamColor: Color = Color(red: 0.98, green: 0.96, blue: 0.92),
        strokeColor: Color = Color(red: 0.30, green: 0.22, blue: 0.20),
        hasGleam: Bool = true
    ) {
        // 1. 微光晕 (柔和透明光环)
        var glow = Path()
        let glowR = r * 1.45
        glow.addEllipse(in: CGRect(x: pt.x - glowR, y: pt.y - glowR, width: glowR * 2, height: glowR * 2))
        ctx.fill(glow, with: .color(outerColor.opacity(0.18)))

        // 2. 浆果外体
        var body = Path()
        body.addEllipse(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
        ctx.fill(body, with: .color(outerColor.opacity(0.92)))
        ctx.stroke(body, with: .color(strokeColor.opacity(0.80)), lineWidth: 0.60)

        // 3. 内部透光琥珀/珊瑚核心
        let innerR = r * 0.44
        var core = Path()
        core.addEllipse(in: CGRect(x: pt.x - innerR, y: pt.y - innerR + r * 0.08, width: innerR * 2, height: innerR * 2))
        ctx.fill(core, with: .color(coreColor.opacity(0.85)))

        // 4. 高光晨露微点 (偏心高光，营造晶莹水珠光泽感)
        if hasGleam {
            let gleamR = max(0.65, r * 0.22)
            var gleam = Path()
            gleam.addEllipse(in: CGRect(
                x: pt.x - r * 0.32 - gleamR,
                y: pt.y - r * 0.32 - gleamR,
                width: gleamR * 2,
                height: gleamR * 2
            ))
            ctx.fill(gleam, with: .color(gleamColor.opacity(0.88)))
        }
    }

    /// 伴生漂浮星尘微粒
    private func drawSatelliteDots(
        ctx: GraphicsContext,
        c: CGPoint,
        r: CGFloat,
        count: Int,
        colors: [Color],
        phase: Double,
        speed: Double = 0.22
    ) {
        guard count > 0, !colors.isEmpty else { return }
        for i in 0..<count {
            let baseAngle = Double(i) / Double(count) * Double.pi * 2.0
            let a = baseAngle + phase * speed
            let wobble = sin(phase * 1.6 + Double(i) * 2.2) * 2.2
            let currentR = r + CGFloat(wobble)
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * currentR, y: c.y + CGFloat(sin(a)) * currentR)
            let dotR: CGFloat = (i % 2 == 0) ? 1.5 : 1.0
            var dot = Path()
            dot.addEllipse(in: CGRect(x: pt.x - dotR, y: pt.y - dotR, width: dotR * 2, height: dotR * 2))
            let col = colors[i % colors.count]
            ctx.fill(dot, with: .color(col.opacity(0.82)))
        }
    }

    /// 微小矢量飞蜂
    private func drawLittleBee(ctx: GraphicsContext, pt: CGPoint, phase: Double) {
        let flutter = sin(phase * 12.0) * 1.5
        var body = Path()
        body.addEllipse(in: CGRect(x: pt.x - 3.2, y: pt.y - 2.0, width: 6.4, height: 4.0))
        ctx.fill(body, with: .color(Color(red: 0.90, green: 0.70, blue: 0.20)))
        ctx.stroke(body, with: .color(Color.black.opacity(0.8)), lineWidth: 0.6)

        for xOff in [-0.8, 1.0] {
            var s = Path()
            s.move(to: CGPoint(x: pt.x + CGFloat(xOff), y: pt.y - 2.0))
            s.addLine(to: CGPoint(x: pt.x + CGFloat(xOff), y: pt.y + 2.0))
            ctx.stroke(s, with: .color(Color.black.opacity(0.8)), lineWidth: 0.65)
        }

        var wing1 = Path()
        wing1.addEllipse(in: CGRect(x: pt.x - 2.2, y: pt.y - 4.6 + CGFloat(flutter * 0.4), width: 3.6, height: 3.0))
        ctx.stroke(wing1, with: .color(Color.black.opacity(0.4)), lineWidth: 0.5)

        var wing2 = Path()
        wing2.addEllipse(in: CGRect(x: pt.x + 0.6, y: pt.y - 4.4 - CGFloat(flutter * 0.4), width: 3.6, height: 2.8))
        ctx.stroke(wing2, with: .color(Color.black.opacity(0.4)), lineWidth: 0.5)
    }

    /// 在花冠头顶上方绘制灵动浮动的极光游动曲线与微星尘
    private func drawFloatingAuraLines(
        ctx: GraphicsContext,
        c: CGPoint,
        s: CGFloat,
        phase: Double,
        colors: [Color],
        crownTopY: CGFloat
    ) {
        guard !colors.isEmpty else { return }
        let lineDefs: [(yOffset: CGFloat, waveFreq: Double, amp: CGFloat, span: CGFloat, cIdx: Int)] = [
            (-4.0 * s, 1.8, 3.2 * s, 36.0 * s, 0),
            (-8.5 * s, 1.4, 3.8 * s, 28.0 * s, 1),
            (-13.0 * s, 2.2, 2.8 * s, 22.0 * s, 0),
            (-17.5 * s, 1.6, 3.5 * s, 16.0 * s, 1)
        ]
        for (yOff, freq, amp, span, cIdx) in lineDefs {
            let baseY = crownTopY + yOff
            let wave1 = sin(phase * freq) * amp
            let wave2 = cos(phase * (freq * 0.85) + 1.2) * amp
            let startPt = CGPoint(x: c.x - span * 0.5, y: baseY + wave1)
            let endPt = CGPoint(x: c.x + span * 0.5, y: baseY - wave1 * 0.6)
            let cp1 = CGPoint(x: c.x - span * 0.22, y: baseY - amp * 1.1 + wave2)
            let cp2 = CGPoint(x: c.x + span * 0.22, y: baseY + amp * 1.1 - wave2)

            var ribbon = Path()
            ribbon.move(to: startPt)
            ribbon.addCurve(to: endPt, control1: cp1, control2: cp2)
            let col = colors[cIdx % colors.count]
            ctx.stroke(ribbon, with: .color(col.opacity(0.68)), lineWidth: 0.60)

            // 端点微星尘节点
            var dot1 = Path()
            dot1.addEllipse(in: CGRect(x: startPt.x - 1.1, y: startPt.y - 1.1, width: 2.2, height: 2.2))
            ctx.fill(dot1, with: .color(col.opacity(0.85)))

            var dot2 = Path()
            dot2.addEllipse(in: CGRect(x: endPt.x - 1.1, y: endPt.y - 1.1, width: 2.2, height: 2.2))
            ctx.fill(dot2, with: .color(col.opacity(0.85)))
        }
    }

    // =========================================================================
    // MARK: - 1. 蓝金星芒 (Hawthorn / Constellation Lattice & Dual Nebula)
    // =========================================================================
    private func renderSpecies1(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let darkIndigo = Color(red: 0.18, green: 0.22, blue: 0.38)
        let goldAmber = Color(red: 0.92, green: 0.70, blue: 0.24)
        let sageGreen = Color(red: 0.65, green: 0.72, blue: 0.55)

        if p < 0.25 {
            drawHaloRings(ctx: ctx, c: c, maxR: 28 * s, count: 3, phase: phase)
            var budL = Path()
            budL.move(to: c)
            budL.addQuadCurve(to: CGPoint(x: c.x - 7 * s, y: c.y - 12 * s), control: CGPoint(x: c.x - 8 * s, y: c.y - 4 * s))
            ctx.stroke(budL, with: .color(pal.stem), lineWidth: 0.75)
            drawTopologicalNode(ctx: ctx, pt: CGPoint(x: c.x - 7 * s, y: c.y - 12 * s), ringColor: sageGreen, coreColor: darkIndigo, r: 2.2 * min(s, 1.35))

            var budR = Path()
            budR.move(to: c)
            budR.addQuadCurve(to: CGPoint(x: c.x + 6 * s, y: c.y - 18 * s), control: CGPoint(x: c.x + 8 * s, y: c.y - 8 * s))
            ctx.stroke(budR, with: .color(pal.stem), lineWidth: 0.75)
            drawTopologicalNode(ctx: ctx, pt: CGPoint(x: c.x + 6 * s, y: c.y - 18 * s), ringColor: sageGreen, coreColor: darkIndigo, r: 2.6 * min(s, 1.35))
            return
        }

        if p < 0.50 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 4 * s, y: c.y - 6 * s), color: goldAmber, rx: 22 * s, ry: 20 * s, opacity: 0.35)
            let nodes: [CGPoint] = [
                CGPoint(x: c.x, y: c.y - 18 * s),
                CGPoint(x: c.x + 14 * s, y: c.y - 10 * s),
                CGPoint(x: c.x + 12 * s, y: c.y + 8 * s),
                CGPoint(x: c.x - 8 * s, y: c.y + 12 * s),
                CGPoint(x: c.x - 16 * s, y: c.y - 4 * s),
                CGPoint(x: c.x - 4 * s, y: c.y - 10 * s)
            ]
            for i in 0..<nodes.count {
                var line = Path()
                line.move(to: c)
                line.addLine(to: nodes[i])
                line.addLine(to: nodes[(i + 1) % nodes.count])
                ctx.stroke(line, with: .color(darkIndigo.opacity(0.65)), lineWidth: 0.60)
                drawTopologicalNode(ctx: ctx, pt: nodes[i], ringColor: goldAmber, coreColor: darkIndigo, r: 2.4 * min(s, 1.35))
            }
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y - 8 * s), color: goldAmber, rx: 28 * s, ry: 24 * s, opacity: 0.38)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 10 * s, y: c.y + 6 * s), color: darkIndigo, rx: 22 * s, ry: 20 * s, opacity: 0.25)
            drawHaloRings(ctx: ctx, c: c, maxR: 38 * s, count: 3, phase: phase)

            let count = 12
            var pts: [CGPoint] = []
            for i in 0..<count {
                let a = Double(i) / Double(count) * Double.pi * 2.0 + phase * 0.05
                let r: CGFloat = (i % 2 == 0 ? 28.0 : 18.0) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                pts.append(pt)
                var ray = Path()
                ray.move(to: c)
                ray.addLine(to: pt)
                ctx.stroke(ray, with: .color(darkIndigo), lineWidth: 0.60)
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: goldAmber, coreColor: darkIndigo, r: 2.5 * min(s, 1.35))
            }
            for i in 0..<count {
                var chord = Path()
                chord.move(to: pts[i])
                chord.addLine(to: pts[(i + 1) % count])
                ctx.stroke(chord, with: .color(goldAmber.opacity(0.65)), lineWidth: 0.50)
            }
            return
        }

        // Stage 4: 局部三色温弥散光团 + 非对称晶格刺芒网 (1-4 缩小 0.75)
        let s4: CGFloat = s * 0.75
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 12 * s4, y: c.y - 10 * s4), color: goldAmber, rx: 38 * s4, ry: 34 * s4, opacity: 0.48)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 14 * s4, y: c.y + 8 * s4), color: Color(red: 0.32, green: 0.24, blue: 0.55), rx: 32 * s4, ry: 28 * s4, opacity: 0.35)
        drawGlowBlob(ctx: ctx, c: c, color: Color(red: 0.98, green: 0.85, blue: 0.45), rx: 16 * s4, ry: 16 * s4, opacity: 0.50)
        drawHaloRings(ctx: ctx, c: c, maxR: 44 * s4, count: 3, phase: phase)

        let count4 = 16
        var meshPts: [CGPoint] = []
        for i in 0..<count4 {
            let petalScale = computeSequentialPetalScale(index: i, total: count4, phase: phase, progress: p, isCircular: true)
            let a = Double(i) / Double(count4) * Double.pi * 2.0
            let stretch: CGFloat = (i % 4 == 0) ? 36.0 : ((i % 2 == 0) ? 28.0 : 18.0)
            let shimmer = sin(phase * 2.0 + Double(i) * 0.8) * 2.0
            let r: CGFloat = (stretch + CGFloat(shimmer)) * CGFloat(b) * s4 * petalScale
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            meshPts.append(pt)

            var ray = Path()
            ray.move(to: c)
            ray.addLine(to: pt)
            ctx.stroke(ray, with: .color(goldAmber), lineWidth: 0.65)
            drawTopologicalNode(ctx: ctx, pt: pt, ringColor: (i % 2 == 0) ? goldAmber : sageGreen, coreColor: darkIndigo, r: 2.6 * min(s4, 1.35) * min(1.35, petalScale))
        }

        for i in 0..<count4 {
            var chord = Path()
            chord.move(to: meshPts[i])
            chord.addLine(to: meshPts[(i + 1) % count4])
            ctx.stroke(chord, with: .color(goldAmber.opacity(0.60)), lineWidth: 0.55)

            if i % 2 == 0 {
                var innerChord = Path()
                innerChord.move(to: meshPts[i])
                innerChord.addLine(to: meshPts[(i + 3) % count4])
                ctx.stroke(innerChord, with: .color(darkIndigo.opacity(0.40)), lineWidth: 0.50)
            }
        }

        var core = Path()
        let coreR: CGFloat = 5.5 * min(s4, 1.35)
        core.addEllipse(in: CGRect(x: c.x - coreR, y: c.y - coreR, width: coreR * 2, height: coreR * 2))
        ctx.fill(core, with: .color(darkIndigo))
        ctx.stroke(core, with: .color(goldAmber), lineWidth: 0.8)

        drawSatelliteDots(ctx: ctx, c: c, r: 42 * s4, count: 3, colors: [goldAmber, sageGreen], phase: phase, speed: 0.22)
    }

    // =========================================================================
    // MARK: - 2. 珊瑚伞花 (Dandelion / Asymmetrical Coral Horn & Dual Luminous Orbs)
    // =========================================================================
    private func renderSpecies2(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let coral = Color(red: 0.90, green: 0.42, blue: 0.35)
        let turquoise = Color(red: 0.25, green: 0.68, blue: 0.70)
        let amber = Color(red: 0.92, green: 0.72, blue: 0.25)
        let darkStem = Color(red: 0.26, green: 0.18, blue: 0.16)

        if p < 0.25 {
            // 阶段 1: 蒲公英羽茸初芽 (Dandelion Calyx & Feather Plumes)
            // 彻底去除多余细线，花苞基底直接座落在茎秆顶端 c 点，明显加大并呈现蒲公英总苞与冠毛羽丝特征
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 12 * s), color: coral, rx: 22 * s, ry: 20 * s, opacity: 0.35)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 16 * s), color: turquoise, rx: 16 * s, ry: 16 * s, opacity: 0.28)
            drawHaloRings(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 10 * s), maxR: 28 * s, count: 3, phase: phase)

            // 1. 蒲公英双层外展总苞萼片 (Involucral Bracts)，牢牢抱住基底 c
            var leftBract = Path()
            leftBract.move(to: c)
            leftBract.addQuadCurve(to: CGPoint(x: c.x - 9 * s, y: c.y - 16 * s), control: CGPoint(x: c.x - 9 * s, y: c.y - 6 * s))
            leftBract.addQuadCurve(to: CGPoint(x: c.x - 4 * s, y: c.y - 8 * s), control: CGPoint(x: c.x - 6 * s, y: c.y - 14 * s))
            leftBract.closeSubpath()
            ctx.fill(leftBract, with: .color(pal.stem.opacity(0.85)))
            ctx.stroke(leftBract, with: .color(darkStem), lineWidth: 0.70)

            var rightBract = Path()
            rightBract.move(to: c)
            rightBract.addQuadCurve(to: CGPoint(x: c.x + 9 * s, y: c.y - 16 * s), control: CGPoint(x: c.x + 9 * s, y: c.y - 6 * s))
            rightBract.addQuadCurve(to: CGPoint(x: c.x + 4 * s, y: c.y - 8 * s), control: CGPoint(x: c.x + 6 * s, y: c.y - 14 * s))
            rightBract.closeSubpath()
            ctx.fill(rightBract, with: .color(pal.stem.opacity(0.85)))
            ctx.stroke(rightBract, with: .color(darkStem), lineWidth: 0.70)

            // 2. 内部绽放的放射状羽茸冠毛丝束 (Pappus Feather Plumes)，从 c 点放射展开
            let plumeCount = 7
            for i in 0..<plumeCount {
                let frac = Double(i) / Double(plumeCount - 1)
                let a = -Double.pi * 0.74 + frac * (Double.pi * 0.48)
                let len: CGFloat = (22.0 + CGFloat(sin(frac * Double.pi)) * 6.0) * s
                let tip = CGPoint(x: c.x + CGFloat(cos(a)) * len, y: c.y + CGFloat(sin(a)) * len)

                var feather = Path()
                feather.move(to: c)
                let ctrl = CGPoint(
                    x: c.x + CGFloat(cos(a + (i < plumeCount / 2 ? -0.08 : 0.08))) * (len * 0.55),
                    y: c.y + CGFloat(sin(a + (i < plumeCount / 2 ? -0.08 : 0.08))) * (len * 0.55)
                )
                feather.addQuadCurve(to: tip, control: ctrl)
                let lineColor = (i % 2 == 0) ? coral : turquoise
                ctx.stroke(feather, with: .color(lineColor.opacity(0.90)), lineWidth: 0.65)

                let beadCol = (i % 2 == 0) ? coral : turquoise
                drawTopologicalNode(ctx: ctx, pt: tip, ringColor: beadCol, coreColor: darkStem, r: 2.2 * min(s, 1.35))
            }

            // 3. 基底花托锚点 (Receptacle Node)
            var baseNode = Path()
            let bR: CGFloat = 3.2 * min(s, 1.35)
            baseNode.addEllipse(in: CGRect(x: c.x - bR, y: c.y - bR, width: bR * 2, height: bR * 2))
            ctx.fill(baseNode, with: .color(pal.stem))
            ctx.stroke(baseNode, with: .color(darkStem), lineWidth: 0.70)
            return
        }

        if p < 0.50 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 10 * s), color: turquoise, rx: 24 * s, ry: 20 * s, opacity: 0.35)
            let rayCount = 8
            for i in 0..<rayCount {
                let frac = Double(i) / Double(rayCount - 1)
                let a = -Double.pi * 0.84 + frac * (Double.pi * 0.68)
                let r: CGFloat = (18.0 + CGFloat(frac) * 10.0) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                var ray = Path()
                ray.move(to: c)
                ray.addLine(to: pt)
                ctx.stroke(ray, with: .color(darkStem), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: (i % 2 == 0) ? coral : turquoise, coreColor: darkStem, r: 2.4 * min(s, 1.35))
            }
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 6 * s, y: c.y - 10 * s), color: coral, rx: 28 * s, ry: 24 * s, opacity: 0.40)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 6 * s, y: c.y - 10 * s), color: turquoise, rx: 22 * s, ry: 18 * s, opacity: 0.35)

            let rayCount = 16
            for i in 0..<rayCount {
                let frac = Double(i) / Double(rayCount - 1)
                let a = -Double.pi * 0.89 + frac * (Double.pi * 0.78)
                let r: CGFloat = (22.0 + CGFloat(sin(frac * Double.pi)) * 12.0) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                var ray = Path()
                ray.move(to: c)
                ray.addLine(to: pt)
                ctx.stroke(ray, with: .color(darkStem), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: (i % 2 == 0) ? coral : turquoise, coreColor: darkStem, r: 2.5 * min(s, 1.35))
            }
            let beePt = CGPoint(x: c.x + (24 + CGFloat(cos(phase * 1.5)) * 4) * s, y: c.y - (22 + CGFloat(sin(phase * 1.8)) * 3) * s)
            drawLittleBee(ctx: ctx, pt: beePt, phase: phase)
            return
        }

        // Stage 4: 珊瑚伞花 (对称向上展扇，由切线方向自适应对齐茎杆朝向)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y - 12 * s), color: coral, rx: 36 * s, ry: 30 * s, opacity: 0.48)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 8 * s, y: c.y - 12 * s), color: turquoise, rx: 28 * s, ry: 24 * s, opacity: 0.38)
        drawHaloRings(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 10 * s), maxR: 42 * s, count: 3, phase: phase)

        let rayCount4 = 22
        var tipPts: [CGPoint] = []
        for i in 0..<rayCount4 {
            let frac = Double(i) / Double(rayCount4 - 1)
            let a = -Double.pi * 0.94 + frac * (Double.pi * 0.88)
            let archLen: CGFloat = (24.0 + CGFloat(sin(frac * Double.pi * 0.9)) * 14.0) * CGFloat(b) * s
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * archLen, y: c.y + CGFloat(sin(a)) * archLen)
            tipPts.append(pt)

            var spine = Path()
            spine.move(to: c)
            let ctrl = CGPoint(x: c.x + CGFloat(cos(a - 0.15)) * (archLen * 0.5), y: c.y + CGFloat(sin(a - 0.15)) * (archLen * 0.5))
            spine.addQuadCurve(to: pt, control: ctrl)
            ctx.stroke(spine, with: .color(darkStem), lineWidth: 0.65)

            let beadCol = (i % 3 == 0) ? amber : ((i % 2 == 0) ? coral : turquoise)
            drawTopologicalNode(ctx: ctx, pt: pt, ringColor: beadCol, coreColor: darkStem, r: 2.6 * min(s, 1.35))
        }

        for i in 0..<(tipPts.count - 1) {
            var rib = Path()
            rib.move(to: tipPts[i])
            rib.addLine(to: tipPts[i + 1])
            ctx.stroke(rib, with: .color(coral.opacity(0.55)), lineWidth: 0.50)
        }

        let beePt = CGPoint(x: c.x + (26 + CGFloat(cos(phase * 1.6)) * 4) * s, y: c.y - (24 + CGFloat(sin(phase * 1.9)) * 3) * s)
        drawLittleBee(ctx: ctx, pt: beePt, phase: phase)
    }

    // =========================================================================
    // MARK: - 3. 孔雀彩扇 (BayWreath / Layered Topological Plumes & Swarm)
    // =========================================================================
    private func renderSpecies3(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let limeGreen = Color(red: 0.78, green: 0.88, blue: 0.42)
        let coralVermilion = Color(red: 0.90, green: 0.42, blue: 0.32)
        let warmAmber = Color(red: 0.92, green: 0.72, blue: 0.28)
        let violet = Color(red: 0.55, green: 0.35, blue: 0.65)
        let darkStem = Color(red: 0.26, green: 0.20, blue: 0.18)

        if p < 0.25 {
            // 阶段 1: 孔雀翎羽初绽幼芽 (BayWreath Peacock Feather Plume)
            // 彻底去除多余细线，花苞基底直接座落在茎秆顶端 c 点，沿 Y 轴对称展开，以便自适应对齐茎杆切线
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 14 * s), color: limeGreen, rx: 20 * s, ry: 20 * s, opacity: 0.35)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 14 * s), color: warmAmber, rx: 14 * s, ry: 14 * s, opacity: 0.25)
            drawHaloRings(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 12 * s), maxR: 26 * s, count: 3, phase: phase)

            let plumeHeight: CGFloat = 28.0 * s
            let plumeWidth: CGFloat = 11.0 * s
            let tip = CGPoint(x: c.x, y: c.y - plumeHeight)

            // 1. 外层宽阔的孔雀翎羽轮廓叶苞 (Peacock Plume Blade)
            var outerPlume = Path()
            outerPlume.move(to: c)
            outerPlume.addCurve(
                to: tip,
                control1: CGPoint(x: c.x - plumeWidth, y: c.y - plumeHeight * 0.35),
                control2: CGPoint(x: c.x - plumeWidth * 0.8, y: c.y - plumeHeight * 0.75)
            )
            outerPlume.addCurve(
                to: c,
                control1: CGPoint(x: c.x + plumeWidth * 0.8, y: c.y - plumeHeight * 0.75),
                control2: CGPoint(x: c.x + plumeWidth, y: c.y - plumeHeight * 0.35)
            )
            ctx.fill(outerPlume, with: .color(limeGreen.opacity(0.65)))
            ctx.stroke(outerPlume, with: .color(darkStem), lineWidth: 0.70)

            // 2. 内层羽轴主茎 (Rachis Quill) 从 c 直达 tip
            var rachis = Path()
            rachis.move(to: c)
            rachis.addLine(to: tip)
            ctx.stroke(rachis, with: .color(darkStem), lineWidth: 0.75)

            // 3. 翎羽斜向侧支羽纹 (Chevron Barbs)
            for i in 1...4 {
                let frac = CGFloat(i) / 5.0
                let yPos = c.y - plumeHeight * frac
                let barbW = plumeWidth * (1.0 - abs(frac - 0.5) * 0.9)

                var leftBarb = Path()
                leftBarb.move(to: CGPoint(x: c.x, y: yPos))
                leftBarb.addLine(to: CGPoint(x: c.x - barbW, y: yPos - 3.5 * s))
                ctx.stroke(leftBarb, with: .color(coralVermilion.opacity(0.75)), lineWidth: 0.55)

                var rightBarb = Path()
                rightBarb.move(to: CGPoint(x: c.x, y: yPos))
                rightBarb.addLine(to: CGPoint(x: c.x + barbW, y: yPos - 3.5 * s))
                ctx.stroke(rightBarb, with: .color(coralVermilion.opacity(0.75)), lineWidth: 0.55)
            }

            // 4. 翎羽顶端紫罗兰拓扑宝石节点 (Crown Jewel Node) 与侧珠
            drawTopologicalNode(ctx: ctx, pt: tip, ringColor: violet, coreColor: darkStem, r: 2.8 * min(s, 1.35))
            drawTopologicalNode(ctx: ctx, pt: CGPoint(x: c.x - 7 * s, y: c.y - plumeHeight * 0.55), ringColor: warmAmber, coreColor: darkStem, r: 1.8 * min(s, 1.35))
            drawTopologicalNode(ctx: ctx, pt: CGPoint(x: c.x + 7 * s, y: c.y - plumeHeight * 0.55), ringColor: coralVermilion, coreColor: darkStem, r: 1.8 * min(s, 1.35))
            return
        }

        if p < 0.50 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 6 * s, y: c.y - 10 * s), color: limeGreen, rx: 20 * s, ry: 18 * s, opacity: 0.35)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 6 * s, y: c.y - 10 * s), color: warmAmber, rx: 20 * s, ry: 18 * s, opacity: 0.35)

            for (angle, col) in [(-Double.pi * 0.65, limeGreen), (-Double.pi * 0.35, coralVermilion)] {
                let tip = CGPoint(x: c.x + CGFloat(cos(angle)) * 24.0 * s, y: c.y + CGFloat(sin(angle)) * 24.0 * s)
                var pPath = Path()
                pPath.move(to: c)
                pPath.addLine(to: tip)
                ctx.stroke(pPath, with: .color(darkStem), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: tip, ringColor: col, coreColor: darkStem, r: 2.4 * min(s, 1.35))
            }
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 12 * s), color: coralVermilion, rx: 26 * s, ry: 22 * s, opacity: 0.40)
            let plumeAngles = [-Double.pi * 0.80, -Double.pi * 0.50, -Double.pi * 0.20]
            let colors = [limeGreen, coralVermilion, warmAmber]
            for i in 0..<3 {
                let petalScale = computeSequentialPetalScale(index: i, total: 3, phase: phase, progress: p, isCircular: false)
                let a = plumeAngles[i]
                let plumeLen = 28.0 * petalScale * s
                let tip = CGPoint(x: c.x + CGFloat(cos(a)) * plumeLen, y: c.y + CGFloat(sin(a)) * plumeLen)
                var lobe = Path()
                lobe.move(to: c)
                let c1 = CGPoint(x: c.x + CGFloat(cos(a - 0.2)) * (plumeLen * 0.58), y: c.y + CGFloat(sin(a - 0.2)) * (plumeLen * 0.58))
                let c2 = CGPoint(x: c.x + CGFloat(cos(a + 0.2)) * (plumeLen * 0.58), y: c.y + CGFloat(sin(a + 0.2)) * (plumeLen * 0.58))
                lobe.addQuadCurve(to: tip, control: c1)
                lobe.addQuadCurve(to: c, control: c2)
                ctx.fill(lobe, with: .color(colors[i].opacity(0.65)))
                ctx.stroke(lobe, with: .color(darkStem), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: tip, ringColor: violet, coreColor: darkStem, r: 2.5 * min(s, 1.35) * min(1.35, petalScale))
            }
            let beePt = CGPoint(x: c.x + 22 * s, y: c.y - 24 * s)
            drawLittleBee(ctx: ctx, pt: beePt, phase: phase)
            return
        }

        // Stage 4: 5 瓣彩羽扇面随着顺序 1-2 倍膨胀放大再复原
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 14 * s, y: c.y - 12 * s), color: limeGreen, rx: 26 * s, ry: 22 * s, opacity: 0.38)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 16 * s), color: coralVermilion, rx: 32 * s, ry: 26 * s, opacity: 0.45)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 14 * s, y: c.y - 10 * s), color: warmAmber, rx: 26 * s, ry: 22 * s, opacity: 0.38)

        let petalCount = 5
        for i in 0..<petalCount {
            let petalScale = computeSequentialPetalScale(index: i, total: petalCount, phase: phase, progress: p, isCircular: false)
            let frac = Double(i) / Double(petalCount - 1)
            let a = -Double.pi * 0.88 + frac * (Double.pi * 0.76)
            let baseLen: CGFloat = (26.0 + CGFloat(sin(frac * Double.pi)) * 10.0) * CGFloat(b) * s
            let plumeLen = baseLen * petalScale
            let tip = CGPoint(x: c.x + CGFloat(cos(a)) * plumeLen, y: c.y + CGFloat(sin(a)) * plumeLen)

            var lobe = Path()
            lobe.move(to: c)
            let c1 = CGPoint(x: c.x + CGFloat(cos(a - 0.22)) * (plumeLen * 0.6), y: c.y + CGFloat(sin(a - 0.22)) * (plumeLen * 0.6))
            let c2 = CGPoint(x: c.x + CGFloat(cos(a + 0.22)) * (plumeLen * 0.6), y: c.y + CGFloat(sin(a + 0.22)) * (plumeLen * 0.6))
            lobe.addQuadCurve(to: tip, control: c1)
            lobe.addQuadCurve(to: c, control: c2)
            let col = (i % 3 == 0) ? limeGreen : ((i % 3 == 1) ? coralVermilion : warmAmber)
            ctx.fill(lobe, with: .color(col.opacity(0.68)))
            ctx.stroke(lobe, with: .color(darkStem), lineWidth: 0.65)

            var rib = Path()
            rib.move(to: c)
            rib.addLine(to: tip)
            ctx.stroke(rib, with: .color(darkStem.opacity(0.70)), lineWidth: 0.50)
            drawTopologicalNode(ctx: ctx, pt: tip, ringColor: violet, coreColor: darkStem, r: 2.6 * min(s, 1.35) * min(1.35, petalScale))
        }

        let pCount = 36
        for i in 0..<pCount {
            let frac = Double(i) / Double(pCount - 1)
            let a = -Double.pi * 0.95 + frac * (Double.pi * 0.90)
            let wave = sin(phase * 2.2 + Double(i) * 0.45) * 2.2
            let rDot: CGFloat = (34.0 + CGFloat(wave)) * CGFloat(b) * s
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rDot, y: c.y + CGFloat(sin(a)) * rDot)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: pt.x - 1.1, y: pt.y - 1.1, width: 2.2, height: 2.2))
            let col = (i % 2 == 0) ? warmAmber : coralVermilion
            ctx.fill(dot, with: .color(col.opacity(0.85)))
        }
    }

    // =========================================================================
    // MARK: - 4. 几何风车 (Cornflower / Faceted Crystal Shard Cluster)
    // =========================================================================
    private func renderSpecies4(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let teal = Color(red: 0.22, green: 0.68, blue: 0.70)
        let violet = Color(red: 0.55, green: 0.35, blue: 0.72)
        let rose = Color(red: 0.85, green: 0.45, blue: 0.52)
        let amber = Color(red: 0.92, green: 0.72, blue: 0.25)
        let darkLine = Color(red: 0.18, green: 0.16, blue: 0.24)

        let spin = phase * 0.25

        if p < 0.25 {
            drawHaloRings(ctx: ctx, c: c, maxR: 26 * s, count: 3, phase: phase)
            let pts: [CGPoint] = [
                CGPoint(x: c.x, y: c.y - 14 * s),
                CGPoint(x: c.x + 10 * s, y: c.y - 4 * s),
                CGPoint(x: c.x - 10 * s, y: c.y - 4 * s)
            ]
            for i in 0..<3 {
                var tri = Path()
                tri.move(to: c)
                tri.addLine(to: pts[i])
                tri.addLine(to: pts[(i + 1) % 3])
                tri.closeSubpath()
                ctx.fill(tri, with: .color(teal.opacity(0.70)))
                ctx.stroke(tri, with: .color(darkLine), lineWidth: 0.65)
            }
            return
        }

        if p < 0.50 {
            drawGlowBlob(ctx: ctx, c: c, color: teal, rx: 22 * s, ry: 22 * s, opacity: 0.35)
            for i in 0..<5 {
                let a = Double(i) / 5.0 * Double.pi * 2.0 + spin
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * 18.0 * s, y: c.y + CGFloat(sin(a)) * 18.0 * s)
                var shard = Path()
                shard.move(to: c)
                shard.addLine(to: pt)
                shard.addLine(to: CGPoint(x: c.x + CGFloat(cos(a + 0.3)) * 12.0 * s, y: c.y + CGFloat(sin(a + 0.3)) * 12.0 * s))
                shard.closeSubpath()
                let col = (i % 2 == 0) ? teal : violet
                ctx.fill(shard, with: .color(col.opacity(0.78)))
                ctx.stroke(shard, with: .color(darkLine), lineWidth: 0.65)
            }
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y - 8 * s), color: teal, rx: 26 * s, ry: 22 * s, opacity: 0.38)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 8 * s, y: c.y + 6 * s), color: violet, rx: 22 * s, ry: 20 * s, opacity: 0.35)

            for i in 0..<7 {
                let petalScale = computeSequentialPetalScale(index: i, total: 7, phase: phase, progress: p, isCircular: true)
                let a = Double(i) / 7.0 * Double.pi * 2.0 + spin
                let r: CGFloat = (22.0 + (i % 2 == 0 ? 6.0 : 0.0)) * CGFloat(b) * s * petalScale
                let ptOuter = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                let ptTip = CGPoint(x: c.x + CGFloat(cos(a + 0.28)) * (r * 0.65), y: c.y + CGFloat(sin(a + 0.28)) * (r * 0.65))

                var blade = Path()
                blade.move(to: c)
                blade.addLine(to: ptOuter)
                blade.addLine(to: ptTip)
                blade.closeSubpath()
                let col = (i % 2 == 0) ? teal : rose
                ctx.fill(blade, with: .color(col.opacity(0.82)))
                ctx.stroke(blade, with: .color(darkLine), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: ptOuter, ringColor: amber, coreColor: darkLine, r: 2.3 * min(s, 1.35) * min(1.35, petalScale))
            }
            return
        }

        // Stage 4: 局部双子极光团 + 8 晶棱折面水晶簇，随着顺序 1-2 倍顺次放大再复原
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 10 * s, y: c.y - 10 * s), color: teal, rx: 34 * s, ry: 28 * s, opacity: 0.48)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 10 * s, y: c.y + 8 * s), color: violet, rx: 30 * s, ry: 26 * s, opacity: 0.38)
        drawHaloRings(ctx: ctx, c: c, maxR: 44 * s, count: 3, phase: phase)

        let bladeCount4 = 8
        for i in 0..<bladeCount4 {
            let petalScale = computeSequentialPetalScale(index: i, total: bladeCount4, phase: phase, progress: p, isCircular: true)
            let a = Double(i) / Double(bladeCount4) * Double.pi * 2.0 + spin
            let baseLen: CGFloat = (i % 3 == 0 ? 32.0 : (i % 2 == 0 ? 25.0 : 20.0)) * CGFloat(b) * s
            let shardLen: CGFloat = baseLen * petalScale
            let ptOuter = CGPoint(x: c.x + CGFloat(cos(a)) * shardLen, y: c.y + CGFloat(sin(a)) * shardLen)
            let ptMid = CGPoint(x: c.x + CGFloat(cos(a + 0.24)) * (shardLen * 0.6), y: c.y + CGFloat(sin(a + 0.24)) * (shardLen * 0.6))

            var shard1 = Path()
            shard1.move(to: c)
            shard1.addLine(to: ptOuter)
            shard1.addLine(to: ptMid)
            shard1.closeSubpath()
            let col1 = (i % 2 == 0) ? teal : violet
            ctx.fill(shard1, with: .color(col1.opacity(0.85)))
            ctx.stroke(shard1, with: .color(darkLine), lineWidth: 0.65)

            let ptBack = CGPoint(x: c.x + CGFloat(cos(a - 0.18)) * (shardLen * 0.5), y: c.y + CGFloat(sin(a - 0.18)) * (shardLen * 0.5))
            var shard2 = Path()
            shard2.move(to: c)
            shard2.addLine(to: ptOuter)
            shard2.addLine(to: ptBack)
            shard2.closeSubpath()
            ctx.fill(shard2, with: .color(col1.opacity(0.45)))
            ctx.stroke(shard2, with: .color(darkLine), lineWidth: 0.55)

            let antTip = CGPoint(x: c.x + CGFloat(cos(a)) * (shardLen + 5.0 * s * petalScale), y: c.y + CGFloat(sin(a)) * (shardLen + 5.0 * s * petalScale))
            var ant = Path()
            ant.move(to: ptOuter)
            ant.addLine(to: antTip)
            ctx.stroke(ant, with: .color(darkLine), lineWidth: 0.55)
            drawTopologicalNode(ctx: ctx, pt: antTip, ringColor: amber, coreColor: darkLine, r: 2.5 * min(s, 1.35) * min(1.35, petalScale))
        }

        var hub = Path()
        let hubR: CGFloat = 3.5 * min(s, 1.35)
        hub.addEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2))
        ctx.fill(hub, with: .color(darkLine))
    }

    // =========================================================================
    // MARK: - 5. 垂帘浆果 (RedBerries / Weeping Fluid Droplets & Berry Nodes)
    // =========================================================================
    private func renderSpecies5(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let plumWine = Color(red: 0.70, green: 0.22, blue: 0.42)
        let plumBright = Color(red: 0.82, green: 0.30, blue: 0.48)
        let amberGold = Color(red: 0.94, green: 0.72, blue: 0.28)
        let coralRose = Color(red: 0.92, green: 0.50, blue: 0.56)
        let darkStem = Color(red: 0.30, green: 0.22, blue: 0.20)
        let gleam = Color(red: 0.98, green: 0.96, blue: 0.92)

        let clampedS = min(s, 1.35)

        // ---------------------------------------------------------------------
        // 阶段 1: 破土萌芽 (Sprout / Weeping Tendril Shoot)
        // ---------------------------------------------------------------------
        if p < 0.25 {
            let sway = CGFloat(sin(phase * 1.5)) * 3.0 * s

            // 顶端柔和水彩光晕
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 3 * s, y: c.y + 4 * s), color: amberGold, rx: 16 * s, ry: 16 * s, opacity: 0.30)

            // 柔和微风涟漪环
            drawHaloRings(ctx: ctx, c: c, maxR: 18 * s, count: 2, color: amberGold.opacity(0.25), phase: phase)

            // 优美低垂的萌芽主茎 (Cubic Bezier 牧羊杖式垂拱)
            var tendril = Path()
            tendril.move(to: c)
            let tip1 = CGPoint(x: c.x - 10 * s + sway, y: c.y + 18 * s)
            tendril.addCurve(
                to: tip1,
                control1: CGPoint(x: c.x + 3 * s, y: c.y - 8 * s),
                control2: CGPoint(x: c.x - 8 * s + sway * 0.5, y: c.y + 6 * s)
            )
            ctx.stroke(tendril, with: .color(darkStem), lineWidth: 0.70)

            // 伴生微侧芽
            var sideBract = Path()
            sideBract.move(to: CGPoint(x: c.x, y: c.y + 2 * s))
            sideBract.addQuadCurve(
                to: CGPoint(x: c.x + 6 * s - sway * 0.3, y: c.y + 9 * s),
                control: CGPoint(x: c.x + 4 * s, y: c.y + 3 * s)
            )
            ctx.stroke(sideBract, with: .color(darkStem.opacity(0.75)), lineWidth: 0.55)

            // 萌芽苞片节点 (顺沿主茎自然分布的露珠浆果)
            let sproutPoints: [(pt: CGPoint, r: CGFloat, outer: Color, core: Color)] = [
                (CGPoint(x: c.x + 0.5 * s, y: c.y - 4 * s), 2.0 * clampedS, coralRose, amberGold),
                (CGPoint(x: c.x - 5.0 * s + sway * 0.3, y: c.y + 6 * s), 2.5 * clampedS, plumBright, amberGold),
                (tip1, 3.2 * clampedS, plumWine, amberGold),
                (CGPoint(x: c.x + 6 * s - sway * 0.3, y: c.y + 9 * s), 1.8 * clampedS, coralRose, amberGold)
            ]
            for sp in sproutPoints {
                drawJewelBerry(ctx: ctx, pt: sp.pt, r: sp.r, outerColor: sp.outer, coreColor: sp.core, gleamColor: gleam, strokeColor: darkStem)
            }
            return
        }

        // ---------------------------------------------------------------------
        // 阶段 2: 含苞积蓄 (Budding Cascades / Twin Weeping Arches)
        // ---------------------------------------------------------------------
        if p < 0.50 {
            let swayL = CGFloat(sin(phase * 1.5)) * 3.5 * s
            let swayR = CGFloat(sin(phase * 1.5 - 0.7)) * 2.8 * s

            // 双核水彩弥散光斑 (琥珀顶光 + 柔粉侧晕)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y + 2 * s), color: amberGold, rx: 22 * s, ry: 18 * s, opacity: 0.32)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 6 * s, y: c.y + 12 * s), color: plumWine, rx: 18 * s, ry: 16 * s, opacity: 0.28)
            drawHaloRings(ctx: ctx, c: c, maxR: 26 * s, count: 2, color: plumBright.opacity(0.22), phase: phase)

            // 顶端双裂花萼托
            var calyx = Path()
            let calyxR: CGFloat = 2.4 * clampedS
            calyx.addEllipse(in: CGRect(x: c.x - calyxR, y: c.y - calyxR * 0.8, width: calyxR * 2, height: calyxR * 1.6))
            ctx.fill(calyx, with: .color(darkStem))

            // 左侧主垂帘拱弧
            let tipL = CGPoint(x: c.x - 18 * s + swayL, y: c.y + 24 * s)
            var archL = Path()
            archL.move(to: c)
            archL.addCurve(
                to: tipL,
                control1: CGPoint(x: c.x - 6 * s, y: c.y - 10 * s),
                control2: CGPoint(x: c.x - 16 * s + swayL * 0.6, y: c.y + 8 * s)
            )
            ctx.stroke(archL, with: .color(darkStem), lineWidth: 0.70)

            // 右侧平衡垂帘拱弧
            let tipR = CGPoint(x: c.x + 15 * s + swayR, y: c.y + 20 * s)
            var archR = Path()
            archR.move(to: c)
            archR.addCurve(
                to: tipR,
                control1: CGPoint(x: c.x + 5 * s, y: c.y - 8 * s),
                control2: CGPoint(x: c.x + 13 * s + swayR * 0.6, y: c.y + 6 * s)
            )
            ctx.stroke(archR, with: .color(darkStem), lineWidth: 0.70)

            // 双拱之间的发丝星轨微连线 (Constellation Whisper Link)
            let midNodeL = CGPoint(x: c.x - 11 * s + swayL * 0.4, y: c.y + 12 * s)
            let midNodeR = CGPoint(x: c.x + 9 * s + swayR * 0.4, y: c.y + 10 * s)
            var whisperLink = Path()
            whisperLink.move(to: midNodeL)
            whisperLink.addLine(to: midNodeR)
            ctx.stroke(whisperLink, with: .color(amberGold.opacity(0.35)), lineWidth: 0.45)

            // 顺沿自然曲率分布的露珠浆果 (无僵硬水平直线，平滑挂靠弧线)
            let berriesStage2: [(pt: CGPoint, r: CGFloat, outer: Color, core: Color, pedicelFrom: CGPoint)] = [
                // 左拱垂帘序列 (由上至下平滑递增与过渡)
                (CGPoint(x: c.x - 4 * s, y: c.y - 5 * s), 2.2 * clampedS, coralRose, amberGold, c),
                (midNodeL, 2.8 * clampedS, plumBright, amberGold, CGPoint(x: c.x - 9 * s + swayL * 0.3, y: c.y + 7 * s)),
                (CGPoint(x: c.x - 15 * s + swayL * 0.7, y: c.y + 17 * s), 3.0 * clampedS, plumWine, amberGold, CGPoint(x: c.x - 13 * s + swayL * 0.5, y: c.y + 14 * s)),
                (tipL, 3.2 * clampedS, plumWine, coralRose, CGPoint(x: c.x - 17 * s + swayL * 0.8, y: c.y + 21 * s)),

                // 右拱垂帘序列
                (CGPoint(x: c.x + 3 * s, y: c.y - 4 * s), 2.0 * clampedS, coralRose, amberGold, c),
                (midNodeR, 2.7 * clampedS, plumBright, amberGold, CGPoint(x: c.x + 7 * s + swayR * 0.3, y: c.y + 6 * s)),
                (tipR, 3.1 * clampedS, plumWine, amberGold, CGPoint(x: c.x + 14 * s + swayR * 0.7, y: c.y + 17 * s))
            ]

            for b in berriesStage2 {
                if b.pedicelFrom != b.pt {
                    var ped = Path()
                    ped.move(to: b.pedicelFrom)
                    ped.addLine(to: b.pt)
                    ctx.stroke(ped, with: .color(darkStem.opacity(0.60)), lineWidth: 0.50)
                }
                drawJewelBerry(ctx: ctx, pt: b.pt, r: b.r, outerColor: b.outer, coreColor: b.core, gleamColor: gleam, strokeColor: darkStem)
            }
            return
        }

        // ---------------------------------------------------------------------
        // 阶段 3: 初绽展露 (Emerging Chandelier Cascade / Triple Weeping Strands)
        // ---------------------------------------------------------------------
        if p < 0.75 {
            let swayL = CGFloat(sin(phase * 1.4)) * 3.8 * s
            let swayC = CGFloat(sin(phase * 1.4 - 0.5)) * 2.6 * s
            let swayR = CGFloat(sin(phase * 1.4 - 1.0)) * -3.2 * s

            // 三层水彩星云光斑 (琥珀顶核 + 紫红中腹 + 珊瑚流霞)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y + 2 * s), color: amberGold, rx: 28 * s, ry: 22 * s, opacity: 0.35)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 6 * s, y: c.y + 16 * s), color: plumWine, rx: 26 * s, ry: 22 * s, opacity: 0.30)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y + 18 * s), color: coralRose, rx: 24 * s, ry: 20 * s, opacity: 0.26)
            drawHaloRings(ctx: ctx, c: c, maxR: 36 * s, count: 3, color: plumBright.opacity(0.25), phase: phase)

            // 花萼核心
            var calyx = Path()
            let calyxRx: CGFloat = 3.2 * clampedS
            let calyxRy: CGFloat = 2.0 * clampedS
            calyx.addEllipse(in: CGRect(x: c.x - calyxRx, y: c.y - calyxRy, width: calyxRx * 2, height: calyxRy * 2))
            ctx.fill(calyx, with: .color(darkStem))

            // 三股自然低垂拱形茎脉 (左展、中垂、右展)
            let tipL = CGPoint(x: c.x - 22 * s + swayL, y: c.y + 26 * s)
            let tipC = CGPoint(x: c.x + 1 * s + swayC, y: c.y + 34 * s)
            let tipR = CGPoint(x: c.x + 20 * s + swayR, y: c.y + 28 * s)

            var strandL = Path()
            strandL.move(to: c)
            strandL.addCurve(
                to: tipL,
                control1: CGPoint(x: c.x - 8 * s, y: c.y - 10 * s),
                control2: CGPoint(x: c.x - 18 * s + swayL * 0.6, y: c.y + 10 * s)
            )
            ctx.stroke(strandL, with: .color(darkStem), lineWidth: 0.70)

            var strandC = Path()
            strandC.move(to: c)
            strandC.addCurve(
                to: tipC,
                control1: CGPoint(x: c.x - 2 * s, y: c.y + 8 * s),
                control2: CGPoint(x: c.x + 2 * s + swayC * 0.5, y: c.y + 20 * s)
            )
            ctx.stroke(strandC, with: .color(darkStem), lineWidth: 0.70)

            var strandR = Path()
            strandR.move(to: c)
            strandR.addCurve(
                to: tipR,
                control1: CGPoint(x: c.x + 7 * s, y: c.y - 9 * s),
                control2: CGPoint(x: c.x + 16 * s + swayR * 0.6, y: c.y + 10 * s)
            )
            ctx.stroke(strandR, with: .color(darkStem), lineWidth: 0.70)

            // 三重垂帘之间的轻盈发丝微织网 (Celestial Harp Weave)
            let pL1 = CGPoint(x: c.x - 12 * s + swayL * 0.4, y: c.y + 13 * s)
            let pC1 = CGPoint(x: c.x + 0.5 * s + swayC * 0.4, y: c.y + 16 * s)
            let pR1 = CGPoint(x: c.x + 11 * s + swayR * 0.4, y: c.y + 14 * s)

            var weave = Path()
            weave.move(to: pL1)
            weave.addLine(to: pC1)
            weave.addLine(to: pR1)
            ctx.stroke(weave, with: .color(amberGold.opacity(0.30)), lineWidth: 0.45)

            // 13 颗露珠浆果，依附曲率自然垂落 (无生硬直排)
            let berriesStage3: [(pt: CGPoint, r: CGFloat, outer: Color, core: Color, pedFrom: CGPoint)] = [
                // 左侧序列
                (CGPoint(x: c.x - 5 * s, y: c.y - 6 * s), 2.2 * clampedS, coralRose, amberGold, c),
                (pL1, 2.9 * clampedS, plumBright, amberGold, CGPoint(x: c.x - 10 * s + swayL * 0.3, y: c.y + 8 * s)),
                (CGPoint(x: c.x - 18 * s + swayL * 0.7, y: c.y + 20 * s), 3.2 * clampedS, plumWine, amberGold, CGPoint(x: c.x - 16 * s + swayL * 0.5, y: c.y + 16 * s)),
                (tipL, 3.4 * clampedS, plumWine, coralRose, CGPoint(x: c.x - 20 * s + swayL * 0.8, y: c.y + 23 * s)),

                // 中轴纵垂序列 (珠帘坠落)
                (CGPoint(x: c.x - 1 * s, y: c.y + 6 * s), 2.5 * clampedS, coralRose, amberGold, c),
                (pC1, 3.0 * clampedS, plumBright, amberGold, CGPoint(x: c.x, y: c.y + 11 * s)),
                (CGPoint(x: c.x + 1 * s + swayC * 0.6, y: c.y + 25 * s), 3.3 * clampedS, plumWine, amberGold, CGPoint(x: c.x + 0.5 * s + swayC * 0.5, y: c.y + 20 * s)),
                (tipC, 3.5 * clampedS, plumWine, amberGold, CGPoint(x: c.x + 1 * s + swayC * 0.8, y: c.y + 30 * s)),

                // 右侧序列
                (CGPoint(x: c.x + 4 * s, y: c.y - 5 * s), 2.2 * clampedS, coralRose, amberGold, c),
                (pR1, 2.8 * clampedS, plumBright, amberGold, CGPoint(x: c.x + 9 * s + swayR * 0.3, y: c.y + 8 * s)),
                (CGPoint(x: c.x + 16 * s + swayR * 0.7, y: c.y + 21 * s), 3.1 * clampedS, plumWine, amberGold, CGPoint(x: c.x + 14 * s + swayR * 0.5, y: c.y + 17 * s)),
                (tipR, 3.3 * clampedS, plumWine, coralRose, CGPoint(x: c.x + 18 * s + swayR * 0.8, y: c.y + 25 * s)),

                // 侧生悬空微露
                (CGPoint(x: c.x - 13 * s + swayL * 0.5, y: c.y + 22 * s), 2.4 * clampedS, coralRose, amberGold, pL1)
            ]

            for b in berriesStage3 {
                var ped = Path()
                ped.move(to: b.pedFrom)
                ped.addLine(to: b.pt)
                ctx.stroke(ped, with: .color(darkStem.opacity(0.60)), lineWidth: 0.50)
                drawJewelBerry(ctx: ctx, pt: b.pt, r: b.r, outerColor: b.outer, coreColor: b.core, gleamColor: gleam, strokeColor: darkStem)
            }
            return
        }

        // ---------------------------------------------------------------------
        // 阶段 4: 全盛繁盛 (Full Radiance Celestial Weeping Cascade)
        // ---------------------------------------------------------------------
        // 1. 广域多核水彩星云光斑 (琥珀顶核 + 紫红流光 + 珊瑚薄雾)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 1 * s), color: amberGold, rx: 36 * s, ry: 26 * s, opacity: 0.42)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y + 18 * s), color: plumWine, rx: 44 * s, ry: 34 * s, opacity: 0.36)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y + 30 * s), color: coralRose, rx: 32 * s, ry: 24 * s, opacity: 0.28)

        // 2. 顶端多重动态等高发丝涟漪 (Halo Ripple Rings)
        drawHaloRings(ctx: ctx, c: c, maxR: 44 * s, count: 3, color: plumBright.opacity(0.26), phase: phase)

        // 3. 几何花萼托座与向天顶生长的微触角天线
        var calyx = Path()
        let calyxRx: CGFloat = 4.2 * clampedS
        let calyxRy: CGFloat = 2.5 * clampedS
        calyx.addEllipse(in: CGRect(x: c.x - calyxRx, y: c.y - calyxRy, width: calyxRx * 2, height: calyxRy * 2))
        ctx.fill(calyx, with: .color(darkStem))
        ctx.stroke(calyx, with: .color(amberGold.opacity(0.85)), lineWidth: 0.70)

        // 顶生金星触角
        for aOff in [-3.0, 0.0, 3.0] {
            var antenna = Path()
            antenna.move(to: CGPoint(x: c.x + CGFloat(aOff) * s, y: c.y - calyxRy))
            antenna.addLine(to: CGPoint(x: c.x + CGFloat(aOff * 1.5) * s, y: c.y - (calyxRy + 5.5 * s)))
            ctx.stroke(antenna, with: .color(darkStem), lineWidth: 0.55)
            drawTopologicalNode(
                ctx: ctx,
                pt: CGPoint(x: c.x + CGFloat(aOff * 1.5) * s, y: c.y - (calyxRy + 5.5 * s)),
                ringColor: amberGold,
                coreColor: darkStem,
                r: 1.6 * clampedS,
                lineWidth: 0.50
            )
        }

        // 4. 五重流线型低垂拱脉 (Five Cascading Weeping Tendrils)
        struct TendrilSpec {
            let tip: CGPoint
            let c1: CGPoint
            let c2: CGPoint
            let phaseDelay: Double
            let swayScale: CGFloat
        }

        let tendrilSpecs: [TendrilSpec] = [
            // 1. 远左展幔 (Far-left arch)
            TendrilSpec(
                tip: CGPoint(x: c.x - 36 * s, y: c.y + 26 * s),
                c1: CGPoint(x: c.x - 15 * s, y: c.y - 14 * s),
                c2: CGPoint(x: c.x - 30 * s, y: c.y + 7 * s),
                phaseDelay: 0.0,
                swayScale: 4.2
            ),
            // 2. 次左垂帘 (Mid-left arch)
            TendrilSpec(
                tip: CGPoint(x: c.x - 19 * s, y: c.y + 40 * s),
                c1: CGPoint(x: c.x - 8 * s, y: c.y - 9 * s),
                c2: CGPoint(x: c.x - 18 * s, y: c.y + 17 * s),
                phaseDelay: 0.45,
                swayScale: 3.4
            ),
            // 3. 中轴珠帘瀑布 (Center plunge cascade)
            TendrilSpec(
                tip: CGPoint(x: c.x, y: c.y + 48 * s),
                c1: CGPoint(x: c.x - 2 * s, y: c.y + 10 * s),
                c2: CGPoint(x: c.x + 1 * s, y: c.y + 28 * s),
                phaseDelay: 0.90,
                swayScale: 2.5
            ),
            // 4. 次右垂帘 (Mid-right arch)
            TendrilSpec(
                tip: CGPoint(x: c.x + 21 * s, y: c.y + 38 * s),
                c1: CGPoint(x: c.x + 8 * s, y: c.y - 9 * s),
                c2: CGPoint(x: c.x + 19 * s, y: c.y + 16 * s),
                phaseDelay: 1.35,
                swayScale: -3.5
            ),
            // 5. 远右展幔 (Far-right arch)
            TendrilSpec(
                tip: CGPoint(x: c.x + 36 * s, y: c.y + 27 * s),
                c1: CGPoint(x: c.x + 15 * s, y: c.y - 13 * s),
                c2: CGPoint(x: c.x + 30 * s, y: c.y + 8 * s),
                phaseDelay: 1.80,
                swayScale: -4.0
            )
        ]

        var dynamicTips: [CGPoint] = []
        for spec in tendrilSpecs {
            let sway = CGFloat(sin(phase * 1.3 - spec.phaseDelay)) * spec.swayScale * s
            let actualTip = CGPoint(x: spec.tip.x + sway, y: spec.tip.y)
            dynamicTips.append(actualTip)

            var tPath = Path()
            tPath.move(to: c)
            tPath.addCurve(
                to: actualTip,
                control1: spec.c1,
                control2: CGPoint(x: spec.c2.x + sway * 0.55, y: spec.c2.y)
            )
            ctx.stroke(tPath, with: .color(darkStem), lineWidth: 0.70)
        }

        // 5. 跨枝微丝星轨网络 (Constellation Web Chords)
        let chordPoints: [(p1: CGPoint, p2: CGPoint)] = [
            (CGPoint(x: c.x - 24 * s, y: c.y + 12 * s), CGPoint(x: c.x - 12 * s, y: c.y + 18 * s)),
            (CGPoint(x: c.x - 12 * s, y: c.y + 18 * s), CGPoint(x: c.x, y: c.y + 23 * s)),
            (CGPoint(x: c.x, y: c.y + 23 * s), CGPoint(x: c.x + 13 * s, y: c.y + 18 * s)),
            (CGPoint(x: c.x + 13 * s, y: c.y + 18 * s), CGPoint(x: c.x + 25 * s, y: c.y + 12 * s)),
            (CGPoint(x: c.x - 17 * s, y: c.y + 30 * s), CGPoint(x: c.x, y: c.y + 36 * s)),
            (CGPoint(x: c.x, y: c.y + 36 * s), CGPoint(x: c.x + 18 * s, y: c.y + 29 * s))
        ]
        for chord in chordPoints {
            var ch = Path()
            ch.move(to: chord.p1)
            ch.addLine(to: chord.p2)
            ctx.stroke(ch, with: .color(amberGold.opacity(0.32)), lineWidth: 0.45)
        }

        // 6. 22 颗生成式晶莹露珠浆果 (Organically Arranged Cascading Racemes)
        struct BerryData {
            let offset: CGPoint
            let r: CGFloat
            let outer: Color
            let core: Color
            let branchIdx: Int
            let attachT: CGFloat
        }

        let stage4Berries: [BerryData] = [
            // 远左拱 (Strand 0)
            BerryData(offset: CGPoint(x: -10 * s, y: -5 * s), r: 2.4, outer: coralRose, core: amberGold, branchIdx: 0, attachT: 0.20),
            BerryData(offset: CGPoint(x: -21 * s, y: 7 * s), r: 3.1, outer: plumBright, core: amberGold, branchIdx: 0, attachT: 0.50),
            BerryData(offset: CGPoint(x: -29 * s, y: 17 * s), r: 3.5, outer: plumWine, core: amberGold, branchIdx: 0, attachT: 0.75),
            BerryData(offset: CGPoint(x: -36 * s, y: 26 * s), r: 3.6, outer: plumWine, core: coralRose, branchIdx: 0, attachT: 1.00),

            // 次左垂帘 (Strand 1)
            BerryData(offset: CGPoint(x: -6 * s, y: 2 * s), r: 2.4, outer: coralRose, core: amberGold, branchIdx: 1, attachT: 0.20),
            BerryData(offset: CGPoint(x: -13 * s, y: 14 * s), r: 3.2, outer: plumBright, core: amberGold, branchIdx: 1, attachT: 0.45),
            BerryData(offset: CGPoint(x: -20 * s, y: 25 * s), r: 3.7, outer: plumWine, core: amberGold, branchIdx: 1, attachT: 0.70),
            BerryData(offset: CGPoint(x: -15 * s, y: 34 * s), r: 3.5, outer: plumWine, core: amberGold, branchIdx: 1, attachT: 0.88),
            BerryData(offset: CGPoint(x: -19 * s, y: 40 * s), r: 3.4, outer: plumWine, core: coralRose, branchIdx: 1, attachT: 1.00),

            // 中轴长垂帘瀑布 (Strand 2)
            BerryData(offset: CGPoint(x: -1 * s, y: 8 * s), r: 2.6, outer: coralRose, core: amberGold, branchIdx: 2, attachT: 0.20),
            BerryData(offset: CGPoint(x: 2 * s, y: 18 * s), r: 3.4, outer: plumBright, core: amberGold, branchIdx: 2, attachT: 0.40),
            BerryData(offset: CGPoint(x: -2 * s, y: 28 * s), r: 3.8, outer: plumWine, core: amberGold, branchIdx: 2, attachT: 0.60),
            BerryData(offset: CGPoint(x: 2 * s, y: 38 * s), r: 3.7, outer: plumWine, core: amberGold, branchIdx: 2, attachT: 0.80),
            BerryData(offset: CGPoint(x: 0 * s, y: 48 * s), r: 3.5, outer: plumWine, core: coralRose, branchIdx: 2, attachT: 1.00),

            // 次右垂帘 (Strand 3)
            BerryData(offset: CGPoint(x: 6 * s, y: 1 * s), r: 2.4, outer: coralRose, core: amberGold, branchIdx: 3, attachT: 0.20),
            BerryData(offset: CGPoint(x: 14 * s, y: 13 * s), r: 3.2, outer: plumBright, core: amberGold, branchIdx: 3, attachT: 0.45),
            BerryData(offset: CGPoint(x: 21 * s, y: 24 * s), r: 3.7, outer: plumWine, core: amberGold, branchIdx: 3, attachT: 0.70),
            BerryData(offset: CGPoint(x: 16 * s, y: 33 * s), r: 3.5, outer: plumWine, core: amberGold, branchIdx: 3, attachT: 0.88),
            BerryData(offset: CGPoint(x: 21 * s, y: 38 * s), r: 3.4, outer: plumWine, core: coralRose, branchIdx: 3, attachT: 1.00),

            // 远右拱 (Strand 4)
            BerryData(offset: CGPoint(x: 10 * s, y: -4 * s), r: 2.4, outer: coralRose, core: amberGold, branchIdx: 4, attachT: 0.20),
            BerryData(offset: CGPoint(x: 21 * s, y: 8 * s), r: 3.1, outer: plumBright, core: amberGold, branchIdx: 4, attachT: 0.50),
            BerryData(offset: CGPoint(x: 29 * s, y: 18 * s), r: 3.5, outer: plumWine, core: amberGold, branchIdx: 4, attachT: 0.75),
            BerryData(offset: CGPoint(x: 36 * s, y: 27 * s), r: 3.6, outer: plumWine, core: coralRose, branchIdx: 4, attachT: 1.00)
        ]

        for b in stage4Berries {
            let spec = tendrilSpecs[b.branchIdx]
            let sway = CGFloat(sin(phase * 1.3 - spec.phaseDelay)) * spec.swayScale * s * b.attachT
            let berryPos = CGPoint(x: c.x + b.offset.x + sway, y: c.y + b.offset.y)

            // 柔和微弯的小花梗 (Pedicel)
            let stemAnchor = CGPoint(
                x: c.x + (b.offset.x * 0.82) + sway * 0.9,
                y: c.y + (b.offset.y - 4.5 * s)
            )
            var ped = Path()
            ped.move(to: stemAnchor)
            ped.addLine(to: berryPos)
            ctx.stroke(ped, with: .color(darkStem.opacity(0.65)), lineWidth: 0.50)

            drawJewelBerry(
                ctx: ctx,
                pt: berryPos,
                r: b.r * clampedS,
                outerColor: b.outer,
                coreColor: b.core,
                gleamColor: gleam,
                strokeColor: darkStem
            )
        }

        // 7. 伴生漂浮星尘微粒 (Satellite Luminous Stardust)
        drawSatelliteDots(
            ctx: ctx,
            c: CGPoint(x: c.x, y: c.y + 22 * s),
            r: 34 * s,
            count: 4,
            colors: [amberGold, plumBright, coralRose],
            phase: phase,
            speed: 0.25
        )
    }

    // =========================================================================
    // MARK: - 6. 金琥珀阳 (Mimosa / Directional Solar Corona & Flare Pods)
    // =========================================================================
    private func renderSpecies6(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let goldAmber = Color(red: 0.94, green: 0.68, blue: 0.22)
        let turquoise = Color(red: 0.28, green: 0.68, blue: 0.72)
        let darkStem = Color(red: 0.28, green: 0.20, blue: 0.18)

        if p < 0.25 {
            for i in 0..<5 {
                let a = -Double.pi * 0.5 - 0.36 + Double(i) * 0.18
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * 14.0 * s, y: c.y + CGFloat(sin(a)) * 14.0 * s)
                var ray = Path()
                ray.move(to: c)
                ray.addLine(to: pt)
                ctx.stroke(ray, with: .color(goldAmber), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: goldAmber, coreColor: darkStem, r: 2.0 * min(s, 1.35))
            }
            return
        }

        if p < 0.50 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 10 * s), color: goldAmber, rx: 24 * s, ry: 20 * s, opacity: 0.38)
            let rayCount = 12
            for i in 0..<rayCount {
                let frac = Double(i) / Double(rayCount - 1)
                let a = -Double.pi * 0.90 + frac * (Double.pi * 0.80)
                let r: CGFloat = (18.0 + (i % 2 == 0 ? 8.0 : 0.0)) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                var ray = Path()
                ray.move(to: c)
                ray.addLine(to: pt)
                ctx.stroke(ray, with: .color(goldAmber), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: goldAmber, coreColor: darkStem, r: 2.3 * min(s, 1.35))
            }
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 12 * s), color: goldAmber, rx: 30 * s, ry: 26 * s, opacity: 0.42)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y + 4 * s), color: Color(red: 0.85, green: 0.80, blue: 0.40), rx: 18 * s, ry: 16 * s, opacity: 0.30)

            let count = 20
            for i in 0..<count {
                let frac = Double(i) / Double(count - 1)
                let a = -Double.pi * 0.975 + frac * (Double.pi * 0.95)
                let r: CGFloat = (22.0 + (i % 2 == 0 ? 10.0 : 2.0)) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                var ray = Path()
                ray.move(to: c)
                ray.addLine(to: pt)
                ctx.stroke(ray, with: .color(darkStem), lineWidth: 0.60)
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: goldAmber, coreColor: darkStem, r: 2.4 * min(s, 1.35))
            }
            return
        }

        // Stage 4: 全盛金琥珀阳 (以中点圆心 c 为绝对同心基准)
        drawGlowBlob(ctx: ctx, c: c, color: goldAmber, rx: 42 * s, ry: 36 * s, opacity: 0.50)
        drawGlowBlob(ctx: ctx, c: c, color: Color(red: 0.78, green: 0.88, blue: 0.40), rx: 26 * s, ry: 22 * s, opacity: 0.32)
        drawHaloRings(ctx: ctx, c: c, maxR: 44 * s, count: 3, phase: phase)

        let count4 = 32
        for i in 0..<count4 {
            let frac = Double(i) / Double(count4 - 1)
            // 严格以垂直 Y 轴 (-0.5*pi) 为对称轴展开对称放射金阳芒扇
            let a = -Double.pi * 1.08 + frac * (Double.pi * 1.16)
            let shimmer = sin(phase * 1.2 + Double(i) * 0.4) * 1.2
            let isSpire = (i % 3 == 0)
            let baseLen: CGFloat = isSpire ? 38.0 : (i % 2 == 0 ? 28.0 : 20.0)
            let r: CGFloat = (baseLen + CGFloat(shimmer)) * CGFloat(b) * s
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            var ray = Path()
            ray.move(to: c)
            ray.addLine(to: pt)
            ctx.stroke(ray, with: .color(darkStem), lineWidth: 0.60)
            drawTopologicalNode(ctx: ctx, pt: pt, ringColor: isSpire ? Color(red: 0.98, green: 0.95, blue: 0.80) : goldAmber, coreColor: darkStem, r: (isSpire ? 2.6 : 2.2) * min(s, 1.35))
        }

        var core = Path()
        let coreR: CGFloat = 5.0 * min(s, 1.35)
        core.addEllipse(in: CGRect(x: c.x - coreR, y: c.y - coreR, width: coreR * 2, height: coreR * 2))
        ctx.fill(core, with: .color(darkStem))
        ctx.stroke(core, with: .color(goldAmber), lineWidth: 0.8)

        drawSatelliteDots(ctx: ctx, c: c, r: 24 * s, count: 3, colors: [goldAmber, turquoise], phase: phase, speed: 0.25)
    }

    // =========================================================================
    // MARK: - 7. 青绒蒲公英 (Hydrangea / Amorphous Fluid Cloud & Crown)
    // =========================================================================
    private func renderSpecies7(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let lime = Color(red: 0.78, green: 0.88, blue: 0.42)
        let plum = Color(red: 0.75, green: 0.28, blue: 0.42)
        let goldAmber = Color(red: 0.94, green: 0.72, blue: 0.32)
        let darkStem = Color(red: 0.30, green: 0.20, blue: 0.22)

        if p < 0.25 {
            var drop = Path()
            drop.addEllipse(in: CGRect(x: c.x - 7 * s, y: c.y - 12 * s, width: 14 * s, height: 16 * s))
            ctx.fill(drop, with: .color(lime.opacity(0.70)))
            ctx.stroke(drop, with: .color(darkStem), lineWidth: 0.65)
            drawTopologicalNode(ctx: ctx, pt: CGPoint(x: c.x, y: c.y - 12 * s), ringColor: plum, coreColor: darkStem, r: 2.2 * min(s, 1.35))
            return
        }

        if p < 0.50 {
            drawGlowBlob(ctx: ctx, c: c, color: lime, rx: 22 * s, ry: 20 * s, opacity: 0.35)
            var blob = Path()
            let ptsCount = 10
            for i in 0..<ptsCount {
                let a = Double(i) / Double(ptsCount) * Double.pi * 2.0
                let r: CGFloat = (16.0 + CGFloat(sin(a * 3.0 + phase)) * 3.0) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                if i == 0 { blob.move(to: pt) } else { blob.addLine(to: pt) }
            }
            blob.closeSubpath()
            ctx.fill(blob, with: .color(lime.opacity(0.65)))
            ctx.stroke(blob, with: .color(darkStem), lineWidth: 0.65)
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 6 * s, y: c.y - 6 * s), color: lime, rx: 26 * s, ry: 22 * s, opacity: 0.38)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 6 * s, y: c.y + 6 * s), color: plum, rx: 22 * s, ry: 20 * s, opacity: 0.30)

            var blob = Path()
            let ptsCount = 16
            var ringPts: [CGPoint] = []
            for i in 0..<ptsCount {
                let a = Double(i) / Double(ptsCount) * Double.pi * 2.0
                let r: CGFloat = (22.0 + CGFloat(sin(a * 3.0 + phase * 1.5)) * 4.0) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                ringPts.append(pt)
                if i == 0 { blob.move(to: pt) } else { blob.addLine(to: pt) }
            }
            blob.closeSubpath()
            ctx.fill(blob, with: .color(lime.opacity(0.55)))
            ctx.stroke(blob, with: .color(darkStem), lineWidth: 0.65)

            // Stage 3 内部萌芽发光微粒 (8 颗)
            for i in 0..<8 {
                let a = Double(i) / 8.0 * Double.pi * 2.0 + phase * 0.4
                let rDist: CGFloat = (6.0 + CGFloat(i % 3) * 4.0) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rDist, y: c.y + CGFloat(sin(a)) * rDist)
                let twinkle = sin(phase * 3.0 + Double(i) * 1.2) * 0.35 + 0.65
                var pCore = Path()
                pCore.addEllipse(in: CGRect(x: pt.x - 1.5, y: pt.y - 1.5, width: 3.0, height: 3.0))
                ctx.fill(pCore, with: .color(goldAmber.opacity(0.85 * twinkle)))
            }

            for pt in ringPts {
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: plum, coreColor: darkStem, r: 2.3 * min(s, 1.35))
            }
            return
        }

        // Stage 4: 7-4 内部发光粒子系统 + 流体拓扑云胞
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 8 * s, y: c.y - 8 * s), color: lime, rx: 34 * s, ry: 28 * s, opacity: 0.45)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y + 6 * s), color: plum, rx: 30 * s, ry: 26 * s, opacity: 0.38)
        drawHaloRings(ctx: ctx, c: c, maxR: 44 * s, count: 3, phase: phase)

        let ptsCount4 = 24
        var fluidPts: [CGPoint] = []
        var blob4 = Path()
        for i in 0..<ptsCount4 {
            let a = Double(i) / Double(ptsCount4) * Double.pi * 2.0
            let harmonic1 = sin(a * 3.0 + phase * 1.8) * 4.5
            let harmonic2 = cos(a * 5.0 - phase * 1.2) * 2.5
            let r: CGFloat = (26.0 + CGFloat(harmonic1 + harmonic2)) * CGFloat(b) * s
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            fluidPts.append(pt)
            if i == 0 { blob4.move(to: pt) } else { blob4.addLine(to: pt) }
        }
        blob4.closeSubpath()
        // 流体云胞半透明膜：使内部发光微粒清晰显映
        ctx.fill(blob4, with: .color(lime.opacity(0.48)))
        ctx.stroke(blob4, with: .color(darkStem), lineWidth: 0.70)

        // 7-4 内部发光粒子群 (Internal Bioluminescent Glowing Particles)
        let internalParticleCount = 20
        var internalPts: [CGPoint] = []
        for i in 0..<internalParticleCount {
            let goldenAngle = Double.pi * (3.0 - sqrt(5.0))
            let baseAngle = Double(i) * goldenAngle + phase * 0.35

            // 径向距离限制在流体团内部 (3.5pt ~ 18.0pt * s)
            let rNorm = sqrt((Double(i) + 1.0) / Double(internalParticleCount)) // 0.22 ~ 1.0
            let rDist: CGFloat = CGFloat(3.5 + rNorm * 14.5) * CGFloat(b) * s

            // 胞质微流动漂移
            let driftX = sin(phase * 1.5 + Double(i) * 2.1) * 2.2 * s
            let driftY = cos(phase * 1.8 + Double(i) * 1.7) * 2.2 * s
            let pt = CGPoint(
                x: c.x + CGFloat(cos(baseAngle)) * rDist + driftX,
                y: c.y + CGFloat(sin(baseAngle)) * rDist + driftY
            )
            internalPts.append(pt)
        }

        // 内部微观引力连线 (极细发丝 0.45pt)
        for i in 0..<internalPts.count {
            for j in (i + 1)..<internalPts.count {
                let dx = internalPts[i].x - internalPts[j].x
                let dy = internalPts[i].y - internalPts[j].y
                let dist = hypot(dx, dy)
                if dist < 12.0 * s {
                    var link = Path()
                    link.move(to: internalPts[i])
                    link.addLine(to: internalPts[j])
                    let alpha = (1.0 - dist / (12.0 * s)) * 0.35
                    ctx.stroke(link, with: .color(goldAmber.opacity(alpha)), lineWidth: 0.45)
                }
            }
        }

        // 绘制内部发光粒子 (双层：外层漫反射微光晕 + 内层晶亮发光核)
        for (i, pt) in internalPts.enumerated() {
            let twinkle = sin(phase * 3.5 + Double(i) * 1.4) * 0.35 + 0.65
            let particleColor: Color = (i % 3 == 0) ? goldAmber : ((i % 3 == 1) ? plum : Color(red: 0.95, green: 0.98, blue: 0.65))

            // 外层微光晕
            let haloR: CGFloat = (3.6 + CGFloat(twinkle) * 1.6) * min(s, 1.35)
            var halo = Path()
            halo.addEllipse(in: CGRect(x: pt.x - haloR, y: pt.y - haloR, width: haloR * 2, height: haloR * 2))
            ctx.fill(halo, with: .color(particleColor.opacity(0.38 * twinkle)))

            // 内层高亮微晶核
            let coreR: CGFloat = (1.2 + CGFloat(twinkle) * 0.5) * min(s, 1.35)
            var particleCore = Path()
            particleCore.addEllipse(in: CGRect(x: pt.x - coreR, y: pt.y - coreR, width: coreR * 2, height: coreR * 2))
            ctx.fill(particleCore, with: .color(particleColor.opacity(0.95)))
            ctx.stroke(particleCore, with: .color(darkStem.opacity(0.55)), lineWidth: 0.40)
        }

        for i in 0..<ptsCount4 {
            let a = Double(i) / Double(ptsCount4) * Double.pi * 2.0
            let ptBase = fluidPts[i]
            let spireLen: CGFloat = (6.0 + (i % 2 == 0 ? 4.0 : 0.0)) * CGFloat(b) * s
            let ptTip = CGPoint(x: ptBase.x + CGFloat(cos(a)) * spireLen, y: ptBase.y + CGFloat(sin(a)) * spireLen)
            var ray = Path()
            ray.move(to: ptBase)
            ray.addLine(to: ptTip)
            ctx.stroke(ray, with: .color(darkStem), lineWidth: 0.55)
            drawTopologicalNode(ctx: ctx, pt: ptTip, ringColor: plum, coreColor: darkStem, r: 2.4 * min(s, 1.35))
        }

        var core = Path()
        let coreR: CGFloat = 4.8 * min(s, 1.35)
        core.addEllipse(in: CGRect(x: c.x - coreR, y: c.y - coreR, width: coreR * 2, height: coreR * 2))
        ctx.fill(core, with: .color(goldAmber))
        ctx.stroke(core, with: .color(darkStem), lineWidth: 0.75)
    }

    // =========================================================================
    // MARK: - 8. 珊瑚青瓣 (Allium / Metamorphic Ribbon Loops & Shards)
    // =========================================================================
    private func renderSpecies8(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let coral = Color(red: 0.90, green: 0.45, blue: 0.38)
        let turquoise = Color(red: 0.28, green: 0.70, blue: 0.72)
        let darkStem = Color(red: 0.25, green: 0.22, blue: 0.28)

        if p < 0.25 {
            // 阶段 1: 葱属球状包被 / 珊瑚经纬晶球幼苞 (Allium Seed Bulb Globe)
            // 彻底去除多余细线与漂浮位移，基底花托直接座落在茎秆顶端 c 点，沿 Y 轴对称展开，自适应对齐茎杆切线
            let bulbR: CGFloat = 12.0 * s
            let bulbCenter = CGPoint(x: c.x, y: c.y - bulbR)

            drawGlowBlob(ctx: ctx, c: bulbCenter, color: coral, rx: 22 * s, ry: 20 * s, opacity: 0.38)
            drawGlowBlob(ctx: ctx, c: bulbCenter, color: turquoise, rx: 16 * s, ry: 16 * s, opacity: 0.30)
            drawHaloRings(ctx: ctx, c: bulbCenter, maxR: 26 * s, count: 3, phase: phase)

            // 1. 基底托杯 (Receptacle Cup)，紧紧座落在 c 点
            var cup = Path()
            cup.move(to: CGPoint(x: c.x - 6 * s, y: c.y - 2 * s))
            cup.addQuadCurve(to: CGPoint(x: c.x + 6 * s, y: c.y - 2 * s), control: CGPoint(x: c.x, y: c.y + 2 * s))
            cup.addLine(to: CGPoint(x: c.x + 5 * s, y: c.y - 5 * s))
            cup.addLine(to: CGPoint(x: c.x - 5 * s, y: c.y - 5 * s))
            cup.closeSubpath()
            ctx.fill(cup, with: .color(darkStem))

            // 2. 立体晶球外壳 (Spherical Globe Shell)
            var globe = Path()
            globe.addEllipse(in: CGRect(x: bulbCenter.x - bulbR, y: bulbCenter.y - bulbR, width: bulbR * 2, height: bulbR * 2))
            ctx.fill(globe, with: .color(turquoise.opacity(0.72)))
            ctx.stroke(globe, with: .color(darkStem), lineWidth: 0.70)

            // 3. 经度立体透视经线 (Longitudinal Meridian Ribs)
            for factor in [0.35, 0.70] {
                let rx = bulbR * CGFloat(factor)
                var rib = Path()
                rib.addEllipse(in: CGRect(x: bulbCenter.x - rx, y: bulbCenter.y - bulbR, width: rx * 2, height: bulbR * 2))
                ctx.stroke(rib, with: .color(darkStem.opacity(0.60)), lineWidth: 0.55)
            }

            // 4. 赤道纬线环 (Equatorial Latitude Ring)
            var equator = Path()
            equator.addEllipse(in: CGRect(x: bulbCenter.x - bulbR, y: bulbCenter.y - bulbR * 0.32, width: bulbR * 2, height: bulbR * 0.64))
            ctx.stroke(equator, with: .color(coral.opacity(0.80)), lineWidth: 0.60)

            // 5. 顶端放射的 5 根微型星花触须 (Satellite Seed Florets)
            let floretAngles = [-Double.pi * 0.85, -Double.pi * 0.68, -Double.pi * 0.50, -Double.pi * 0.32, -Double.pi * 0.15]
            for (idx, a) in floretAngles.enumerated() {
                let rimPt = CGPoint(x: bulbCenter.x + CGFloat(cos(a)) * bulbR, y: bulbCenter.y + CGFloat(sin(a)) * bulbR)
                let spurTip = CGPoint(x: bulbCenter.x + CGFloat(cos(a)) * (bulbR + 4.5 * s), y: bulbCenter.y + CGFloat(sin(a)) * (bulbR + 4.5 * s))
                var spur = Path()
                spur.move(to: rimPt)
                spur.addLine(to: spurTip)
                ctx.stroke(spur, with: .color(darkStem), lineWidth: 0.55)
                let beadColor = (idx % 2 == 0) ? coral : turquoise
                drawTopologicalNode(ctx: ctx, pt: spurTip, ringColor: beadColor, coreColor: darkStem, r: 2.0 * min(s, 1.35))
            }
            return
        }

        if p < 0.50 {
            drawGlowBlob(ctx: ctx, c: c, color: coral, rx: 22 * s, ry: 20 * s, opacity: 0.35)
            for i in 0..<4 {
                let a = Double(i) / 4.0 * Double.pi * 2.0 + 0.35
                let ptTip = CGPoint(x: c.x + CGFloat(cos(a)) * 20.0 * s, y: c.y + CGFloat(sin(a)) * 20.0 * s)
                var pPath = Path()
                pPath.move(to: c)
                pPath.addQuadCurve(to: ptTip, control: CGPoint(x: c.x + CGFloat(cos(a - 0.3)) * 12.0 * s, y: c.y + CGFloat(sin(a - 0.3)) * 12.0 * s))
                pPath.addQuadCurve(to: c, control: CGPoint(x: c.x + CGFloat(cos(a + 0.3)) * 12.0 * s, y: c.y + CGFloat(sin(a + 0.3)) * 12.0 * s))
                ctx.fill(pPath, with: .color(coral.opacity(0.80)))
                ctx.stroke(pPath, with: .color(darkStem), lineWidth: 0.65)
            }
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y - 6 * s), color: coral, rx: 26 * s, ry: 22 * s, opacity: 0.40)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 8 * s, y: c.y + 6 * s), color: turquoise, rx: 24 * s, ry: 20 * s, opacity: 0.35)

            for i in 0..<6 {
                let a = Double(i) / 6.0 * Double.pi * 2.0 + (i % 2 == 0 ? 0.15 : -0.15)
                let r: CGFloat = (24.0 + (i % 2 == 0 ? 5.0 : 0.0)) * CGFloat(b) * s
                let ptTip = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                var petal = Path()
                petal.move(to: c)
                petal.addQuadCurve(to: ptTip, control: CGPoint(x: c.x + CGFloat(cos(a - 0.25)) * (r * 0.6), y: c.y + CGFloat(sin(a - 0.25)) * (r * 0.6)))
                petal.addQuadCurve(to: c, control: CGPoint(x: c.x + CGFloat(cos(a + 0.25)) * (r * 0.6), y: c.y + CGFloat(sin(a + 0.25)) * (r * 0.6)))
                let col = (i % 2 == 0) ? coral : turquoise
                ctx.fill(petal, with: .color(col.opacity(0.75)))
                ctx.stroke(petal, with: .color(darkStem), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: ptTip, ringColor: turquoise, coreColor: darkStem, r: 2.6 * min(s, 1.35))
            }
            return
        }

        // Stage 4
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 10 * s, y: c.y - 8 * s), color: coral, rx: 36 * s, ry: 28 * s, opacity: 0.48)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 10 * s, y: c.y + 8 * s), color: turquoise, rx: 30 * s, ry: 24 * s, opacity: 0.40)
        drawHaloRings(ctx: ctx, c: c, maxR: 44 * s, count: 3, phase: phase)

        let petalCount = 8
        for i in 0..<petalCount {
            let petalScale = computeSequentialPetalScale(index: i, total: petalCount, phase: phase, progress: p, isCircular: true)
            let a = Double(i) / Double(petalCount) * Double.pi * 2.0 + sin(phase * 1.5 + Double(i)) * 0.08
            let baseLen: CGFloat = (28.0 + (i % 2 == 0 ? 6.0 : 0.0)) * CGFloat(b) * s
            let petalLen: CGFloat = baseLen * petalScale
            let ptTip = CGPoint(x: c.x + CGFloat(cos(a)) * petalLen, y: c.y + CGFloat(sin(a)) * petalLen)

            var petal = Path()
            petal.move(to: c)
            let pCtrl1 = CGPoint(x: c.x + CGFloat(cos(a - 0.26)) * (petalLen * 0.65), y: c.y + CGFloat(sin(a - 0.26)) * (petalLen * 0.65))
            let pCtrl2 = CGPoint(x: c.x + CGFloat(cos(a + 0.26)) * (petalLen * 0.65), y: c.y + CGFloat(sin(a + 0.26)) * (petalLen * 0.65))
            petal.addQuadCurve(to: ptTip, control: pCtrl1)
            petal.addQuadCurve(to: c, control: pCtrl2)
            ctx.fill(petal, with: .color(coral.opacity(0.82)))
            ctx.stroke(petal, with: .color(darkStem), lineWidth: 0.65)

            var rib = Path()
            rib.move(to: c)
            rib.addLine(to: ptTip)
            ctx.stroke(rib, with: .color(darkStem.opacity(0.65)), lineWidth: 0.50)

            drawTopologicalNode(ctx: ctx, pt: ptTip, ringColor: turquoise, coreColor: darkStem, r: 2.7 * min(s, 1.35) * min(1.35, petalScale))
        }

        var centerDisc = Path()
        let cDiscR: CGFloat = 6.0 * min(s, 1.35)
        centerDisc.addEllipse(in: CGRect(x: c.x - cDiscR, y: c.y - cDiscR, width: cDiscR * 2, height: cDiscR * 2))
        ctx.fill(centerDisc, with: .color(turquoise))
        ctx.stroke(centerDisc, with: .color(darkStem), lineWidth: 0.75)
    }

    // =========================================================================
    // MARK: - 9. 金晕绯瑰 (LotusPod / Multi-Core Nebula & Cellular Void Matrix)
    // =========================================================================
    private func renderSpecies9(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let wineRose = Color(red: 0.88, green: 0.38, blue: 0.48)
        let goldAmber = Color(red: 0.92, green: 0.72, blue: 0.28)
        let darkStem = Color(red: 0.28, green: 0.16, blue: 0.20)

        if p < 0.25 {
            drawHaloRings(ctx: ctx, c: c, maxR: 28 * s, count: 3, phase: phase)
            drawTopologicalNode(ctx: ctx, pt: CGPoint(x: c.x - 4 * s, y: c.y - 12 * s), ringColor: goldAmber, coreColor: darkStem, r: 2.3 * min(s, 1.35))
            drawTopologicalNode(ctx: ctx, pt: CGPoint(x: c.x + 5 * s, y: c.y - 14 * s), ringColor: wineRose, coreColor: darkStem, r: 2.3 * min(s, 1.35))
            return
        }

        if p < 0.50 {
            drawGlowBlob(ctx: ctx, c: c, color: wineRose, rx: 24 * s, ry: 20 * s, opacity: 0.38)
            for (ox, oy) in [(-6, -6), (6, -6), (0, 4)] {
                let cellR: CGFloat = 4.0 * min(s, 1.35)
                var cell = Path()
                cell.addEllipse(in: CGRect(x: c.x + CGFloat(ox) * s - cellR, y: c.y + CGFloat(oy) * s - cellR, width: cellR * 2, height: cellR * 2))
                ctx.stroke(cell, with: .color(darkStem), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: CGPoint(x: c.x + CGFloat(ox) * s, y: c.y + CGFloat(oy) * s), ringColor: goldAmber, coreColor: darkStem, r: 2.0 * min(s, 1.35))
            }
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 8 * s, y: c.y - 6 * s), color: wineRose, rx: 28 * s, ry: 24 * s, opacity: 0.42)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y + 6 * s), color: goldAmber, rx: 24 * s, ry: 20 * s, opacity: 0.38)

            let cellOffsets: [(CGFloat, CGFloat)] = [
                (0, 0), (-9, -5), (9, -5), (-9, 6), (9, 6), (0, -11), (0, 11)
            ]
            for (ox, oy) in cellOffsets {
                let pt = CGPoint(x: c.x + ox * s, y: c.y + oy * s)
                let cR: CGFloat = 4.5 * min(s, 1.35)
                var cell = Path()
                cell.addEllipse(in: CGRect(x: pt.x - cR, y: pt.y - cR, width: cR * 2, height: cR * 2))
                ctx.fill(cell, with: .color(wineRose.opacity(0.60)))
                ctx.stroke(cell, with: .color(darkStem), lineWidth: 0.65)
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: goldAmber, coreColor: darkStem, r: 2.2 * min(s, 1.35))
            }
            return
        }

        // Stage 4: 渐变多层次分色光晕系统 (太阳金 -> 珊瑚玫 -> 绛紫绯红 -> 暮雾紫) + 蜂巢拓扑矩阵
        let glowTiers: [(color: Color, rx: CGFloat, ry: CGFloat, opacity: Double)] = [
            (color: goldAmber, rx: 18 * s, ry: 18 * s, opacity: 0.58),
            (color: wineRose, rx: 30 * s, ry: 28 * s, opacity: 0.46),
            (color: Color(red: 0.74, green: 0.20, blue: 0.44), rx: 42 * s, ry: 38 * s, opacity: 0.36),
            (color: Color(red: 0.58, green: 0.35, blue: 0.70), rx: 54 * s, ry: 48 * s, opacity: 0.24)
        ]
        let glowRings: [(color: Color, r: CGFloat, lineWidth: CGFloat)] = [
            (color: goldAmber.opacity(0.50), r: 16 * s, lineWidth: 0.60),
            (color: wineRose.opacity(0.40), r: 28 * s, lineWidth: 0.55),
            (color: Color(red: 0.74, green: 0.20, blue: 0.44).opacity(0.32), r: 40 * s, lineWidth: 0.50),
            (color: Color(red: 0.58, green: 0.35, blue: 0.70).opacity(0.25), r: 52 * s, lineWidth: 0.45)
        ]
        drawLayeredChromaticHalo(ctx: ctx, c: c, tiers: glowTiers, rings: glowRings, phase: phase)

        let matrixOffsets: [(CGFloat, CGFloat)] = [
            (0, 0), (-11, -7), (11, -7), (-11, 8), (11, 8),
            (0, -14), (0, 14), (-18, 0), (18, 0)
        ]
        for (ox, oy) in matrixOffsets {
            let pt = CGPoint(x: c.x + ox * CGFloat(b) * s, y: c.y + oy * CGFloat(b) * s)
            let cR: CGFloat = 5.0 * min(s, 1.35)
            var cell = Path()
            cell.addEllipse(in: CGRect(x: pt.x - cR, y: pt.y - cR, width: cR * 2, height: cR * 2))
            ctx.fill(cell, with: .color(wineRose.opacity(0.65)))
            ctx.stroke(cell, with: .color(darkStem), lineWidth: 0.70)
            drawTopologicalNode(ctx: ctx, pt: pt, ringColor: goldAmber, coreColor: darkStem, r: 2.4 * min(s, 1.35))
        }

        let antennaCount = 14
        for i in 0..<antennaCount {
            let a = Double(i) / Double(antennaCount) * Double.pi * 2.0
            let r: CGFloat = (30.0 + (i % 2 == 0 ? 8.0 : 0.0)) * CGFloat(b) * s
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            var ant = Path()
            ant.move(to: c)
            ant.addLine(to: pt)
            ctx.stroke(ant, with: .color(darkStem.opacity(0.60)), lineWidth: 0.55)
            drawTopologicalNode(ctx: ctx, pt: pt, ringColor: goldAmber, coreColor: darkStem, r: 2.4 * min(s, 1.35))
        }

        drawSatelliteDots(ctx: ctx, c: c, r: 44 * s, count: 4, colors: [wineRose, goldAmber], phase: phase, speed: 0.20)
    }

    // =========================================================================
    // MARK: - 10. 双色几何伞 (CherryBlossom / Aurora Wing & Streamer Chandelier)
    // =========================================================================
    private func renderSpecies10(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let cyan = Color(red: 0.22, green: 0.75, blue: 0.85)
        let peachTan = Color(red: 0.88, green: 0.55, blue: 0.38)
        let darkStem = Color(red: 0.24, green: 0.22, blue: 0.28)

        if p < 0.25 {
            // 阶段 1: 极光双色垂铃瓣苞 (CherryBlossom Teardrop Lantern Bud)
            // 彻底去除多余细线，花苞基底直接座落在茎秆顶端 c 点，沿 Y 轴对称向上生长，随切线角自适应朝向
            let budH: CGFloat = 28.0 * s
            let budW: CGFloat = 10.0 * s
            let apex = CGPoint(x: c.x, y: c.y - budH)

            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - budH * 0.5), color: cyan, rx: 22 * s, ry: 20 * s, opacity: 0.38)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - budH * 0.5), color: peachTan, rx: 18 * s, ry: 16 * s, opacity: 0.30)
            drawHaloRings(ctx: ctx, c: CGPoint(x: c.x, y: c.y - budH * 0.5), maxR: 28 * s, count: 3, phase: phase)

            // 1. 基底抱合小萼片 (Basal Sepal Scales)
            for side in [-1.0, 1.0] {
                var sepal = Path()
                sepal.move(to: c)
                sepal.addQuadCurve(
                    to: CGPoint(x: c.x + CGFloat(side) * 5 * s, y: c.y - 6 * s),
                    control: CGPoint(x: c.x + CGFloat(side) * 6 * s, y: c.y - 2 * s)
                )
                ctx.stroke(sepal, with: .color(darkStem), lineWidth: 0.70)
            }

            // 2. 优雅交叠的双色灯笼花瓣：左瓣青冰碧蓝，右瓣暖杏桃红
            var leftPetal = Path()
            leftPetal.move(to: c)
            leftPetal.addCurve(
                to: apex,
                control1: CGPoint(x: c.x - budW * 1.1, y: c.y - budH * 0.35),
                control2: CGPoint(x: c.x - budW * 0.7, y: c.y - budH * 0.80)
            )
            leftPetal.addQuadCurve(to: c, control: CGPoint(x: c.x + 2 * s, y: c.y - budH * 0.45))
            ctx.fill(leftPetal, with: .color(cyan.opacity(0.70)))
            ctx.stroke(leftPetal, with: .color(darkStem), lineWidth: 0.70)

            var rightPetal = Path()
            rightPetal.move(to: c)
            rightPetal.addCurve(
                to: apex,
                control1: CGPoint(x: c.x + budW * 1.1, y: c.y - budH * 0.35),
                control2: CGPoint(x: c.x + budW * 0.7, y: c.y - budH * 0.80)
            )
            rightPetal.addQuadCurve(to: c, control: CGPoint(x: c.x - 2 * s, y: c.y - budH * 0.45))
            ctx.fill(rightPetal, with: .color(peachTan.opacity(0.65)))
            ctx.stroke(rightPetal, with: .color(darkStem), lineWidth: 0.70)

            // 3. 瓣缝中隐现的金琥珀花蕊 (Stamen Pearl Core)
            var stamen = Path()
            stamen.move(to: CGPoint(x: c.x, y: c.y - 6 * s))
            stamen.addLine(to: CGPoint(x: c.x, y: c.y - budH * 0.72))
            ctx.stroke(stamen, with: .color(Color(red: 0.94, green: 0.74, blue: 0.28)), lineWidth: 0.80)

            let pearlPt = CGPoint(x: c.x, y: c.y - budH * 0.72)
            drawTopologicalNode(ctx: ctx, pt: pearlPt, ringColor: Color(red: 0.94, green: 0.74, blue: 0.28), coreColor: darkStem, r: 2.0 * min(s, 1.35))

            // 4. 尖端冰青色拓扑宝珠 (Apex Jewel)
            drawTopologicalNode(ctx: ctx, pt: apex, ringColor: cyan, coreColor: darkStem, r: 2.6 * min(s, 1.35))
            return
        }

        if p < 0.50 {
            // 阶段 2: 极光伞冠与初垂流苏 (Aurora Canopy & Early Streamers)
            // 相比 2-2 大幅加大且结构更加复杂：包含上方极光拱形伞架 + 蛛网拱圈 + 下方垂落波浪流苏
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 6 * s, y: c.y - 12 * s), color: cyan, rx: 32 * s, ry: 26 * s, opacity: 0.40)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 6 * s, y: c.y + 4 * s), color: peachTan, rx: 26 * s, ry: 22 * s, opacity: 0.35)
            drawHaloRings(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 4 * s), maxR: 36 * s, count: 3, phase: phase)

            // 1. 下方垂落的柔波极光流苏 (Weeping Streamers: 10 根垂丝)
            let earlyStreamCount = 10
            for i in 0..<earlyStreamCount {
                let frac = Double(i) / Double(earlyStreamCount - 1)
                let a = Double.pi * 0.12 + frac * Double.pi * 0.76
                let wave = sin(phase * 2.6 + Double(i) * 0.7) * 2.8
                let len: CGFloat = (18.0 + CGFloat(sin(Double(i) * 0.8)) * 6.0 + CGFloat(wave)) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * len, y: c.y + CGFloat(sin(a)) * len)

                var ray = Path()
                ray.move(to: c)
                let ctrl = CGPoint(x: c.x + CGFloat(cos(a + 0.12)) * (len * 0.50), y: c.y + CGFloat(sin(a + 0.12)) * (len * 0.50))
                ray.addQuadCurve(to: pt, control: ctrl)
                ctx.stroke(ray, with: .color(cyan.opacity(0.80)), lineWidth: 0.55)

                var dot = Path()
                dot.addEllipse(in: CGRect(x: pt.x - 1.0, y: pt.y - 1.0, width: 2.0, height: 2.0))
                ctx.fill(dot, with: .color(cyan))
            }

            // 2. 上方辐射展开的极光拱架伞骨 (Aurora Crown Struts: 11 根骨架，半径扩大至 34*s)
            let count2 = 11
            let startA = -Double.pi * 0.96
            let endA = -Double.pi * 0.04
            var strutTips: [CGPoint] = []

            for i in 0..<count2 {
                let frac = Double(i) / Double(count2 - 1)
                let a = startA + frac * (endA - startA)
                let r: CGFloat = (30.0 + CGFloat(sin(frac * Double.pi)) * 6.0) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                strutTips.append(pt)

                var ray = Path()
                ray.move(to: c)
                ray.addLine(to: pt)
                ctx.stroke(ray, with: .color(peachTan), lineWidth: 0.75)

                let nodeColor = (i % 2 == 0) ? cyan : peachTan
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: nodeColor, coreColor: darkStem, r: 2.6 * min(s, 1.35))
            }

            // 3. 上方外周拱形蛛网连线 (Scalloped Web Arches) 连接伞骨顶端
            for i in 0..<(strutTips.count - 1) {
                var arch = Path()
                arch.move(to: strutTips[i])
                let midX = (strutTips[i].x + strutTips[i + 1].x) * 0.5
                let midY = (strutTips[i].y + strutTips[i + 1].y) * 0.5
                let pullCtrl = CGPoint(x: (midX + c.x) * 0.5, y: (midY + c.y) * 0.5)
                arch.addQuadCurve(to: strutTips[i + 1], control: pullCtrl)
                ctx.stroke(arch, with: .color(peachTan.opacity(0.60)), lineWidth: 0.55)
            }

            // 4. 中心双色几何核心 (Central Jewel Hub)
            var hub = Path()
            let hubR: CGFloat = 3.2 * min(s, 1.35)
            hub.addEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2))
            ctx.fill(hub, with: .color(cyan))
            ctx.stroke(hub, with: .color(darkStem), lineWidth: 0.70)
            return
        }

        if p < 0.75 {
            // 阶段 3: 极光穹顶与垂瀑流苏 (Grand Aurora Canopy & Chandelier Streams)
            // 结合 10-4 加大加复杂，并于头顶添加飘逸浮动的极光曲线与游动星光
            let crownTopY = c.y - 38.0 * CGFloat(b) * s

            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 8 * s, y: c.y - 12 * s), color: cyan, rx: 38 * s, ry: 30 * s, opacity: 0.45)
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y + 6 * s), color: peachTan, rx: 30 * s, ry: 26 * s, opacity: 0.38)
            drawHaloRings(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 4 * s), maxR: 44 * s, count: 3, phase: phase)

            // 1. 头顶浮动线条元素 (Floating Kinetic Streamlines Above the Crown)
            drawFloatingAuraLines(ctx: ctx, c: c, s: s, phase: phase, colors: [cyan, peachTan], crownTopY: crownTopY)

            // 2. 下部垂落的 20 根波浪极光流苏 (结合 10-4 密密垂挂的流苏羽丝)
            let streamCount3 = 20
            for i in 0..<streamCount3 {
                let frac = Double(i) / Double(streamCount3 - 1)
                let a = Double.pi * 0.08 + frac * Double.pi * 0.84
                let wave = sin(phase * 3.2 + Double(i) * 0.6) * 3.2
                let len: CGFloat = (20.0 + CGFloat(sin(Double(i) * 0.75)) * 8.0 + CGFloat(wave)) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * len, y: c.y + CGFloat(sin(a)) * len)

                var ray = Path()
                ray.move(to: c)
                let ctrl = CGPoint(x: c.x + CGFloat(cos(a + 0.10)) * (len * 0.52), y: c.y + CGFloat(sin(a + 0.10)) * (len * 0.52))
                ray.addQuadCurve(to: pt, control: ctrl)
                ctx.stroke(ray, with: .color(cyan.opacity(0.85)), lineWidth: 0.55)

                var dot = Path()
                dot.addEllipse(in: CGRect(x: pt.x - 1.1, y: pt.y - 1.1, width: 2.2, height: 2.2))
                ctx.fill(dot, with: .color(cyan))
            }

            // 3. 上方极光穹顶骨架 (14 根双色拱肋，半径加大至 38*s ~ 44*s)
            let count3 = 14
            let startA = -Double.pi * 0.96
            let endA = -Double.pi * 0.04
            var strutTips: [CGPoint] = []
            var midPoints: [CGPoint] = []

            for i in 0..<count3 {
                let frac = Double(i) / Double(count3 - 1)
                let a = startA + frac * (endA - startA)
                let r: CGFloat = (34.0 + CGFloat(sin(frac * Double.pi)) * 8.0) * CGFloat(b) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                strutTips.append(pt)

                let midPt = CGPoint(x: c.x + CGFloat(cos(a)) * (r * 0.58), y: c.y + CGFloat(sin(a)) * (r * 0.58))
                midPoints.append(midPt)

                var ray = Path()
                ray.move(to: c)
                ray.addLine(to: pt)
                ctx.stroke(ray, with: .color(peachTan), lineWidth: 0.78)

                let nodeColor = (i % 2 == 0) ? cyan : peachTan
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: nodeColor, coreColor: darkStem, r: 2.8 * min(s, 1.35))
            }

            // 4. 双层穹顶互锁拱环 (Dual Scalloped Web Arches)
            for i in 0..<(strutTips.count - 1) {
                // 外层拱环
                var archOuter = Path()
                archOuter.move(to: strutTips[i])
                let midX = (strutTips[i].x + strutTips[i + 1].x) * 0.5
                let midY = (strutTips[i].y + strutTips[i + 1].y) * 0.5
                let pullOuter = CGPoint(x: (midX + c.x) * 0.5, y: (midY + c.y) * 0.5)
                archOuter.addQuadCurve(to: strutTips[i + 1], control: pullOuter)
                ctx.stroke(archOuter, with: .color(peachTan.opacity(0.65)), lineWidth: 0.55)

                // 中层同心连接线
                var archInner = Path()
                archInner.move(to: midPoints[i])
                archInner.addLine(to: midPoints[i + 1])
                ctx.stroke(archInner, with: .color(cyan.opacity(0.50)), lineWidth: 0.50)
            }

            // 5. 核心宝珠中心
            var hub = Path()
            let hubR: CGFloat = 3.6 * min(s, 1.35)
            hub.addEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2))
            ctx.fill(hub, with: .color(peachTan))
            ctx.stroke(hub, with: .color(darkStem), lineWidth: 0.75)
            return
        }

        // Stage 4: 极盛双色极光穹顶与星流花瀑 (Full Radiance Grand Aurora Chandelier)
        // 相比 10-3 更加奢华绚丽：底部放射雨丝成倍加密、顶部 18 根极光骨架与三重同心连拱、蓝色节点环绕呼吸状暖金橙辉光
        let crownTopY4 = c.y - 42.0 * CGFloat(b) * s
        let amberGold = Color(red: 0.96, green: 0.70, blue: 0.22)
        let softAmber = Color(red: 0.98, green: 0.82, blue: 0.36)

        // 1. 多层漫射极光星云 (Nebula Glow Blobs & Radial Rings)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 6 * s, y: c.y - 14 * s), color: cyan, rx: 44 * s, ry: 36 * s, opacity: 0.52)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y + 10 * s), color: peachTan, rx: 36 * s, ry: 30 * s, opacity: 0.42)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 8 * s), color: amberGold, rx: 24 * s, ry: 20 * s, opacity: 0.30)
        drawHaloRings(ctx: ctx, c: CGPoint(x: c.x, y: c.y - 6 * s), maxR: 48 * s, count: 4, phase: phase)

        // 2. 冠顶 5 重浮动极光线条与游动星尘
        drawFloatingAuraLines(ctx: ctx, c: c, s: s, phase: phase, colors: [cyan, peachTan, amberGold], crownTopY: crownTopY4)

        // 3. 底部多层极盛放射雨丝流苏瀑布 (56 根高密放射流线：短层、中层与曳地长丝)
        // 3.1 内层高密柔光雨丝 (24 根)
        let innerStreamCount = 24
        for i in 0..<innerStreamCount {
            let frac = Double(i) / Double(innerStreamCount - 1)
            let a = Double.pi * 0.14 + frac * Double.pi * 0.72
            let wave = sin(phase * 2.8 + Double(i) * 0.5) * 2.5
            let len: CGFloat = (18.0 + CGFloat(sin(Double(i) * 0.9)) * 6.0 + CGFloat(wave)) * CGFloat(b) * s
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * len, y: c.y + CGFloat(sin(a)) * len)

            var ray = Path()
            ray.move(to: c)
            let ctrl = CGPoint(x: c.x + CGFloat(cos(a + 0.12)) * (len * 0.48), y: c.y + CGFloat(sin(a + 0.12)) * (len * 0.48))
            ray.addQuadCurve(to: pt, control: ctrl)
            ctx.stroke(ray, with: .color(cyan.opacity(0.65)), lineWidth: 0.48)

            var dot = Path()
            dot.addEllipse(in: CGRect(x: pt.x - 0.9, y: pt.y - 0.9, width: 1.8, height: 1.8))
            ctx.fill(dot, with: .color(cyan.opacity(0.85)))
        }

        // 3.2 主体外层长垂瀑流苏 (32 根)
        let streamCount4 = 32
        for i in 0..<streamCount4 {
            let frac = Double(i) / Double(streamCount4 - 1)
            let a = Double.pi * 0.06 + frac * Double.pi * 0.88
            let wave = sin(phase * 3.4 + Double(i) * 0.55) * 3.8
            let isLong = (i % 3 == 0)
            let baseLen: CGFloat = isLong ? 32.0 : 24.0
            let len: CGFloat = (baseLen + CGFloat(sin(Double(i) * 0.72)) * 8.0 + CGFloat(wave)) * CGFloat(b) * s
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * len, y: c.y + CGFloat(sin(a)) * len)

            var ray = Path()
            ray.move(to: c)
            let ctrl = CGPoint(x: c.x + CGFloat(cos(a + (isLong ? 0.14 : 0.09))) * (len * 0.52),
                               y: c.y + CGFloat(sin(a + (isLong ? 0.14 : 0.09))) * (len * 0.52))
            ray.addQuadCurve(to: pt, control: ctrl)
            let strokeCol = (i % 2 == 0) ? cyan.opacity(0.90) : peachTan.opacity(0.78)
            ctx.stroke(ray, with: .color(strokeCol), lineWidth: isLong ? 0.65 : 0.55)

            // 垂丝末端微珠
            if isLong {
                drawTopologicalNode(ctx: ctx, pt: pt, ringColor: cyan, coreColor: darkStem, r: 1.8 * min(s, 1.35))
            } else {
                var dot = Path()
                dot.addEllipse(in: CGRect(x: pt.x - 1.1, y: pt.y - 1.1, width: 2.2, height: 2.2))
                ctx.fill(dot, with: .color(cyan))
            }
        }

        // 4. 上部宏大极光穹顶 (18 根辐射拱肋，半径扩大至 38*s ~ 46*s)
        let count4 = 18
        let startA = -Double.pi * 0.97
        let endA = -Double.pi * 0.03
        var strutTips: [CGPoint] = []
        var midTierPts: [CGPoint] = []

        for i in 0..<count4 {
            let frac = Double(i) / Double(count4 - 1)
            let a = startA + frac * (endA - startA)
            let r: CGFloat = (36.0 + CGFloat(sin(frac * Double.pi)) * 10.0) * CGFloat(b) * s
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            strutTips.append(pt)

            let midPt = CGPoint(x: c.x + CGFloat(cos(a)) * (r * 0.60), y: c.y + CGFloat(sin(a)) * (r * 0.60))
            midTierPts.append(midPt)

            var ray = Path()
            ray.move(to: c)
            ray.addLine(to: pt)
            ctx.stroke(ray, with: .color(peachTan), lineWidth: 0.82)

            // 4.1 蓝色小圆点周围加入橙黄色小辉光 (呼吸状动效)
            let glowPulse = sin(phase * 2.6 + Double(i) * 0.55) * 0.35 + 0.65 // 0.30 ~ 1.00 呼吸律动
            let amberGlowR: CGFloat = (5.5 + CGFloat(glowPulse) * 3.2) * min(s, 1.35)

            var glowOrb = Path()
            glowOrb.addEllipse(in: CGRect(x: pt.x - amberGlowR, y: pt.y - amberGlowR, width: amberGlowR * 2, height: amberGlowR * 2))
            ctx.fill(glowOrb, with: .color(amberGold.opacity(0.38 * glowPulse)))

            var amberHaloRing = Path()
            let ringR: CGFloat = (3.8 + CGFloat(glowPulse) * 1.6) * min(s, 1.35)
            amberHaloRing.addEllipse(in: CGRect(x: pt.x - ringR, y: pt.y - ringR, width: ringR * 2, height: ringR * 2))
            ctx.stroke(amberHaloRing, with: .color(softAmber.opacity(0.55 * glowPulse)), lineWidth: 0.50)

            // 4.2 中心冰青色拓扑蓝宝珠
            drawTopologicalNode(ctx: ctx, pt: pt, ringColor: cyan, coreColor: darkStem, r: 2.8 * min(s, 1.35))
        }

        // 5. 穹顶三重同心哥特交织拱环 (Triple Interlocking Gothic Arches)
        for i in 0..<(strutTips.count - 1) {
            // 外缘拱线
            var archOuter = Path()
            archOuter.move(to: strutTips[i])
            let midX = (strutTips[i].x + strutTips[i + 1].x) * 0.5
            let midY = (strutTips[i].y + strutTips[i + 1].y) * 0.5
            let pullOuter = CGPoint(x: (midX + c.x) * 0.5, y: (midY + c.y) * 0.5)
            archOuter.addQuadCurve(to: strutTips[i + 1], control: pullOuter)
            ctx.stroke(archOuter, with: .color(peachTan.opacity(0.70)), lineWidth: 0.58)

            // 中层同心花冠连线
            var archMid = Path()
            archMid.move(to: midTierPts[i])
            archMid.addLine(to: midTierPts[i + 1])
            ctx.stroke(archMid, with: .color(cyan.opacity(0.55)), lineWidth: 0.50)
        }

        // 6. 核心双色同心几何宝珠 (Concentric Crown Jewel Hub)
        var outerHub = Path()
        let oHubR: CGFloat = 5.2 * min(s, 1.35)
        outerHub.addEllipse(in: CGRect(x: c.x - oHubR, y: c.y - oHubR, width: oHubR * 2, height: oHubR * 2))
        ctx.fill(outerHub, with: .color(peachTan.opacity(0.60)))
        ctx.stroke(outerHub, with: .color(amberGold), lineWidth: 0.65)

        var hub = Path()
        let hubR: CGFloat = 3.6 * min(s, 1.35)
        hub.addEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2))
        ctx.fill(hub, with: .color(cyan))
        ctx.stroke(hub, with: .color(darkStem), lineWidth: 0.75)
    }
    // MARK: - 11. 经纬金晕葱 (Cosmos / Multi-Axis Armillary Torus & Cosmic Core)
    // =========================================================================
    private func renderSpecies11(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let violet = Color(red: 0.52, green: 0.28, blue: 0.68)
        let chartreuse = Color(red: 0.78, green: 0.88, blue: 0.40)
        let peach = Color(red: 0.92, green: 0.65, blue: 0.45)
        let darkStem = Color(red: 0.25, green: 0.18, blue: 0.28)

        if p < 0.25 {
            drawHaloRings(ctx: ctx, c: c, maxR: 26 * s, count: 3, phase: phase)
            let pt = CGPoint(x: c.x, y: c.y - 14 * s)
            drawTopologicalNode(ctx: ctx, pt: pt, ringColor: violet, coreColor: chartreuse, r: 2.2 * min(s, 1.35))
            return
        }

        if p < 0.50 {
            drawHaloRings(ctx: ctx, c: c, maxR: 36 * s, count: 4, phase: phase)
            drawGlowBlob(ctx: ctx, c: c, color: Color(red: 0.70, green: 0.60, blue: 0.85), rx: 26 * s, ry: 24 * s, opacity: 0.35)

            let sphereR: CGFloat = 16.0 * CGFloat(b) * s
            var sphereOutline = Path()
            sphereOutline.addEllipse(in: CGRect(x: c.x - sphereR, y: c.y - sphereR, width: sphereR * 2, height: sphereR * 2))
            ctx.fill(sphereOutline, with: .color(Color.white.opacity(0.85)))
            ctx.stroke(sphereOutline, with: .color(darkStem), lineWidth: 0.70)

            for ryFactor in [0.35, 0.70] {
                let ry = sphereR * CGFloat(ryFactor)
                var lat = Path()
                lat.addEllipse(in: CGRect(x: c.x - sphereR, y: c.y - ry, width: sphereR * 2, height: ry * 2))
                ctx.stroke(lat, with: .color(darkStem.opacity(0.65)), lineWidth: 0.55)
            }

            let rot = phase * 0.6
            for lonOffset in [0.0, Double.pi / 3.0, Double.pi * 2.0 / 3.0] {
                let currentAngle = lonOffset + rot
                let rxFactor = abs(cos(currentAngle))
                let rx = max(1.0, sphereR * CGFloat(rxFactor))
                var lon = Path()
                lon.addEllipse(in: CGRect(x: c.x - rx, y: c.y - sphereR, width: rx * 2, height: sphereR * 2))
                ctx.stroke(lon, with: .color(darkStem.opacity(0.65)), lineWidth: 0.55)
            }

            for lonOffset in [0.0, Double.pi / 3.0, Double.pi * 2.0 / 3.0] {
                let currentAngle = lonOffset + rot
                let x = c.x + CGFloat(cos(currentAngle)) * sphereR * 0.95
                let y = c.y
                var dot = Path()
                dot.addEllipse(in: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4))
                ctx.fill(dot, with: .color(chartreuse))
            }
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: c, color: violet, rx: 28 * s, ry: 24 * s, opacity: 0.40)
            let r: CGFloat = 24.0 * CGFloat(b) * s
            var ring1 = Path()
            ring1.addEllipse(in: CGRect(x: c.x - r, y: c.y - r * 0.5, width: r * 2, height: r))
            ctx.stroke(ring1, with: .color(darkStem), lineWidth: 0.65)

            var ring2 = Path()
            ring2.addEllipse(in: CGRect(x: c.x - r * 0.5, y: c.y - r, width: r, height: r * 2))
            ctx.stroke(ring2, with: .color(darkStem), lineWidth: 0.65)
            return
        }

        // Stage 4: 渐变多层次分色光晕系统 (明金嫩黄 -> 蜜桃珊瑚 -> 宇宙紫罗兰 -> 碧青星云雾) + 浑天仪透视轨道环
        let cyanMist = Color(red: 0.38, green: 0.72, blue: 0.86)
        let glowTiers: [(color: Color, rx: CGFloat, ry: CGFloat, opacity: Double)] = [
            (color: chartreuse, rx: 18 * s, ry: 18 * s, opacity: 0.60),
            (color: peach, rx: 30 * s, ry: 28 * s, opacity: 0.48),
            (color: violet, rx: 44 * s, ry: 40 * s, opacity: 0.38),
            (color: cyanMist, rx: 56 * s, ry: 50 * s, opacity: 0.22)
        ]
        let glowRings: [(color: Color, r: CGFloat, lineWidth: CGFloat)] = [
            (color: chartreuse.opacity(0.52), r: 16 * s, lineWidth: 0.60),
            (color: peach.opacity(0.42), r: 28 * s, lineWidth: 0.55),
            (color: violet.opacity(0.34), r: 42 * s, lineWidth: 0.50),
            (color: cyanMist.opacity(0.24), r: 54 * s, lineWidth: 0.45)
        ]
        drawLayeredChromaticHalo(ctx: ctx, c: c, tiers: glowTiers, rings: glowRings, phase: phase)

        let armillaryR: CGFloat = 32.0 * CGFloat(b) * s
        let ringRot = phase * 0.45

        for i in 0..<8 {
            let a = Double(i) / 8.0 * Double.pi * 2.0 + ringRot
            let orbX = c.x + CGFloat(cos(a)) * armillaryR
            let orbY = c.y + CGFloat(sin(a)) * (armillaryR * 0.5)
            drawTopologicalNode(ctx: ctx, pt: CGPoint(x: orbX, y: orbY), ringColor: (i % 2 == 0) ? chartreuse : peach, coreColor: darkStem, r: 2.6 * min(s, 1.35))
        }

        // 10-4 下部流线装饰复刻为 360° 中心高密放射流线星冠 (Centered Streamer Crown)
        let centerStreamCount = 32
        for i in 0..<centerStreamCount {
            let frac = Double(i) / Double(centerStreamCount)
            let a = frac * Double.pi * 2.0
            let wave = sin(phase * 3.0 + Double(i) * 0.6) * 3.0
            let len: CGFloat = (16.0 + CGFloat(sin(Double(i) * 0.7)) * 5.0 + CGFloat(wave)) * CGFloat(b) * min(s, 1.40)
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * len, y: c.y + CGFloat(sin(a)) * len)

            var ray = Path()
            ray.move(to: c)
            let ctrl = CGPoint(
                x: c.x + CGFloat(cos(a + 0.12)) * (len * 0.52),
                y: c.y + CGFloat(sin(a + 0.12)) * (len * 0.52)
            )
            ray.addQuadCurve(to: pt, control: ctrl)
            let rayColor = (i % 2 == 0) ? chartreuse.opacity(0.85) : peach.opacity(0.85)
            ctx.stroke(ray, with: .color(rayColor), lineWidth: 0.55)

            var dot = Path()
            let dotColor = (i % 2 == 0) ? chartreuse : violet
            dot.addEllipse(in: CGRect(x: pt.x - 1.2, y: pt.y - 1.2, width: 2.4, height: 2.4))
            ctx.fill(dot, with: .color(dotColor))
        }

        var core = Path()
        let coreR: CGFloat = 6.0 * min(s, 1.35)
        core.addEllipse(in: CGRect(x: c.x - coreR, y: c.y - coreR, width: coreR * 2, height: coreR * 2))
        ctx.fill(core, with: .color(Color(red: 0.88, green: 0.82, blue: 0.96)))
        ctx.stroke(core, with: .color(darkStem), lineWidth: 0.8)
    }

    // =========================================================================
    // MARK: - 12. 极夜十二星 (NightJasmine / Asymmetrical Shards & Eccentric Nebula)
    // =========================================================================
    private func renderSpecies12(ctx: GraphicsContext, c: CGPoint, pal: PosyPalette, p: Double, b: Double, phase: Double, s: CGFloat) {
        let cobalt = Color(red: 0.22, green: 0.38, blue: 0.75)
        let plum = Color(red: 0.55, green: 0.25, blue: 0.48)
        let coralPeach = Color(red: 0.94, green: 0.55, blue: 0.45)
        let darkStem = Color(red: 0.22, green: 0.20, blue: 0.28)

        if p < 0.25 {
            drawHaloRings(ctx: ctx, c: c, maxR: 26 * s, count: 3, phase: phase)
            drawTopologicalNode(ctx: ctx, pt: CGPoint(x: c.x, y: c.y - 12 * s), ringColor: plum, coreColor: darkStem, r: 2.2 * min(s, 1.35))
            let beePt = CGPoint(x: c.x + 18 * s, y: c.y - 20 * s)
            drawLittleBee(ctx: ctx, pt: beePt, phase: phase)
            return
        }

        if p < 0.50 {
            drawGlowBlob(ctx: ctx, c: c, color: coralPeach, rx: 22 * s, ry: 20 * s, opacity: 0.35)
            let starPts = 8
            var star = Path()
            for i in 0..<(starPts * 2) {
                let a = Double(i) / Double(starPts * 2) * Double.pi * 2.0 - Double.pi / 2.0
                let rCur: CGFloat = (i % 2 == 0 ? 20.0 : 8.0) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rCur, y: c.y + CGFloat(sin(a)) * rCur)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            ctx.fill(star, with: .color(plum.opacity(0.80)))
            ctx.stroke(star, with: .color(darkStem), lineWidth: 0.65)
            return
        }

        if p < 0.75 {
            drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 8 * s, y: c.y - 8 * s), color: coralPeach, rx: 28 * s, ry: 24 * s, opacity: 0.42)
            let starPts = 12
            var star = Path()
            for i in 0..<(starPts * 2) {
                let a = Double(i) / Double(starPts * 2) * Double.pi * 2.0 - Double.pi / 2.0
                let rCur: CGFloat = (i % 2 == 0 ? 26.0 : 12.0) * s
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rCur, y: c.y + CGFloat(sin(a)) * rCur)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            ctx.fill(star, with: .color(cobalt.opacity(0.85)))
            ctx.stroke(star, with: .color(darkStem), lineWidth: 0.65)
            return
        }

        // Stage 4
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x + 10 * s, y: c.y - 12 * s), color: coralPeach, rx: 38 * s, ry: 30 * s, opacity: 0.52)
        drawGlowBlob(ctx: ctx, c: CGPoint(x: c.x - 8 * s, y: c.y + 6 * s), color: cobalt, rx: 30 * s, ry: 24 * s, opacity: 0.38)
        drawHaloRings(ctx: ctx, c: c, maxR: 44 * s, count: 3, phase: phase)

        let starPoints = 12
        var star = Path()
        for i in 0..<(starPoints * 2) {
            let a = Double(i) / Double(starPoints * 2) * Double.pi * 2.0 - Double.pi / 2.0
            let isMajor = (i % 4 == 0)
            let rOuter: CGFloat = (isMajor ? 38.0 : 28.0) * CGFloat(b) * s
            let rInner: CGFloat = 16.0 * CGFloat(b) * s
            let rCur = (i % 2 == 0) ? rOuter : rInner
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rCur, y: c.y + CGFloat(sin(a)) * rCur)
            if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        ctx.fill(star, with: .color(cobalt))
        ctx.stroke(star, with: .color(darkStem), lineWidth: 0.65)

        var blueDisc = Path()
        let bDiscR: CGFloat = 11.0 * min(s, 1.35)
        blueDisc.addEllipse(in: CGRect(x: c.x - bDiscR, y: c.y - bDiscR, width: bDiscR * 2, height: bDiscR * 2))
        ctx.fill(blueDisc, with: .color(cobalt.opacity(0.92)))
        ctx.stroke(blueDisc, with: .color(Color.white.opacity(0.85)), lineWidth: 0.60)

        let beadRot = -phase * 0.25
        for i in 0..<12 {
            let a = Double(i) / 12.0 * Double.pi * 2.0 + beadRot
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * 14.0 * s, y: c.y + CGFloat(sin(a)) * 14.0 * s)
            var bead = Path()
            bead.addEllipse(in: CGRect(x: pt.x - 1.2, y: pt.y - 1.2, width: 2.4, height: 2.4))
            ctx.fill(bead, with: .color(Color(red: 0.96, green: 0.86, blue: 0.58)))
        }
    }
}
