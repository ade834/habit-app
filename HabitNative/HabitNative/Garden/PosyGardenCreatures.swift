import SwiftUI

// MARK: - 动态飞舞的蝴蝶与小蜜蜂（两阶段点击互动物理引擎）
/// 交互规范：
/// 1. 第一次点击：惊飞并随机移居到其他花朵或开阔空白处，持续轻盈悬停盘旋；
/// 2. 第二次点击：受惊高速逃逸至屏幕外，在屏幕外静默等待 5 秒钟；
/// 3. 等待结束后：随机从屏幕外（左/右/顶边界）顺滑飞入，回归花园，重置点击计数；
/// 4. 彻底杜绝从屏幕正中突然变出，全程空间连续位移。
public struct PosyCreaturesView: View {
    let elapsed: Double
    let windSpeed: Double
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    let isSnapshot: Bool

    // 蝴蝶独立航行状态机
    @State private var butterflyState = CreatureState(
        anchorPos: CGPoint(x: 120, y: 240),
        isInitialized: false
    )

    // 蜜蜂独立航行状态机
    @State private var beeState = CreatureState(
        anchorPos: CGPoint(x: 280, y: 280),
        isInitialized: false
    )

    public init(elapsed: Double, windSpeed: Double, canvasWidth: CGFloat, canvasHeight: CGFloat, isSnapshot: Bool = false) {
        self.elapsed = elapsed
        self.windSpeed = windSpeed
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.isSnapshot = isSnapshot
    }

    public var body: some View {
        ZStack {
            butterflyNode
            beeNode
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .onAppear {
            if !isSnapshot { setupInitialFlightPlans() }
        }
        .allowsHitTesting(!isSnapshot)
    }

    // MARK: - 初始入场航线初始化
    private func setupInitialFlightPlans() {
        if !butterflyState.isInitialized {
            let start = CGPoint(x: -80, y: canvasHeight * 0.22)
            let target = CGPoint(x: canvasWidth * 0.32, y: canvasHeight * 0.28)
            butterflyState.isInitialized = true
            butterflyState.anchorPos = target
            butterflyState.isReentering = true
            butterflyState.reentryStart = elapsed
            butterflyState.reentryDuration = 2.4
            butterflyState.reentryFrom = start
            butterflyState.reentryTo = target
        }

        if !beeState.isInitialized {
            let start = CGPoint(x: canvasWidth + 80, y: canvasHeight * 0.26)
            let target = CGPoint(x: canvasWidth * 0.72, y: canvasHeight * 0.34)
            beeState.isInitialized = true
            beeState.anchorPos = target
            beeState.isReentering = true
            beeState.reentryStart = elapsed + 0.5
            beeState.reentryDuration = 2.4
            beeState.reentryFrom = start
            beeState.reentryTo = target
        }
    }

    // MARK: - 1. 蝴蝶节点
    @ViewBuilder
    private var butterflyNode: some View {
        let (pos, isVisible, rot) = calculateCreatureTransform(state: butterflyState, isBee: false)
        let wingFlap = sin(elapsed * 22.0)

        if isVisible {
            Button(action: {
                handleTap(isBee: false, currentPos: pos)
            }) {
                ZStack {
                    // 增大轻量透明命中区 (Apple HIG 48x48 pt)，极大改善移动端误触与漏触
                    Color.clear
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())

                    HStack(spacing: 1.5) {
                        // 左翅膀
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.65, blue: 0.85), Color(red: 0.80, green: 0.45, blue: 0.95)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 14, height: 18)
                            .scaleEffect(x: CGFloat(max(0.2, abs(wingFlap))), y: 1.0, anchor: .trailing)

                        // 躯干
                        Capsule()
                            .fill(Color(red: 0.35, green: 0.20, blue: 0.35))
                            .frame(width: 3, height: 13)

                        // 右翅膀
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.65, blue: 0.85), Color(red: 0.80, green: 0.45, blue: 0.95)],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                            .frame(width: 14, height: 18)
                            .scaleEffect(x: CGFloat(max(0.2, abs(wingFlap))), y: 1.0, anchor: .leading)
                    }
                    .shadow(color: Color.pink.opacity(0.4), radius: 6, x: 0, y: 3)
                    .rotationEffect(.degrees(rot))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .position(pos)
        }
    }

    // MARK: - 2. 蜜蜂节点
    @ViewBuilder
    private var beeNode: some View {
        let (pos, isVisible, rot) = calculateCreatureTransform(state: beeState, isBee: true)
        let wingVibrate = sin(elapsed * 36.0)

        if isVisible {
            Button(action: {
                handleTap(isBee: true, currentPos: pos)
            }) {
                ZStack {
                    // 增大轻量透明命中区
                    Color.clear
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())

                    HStack(spacing: 2) {
                        // 半透明微晶双翅
                        VStack(spacing: 2) {
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 10, height: 4)
                                .scaleEffect(y: CGFloat(max(0.3, abs(wingVibrate))))
                        }

                        // 身体
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.85, blue: 0.15), Color(red: 0.98, green: 0.62, blue: 0.08)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 15, height: 11)

                            // 斑纹
                            HStack(spacing: 2) {
                                Rectangle().fill(Color.black.opacity(0.75)).frame(width: 2, height: 9)
                                Rectangle().fill(Color.black.opacity(0.75)).frame(width: 2, height: 9)
                            }
                        }
                    }
                    .shadow(color: Color.orange.opacity(0.4), radius: 6, x: 0, y: 3)
                    .rotationEffect(.degrees(rot))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .position(pos)
        }
    }

    // MARK: - 点击交互状态调度 (两阶段：1次随机换位，2次惊飞离场+5秒返场)
    private func handleTap(isBee: Bool, currentPos: CGPoint) {
        if isBee {
            // 忽略飞行/离场中的重复触发
            if beeState.isFlying && elapsed < beeState.flyStart + beeState.flyDuration { return }
            if beeState.isOffscreenCycle && elapsed < beeState.reentryStart + beeState.reentryDuration { return }

            if beeState.clickCount == 0 {
                // 第一次点击：随机跑到其他花朵或者空白处
                let target = pickRandomGardenSpot(excluding: currentPos)
                beeState.isFlying = true
                beeState.flyStart = elapsed
                beeState.flyDuration = 1.0
                beeState.flyFrom = currentPos
                beeState.flyTo = target
                beeState.anchorPos = target
                beeState.isOffscreenCycle = false
                beeState.isReentering = false
                beeState.clickCount = 1
            } else {
                // 第二次点击：飞到屏幕外，等待 5 秒，再随机从屏幕外飞回
                let exitPoint = pickOffscreenExit(from: currentPos)
                let entryPoint = pickOffscreenEntry()
                let targetReturn = pickRandomGardenSpot(excluding: currentPos)

                let fleeDur: Double = 0.85
                let waitDur: Double = 5.0
                let reentryDur: Double = 2.2

                beeState.isFlying = false
                beeState.isOffscreenCycle = true
                beeState.fleeStart = elapsed
                beeState.fleeDuration = fleeDur
                beeState.fleeExit = exitPoint
                beeState.waitEndTime = elapsed + fleeDur + waitDur
                beeState.reentryStart = beeState.waitEndTime
                beeState.reentryDuration = reentryDur
                beeState.reentryFrom = entryPoint
                beeState.reentryTo = targetReturn
                beeState.anchorPos = targetReturn
                beeState.clickCount = 0
            }
        } else {
            // 蝴蝶逻辑
            if butterflyState.isFlying && elapsed < butterflyState.flyStart + butterflyState.flyDuration { return }
            if butterflyState.isOffscreenCycle && elapsed < butterflyState.reentryStart + butterflyState.reentryDuration { return }

            if butterflyState.clickCount == 0 {
                // 第一次点击：换位
                let target = pickRandomGardenSpot(excluding: currentPos)
                butterflyState.isFlying = true
                butterflyState.flyStart = elapsed
                butterflyState.flyDuration = 1.1
                butterflyState.flyFrom = currentPos
                butterflyState.flyTo = target
                butterflyState.anchorPos = target
                butterflyState.isOffscreenCycle = false
                butterflyState.isReentering = false
                butterflyState.clickCount = 1
            } else {
                // 第二次点击：离场5秒后飞回
                let exitPoint = pickOffscreenExit(from: currentPos)
                let entryPoint = pickOffscreenEntry()
                let targetReturn = pickRandomGardenSpot(excluding: currentPos)

                let fleeDur: Double = 0.85
                let waitDur: Double = 5.0
                let reentryDur: Double = 2.4

                butterflyState.isFlying = false
                butterflyState.isOffscreenCycle = true
                butterflyState.fleeStart = elapsed
                butterflyState.fleeDuration = fleeDur
                butterflyState.fleeExit = exitPoint
                butterflyState.waitEndTime = elapsed + fleeDur + waitDur
                butterflyState.reentryStart = butterflyState.waitEndTime
                butterflyState.reentryDuration = reentryDur
                butterflyState.reentryFrom = entryPoint
                butterflyState.reentryTo = targetReturn
                butterflyState.anchorPos = targetReturn
                butterflyState.clickCount = 0
            }
        }
    }

    // MARK: - 实时坐标与姿态计算 (纯函数无状态副作用)
    private func calculateCreatureTransform(state: CreatureState, isBee: Bool) -> (pos: CGPoint, isVisible: Bool, rot: Double) {
        // 1. 离场循环（惊飞 -> 屏外等 5 秒 -> 屏外顺滑飞入）
        if state.isOffscreenCycle {
            if elapsed < state.fleeStart + state.fleeDuration {
                // 逃逸阶段：向屏幕外快速直线拉升
                let p = min(1.0, max(0.0, (elapsed - state.fleeStart) / state.fleeDuration))
                let ease = p * p // 加速离场
                let x = state.anchorPos.x + (state.fleeExit.x - state.anchorPos.x) * ease
                let y = state.anchorPos.y + (state.fleeExit.y - state.anchorPos.y) * ease
                let rot = isBee ? 45.0 : -40.0
                return (CGPoint(x: x, y: y), true, rot)
            } else if elapsed < state.waitEndTime {
                // 屏外静默阶段：持续整整 5 秒不可见
                return (CGPoint(x: -300, y: -300), false, 0.0)
            } else if elapsed < state.reentryStart + state.reentryDuration {
                // 返场飞入阶段：从屏幕外顺滑减速进入目标点
                let p = min(1.0, max(0.0, (elapsed - state.reentryStart) / state.reentryDuration))
                let ease = 1.0 - pow(1.0 - p, 3) // easeOutCubic
                let arc = -sin(p * .pi) * 32.0
                let x = state.reentryFrom.x + (state.reentryTo.x - state.reentryFrom.x) * ease
                let y = state.reentryFrom.y + (state.reentryTo.y - state.reentryFrom.y) * ease + arc
                let rot = sin(elapsed * 4.0) * 16.0
                return (CGPoint(x: x, y: y), true, rot)
            } else {
                // 返场落地完成：在 reentryTo 位置盘旋
                let hover = computeHover(center: state.reentryTo, isBee: isBee)
                return (hover.pos, true, hover.rot)
            }
        }

        // 2. 初次开屏飞入
        if state.isReentering && elapsed < state.reentryStart + state.reentryDuration {
            let p = min(1.0, max(0.0, (elapsed - state.reentryStart) / state.reentryDuration))
            let ease = 1.0 - pow(1.0 - p, 3)
            let arc = -sin(p * .pi) * 28.0
            let x = state.reentryFrom.x + (state.reentryTo.x - state.reentryFrom.x) * ease
            let y = state.reentryFrom.y + (state.reentryTo.y - state.reentryFrom.y) * ease + arc
            let rot = sin(elapsed * 3.5) * 14.0
            return (CGPoint(x: x, y: y), true, rot)
        }

        // 3. 第一次点击换位飞行 (弧线跃迁)
        if state.isFlying && elapsed < state.flyStart + state.flyDuration {
            let p = min(1.0, max(0.0, (elapsed - state.flyStart) / state.flyDuration))
            let ease = p * p * (3.0 - 2.0 * p) // smoothStep
            let arc = -sin(p * .pi) * 38.0
            let x = state.flyFrom.x + (state.flyTo.x - state.flyFrom.x) * ease
            let y = state.flyFrom.y + (state.flyTo.y - state.flyFrom.y) * ease + arc
            let rot = sin(elapsed * 5.0) * 20.0
            return (CGPoint(x: x, y: y), true, rot)
        }

        // 4. 自然优雅悬停
        let hover = computeHover(center: state.anchorPos, isBee: isBee)
        return (hover.pos, true, hover.rot)
    }

    // MARK: - 悬停微摆动动力学
    private func computeHover(center: CGPoint, isBee: Bool) -> (pos: CGPoint, rot: Double) {
        let t = elapsed
        if isBee {
            let hx = cos(t * 2.8) * 16.0 + sin(t * 1.1) * 8.0
            let hy = sin(t * 2.1) * 12.0 + cos(t * 1.4) * 6.0
            let rot = cos(t * 1.8) * 14.0
            return (CGPoint(x: center.x + CGFloat(hx), y: center.y + CGFloat(hy)), rot)
        } else {
            let hx = sin(t * 1.6) * 20.0 + cos(t * 0.7) * 10.0
            let hy = cos(t * 1.3) * 15.0 + sin(t * 0.9) * 8.0
            let rot = sin(t * 1.2) * 18.0
            return (CGPoint(x: center.x + CGFloat(hx), y: center.y + CGFloat(hy)), rot)
        }
    }

    // MARK: - 目标候选路标 (花朵位置与开阔空白区域)
    private func pickRandomGardenSpot(excluding currentPos: CGPoint) -> CGPoint {
        let candidates: [(CGFloat, CGFloat)] = [
            // 花丛着陆点 (不同高度的花朵冠部)
            (0.18, 0.38),
            (0.32, 0.30),
            (0.48, 0.25),
            (0.62, 0.34),
            (0.78, 0.28),
            (0.85, 0.36),
            // 空阔微域 (中高空与微风区)
            (0.20, 0.18),
            (0.40, 0.15),
            (0.65, 0.16),
            (0.82, 0.20),
            (0.30, 0.50),
            (0.70, 0.48)
        ]

        let validCandidates = candidates.filter { norm in
            let pt = CGPoint(x: canvasWidth * norm.0, y: canvasHeight * norm.1)
            let dist = hypot(pt.x - currentPos.x, pt.y - currentPos.y)
            return dist > 70.0
        }

        let selected = validCandidates.randomElement() ?? candidates.randomElement()!
        return CGPoint(x: canvasWidth * selected.0, y: canvasHeight * selected.1)
    }

    // MARK: - 随机离场终点 (飞出屏幕边缘)
    private func pickOffscreenExit(from currentPos: CGPoint) -> CGPoint {
        let isLeft = currentPos.x < canvasWidth * 0.5
        let deltaX: CGFloat = isLeft ? -CGFloat.random(in: 260...380) : CGFloat.random(in: 260...380)
        let deltaY: CGFloat = -CGFloat.random(in: 280...420)
        return CGPoint(x: currentPos.x + deltaX, y: currentPos.y + deltaY)
    }

    // MARK: - 随机入场起点 (从屏幕外边界飞入)
    private func pickOffscreenEntry() -> CGPoint {
        let side = Int.random(in: 0...2)
        switch side {
        case 0:
            // 左边缘外
            return CGPoint(x: -80, y: CGFloat.random(in: 0.18...0.45) * canvasHeight)
        case 1:
            // 右边缘外
            return CGPoint(x: canvasWidth + 80, y: CGFloat.random(in: 0.18...0.45) * canvasHeight)
        default:
            // 上边缘外
            return CGPoint(x: CGFloat.random(in: 0.20...0.80) * canvasWidth, y: -70)
        }
    }
}

// MARK: - 昆虫飞行状态结构体
private struct CreatureState {
    var anchorPos: CGPoint
    var isInitialized: Bool = false
    var clickCount: Int = 0

    // 第一次点击：换位航行
    var isFlying: Bool = false
    var flyStart: Double = 0
    var flyDuration: Double = 1.0
    var flyFrom: CGPoint = .zero
    var flyTo: CGPoint = .zero

    // 第二次点击：离场与返场
    var isOffscreenCycle: Bool = false
    var fleeStart: Double = 0
    var fleeDuration: Double = 0.85
    var fleeExit: CGPoint = .zero
    var waitEndTime: Double = 0
    var reentryStart: Double = 0
    var reentryDuration: Double = 2.4
    var reentryFrom: CGPoint = .zero
    var reentryTo: CGPoint = .zero

    // 初始入场
    var isReentering: Bool = false
}

