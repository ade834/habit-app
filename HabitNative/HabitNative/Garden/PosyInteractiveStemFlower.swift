import SwiftUI

public struct PosyPlantPlacement: Codable, Equatable {
    public var rootOffsetX: Double = 0
    public var rootOffsetY: Double = 0
    public var tipOffsetX: Double = 0
    public var tipOffsetY: Double = 0
    public var restSupportFraction: Double? = nil
    public var windSupportFraction: Double? = nil

    // Optional fields keep placements saved before these traits readable.
    mutating func assignSupportIfNeeded() {
        if restSupportFraction == nil {
            restSupportFraction = Double.random(in: (1.0 / 3.0)...(5.0 / 12.0))
        }
        if windSupportFraction == nil {
            windSupportFraction = Double.random(in: 0.085...0.115)
        }
    }

    public static let zero = PosyPlantPlacement()
}

// MARK: - POSY 柔性三次贝塞尔茎秆与手势物理引擎
/// 1. 终极绝对绑定：将茎秆贝塞尔曲线绘制与花头中心锚点整合进同一个 AnimatableModifier；
/// 2. 无论用户拖拽拉扯、松手弹簧回弹、自然微风吹拂，每一毫秒渲染帧中，茎秆末端与花朵中心点 100% 绝对重合，彻底杜绝脱离现象！
/// 3. 根部位置随手放下精准同步，垂直限制 10pt 内吸附，拽拉花头时根部固定；
public struct PosyInteractiveStemFlower: View {
    public let type: PosyFloraType
    public let progress: Double        // 生长阶段 0.0 ~ 1.0
    public let basePosition: CGPoint   // 根部初始基准坐标
    public let stemHeight: CGFloat     // 茎秆高度
    public let ambientSway: Double     // 茎秆结构性风动弯曲与位移
    public let windAlignment: Double   // Signed applied wind, separate from idle sway
    public let headWobble: Double      // 花头专属低阻尼惯性自振与滞后晃动 (实现茎杆停下花头继续摇曳)
    public let breathingPhase: Double  // 呼吸振幅
    public let seed: Int
    public let initialPlacement: PosyPlantPlacement

    public let canvasSize: CGSize      // 画布/屏幕尺寸 (默认 0 时自适应 UIScreen)
    public let elapsed: Double         // 连续物理与随机动效时间戳

    // 花头顶部手势拖拽与持久重定位偏移 (松手后永久保持花头新位置)
    @State private var persistentTipOffset: CGSize = .zero
    @State private var activeFlowerDragTip: CGPoint? = nil
    @State private var dragStartTipPos: CGPoint? = nil
    @State private var isDraggingFlower: Bool = false
    
    // 根部整体植物位置持久偏移 (拖拽根部放手后保留水平位置，垂直可记录区间为上下 10pt)
    @State private var persistentRootOffsetX: CGFloat = 0.0
    @State private var persistentRootOffsetY: CGFloat = 0.0
    @State private var activeRootX: CGFloat? = nil
    @State private var activeRootY: CGFloat? = nil
    @State private var dragStartRootX: CGFloat? = nil
    @State private var dragStartRootY: CGFloat? = nil
    @State private var isDraggingRoot: Bool = false

    @State private var showLabel: Bool = false
    @State private var stemWindOffset: Double = 0
    @State private var stemWindVelocity: Double = 0
    @State private var rootWindAngle: Double = 0
    @State private var rootWindVelocity: Double = 0
    @State private var flutterEnergy: Double = 0
    @State private var dragReleaseOffset: CGSize = .zero
    @State private var dragReleaseVelocity: CGSize = .zero


    // MARK: - 迪士尼双击灵动交互 (无论处于植物哪个阶段均生动响应)
    @State private var disneyAnimStartTime: Double? = nil
    @State private var activeDisneyRule: PosyDisneyRule = .dewSplash
    @State private var activeDewDrops: [PosyDewDrop] = []

    public var onDragStateChanged: ((Bool) -> Void)? = nil
    public var onPlacementChange: ((PosyPlantPlacement) -> Void)? = nil
    public let habitName: String?
    public let onSelected: (() -> Void)?

    public init(
        type: PosyFloraType,
        progress: Double,
        basePosition: CGPoint,
        stemHeight: CGFloat = 180,
        ambientSway: Double = 0,
        windAlignment: Double = 0,
        headWobble: Double = 0,
        breathingPhase: Double = 0,
        seed: Int = 1,
        initialPlacement: PosyPlantPlacement = .zero,
        canvasSize: CGSize = .zero,
        elapsed: Double = 0,
        habitName: String? = nil,
        onSelected: (() -> Void)? = nil,
        onDragStateChanged: ((Bool) -> Void)? = nil,
        onPlacementChange: ((PosyPlantPlacement) -> Void)? = nil
    ) {
        self.type = type
        self.progress = progress
        self.basePosition = basePosition
        self.stemHeight = stemHeight
        self.ambientSway = ambientSway
        self.windAlignment = windAlignment
        self.headWobble = headWobble
        self.breathingPhase = breathingPhase
        self.seed = seed
        self.initialPlacement = initialPlacement
        self.canvasSize = canvasSize
        self.elapsed = elapsed
        self.onDragStateChanged = onDragStateChanged
        self.onPlacementChange = onPlacementChange
        self.habitName = habitName
        self.onSelected = onSelected
        _persistentRootOffsetX = State(initialValue: CGFloat(initialPlacement.rootOffsetX))
        _persistentRootOffsetY = State(initialValue: CGFloat(initialPlacement.rootOffsetY))
        _persistentTipOffset = State(initialValue: CGSize(
            width: CGFloat(initialPlacement.tipOffsetX),
            height: CGFloat(initialPlacement.tipOffsetY)
        ))
    }

    private var currentPlacement: PosyPlantPlacement {
        PosyPlantPlacement(
            rootOffsetX: Double(persistentRootOffsetX),
            rootOffsetY: Double(persistentRootOffsetY),
            tipOffsetX: Double(persistentTipOffset.width),
            tipOffsetY: Double(persistentTipOffset.height),
            restSupportFraction: initialPlacement.restSupportFraction,
            windSupportFraction: initialPlacement.windSupportFraction
        )
    }

    public var body: some View {
        let palette = type.palette
        let screenW = canvasSize.width > 0 ? canvasSize.width : 402.0
        let screenH = canvasSize.height > 0 ? canvasSize.height : 874.0
        let safeMargin: CGFloat = 10.0
        
        // 固有形态伪随机化：同一种植物即使多次出现，也会因 seed 拥有独特的茎长与自然弯曲
        let seedD = Double(seed)
        let motion = PosyStemMotionProfile(seed: seed, floraIndex: PosyFloraType.allCases.firstIndex(of: type) ?? 0)
        let heightVariation = 1.0 + sin(seedD * 7.1) * 0.08 // ±8% 高度差异
        let currentGrowthHeight = stemHeight * CGFloat(max(0.18, progress) * heightVariation)

        // 固有自然生长弯曲偏角（植物品种专属优美弧度 + 细微种子微调，彻底消除任何直立死线）
        let seedOffset = CGFloat(sin(seedD * 9.7)) * 4.0
        let naturalCurvature: CGFloat = type.naturalCurvature + seedOffset

        // 拖拽时该植物自身完全静止动画；其余植物照常动画
        let isAnySelfDragging = isDraggingFlower || isDraggingRoot

        // 阶段 4 门控：所有 4 阶段的植物内部动效调慢到 0.35x
        let isStage4 = progress >= 0.75
        let stage4AnimSpeed: Double = isStage4 ? 0.35 : 1.0

        let animTime = (elapsed > 0 ? elapsed : breathingPhase / 2.0) * stage4AnimSpeed
        let shake = computeHeadShakeAndJitter(
            t: animTime,
            seedD: seedD,
            progress: progress,
            isDragging: isAnySelfDragging
        )
        let mimosaYAngle = computeMimosaYRotation(
            t: animTime,
            progress: progress,
            isDragging: isAnySelfDragging
        )

        // 1. 浅盘活动范围与茎杆末端 (根部) 实时精准坐标 (底部区域收窄 25%，Y 轴可记录上下 10pt)
        let minSaucerX: CGFloat = max(safeMargin, screenW * 0.17)
        let maxSaucerX: CGFloat = min(screenW - safeMargin, screenW * 0.83)

        let currentRootX: CGFloat = activeRootX ?? max(minSaucerX, min(maxSaucerX, basePosition.x + persistentRootOffsetX))
        let currentRootY: CGFloat = activeRootY ?? max(basePosition.y - 10.0, min(basePosition.y + 10.0, basePosition.y + persistentRootOffsetY))
        let rootPoint = CGPoint(
            x: currentRootX,
            y: currentRootY
        )

        // 2. 基准花头坐标与风力位移 (拖拽自身时风摆彻底归零，保持绝对静止)
        let staticTip = CGPoint(
            x: rootPoint.x + naturalCurvature + persistentTipOffset.width,
            y: rootPoint.y - currentGrowthHeight + persistentTipOffset.height
        )
        // A sustained opposing wind gradually straightens the resting lean before
        // bending the stem downwind. Tiny ambient breezes retain its own shape.
        let restingLean = Double(staticTip.x - rootPoint.x)
        let windBlend = max(0, min(1, abs(windAlignment) / 0.06))
        let alignment = windBlend * windBlend * (3 - 2 * windBlend)
        let opposingLean = restingLean * windAlignment < 0 ? restingLean * alignment : 0
        // Wind supplies flex as well as base rotation, including when it has
        // just straightened a plant's original opposing lean.
        let windFlex = Double(currentGrowthHeight) * 0.14 * sqrt(type.stemFlexFactor)
            * tanh(windAlignment * 3) * motion.response
        let targetWindOffset = ambientSway * Double(currentGrowthHeight) * 0.60 * motion.response - opposingLean + windFlex
        let targetRootAngle = max(-0.30, min(0.30, windAlignment * type.stemFlexFactor * motion.tiltResponse))
        let motionTime = elapsed > 0 ? elapsed : breathingPhase / 2
        let flutterScale = isAnySelfDragging ? 0 : min(1.2, flutterEnergy)
        let flutterAmplitude = CGFloat(flutterScale * motion.flutterAmplitude) * min(1.25, currentGrowthHeight / 180)
        let tipFlutter = flutterAmplitude * CGFloat(motion.noise(at: motionTime, channel: 1))
        let angleFlutter = flutterScale * 0.004 * motion.noise(at: motionTime, channel: 2)
        let baseAngle = isAnySelfDragging ? 0 : rootWindAngle + angleFlutter
        let restingDY = staticTip.y - rootPoint.y
        let rotatedLean = CGFloat(restingLean) * CGFloat(cos(baseAngle)) - restingDY * CGFloat(sin(baseAngle))
        let rotatedHeight = CGFloat(restingLean) * CGFloat(sin(baseAngle)) + restingDY * CGFloat(cos(baseAngle))
        let windDisplacement: CGFloat = isAnySelfDragging ? 0 : CGFloat(stemWindOffset)
        let currentRestingTip = CGPoint(
            x: rootPoint.x + rotatedLean + windDisplacement + tipFlutter + shake.stemWiggle.width + dragReleaseOffset.width,
            y: rootPoint.y + rotatedHeight + shake.stemWiggle.height + dragReleaseOffset.height
        )

        // 3. 拖拽时的实际花头坐标：
        // - 拖拽花头时：直接 1:1 跟手，并绝对钳制在屏幕边界 safeMargin 安全范围内
        // - 拖拽下端根部时：花头保持相对形态与下端整体平移 (形状完全锁定)
        // - 非拖拽时：采用风摆微颤后的基准坐标
        let tipPoint: CGPoint = {
            if isDraggingFlower {
                return activeFlowerDragTip ?? staticTip
            } else if isDraggingRoot {
                return CGPoint(
                    x: max(safeMargin, min(screenW - safeMargin, staticTip.x)),
                    y: max(safeMargin, min(screenH - safeMargin, staticTip.y))
                )
            } else {
                return CGPoint(
                    x: max(safeMargin, min(screenW - safeMargin, currentRestingTip.x)),
                    y: max(safeMargin, min(screenH - safeMargin, currentRestingTip.y))
                )
            }
        }()

        // 4. 茎秆粗细固定 2.8pt (消除拖拽状态切换导致的线宽闪烁)
        let lineWidth: CGFloat = 2.8

        // Each plant retains its stored resting support; wind gradually shortens it.
        let supportBlend = min(1, max(0, flutterEnergy / 0.08))
        let smoothSupportBlend = supportBlend * supportBlend * (3 - 2 * supportBlend)
        let restSupport = initialPlacement.restSupportFraction ?? 0.375
        let windSupport = initialPlacement.windSupportFraction ?? 0.10
        let currentSupport = restSupport + (windSupport - restSupport) * smoothSupportBlend
        let curve = PosyWindStemCurve(
            root: rootPoint,
            tip: tipPoint,
            rootLean: -restingDY * CGFloat(sin(baseAngle)) * 0.65,
            ripple: flutterAmplitude * 0.65 * CGFloat(motion.noise(at: motionTime, channel: 3)),
            supportedFraction: CGFloat(currentSupport),
            restingSupportFraction: CGFloat(restSupport),
            windBlend: CGFloat(smoothSupportBlend)
        )
        let tipTangent = curve.tangent(at: 1)
        let stemTangentAngle = Double(atan2(tipTangent.x, -tipTangent.y))

        // 核心规则：植物种类的 2 (.dandelion)、6 (.mimosa) 与 10 (.cherryBlossom) 要随着茎杆方向调整花头方向，朝向保持绝对一致
        // 第一阶段规则：3 (.bayWreath) 与 8 (.allium) 在阶段 1 顺着茎杆方向生长
        let flowerStemAlignmentAngle: Double = {
            if type == .dandelion || type == .mimosa || type == .cherryBlossom {
                return stemTangentAngle
            }
            if type == .bayWreath || type == .allium {
                if progress < 0.25 {
                    return stemTangentAngle
                } else if progress < 0.35 {
                    let blend = (0.35 - progress) / 0.10
                    return stemTangentAngle * blend
                }
            }
            return 0.0
        }()

        ZStack {
            // MARK: - 1. 柔韧三次贝塞尔茎秆：曲线终点 100% 锁定在 tipPoint (支持圆点虚线与发丝实线)
            Path { p in
                p.move(to: rootPoint)
                let span: CGFloat = 1 / 8
                for index in 0..<8 {
                    let t0 = CGFloat(index) * span
                    let t1 = CGFloat(index + 1) * span
                    let start = curve.point(at: t0)
                    let end = curve.point(at: t1)
                    let startTangent = curve.tangent(at: t0)
                    let endTangent = curve.tangent(at: t1)
                    p.addCurve(
                        to: end,
                        control1: CGPoint(x: start.x + startTangent.x * span / 3, y: start.y + startTangent.y * span / 3),
                        control2: CGPoint(x: end.x - endTangent.x * span / 3, y: end.y - endTangent.y * span / 3)
                    )
                }
            }
            .stroke(
                palette.stem,
                style: type.stemIsDotted
                    ? StrokeStyle(lineWidth: lineWidth * 1.15, lineCap: .round, lineJoin: .round, dash: [0.1, 8.5])
                    : StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .allowsHitTesting(false)

            // MARK: - 2. 茎杆末端独立拖拽交互区 (单独拖拽并持久保存茎杆末端位置)
            ZStack {
                Color.clear
                    .frame(width: 54, height: 54)
                    .contentShape(Rectangle())

                // 拖拽末端时的高光反馈锚点
                if isDraggingRoot {
                    Circle()
                        .stroke(palette.primary.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(palette.glow.opacity(0.35)))
                }
            }
            .position(rootPoint)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("GardenStudioCanvas"))
                    .onChanged { value in
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            if !isDraggingRoot {
                                isDraggingRoot = true
                                dragStartRootX = rootPoint.x
                                dragStartRootY = rootPoint.y
                                onDragStateChanged?(true)
                            }
                            let startX = dragStartRootX ?? rootPoint.x
                            let targetX = startX + value.translation.width
                            activeRootX = max(minSaucerX, min(maxSaucerX, targetX))

                            let startY = dragStartRootY ?? rootPoint.y
                            let targetY = startY + value.translation.height
                            activeRootY = max(basePosition.y - 10.0, min(basePosition.y + 10.0, targetY))
                        }
                    }
                    .onEnded { value in
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            let startX = dragStartRootX ?? rootPoint.x
                            let targetX = startX + value.translation.width
                            let finalRootX = max(minSaucerX, min(maxSaucerX, targetX))
                            let deltaRootX = finalRootX - (basePosition.x + persistentRootOffsetX)
                            persistentRootOffsetX += deltaRootX

                            let startY = dragStartRootY ?? rootPoint.y
                            let targetY = startY + value.translation.height
                            let finalRootY = max(basePosition.y - 10.0, min(basePosition.y + 10.0, targetY))
                            let deltaRootY = finalRootY - (basePosition.y + persistentRootOffsetY)
                            persistentRootOffsetY += deltaRootY
                            
                            // 下端移动时上端保持相对形态与下端整体平移，无需对冲 persistentTipOffset
                            activeRootX = nil
                            activeRootY = nil
                            dragStartRootX = nil
                            dragStartRootY = nil
                            isDraggingRoot = false
                            onDragStateChanged?(false)
                        }
                        onPlacementChange?(currentPlacement)
                    }
            )

            // MARK: - 3. 花头交互本体：中心点绝对绑定在 tipPoint (2 与 6 随茎杆切线方向自适应旋转朝向一致)
            flowerHeadView(
                palette: palette,
                currentGrowthHeight: currentGrowthHeight,
                naturalCurvature: naturalCurvature,
                screenW: screenW,
                screenH: screenH,
                safeMargin: safeMargin,
                currentTip: tipPoint,
                currentRoot: rootPoint,
                stemAlignmentAngle: flowerStemAlignmentAngle,
                shakeAngle: shake.angle,
                jitterOffset: shake.jitter,
                flutterPhase: shake.flutter,
                yRotationDegrees: mimosaYAngle,
                isAnySelfDragging: isAnySelfDragging
            )
            .position(tipPoint)
        }
        .onChange(of: elapsed) { previousTime, currentTime in
            guard !isAnySelfDragging else {
                stemWindOffset = 0
                stemWindVelocity = 0
                rootWindAngle = 0
                rootWindVelocity = 0
                flutterEnergy = 0
                dragReleaseOffset = .zero
                dragReleaseVelocity = .zero
                return
            }
            // Preserve displacement and velocity when the wind changes or stops.
            // Exact damped-spring integration keeps 60/120 Hz motion consistent.
            let dt = max(0, min(0.05, currentTime - previousTime))
            let omega = (4.5 + type.stemReboundSpeed * 0.45) * motion.springRate
            (stemWindOffset, stemWindVelocity) = PosyStemMotionProfile.advanceSpring(
                position: stemWindOffset, velocity: stemWindVelocity, target: targetWindOffset,
                omega: omega, dampingRatio: motion.dampingRatio, dt: dt
            )
            (rootWindAngle, rootWindVelocity) = PosyStemMotionProfile.advanceSpring(
                position: rootWindAngle, velocity: rootWindVelocity, target: targetRootAngle,
                omega: omega * 0.82, dampingRatio: motion.dampingRatio + 0.08, dt: dt
            )
            flutterEnergy += (abs(windAlignment) - flutterEnergy) * (1 - exp(-dt * 7))
            let releaseX = PosyStemMotionProfile.advanceSpring(
                position: Double(dragReleaseOffset.width), velocity: Double(dragReleaseVelocity.width),
                target: 0, omega: 11, dampingRatio: 0.46, dt: dt
            )
            let releaseY = PosyStemMotionProfile.advanceSpring(
                position: Double(dragReleaseOffset.height), velocity: Double(dragReleaseVelocity.height),
                target: 0, omega: 11, dampingRatio: 0.46, dt: dt
            )
            dragReleaseOffset = CGSize(width: releaseX.0, height: releaseY.0)
            dragReleaseVelocity = CGSize(width: releaseX.1, height: releaseY.1)
        }
    }

    // MARK: - 花头交互与高光
    @ViewBuilder
    private func flowerHeadView(
        palette: PosyPalette,
        currentGrowthHeight: CGFloat,
        naturalCurvature: CGFloat,
        screenW: CGFloat,
        screenH: CGFloat,
        safeMargin: CGFloat,
        currentTip: CGPoint,
        currentRoot: CGPoint,
        stemAlignmentAngle: Double,
        shakeAngle: Double,
        jitterOffset: CGSize,
        flutterPhase: Double,
        yRotationDegrees: Double,
        isAnySelfDragging: Bool
    ) -> some View {
        let isGiant = type.isGiantFlora
        let canvasDim: CGFloat = (isGiant ? 240 : 120) * type.headScaleFactor
        let touchSize: CGFloat = max(50.0, min(100.0, 48.0 + CGFloat(progress) * 50.0)) * (isGiant ? 1.5 : 1.0) * type.headScaleFactor

        // 拖拽时该植物自身完全静止动画：暂停呼吸、暂停晃动、暂停高频微颤与风旋转
        // 阶段 4 内部动画整体调慢到 0.35x 速率
        let isStage4 = progress >= 0.75
        let stage4AnimSpeed: Double = isStage4 ? 0.35 : 1.0

        // MARK: - 迪士尼双击动画规则解析 (无论处于阶段 1, 2, 3 还是 4，均生动响应)
        let dk = computeDisneyKinematics(
            elapsed: elapsed,
            animStart: disneyAnimStartTime,
            rule: activeDisneyRule
        )

        let effectiveBreathing = isAnySelfDragging ? 0.0 : ((breathingPhase + flutterPhase + dk.flutter) * stage4AnimSpeed)
        let effectiveWindAngle = isAnySelfDragging ? 0.0 : ambientSway

        // 对于与茎秆切线绝对锁定的植物 (2. 珊瑚伞花, 6. 金琥珀阳, 10. 双色几何伞)：
        // 花头角度严格对齐 stemAlignmentAngle (即 stemTangentAngle = thetaTip)，
        // 杜绝重复叠加风力与外部倾角导致的花颈折断！仅保留微幅动态抖动与交互 waggle：
        let isTangentLockedFlora = (type == .dandelion || type == .mimosa || type == .cherryBlossom)
        let effectiveRotation: Double = {
            if isTangentLockedFlora {
                let dynamicShake = isAnySelfDragging ? 0.0 : (shakeAngle + dk.waggle)
                return stemAlignmentAngle + dynamicShake
            } else {
                return stemAlignmentAngle + (isAnySelfDragging ? 0.0 : (shakeAngle + ambientSway * 0.35 + headWobble + dk.waggle))
            }
        }()
        let effectiveJitter = isAnySelfDragging ? CGSize.zero : CGSize(
            width: jitterOffset.width + dk.jitter.width,
            height: jitterOffset.height + dk.jitter.height
        )

        ZStack {
            // 点击查看标签时的高光背景光晕 (不在拖拽时忽闪弹出)
            if showLabel {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.glow.opacity(0.85), palette.glow.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: isGiant ? 90 : 55
                        )
                    )
                    .frame(width: isGiant ? 180 : 110, height: isGiant ? 180 : 110)
                    .transition(.opacity)
            }

            // 核心矢量花朵本体：其中心直接对齐在 tipPoint
            // 6-4 琥珀金阳支持以中点圆心为轴的周期性 Y 轴 3D 旋转 (拖拽时静止复原)
            PosyFlowerBloomCanvas(
                type: type,
                progress: progress,
                breathingPhase: effectiveBreathing,
                windAngle: effectiveWindAngle,
                seed: seed
            )
            .frame(width: canvasDim, height: canvasDim)
            .rotation3DEffect(
                .degrees(isAnySelfDragging ? 0.0 : yRotationDegrees),
                axis: (x: 0.0, y: 1.0, z: 0.0),
                anchor: .center,
                perspective: 0.35
            )
            .rotationEffect(.radians(effectiveRotation + (isAnySelfDragging ? 0 : Double(dragReleaseOffset.width) * 0.008)))
            .scaleEffect(x: dk.scaleX, y: dk.scaleY)
            .offset(x: effectiveJitter.width, y: effectiveJitter.height + dk.hopY)

            // 规则 1: 晶莹飞溅水珠层 (浮于花瓣上方)
            if !activeDewDrops.isEmpty {
                PosyWaterDropletsView(droplets: activeDewDrops, elapsed: elapsed)
                    .frame(width: canvasDim * 1.6, height: canvasDim * 1.6)
                    .allowsHitTesting(false)
            }

            // 雅致标签与花语 (仅在单次点击时平滑展示，拖拽时不触发跳出)
            if showLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.titleZh.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .tracking(2.0)
                        .foregroundColor(Color(red: 0.25, green: 0.20, blue: 0.25))
                    Text([habitName, type.meaningZh.components(separatedBy: " (").first].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 10, weight: .regular, design: .serif))
                        .foregroundColor(Color(red: 0.45, green: 0.40, blue: 0.45))
                }
                .frame(width: min(260, screenW - 32), alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                )
                .offset(
                    x: min(screenW - min(280, screenW - 12) / 2 - 6,
                           max(min(280, screenW - 12) / 2 + 6, currentTip.x + 75)) - currentTip.x,
                    y: currentTip.y < 60 ? 48 : -35
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: touchSize, height: touchSize)
        .contentShape(Circle())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                triggerDisneyReaction(elapsed: elapsed)
            }
        )
        .gesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named("GardenStudioCanvas"))
                .onChanged { value in
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        if !isDraggingFlower {
                            dragReleaseOffset = .zero
                            dragReleaseVelocity = .zero
                            isDraggingFlower = true
                            dragStartTipPos = currentTip
                            onDragStateChanged?(true)
                        }
                        let startPos = dragStartTipPos ?? currentTip
                        let rawX = startPos.x + value.translation.width
                        let rawY = startPos.y + value.translation.height
                        let clampedX = max(safeMargin, min(screenW - safeMargin, rawX))
                        let clampedY = max(safeMargin, min(screenH - safeMargin, rawY))
                        activeFlowerDragTip = CGPoint(x: clampedX, y: clampedY)
                    }
                }
                .onEnded { value in
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        let startPos = dragStartTipPos ?? currentTip
                        let rawX = startPos.x + value.translation.width
                        let rawY = startPos.y + value.translation.height
                        let clampedX = max(safeMargin, min(screenW - safeMargin, rawX))
                        let clampedY = max(safeMargin, min(screenH - safeMargin, rawY))

                        // 1. 拖拽花头重新定位：茎杆末端绝对固定，准确记录新持久偏移
                        persistentTipOffset = CGSize(
                            width: clampedX - (currentRoot.x + naturalCurvature),
                            height: clampedY - (currentRoot.y - currentGrowthHeight)
                        )

                        // A small release impulse settles around the newly saved position.
                        let predicted = CGSize(
                            width: value.predictedEndTranslation.width - value.translation.width,
                            height: value.predictedEndTranslation.height - value.translation.height
                        )
                        let predictionLength = hypot(predicted.width, predicted.height)
                        let direction = predictionLength > 2 ? predicted : value.translation
                        let directionLength = max(1, hypot(direction.width, direction.height))
                        let impulse = min(76, 36 + predictionLength * 0.3)
                        dragReleaseOffset = .zero
                        dragReleaseVelocity = CGSize(
                            width: direction.width / directionLength * impulse,
                            height: direction.height / directionLength * impulse
                        )
                        activeFlowerDragTip = nil
                        dragStartTipPos = nil
                        isDraggingFlower = false
                        onDragStateChanged?(false)
                    }
                    onPlacementChange?(currentPlacement)
                }
        )
        .onTapGesture(count: 1) {
            onSelected?()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                showLabel.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([type.titleZh, habitName].compactMap { $0 }.joined(separator: "，"))
        .accessibilityIdentifier("posy-flower-\(type.rawValue)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onSelected?()
            showLabel.toggle()
        }
    }

    // MARK: - 2-4 随机摇头与抖动动力学 (精准限定于植物 2-4，平时绝对零微颤)
    /// 解决全员微震问题：
    /// 1. 严格限定仅植物 2（蒲公英）及植物 3、4 在阶段 4 偶发响应，其余植物全部为 0 绝对静止；
    /// 2. 平时状态 burstIntensity 绝对为 0.0，杜绝任何待机微幅颤动；
    /// 3. 仅在偶发波峰时平滑触发 2-4 次左右轻晃并平滑归零。
    private func computeHeadShakeAndJitter(
        t: Double,
        seedD: Double,
        progress: Double,
        isDragging: Bool
    ) -> (angle: Double, stemWiggle: CGSize, jitter: CGSize, flutter: Double) {
        guard !isDragging else { return (.zero, .zero, .zero, 0) }

        // 严格限定仅植物 2（.dandelion / 珊瑚伞花第 4 阶段 2-4）响应；其余所有植物绝不抖动
        let isEligibleType = (type == .dandelion)
        guard isEligibleType else { return (.zero, .zero, .zero, 0) }

        // 阶段 4 门控：仅在 2-4 全盛期 (progress >= 0.72) 偶发触发，阶段 1-3 保持完全静止
        guard progress >= 0.72 else { return (.zero, .zero, .zero, 0) }

        // 偶发间歇性脉冲包络：平时绝对为 0.0，杜绝全员持续高频微颤
        let w1 = sin(t * 0.95 + seedD * 2.3)
        let w2 = sin(t * 1.55 + seedD * 3.7)
        let rawBurst = w1 * 0.55 + w2 * 0.45

        // 仅在波峰越过 0.48 时短时触发 (约 1.2 秒脉冲，随后完全平滑归零)
        guard rawBurst > 0.48 else { return (.zero, .zero, .zero, 0) }
        let u = (rawBurst - 0.48) / 0.52
        let burstIntensity = sin(u * .pi) // 铃形包络：两头绝对为 0，中间平缓升降

        // 摇头动效 (2-4 次花头左右轻晃，茎杆保持静止不摇摆)
        let shakeWave = sin(t * 12.0 + seedD * 2.3)
        let maxAngle: Double = 0.16 // ~9.1 度
        let headAngle = shakeWave * maxAngle * burstIntensity

        // 高频微颤 (仅在摇头峰值伴随轻微柔和颤意)
        let jitterX = CGFloat(sin(t * 70.0 + seedD) * 1.0 * burstIntensity)
        let jitterY = CGFloat(cos(t * 80.0 + seedD) * 0.6 * burstIntensity)
        let jitterAngle = sin(t * 90.0) * 0.02 * burstIntensity

        return (
            angle: headAngle + jitterAngle,
            stemWiggle: .zero, // 严格保持茎杆稳固，抖动时绝不产生茎杆左右来回摇摆
            jitter: CGSize(width: jitterX, height: jitterY),
            flutter: sin(t * 24.0) * 0.15 * burstIntensity
        )
    }

    // MARK: - 6-4 琥珀金阳周期性 Y 轴微旋动力学
    /// 规则：以中点圆心为中心，间隔时间微微以 Y 轴旋转并回到原位。
    /// 1. 严格门控：仅作用于植物 6 (金琥珀阳 .mimosa) 在阶段 4 (progress >= 0.75)；
    /// 2. 拖拽时立即静止归零 (0 度)；
    /// 3. 平时静息原位 (0 度)，以约 5.5 秒为周期：静息约 3.5 秒后，平滑以 Y 轴展开约 28 度微旋，再顺滑复原至 0 度。
    private func computeMimosaYRotation(
        t: Double,
        progress: Double,
        isDragging: Bool
    ) -> Double {
        guard !isDragging else { return 0.0 }
        guard type == .mimosa, progress >= 0.75 else { return 0.0 }

        // 周期设定：在 animTime 体系下 (已由 stage4AnimSpeed=0.35 调速)
        // 设周期 T = 2.0 (对应真实世界耗时 2.0 / 0.35 ≈ 5.7 秒)
        let period = 2.0
        let phaseInCycle = t.truncatingRemainder(dividingBy: period)
        let normPhase = phaseInCycle < 0 ? (phaseInCycle + period) : phaseInCycle

        // 旋转窗口：每周期内静止 1.25 (约 3.6 秒)，微旋动效 0.75 (约 2.1 秒)
        let activeDuration = 0.75
        let restDuration = period - activeDuration

        guard normPhase > restDuration else {
            return 0.0 // 原位静止间歇期
        }

        // 归一化旋动进度 0.0 ~ 1.0
        let u = (normPhase - restDuration) / activeDuration

        // 升余弦平滑包络 (两端一阶导数严格为 0，启停完全平滑无顿挫)：
        let env = 0.5 * (1.0 - cos(2.0 * .pi * u))

        // 奇偶周期微交替旋转方向 (+28° 与 -28°)，增添自然生动呼吸感
        let cycleIdx = Int(floor(t / period))
        let direction: Double = (cycleIdx % 2 == 0) ? 1.0 : -1.0

        let maxAngleDegrees: Double = 28.0
        return direction * maxAngleDegrees * env
    }

    // MARK: - 迪士尼双击灵动动力学计算 (Waggle + Rules A/B/C)
    private func computeDisneyKinematics(
        elapsed: Double,
        animStart: Double?,
        rule: PosyDisneyRule
    ) -> (waggle: Double, scaleX: CGFloat, scaleY: CGFloat, hopY: CGFloat, jitter: CGSize, flutter: Double) {
        guard let animStart = animStart else {
            return (0.0, 1.0, 1.0, 0.0, .zero, 0.0)
        }
        let t = elapsed - animStart
        guard t >= 0 && t <= 2.0 else {
            return (0.0, 1.0, 1.0, 0.0, .zero, 0.0)
        }

        // 1. 经典迪士尼拟人化“摇摇头” (Cute Disney Head Waggle):
        // 快速左右摆头 3~4 次，带自然指数平滑衰减
        let waggleDecay = exp(-t * 3.8)
        let waggle = sin(t * 22.0) * waggleDecay * 0.28 // ±16度

        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
        var hopY: CGFloat = 0.0
        var jitter: CGSize = .zero
        var flutter: Double = 0.0

        switch rule {
        case .dewSplash:
            // 规则 1: 晶莹水珠随摆头甩出，微幅身体后仰并前倾
            let nodDecay = exp(-t * 3.2)
            hopY = sin(t * 14.0) * nodDecay * 3.5

        case .squishyShiver:
            // 规则 2: 全身触电微颤 (小元素高频颤抖与毛绒蓬松感)
            let shiverDecay = exp(-t * 3.6)
            let sx = sin(t * 38.0) * shiverDecay * 4.5
            let sy = cos(t * 40.0) * shiverDecay * 3.2
            jitter = CGSize(width: sx, height: sy)
            flutter = sin(t * 44.0) * shiverDecay * 0.75

        case .squashAndStretch:
            // 规则 3: 经典挤压与拉伸收缩 (Squash & Stretch)
            if t < 0.22 {
                // 预备向下挤压压缩
                let p = t / 0.22
                scaleX = 1.0 + CGFloat(p) * 0.24
                scaleY = 1.0 - CGFloat(p) * 0.26
                hopY = CGFloat(p) * 4.0
            } else if t < 0.48 {
                // 爆发弹起向上拉伸
                let p = (t - 0.22) / 0.26
                scaleX = 1.24 - CGFloat(p) * 0.44
                scaleY = 0.74 + CGFloat(p) * 0.52
                hopY = -CGFloat(sin(p * .pi)) * 14.0
            } else {
                // 弹性果冻回弹稳定
                let dt = t - 0.48
                let decay = exp(-dt * 4.5)
                let wobble = sin(dt * 18.0) * decay * 0.22
                scaleX = 1.0 - CGFloat(wobble)
                scaleY = 1.0 + CGFloat(wobble)
                hopY = 0.0
            }
        }

        return (waggle, scaleX, scaleY, hopY, jitter, flutter)
    }

    // MARK: - 触发迪士尼灵动双击反馈 (摇摇头 + 洒几滴水 / 触电轻颤 / 挤压拉伸收缩)
    private func triggerDisneyReaction(elapsed: Double) {
        disneyAnimStartTime = elapsed
        let chosenRule = PosyDisneyRule.allCases.randomElement() ?? .dewSplash
        activeDisneyRule = chosenRule

        if chosenRule == .dewSplash {
            let dropCount = Int.random(in: 3...5)
            var drops: [PosyDewDrop] = []
            for _ in 0..<dropCount {
                let angle = Double.random(in: -Double.pi * 0.88 ... -Double.pi * 0.12)
                let speed = Double.random(in: 70...140)
                let vx = cos(angle) * speed
                let vy = sin(angle) * speed
                drops.append(
                    PosyDewDrop(
                        birthTime: elapsed,
                        lifetime: Double.random(in: 1.2...1.8),
                        startOffset: CGPoint(
                            x: CGFloat.random(in: -10...10),
                            y: CGFloat.random(in: -10...10)
                        ),
                        velocity: CGVector(dx: vx, dy: vy),
                        radius: CGFloat.random(in: 2.2...3.8),
                        color: Color(red: 0.45, green: 0.78, blue: 0.98).opacity(0.85)
                    )
                )
            }
            activeDewDrops = drops
        } else {
            activeDewDrops.removeAll()
        }
    }
}

// MARK: - 迪士尼动画灵动规则类型
public enum PosyDisneyRule: Int, CaseIterable {
    case dewSplash = 0        // 规则 1: 晶莹露珠飞溅 (洒几滴水)
    case squishyShiver = 1    // 规则 2: 触电轻颤微抖 (每个小元素高频颤抖)
    case squashAndStretch = 2 // 规则 3: 经典挤压与拉伸收缩 (预备收缩 + 弹起延展回弹)
}

// MARK: - 水滴微粒模型
public struct PosyDewDrop: Identifiable {
    public let id = UUID()
    public let birthTime: Double
    public let lifetime: Double
    public let startOffset: CGPoint
    public let velocity: CGVector
    public let radius: CGFloat
    public let color: Color
}

// MARK: - 晶莹飞溅水珠渲染视图
private struct PosyWaterDropletsView: View {
    let droplets: [PosyDewDrop]
    let elapsed: Double

    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let g: CGFloat = 360.0

            for drop in droplets {
                let age = elapsed - drop.birthTime
                guard age >= 0 && age <= drop.lifetime else { continue }

                let progress = age / drop.lifetime
                let alpha = max(0.0, 1.0 - pow(progress, 1.8))

                let px = c.x + drop.startOffset.x + CGFloat(drop.velocity.dx) * CGFloat(age)
                let py = c.y + drop.startOffset.y + CGFloat(drop.velocity.dy) * CGFloat(age) + 0.5 * g * CGFloat(age * age)

                let r = drop.radius * (1.0 - CGFloat(progress) * 0.35)

                // 1. 水珠折射空灵柔光
                var glow = Path()
                let glowR = r * 1.8
                glow.addEllipse(in: CGRect(x: px - glowR, y: py - glowR, width: glowR * 2, height: glowR * 2))
                context.fill(glow, with: .color(Color(red: 0.55, green: 0.85, blue: 1.0).opacity(0.35 * alpha)))

                // 2. 晶莹水珠本体 (水滴形或微拉长椭圆，随下落速度拉伸)
                let stretch = min(1.6, 1.0 + (CGFloat(drop.velocity.dy) + g * CGFloat(age)) * 0.002)
                var body = Path()
                body.addEllipse(in: CGRect(x: px - r, y: py - r * stretch, width: r * 2, height: r * 2 * stretch))
                context.fill(body, with: .color(Color(red: 0.65, green: 0.88, blue: 1.0).opacity(0.88 * alpha)))
                context.stroke(body, with: .color(Color.white.opacity(0.90 * alpha)), lineWidth: 0.55)

                // 3. 晶莹白亮高光微点
                let hlR = r * 0.40
                var hl = Path()
                hl.addEllipse(in: CGRect(x: px - r * 0.35 - hlR, y: py - r * stretch * 0.35 - hlR, width: hlR * 2, height: hlR * 2))
                context.fill(hl, with: .color(Color.white.opacity(0.95 * alpha)))
            }
        }
    }
}


// MARK: - Continuous wind motion shared by every stem
private struct PosyStemMotionProfile {
    let salt: Double
    let response: Double
    let tiltResponse: Double
    let springRate: Double
    let dampingRatio: Double
    let flutterAmplitude: Double
    let flutterFrequency: Double

    init(seed: Int, floraIndex: Int) {
        let salt = Double(seed) * 17.17 + Double(floraIndex) * 131.31
        self.salt = salt
        response = 0.90 + Self.unitNoise(salt + 1) * 0.20
        tiltResponse = 0.18 + Self.unitNoise(salt + 2) * 0.08
        springRate = 0.88 + Self.unitNoise(salt + 3) * 0.24
        dampingRatio = 0.30 + Self.unitNoise(salt + 4) * 0.12
        flutterAmplitude = 1.8 + Self.unitNoise(salt + 5) * 1.2
        flutterFrequency = 3.0 + Self.unitNoise(salt + 6) * 2.5
    }

    private static func unitNoise(_ value: Double) -> Double {
        let sample = sin(value * 12.9898) * 43758.5453
        return sample - floor(sample)
    }

    // Smooth value noise avoids new random jumps on every rendered frame.
    func noise(at time: Double, channel: Int) -> Double {
        let phase = time * flutterFrequency + salt + Double(channel) * 79.7
        let cell = floor(phase)
        let t = phase - cell
        let blend = t * t * t * (t * (t * 6 - 15) + 10)
        let a = Self.unitNoise(cell)
        let b = Self.unitNoise(cell + 1)
        let slowWave = sin(time * (1.7 + Double(channel) * 0.31) + salt)
        return ((a + (b - a) * blend) * 2 - 1) * 0.8 + slowWave * 0.2
    }

    static func advanceSpring(
        position: Double, velocity: Double, target: Double,
        omega: Double, dampingRatio: Double, dt: Double
    ) -> (Double, Double) {
        let damping = omega * dampingRatio
        let frequency = sqrt(omega * omega - damping * damping)
        let displacement = position - target
        let sine = sin(frequency * dt)
        let cosine = cos(frequency * dt)
        let decay = exp(-damping * dt)
        return (
            target + decay * (displacement * cosine + (velocity + damping * displacement) / frequency * sine),
            decay * (velocity * cosine - (damping * velocity + omega * omega * displacement) / frequency * sine)
        )
    }
}

private struct PosyWindStemCurve {
    let root: CGPoint
    let tip: CGPoint
    let rootLean: CGFloat
    let ripple: CGFloat
    var supportedFraction: CGFloat = 5.0 / 12.0
    var restingSupportFraction: CGFloat = 0.375
    var windBlend: CGFloat = 0

    // Spread the resting bend across the whole stem instead of delaying almost
    // all deflection until above the support region. Stored support still sets
    // each plant's firmness: 10% of lateral deflection at that fraction of height.
    private var restingExponent: CGFloat {
        log(CGFloat(0.10)) / log(restingSupportFraction)
    }

    private func bend(at t: CGFloat) -> CGFloat {
        let resting = pow(t, restingExponent)
        let span = 1 - supportedFraction
        let upper = max(0, (t - supportedFraction) / span)
        let windy = 0.04 * t * t + 0.96 * pow(upper, 2.2)
        return resting + (windy - resting) * windBlend
    }

    private func bendDerivative(at t: CGFloat) -> CGFloat {
        let resting = restingExponent * pow(t, restingExponent - 1)
        let span = 1 - supportedFraction
        let upper = max(0, (t - supportedFraction) / span)
        let windy = 0.08 * t + 0.96 * 2.2 * pow(upper, 1.2) / span
        return resting + (windy - resting) * windBlend
    }

    func point(at t: CGFloat) -> CGPoint {
        CGPoint(
            x: root.x + rootLean * t + (tip.x - root.x - rootLean) * bend(at: t)
                + ripple * t * sin(.pi * t),
            y: root.y + (tip.y - root.y) * t
        )
    }

    func tangent(at t: CGFloat) -> CGPoint {
        CGPoint(
            x: rootLean + (tip.x - root.x - rootLean) * bendDerivative(at: t)
                + ripple * (sin(.pi * t) + .pi * t * cos(.pi * t)),
            y: tip.y - root.y
        )
    }
}
