import SwiftUI
import UIKit

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
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
        } else {
            colorTheme.canvas
        }
    }
}

// 两套配色共用四颗光球的尺寸、沿边路径和碰边变形，只替换色板。
private struct CanvasLiquidBackground: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var animationStartTime = Date.timeIntervalSinceReferenceDate
    @State private var collisionPathSeed = Double.random(in: -100_000...100_000)
    let reduceMotion: Bool
    let colorTheme: HabitColorTheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 45, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : max(0, timeline.date.timeIntervalSinceReferenceDate - animationStartTime)

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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                animationStartTime = Date.timeIntervalSinceReferenceDate
            }
        }
    }

    private func drawFluidSpheres(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let minDim = min(size.width, size.height)
        let largeOrbTime = time * 1.25

        // 以可见色域为基准重置尺寸；保持底层两球原有的大小比例。
        let breath = 1 + 0.025 * sin(largeOrbTime * 0.24)
        let baseLargeOrbRadius = minDim * 1.18 * 0.70 * 1.25 * 0.85 * 1.15 * 0.85 * 1.15 * 1.05 * breath
        let baseSmallOrbRadius = baseLargeOrbRadius * (3.5 / 6.5)
        let floatingSmallOrb1Radius = minDim * 0.25 * 0.65 * 0.75
        let floatingSmallOrb2Radius = minDim * 0.15 * 0.65 * 0.75
        let largeOrbMotion = pairedMotion(size: size, radius: baseLargeOrbRadius, time: largeOrbTime, index: 0)
        let smallOrbMotion = pairedMotion(size: size, radius: baseSmallOrbRadius, time: largeOrbTime, index: 1)
        let floatingSmallOrb1Motion = wanderingMotion(size: size, radius: floatingSmallOrb1Radius, time: time, index: 2, period: 31)
        let floatingSmallOrb2Motion = wanderingMotion(size: size, radius: floatingSmallOrb2Radius, time: time, index: 3, period: 37)
        let extraSmallOrb1Radius = floatingSmallOrb1Radius * 0.60
        let extraSmallOrb2Radius = floatingSmallOrb2Radius * 0.60
        let extraSmallOrb1Motion = wanderingMotion(size: size, radius: extraSmallOrb1Radius, time: time, index: 4, period: 41)
        let extraSmallOrb2Motion = wanderingMotion(size: size, radius: extraSmallOrb2Radius, time: time, index: 5, period: 47)
        let collisionOrbRadius = floatingSmallOrb2Radius * 0.60
        let collisionOrb1Motion = collidingFloatingMotion(size: size, time: time, index: 0, radius: collisionOrbRadius)
        let collisionOrb2Motion = collidingFloatingMotion(size: size, time: time, index: 1, radius: collisionOrbRadius)

        let orbStops = colorTheme.floatingOrbSpherePalettes
        let elapsed = largeOrbTime.truncatingRemainder(dividingBy: 68.5)
        // 碰撞时两球只交换尺寸，颜色始终固定在各自的光球上。
        let sizeExchangeIn = reduceMotion ? 0 : smoothStep((elapsed - 12) / 6)
        let sizeExchangeOut = reduceMotion ? 0 : smoothStep((elapsed - 39.25) / 6)
        let sizeExchange = sizeExchangeIn * (1 - sizeExchangeOut)
        let largeOrbRadius = baseLargeOrbRadius * (1 - sizeExchange) + baseSmallOrbRadius * sizeExchange
        let smallOrbRadius = baseSmallOrbRadius * (1 - sizeExchange) + baseLargeOrbRadius * sizeExchange
        // 深紫球保持更集中的紫色色域，减少浅紫混入，并移除压暗处理。
        let largePalette = (colorTheme == .original ? orbStops.large : [
            colorTheme.accent,
            colorTheme.accent.mix(with: colorTheme.companion, by: 0.12),
            colorTheme.accent.mix(with: colorTheme.companion, by: 0.28)
        ]).map { adjustedSaturation($0, increase: 0.10) }
        let smallPalette = (colorTheme == .original ? orbStops.small : orbStops.small.map {
            adjustedSaturation(adjustedSaturation($0.mix(with: .black, by: 0.12), increase: 0.10), increase: -0.05)
        }).map { adjustedSaturation($0, increase: 0.10) }
        let largeColors = zip(largePalette, [1.0, 0.88, 0.38]).map { $0.0.opacity($0.1) }
            + [(largePalette.last ?? .clear).opacity(0)]
        let smallColors = zip(smallPalette, [1.0, 0.86, 0.36]).map { $0.0.opacity($0.1) }
            + [(smallPalette.last ?? .clear).opacity(0)]
        context.drawLayer { layer in
            drawAdhesion(in: &layer, size: size, time: largeOrbTime,
                         first: largeOrbMotion.center, second: smallOrbMotion.center,
                         colors: [largePalette[0], smallPalette[0]])
            drawSphere(in: &layer, motion: largeOrbMotion, bounds: size, radius: largeOrbRadius,
                       blurRadius: 38.4, time: largeOrbTime, phase: 0,
                       colors: largeColors, isVolumetric: true, hasCenterHighlight: true)
            drawSphere(in: &layer, motion: smallOrbMotion, bounds: size, radius: smallOrbRadius,
                       blurRadius: 38.4, time: largeOrbTime, phase: .pi,
                       colors: smallColors, isVolumetric: true)
            // 留白由球体尺寸及路径产生，不再额外挖空背景色域。
        }

        // 两组漂浮小光球单独绘制在主光球上层，阴影先于球体绘制。
        var accentContext = context
        accentContext.opacity = 0.75
        drawFloatingOrb(in: &accentContext, bounds: size, motion: floatingSmallOrb1Motion,
                        radius: floatingSmallOrb1Radius, time: time, phase: 0.8,
                        color: colorTheme.floatingSmallOrb1Color, coreOpacity: 0.55, middleOpacity: 0.78,
                        brightness: 0, saturationIncrease: 0.15,
                        shadowBlur: 22, shadowOpacity: 0.22)
        drawFloatingOrb(in: &accentContext, bounds: size, motion: floatingSmallOrb2Motion,
                        radius: floatingSmallOrb2Radius, time: time, phase: 2.1,
                        color: colorTheme.floatingSmallOrb2Color, coreOpacity: 0.65, middleOpacity: 0.72,
                        brightness: 0, saturationIncrease: 0.15,
                        shadowBlur: 22, shadowOpacity: 0.22)
        // 复制组的阴影模糊和深度均比原组高 50%，亮度遮罩为 30%。
        drawFloatingOrb(in: &accentContext, bounds: size, motion: extraSmallOrb1Motion,
                        radius: extraSmallOrb1Radius, time: time, phase: 3.4,
                        color: colorTheme.floatingSmallOrb1Color, coreOpacity: 0.55, middleOpacity: 0.78,
                        brightness: 0.30, saturationIncrease: 0,
                        shadowBlur: 33, shadowOpacity: 0.33)
        drawFloatingOrb(in: &accentContext, bounds: size, motion: extraSmallOrb2Motion,
                        radius: extraSmallOrb2Radius, time: time, phase: 4.7,
                        color: colorTheme.floatingSmallOrb2Color, coreOpacity: 0.65, middleOpacity: 0.72,
                        brightness: 0.30, saturationIncrease: 0,
                        shadowBlur: 33, shadowOpacity: 0.33)
        var collisionOrbContext = accentContext
        collisionOrbContext.opacity *= 0.75
        let lightOrb1 = colorTheme.floatingSmallOrb1Color
        let lightOrb2 = colorTheme.floatingSmallOrb2Color
        drawFloatingOrb(in: &collisionOrbContext, bounds: size, motion: collisionOrb1Motion,
                        radius: collisionOrbRadius, time: time, phase: 5.6,
                        color: lightOrb1, coreOpacity: 0.60, middleOpacity: 0.78,
                        brightness: 0, saturationIncrease: 0,
                        shadowBlur: 16, shadowOpacity: 0.14)
        drawFloatingOrb(in: &collisionOrbContext, bounds: size, motion: collisionOrb2Motion,
                        radius: collisionOrbRadius, time: time, phase: 6.8,
                        color: lightOrb2, coreOpacity: 0.60, middleOpacity: 0.78,
                        brightness: 0, saturationIncrease: 0,
                        shadowBlur: 16, shadowOpacity: 0.14)
    }

    private func drawFloatingOrb(in context: inout GraphicsContext, bounds: CGSize,
                                 motion: OrbMotion, radius: CGFloat, time: TimeInterval,
                                 phase: Double, color: Color, coreOpacity: Double,
                                 middleOpacity: Double, brightness: Double,
                                 saturationIncrease: CGFloat,
                                 shadowBlur: CGFloat, shadowOpacity: Double) {
        var shadowContext = context
        shadowContext.opacity *= motion.opacity
        shadowContext.addFilter(.blur(radius: shadowBlur * (1 + motion.blurExpansion)))
        let shadowCenter = CGPoint(x: motion.center.x + radius * 0.12,
                                   y: motion.center.y + radius * 0.25)
        let shadowPath = Path(ellipseIn: CGRect(x: shadowCenter.x - radius,
                                               y: shadowCenter.y - radius * 0.70,
                                               width: radius * 2, height: radius * 1.40))
        shadowContext.fill(shadowPath, with: .radialGradient(
            Gradient(colors: [.black.opacity(shadowOpacity), .clear]),
            center: shadowCenter, startRadius: 0, endRadius: radius))

        let saturatedColor = adjustedSaturation(color, increase: saturationIncrease)
        let litColor = brightness >= 0
            ? saturatedColor.mix(with: .white, by: brightness)
            : saturatedColor.mix(with: .black, by: -brightness)
        drawSphere(in: &context, motion: motion, bounds: bounds, radius: radius,
                   blurRadius: 12, time: time, phase: phase,
                   colors: [litColor.opacity(coreOpacity),
                            litColor.opacity(middleOpacity), litColor.opacity(0)])
    }

    private func adjustedSaturation(_ color: Color, increase: CGFloat) -> Color {
        guard increase != 0 else { return color }
        let source = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard source.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return color
        }
        return Color(uiColor: UIColor(hue: hue,
                                      saturation: min(1, saturation * (1 + increase)),
                                      brightness: brightness,
                                      alpha: alpha))
    }

    private struct OrbMotion {
        var center: CGPoint
        var scale: CGSize = CGSize(width: 1, height: 1)
        var angle: Double = 0
        var pressure: Double = 0
        var opacity: Double = 1
        var blurExpansion: Double = 0
    }

    // 按轮次固定随机值，逐帧只插值；随机改向不会抖动或因切换配色重置。
    private func variation(_ cycle: Double, _ salt: Double) -> Double {
        let value = sin(cycle * 127.1 + salt * 311.7) * 43758.5453
        return value - floor(value)
    }

    private func destination(size: CGSize, radius: CGFloat, cycle: Double, index: Int) -> (CGPoint, Int) {
        // 漂浮小光球每轮随机选择不同于上一轮的边，并随机选择沿边落点。
        let edgeSalt = Double(index + 71)
        let previousEdge = min(3, Int(variation(cycle - 1, edgeSalt) * 4))
        let randomAlternative = min(2, Int(variation(cycle, edgeSalt) * 3))
        let edge = randomAlternative >= previousEdge ? randomAlternative + 1 : randomAlternative
        let along = 0.28 + 0.44 * variation(cycle, Double(index + 11))
        let inset = min(radius * 0.78, min(size.width, size.height) * 0.30)
        switch edge {
        case 0: return (CGPoint(x: size.width - inset, y: size.height * along), edge)
        case 1: return (CGPoint(x: size.width * along, y: size.height - inset), edge)
        case 2: return (CGPoint(x: inset, y: size.height * along), edge)
        default: return (CGPoint(x: size.width * along, y: inset), edge)
        }
    }

    /// 68.5 秒：先沿左下—右上交叉，再沿左上—右下交叉，沿边衔接成连续循环。
    private func pairedMotion(size: CGSize, radius: CGFloat, time: TimeInterval, index: Int) -> OrbMotion {
        let elapsed = time.truncatingRemainder(dividingBy: 68.5)
        let first = index == 0
        // 活动范围总尺寸为屏幕的 105%，四边各外扩 2.5%；按外轮廓接触边界定位球心。
        let edgeInset = min(radius, min(size.width, size.height) * 0.48)
        let horizontalOverflow = size.width * 0.025
        let verticalOverflow = size.height * 0.025
        let leftLimit = edgeInset - horizontalOverflow
        let rightLimit = size.width - edgeInset + horizontalOverflow
        let topLimit = edgeInset - verticalOverflow
        let bottomLimit = size.height - edgeInset + verticalOverflow
        let start = CGPoint(x: size.width * (first ? 0.16 : 0.84),
                            y: size.height * (first ? 0.84 : 0.16))
        let firstMeeting = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let opposite = CGPoint(x: size.width - start.x, y: size.height - start.y)
        let nextDiagonalStart = CGPoint(x: start.x, y: opposite.y)
        let nextDiagonalEnd = CGPoint(x: opposite.x, y: start.y)
        let secondMeeting = firstMeeting
        if reduceMotion { return OrbMotion(center: start) }
        var motion: OrbMotion
        if elapsed < 14 {
            motion = mainTravel(from: start, to: firstMeeting, progress: elapsed / 14)
        } else if elapsed < 15.25 {
            motion = OrbMotion(center: firstMeeting)
        } else if elapsed < 27.25 {
            motion = mainTravel(from: firstMeeting, to: opposite, progress: (elapsed - 15.25) / 12)
        } else if elapsed < 31.25 {
            motion = mainTravel(from: opposite, to: nextDiagonalStart, progress: (elapsed - 27.25) / 4)
        } else if elapsed < 41.25 {
            motion = mainTravel(from: nextDiagonalStart, to: secondMeeting, progress: (elapsed - 31.25) / 10)
        } else if elapsed < 42.5 {
            motion = OrbMotion(center: secondMeeting)
        } else if elapsed < 64.5 {
            motion = mainTravel(from: secondMeeting, to: nextDiagonalEnd, progress: (elapsed - 42.5) / 22)
        } else {
            motion = mainTravel(from: nextDiagonalEnd, to: start, progress: (elapsed - 64.5) / 4)
        }
        // 每次完成尺寸交换后，产生向外扩张并逐拍衰减的明显余波。
        let firstRipple = ripplePulse(elapsed - 18)
        let secondRipple = ripplePulse(elapsed - 45.25)
        let ripple = firstRipple + secondRipple
        if abs(ripple) > 0.001 {
            let impactCenter = firstRipple != 0 ? firstMeeting : secondMeeting
            let dx = motion.center.x - impactCenter.x
            let dy = motion.center.y - impactCenter.y
            let distance = max(hypot(dx, dy), 1)
            let displacement = min(size.width, size.height) * ripple * 0.045
            motion.center.x += dx / distance * displacement
            motion.center.y += dy / distance * displacement
            motion.scale.width *= 1 + ripple
            motion.scale.height *= 1 + ripple * 0.72
        }
        // 球心按当前半径内缩至 110% 活动范围的边缘，外轮廓接触边界后反弹。
        motion.center = CGPoint(x: min(max(motion.center.x, leftLimit), rightLimit),
                                y: min(max(motion.center.y, topLimit), bottomLimit))
        return motion
    }

    private func ripplePulse(_ elapsed: Double) -> Double {
        guard elapsed >= 0, elapsed < 3.5 else { return 0 }
        return 0.08 * sin(elapsed * .pi * 2 * 1.25) * exp(-elapsed * 1.05)
    }

    private func mainTravel(from start: CGPoint, to end: CGPoint, progress: Double) -> OrbMotion {
        let t = smoothStep(progress)
        let center = CGPoint(x: start.x + (end.x - start.x) * t,
                             y: start.y + (end.y - start.y) * t)
        let stretch = 1 + 0.025 * sin(.pi * progress)
        return OrbMotion(center: center,
                         scale: CGSize(width: stretch, height: 1 / stretch),
                         angle: atan2(end.y - start.y, end.x - start.x))
    }

    private func drawAdhesion(in context: inout GraphicsContext, size: CGSize, time: TimeInterval,
                              first: CGPoint, second: CGPoint, colors: [Color]) {
        guard !reduceMotion else { return }
        let elapsed = time.truncatingRemainder(dividingBy: 68.5)
        let firstContact = smoothStep((elapsed - 10) / 3) * (1 - smoothStep((elapsed - 15.25) / 4))
        let secondContact = smoothStep((elapsed - 39.25) / 3) * (1 - smoothStep((elapsed - 42.5) / 4))
        let strength = max(firstContact, secondContact)
        guard strength > 0.001 else { return }
        let dx = second.x - first.x
        let dy = second.y - first.y
        let distance = max(hypot(dx, dy), 1)
        let neck = min(size.width, size.height) * 0.18 * strength
        let normal = CGVector(dx: -dy / distance * neck, dy: dx / distance * neck)
        let mid = CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        var bridge = Path()
        bridge.move(to: CGPoint(x: first.x + normal.dx, y: first.y + normal.dy))
        bridge.addCurve(to: CGPoint(x: second.x + normal.dx, y: second.y + normal.dy),
                        control1: CGPoint(x: mid.x + normal.dx * 0.15, y: mid.y + normal.dy * 0.15),
                        control2: CGPoint(x: mid.x + normal.dx * 0.15, y: mid.y + normal.dy * 0.15))
        bridge.addLine(to: CGPoint(x: second.x - normal.dx, y: second.y - normal.dy))
        bridge.addCurve(to: CGPoint(x: first.x - normal.dx, y: first.y - normal.dy),
                        control1: CGPoint(x: mid.x - normal.dx * 0.15, y: mid.y - normal.dy * 0.15),
                        control2: CGPoint(x: mid.x - normal.dx * 0.15, y: mid.y - normal.dy * 0.15))
        bridge.closeSubpath()
        var liquid = context
        liquid.opacity = strength * 0.42
        liquid.addFilter(.blur(radius: 24))
        liquid.fill(bridge, with: .linearGradient(Gradient(colors: colors), startPoint: first, endPoint: second))

        // 分离时保留一缕纤细的高光拉丝，随连接强度同步收回。
        var filament = Path()
        filament.move(to: first)
        filament.addQuadCurve(to: second, control: CGPoint(x: mid.x + normal.dx, y: mid.y + normal.dy))
        var filamentContext = context
        filamentContext.opacity = strength * 0.55
        filamentContext.addFilter(.blur(radius: 9))
        let filamentColors = colors.map { $0.mix(with: .white, by: 0.38) }
        filamentContext.stroke(filament,
                               with: .linearGradient(Gradient(colors: filamentColors), startPoint: first, endPoint: second),
                               style: StrokeStyle(lineWidth: max(2, min(size.width, size.height) * 0.012 * strength),
                                                  lineCap: .round))
    }

    private func wanderingMotion(size: CGSize, radius: CGFloat, time: TimeInterval, index: Int, period: Double) -> OrbMotion {
        let floatingTime = time * 1.30
        let cycle = floor(floatingTime / period)
        let progress = (floatingTime - cycle * period) / period
        let start = destination(size: size, radius: radius, cycle: cycle - 1, index: index).0
        let end = destination(size: size, radius: radius, cycle: cycle, index: index).0
        if reduceMotion { return OrbMotion(center: end) }
        // 不在边缘停留受压，抵达后直接进入下一条四散路径。
        return travelMotion(from: start, to: end, progress: progress,
                            cycle: cycle, salt: Double(index + 50), size: size)
    }

    private func collidingFloatingMotion(size: CGSize, time: TimeInterval, index: Int, radius: CGFloat) -> OrbMotion {
        let cycleDuration = 12.0
        let scaledTime = time * 1.69
        let cycle = floor(scaledTime / cycleDuration)
        let progress = (scaledTime - cycle * cycleDuration) / cycleDuration
        if reduceMotion {
            return OrbMotion(center: randomCollisionConfig(size: size, cycle: cycle).center)
        }

        let previous = randomCollisionConfig(size: size, cycle: cycle - 1)
        let current = randomCollisionConfig(size: size, cycle: cycle)
        let sign: CGFloat = index == 0 ? -1 : 1
        let start = collisionPoint(previous.center, angle: previous.exitAngle,
                                   distance: previous.travelDistance, sign: sign)
        let approachPoint = collisionPoint(current.center, angle: current.incomingAngle,
                                           distance: radius * 0.94, sign: sign)
        let exitPoint = collisionPoint(current.center, angle: current.exitAngle,
                                       distance: current.travelDistance, sign: sign)

        let approachEnd = 0.43
        let reboundStart = 0.50
        let center: CGPoint
        let pathCycle: Double
        let pathSalt: Double
        if progress < approachEnd {
            let t = smoothStep(progress / approachEnd)
            center = randomizedBezier(from: start, to: approachPoint, progress: t,
                                      cycle: cycle, salt: Double(index + 10), size: size)
            pathCycle = cycle
            pathSalt = Double(index + 10)
        } else if progress < reboundStart {
            center = approachPoint
            pathCycle = cycle
            pathSalt = Double(index + 10)
        } else {
            let t = smoothStep((progress - reboundStart) / (1 - reboundStart))
            center = randomizedBezier(from: approachPoint, to: exitPoint, progress: t,
                                      cycle: cycle, salt: Double(index + 30), size: size)
            pathCycle = cycle
            pathSalt = Double(index + 30)
        }
        let pulse = progress >= approachEnd && progress < reboundStart
            ? sin((progress - approachEnd) / (reboundStart - approachEnd) * .pi)
            : 0
        let tangent = randomizedDirection(cycle: pathCycle, salt: pathSalt)
        return OrbMotion(center: center,
                         scale: CGSize(width: 1 + pulse * 0.18, height: 1 - pulse * 0.18),
                         angle: tangent)
    }

    private func randomCollisionConfig(size: CGSize, cycle: Double) -> (center: CGPoint, incomingAngle: Double, exitAngle: Double, travelDistance: CGFloat) {
        let x = 0.28 + randomUnit(cycle, 1) * 0.44
        let y = 0.26 + randomUnit(cycle, 2) * 0.48
        let center = CGPoint(x: size.width * x, y: size.height * y)
        let incoming = randomUnit(cycle, 3) * .pi * 2
        // 随机弹开方向至少偏离入射方向约 55°，避免连续走回同一路径。
        let turn = (0.30 + randomUnit(cycle, 4) * 0.70) * .pi
        let exit = incoming + (randomUnit(cycle, 5) < 0.5 ? -turn : turn)
        let distance = min(size.width, size.height) * CGFloat(0.24 + randomUnit(cycle, 6) * 0.12)
        return (center, incoming, exit, distance)
    }

    private func randomUnit(_ cycle: Double, _ salt: Double) -> Double {
        let value = sin((cycle + collisionPathSeed) * 127.1 + salt * 311.7) * 43758.5453
        return value - floor(value)
    }

    private func collisionPoint(_ center: CGPoint, angle: Double, distance: CGFloat, sign: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * distance * sign,
                y: center.y + sin(angle) * distance * sign)
    }

    private func randomizedDirection(cycle: Double, salt: Double) -> Double {
        randomUnit(cycle, salt + 80) * .pi * 2
    }

    private func randomizedBezier(from start: CGPoint, to end: CGPoint, progress: Double,
                                  cycle: Double, salt: Double, size: CGSize) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(hypot(dx, dy), 1)
        let bend = (randomUnit(cycle, salt + 40) - 0.5) * min(size.width, size.height) * 0.46
        let control = CGPoint(x: (start.x + end.x) * 0.5 - dy / distance * bend,
                              y: (start.y + end.y) * 0.5 + dx / distance * bend)
        return CGPoint(x: (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x,
                       y: (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y)
    }

    private func travelMotion(from start: CGPoint, to end: CGPoint, progress: Double,
                              cycle: Double, salt: Double, size: CGSize) -> OrbMotion {
        let t = smoothStep(progress)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(hypot(dx, dy), 1)
        // 大幅随机侧向弯曲，让路线在跨屏移动时也明显离开对角线。
        let bend = (variation(cycle, salt) - 0.5) * min(size.width, size.height) * 1.8
        let control = CGPoint(x: (start.x + end.x) * 0.5 - dy / distance * bend,
                              y: (start.y + end.y) * 0.5 + dx / distance * bend)
        let center = CGPoint(x: (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x,
                             y: (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y)
        let stretch = 1 + 0.035 * pow(sin(.pi * progress), 2)
        return OrbMotion(center: center, scale: CGSize(width: stretch, height: 1 / stretch), angle: atan2(dy, dx))
    }

    private func wallMotion(center: CGPoint, edge: Int, radius: CGFloat, progress: Double, isAccent: Bool) -> OrbMotion {
        // 碰边后缓慢挤压并沿边展开；漂浮小光球在受压时淡至 30%，回弹时恢复。
        let normals = [CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: -1),
                       CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1)]
        let normal = normals[edge]
        let pressure: Double
        var ripple = 0.0
        var lift = 0.0
        if progress < 0.52 {
            pressure = smoothStep(progress / 0.52)
        } else if progress < 0.68 {
            pressure = 1
        } else {
            let release = (progress - 0.68) / 0.32
            pressure = 1 - smoothStep(release / 0.40)
            // 位移与轮廓错峰：先恢复厚度，再出现两次强度递减的液态余波。
            let tail = min(max((release - 0.24) / 0.76, 0), 1)
            let rippleAmplitude = isAccent ? 0.24 : 0.12
            ripple = rippleAmplitude * sin(tail * .pi * 4) * pow(sin(.pi * tail), 1.35) * exp(-tail * 0.55)
            let reboundStrength = isAccent ? 1.0 : 0.2
            lift = pow(sin(.pi * release), 2) * (0.72 + 0.18 * sin(release * .pi * 4)) * reboundStrength
        }
        // 主光球暂时不做扁压或横向摊开；漂浮小光球保留原有挤压形变。
        let thickness = isAccent
            ? max(0.75, 1 - 0.25 * pressure + ripple)
            : 1
        let spread = isAccent
            ? 1 + 0.50 * pressure - ripple * 0.30
            : 1
        let push = radius * 0.78 * ((isAccent ? 0.32 : 0.85) * pressure)
        let pressedCenter = CGPoint(x: center.x + normal.dx * (radius * lift - push),
                                    y: center.y + normal.dy * (radius * lift - push))
        let scale = edge.isMultiple(of: 2)
            ? CGSize(width: thickness, height: spread)
            : CGSize(width: spread, height: thickness)
        let opacity = isAccent ? 1 - 0.70 * pressure : 1 - 0.15 * pressure
        let blurExpansion = isAccent ? 1.5 * pressure : 0.25 * pressure
        return OrbMotion(center: pressedCenter, scale: scale, pressure: pressure,
                         opacity: opacity, blurExpansion: blurExpansion)
    }

    private func smoothStep(_ value: Double) -> Double {
        let t = min(max(value, 0), 1)
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    // 绘制具有自然表面波形扰动（Fluid Morphing）的球体
    private func drawSphere(
        in context: inout GraphicsContext,
        motion: OrbMotion,
        bounds: CGSize,
        radius: CGFloat,
        blurRadius: CGFloat = 48,
        time: TimeInterval,
        phase: Double,
        colors: [Color],
                                 isVolumetric: Bool = false,
                                 hasCenterHighlight: Bool = false
    ) {
        let center = motion.center
        let path = organicBlobPath(center: center, radius: radius, time: time, phase: phase)
        // 轮廓和径向色阶一起变形，避免只有外框挤扁而球心仍然保持圆形。
        var sphereContext = context
        sphereContext.opacity *= motion.opacity
        // 光球受压变淡时同步扩散模糊，避免柔光层出现硬边；回弹时恢复基准模糊。
        let effectiveBlurRadius = blurRadius * (1 + motion.blurExpansion)
        sphereContext.addFilter(.blur(radius: effectiveBlurRadius))
        sphereContext.clip(to: Path(CGRect(origin: .zero, size: bounds)))
        sphereContext.translateBy(x: center.x, y: center.y)
        sphereContext.rotate(by: .radians(motion.angle))
        sphereContext.scaleBy(x: motion.scale.width, y: motion.scale.height)
        sphereContext.rotate(by: .radians(-motion.angle))
        sphereContext.translateBy(x: -center.x, y: -center.y)
        let gradientStops: [Gradient.Stop]
        if colors.count == 3 {
            gradientStops = [
                .init(color: colors[0], location: 0.0),
                .init(color: colors[1], location: 0.40),
                .init(color: colors[2], location: 0.76)
            ]
        } else {
            gradientStops = [
                .init(color: colors[0], location: 0.0),
                .init(color: colors[1], location: 0.34),
                .init(color: colors[2], location: 0.68),
                .init(color: colors[3], location: 1.0)
            ]
        }
        let gradient = Gradient(stops: gradientStops)
        sphereContext.fill(
            path,
            with: .radialGradient(
                gradient,
                center: CGPoint(x: center.x - radius * 0.12, y: center.y - radius * 0.15),
                startRadius: radius * 0.05,
                endRadius: radius * 1.30
            )
        )
        if isVolumetric {
            // 偏心柔亮高光与反侧暗边共同塑造圆球体积感。
            let highlightCenter = CGPoint(x: center.x - radius * 0.30,
                                           y: center.y - radius * 0.34)
            sphereContext.fill(path, with: .radialGradient(
                Gradient(colors: [.white.opacity(0.30), .white.opacity(0.12), .clear]),
                center: highlightCenter, startRadius: 0, endRadius: radius * 0.60))
            sphereContext.fill(path, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.46),
                    .init(color: colorTheme == .original ? colors[1].opacity(0.03) : .black.opacity(0.05), location: 0.76),
                    .init(color: colorTheme == .original ? colors[1].opacity(0.08) : .black.opacity(0.15), location: 1.0)
                ]),
                center: CGPoint(x: center.x + radius * 0.12, y: center.y + radius * 0.18),
                startRadius: radius * 0.12, endRadius: radius * 1.15))
        }
        if hasCenterHighlight, let centerColor = colors.first {
            let vividCenter = adjustedBrightness(
                adjustedSaturation(centerColor, increase: 0.15),
                increase: 0.08
            )
            let highlightCenter = CGPoint(x: center.x - radius * 0.08,
                                           y: center.y - radius * 0.08)
            var centerGlow = sphereContext
            centerGlow.addFilter(.blur(radius: 15))
            let highlight = Path(ellipseIn: CGRect(x: highlightCenter.x - radius * 0.27,
                                                   y: highlightCenter.y - radius * 0.27,
                                                   width: radius * 0.54,
                                                   height: radius * 0.54))
            centerGlow.fill(highlight, with: .radialGradient(
                Gradient(colors: [vividCenter.opacity(0.42), vividCenter.opacity(0.18), .clear]),
                center: highlightCenter, startRadius: 0, endRadius: radius * 0.27))
        }
    }

    private func adjustedBrightness(_ color: Color, increase: CGFloat) -> Color {
        let source = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard source.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return color
        }
        return Color(uiColor: UIColor(hue: hue, saturation: saturation,
                                      brightness: min(1, brightness * (1 + increase)), alpha: alpha))
    }

    // 连续变化的低频波形让轮廓伸展、收缩并形成流体瓣。
    private func organicBlobPath(
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        phase: Double
    ) -> Path {
        let pointCount = 24
        let wobble = 0.035 * sin(time * 0.52 + phase)
        let points = (0..<pointCount).map { i -> CGPoint in
            let angle = Double(i) / Double(pointCount) * .pi * 2
            let harmonic1 = sin(angle * 3 + time * 0.65 + phase) * 0.055
            let harmonic2 = cos(angle * 2 - time * 0.55 + phase) * 0.035
            let harmonic3 = sin(angle * 4 - time * 0.38 + phase) * 0.015
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
                .fill(.ultraThinMaterial)

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
        .opacity(0.02)
        .allowsHitTesting(false)
        .ignoresSafeArea(.all)
    }
}
