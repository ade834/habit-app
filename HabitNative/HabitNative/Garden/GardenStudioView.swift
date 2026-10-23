import SwiftUI

// The value lives for the app process only. It resets when the app restarts,
// while later visits to the garden can render without replaying the intro.
private enum GardenIntroPlaybackSession {
    static var hasAutomaticallyPlayed = false
    static var lastSceneSnapshots: [HabitColorTheme: UIImage] = [:]
}

private enum GardenPlantPlacementStore {
    private static let key = "garden.plantPlacements"

    static func load(visibleFlora: Set<String>) -> [String: PosyPlantPlacement] {
        let placements: [String: PosyPlantPlacement]
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([String: PosyPlantPlacement].self, from: data) {
            placements = saved
        } else {
            placements = [:]
        }
        return registering(visibleFlora, in: placements)
    }

    static func registering(_ flora: Set<String>, in saved: [String: PosyPlantPlacement]) -> [String: PosyPlantPlacement] {
        var placements = saved
        for id in flora {
            var placement = placements[id] ?? .zero
            placement.assignSupportIfNeeded()
            placements[id] = placement
        }
        if placements != saved { save(placements) }
        return placements
    }

    static func save(_ placements: [String: PosyPlantPlacement]) {
        guard let data = try? JSONEncoder().encode(placements) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - 8向风向枚举与几何投影 (8-Directional Wind System)
public enum PosyWindDirection8: Int, CaseIterable, Equatable {
    case east = 0       // 右 (0°)
    case southEast = 1  // 右下 (45°)
    case south = 2      // 下 (90°)
    case southWest = 3  // 左下 (135°)
    case west = 4       // 左 (180°)
    case northWest = 5  // 左上 (225° / -135°)
    case north = 6      // 上 (270° / -90°)
    case northEast = 7  // 右上 (315° / -45°)

    public var unitVector: CGVector {
        switch self {
        case .east:      return CGVector(dx: 1.0, dy: 0.0)
        case .southEast: return CGVector(dx: 0.70710678, dy: 0.70710678)
        case .south:     return CGVector(dx: 0.0, dy: 1.0)
        case .southWest: return CGVector(dx: -0.70710678, dy: 0.70710678)
        case .west:      return CGVector(dx: -1.0, dy: 0.0)
        case .northWest: return CGVector(dx: -0.70710678, dy: -0.70710678)
        case .north:     return CGVector(dx: 0.0, dy: -1.0)
        case .northEast: return CGVector(dx: 0.70710678, dy: -0.70710678)
        }
    }

    public static func from(dx: CGFloat, dy: CGFloat) -> PosyWindDirection8 {
        var angle = atan2(Double(dy), Double(dx))
        if angle < 0 { angle += 2.0 * .pi }
        let sector = Int((angle + (.pi / 8.0)) / (.pi / 4.0)) % 8
        return PosyWindDirection8(rawValue: sector) ?? .east
    }
}

// MARK: - 植物养成与美学独立实验室 (Garden Studio View)
/// 本轮核心优化：
/// 1. 修复点击/长按空白吹风 Bug：空白背景手势与植物实时风力双向响应，点击或按住空白即刻吹风并按植物各自特性强烈互动！
/// 2. 植物异质风动：大花头与小花头、长茎与短茎受风倾角和晃动周期截然不同；
/// 3. 花茎左右自然随机弯曲，同种植物多次出现高度与弧度皆有区分；
/// 4. 花头绝对绑定在茎秆最上端，回弹丝滑无延迟差；
public struct GardenStudioView: View {
    let embedded: Bool
    let plantProgress: [String: Double]
    let visibleFlora: Set<String>
    let habitNames: [String: String]
    let onSelectFlora: ((PosyFloraType) -> Void)?
    let onIntroVisibilityChange: ((Bool) -> Void)?
    let onSharePhoto: ((UIImage) -> Void)?
    @Environment(\.habitColorTheme) private var colorTheme
    @Environment(\.habitBackgroundFrame) private var backgroundFrame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSoundSettings.storageKey) private var soundEffectsEnabled = true
    @State private var selectedFlora: PosyFloraType = .mimosa
    @State private var windSound = AppSoundFeedback()
    @State private var growthProgress: Double = 0.95
    @State private var isMultiBouquetMode: Bool = true
    @State private var showControlDeck: Bool = true
    @State private var studioResetToken: Int = 0

    // 模拟数据源（对应数据库真实模型 Goal / HabitGardenItem）
    @State private var simulatedPoints: Int = 8
    @State private var simulatedCompletions: Int = 12

    // 交互风力与微粒系统：持续按压 0.25 秒以上触发吹风与微粒位移
    private let windPressTriggerThreshold: Double = 0.25
    @State private var blankTouchStartTime: Double? = nil
    @State private var blankTouchStartPos: CGPoint? = nil
    @State private var isPressingBlank: Bool = false
    @State private var hasTriggeredWindThisTouch: Bool = false
    @State private var windTriggerTimerWorkItem: DispatchWorkItem? = nil

    // 八向风向平滑插值与防误触死区
    @State private var windDirection: Double = 1.0            // +1.0 向右吹，-1.0 向左吹 (兼容标量)
    @State private var targetWindVector: CGVector = CGVector(dx: 1.0, dy: 0.0)
    @State private var directionChangeStartVector: CGVector = CGVector(dx: 1.0, dy: 0.0)
    @State private var directionChangeStartTime: Double = 0.0 // 换向起点时间戳
    @State private var lastDragPoint: CGPoint? = nil          // 手指上一帧拖拽坐标
    @State private var accumulatedDragVector: CGVector = .zero // 累积 2D 拖拽位移 (死区防抖)
    private let dragDirectionHysteresisThreshold: CGFloat = 32.0 // 换向触发死区 (32pt，防敏感抖动)

    // 流动位移分段积分基准
    @State private var flowSegmentStartTime: Double = 0.0     // 当前风向流动段起始时间

    @State private var lastReleaseTime: Double = -100.0       // 最近一次放手时间戳
    @State private var lastReleaseWindIntensity: Double = 0.0 // 放手瞬间风力强度 (0.0 ~ 1.0)
    @State private var lastReleaseWindVector: CGVector = CGVector(dx: 1.0, dy: 0.0)
    @State private var baseWindFlowOffsetX: Double = 0.0      // 持续累积的风向水平位移量
    @State private var baseWindFlowOffsetY: Double = 0.0      // 持续累积的风向垂直位移量
    @State private var touchDragLocation: CGPoint? = nil
    @State private var touchDragDistance: CGFloat = 0.0       // 手指滑动距离 (滑动越长，风力与抖动越大)

    // 右上角吹风气泡提示胶囊
    @State private var isWindHintVisible: Bool = false
    @State private var windHintDismissWorkItem: DispatchWorkItem? = nil

    // 拖拽防背景误触标志位 (仅被拖拽花朵自身静止动画，其他花朵与生灵照旧运行)
    @State private var isAnyFlowerDragging: Bool = false

    // 点击空白处生成的浅玫红/浅橙带光晕漂浮粒子
    @State private var floatingHaloParticles: [PosyFloatingHaloParticle] = []

    // 电影级门扉漫游入场转场状态
    @State private var introStartTime: Double? = nil        // 漫游起始时间戳 (由首帧或重播驱动)
    @State private var isIntroSkipped: Bool = false         // 用户是否点击跳过
    @State private var cachedStageSnapshot: UIImage? = nil  // 漫游穿门期间静态快照缓存 (闪白前展示，闪白达峰后换入实时动画)
    @State private var plantPlacements: [String: PosyPlantPlacement]
    @State private var isActionMenuExpanded = false
    @State private var isContinuousWindEnabled = false
    @State private var continuousWindStartTime: Double?

    public init(embedded: Bool = false, plantProgress: [String: Double] = [:], visibleFlora: Set<String> = Set(PosyFloraType.allCases.map(\.rawValue)), habitNames: [String: String] = [:], onSelectFlora: ((PosyFloraType) -> Void)? = nil, onIntroVisibilityChange: ((Bool) -> Void)? = nil, onSharePhoto: ((UIImage) -> Void)? = nil) {
        self.embedded = embedded
        self.plantProgress = plantProgress
        self.visibleFlora = visibleFlora
        self.habitNames = habitNames
        self.onSelectFlora = onSelectFlora
        self.onIntroVisibilityChange = onIntroVisibilityChange
        self.onSharePhoto = onSharePhoto
        _plantPlacements = State(initialValue: GardenPlantPlacementStore.load(visibleFlora: visibleFlora))
        if CommandLine.arguments.contains("--skip-intro") {
            _isIntroSkipped = State(initialValue: true)
            _introStartTime = State(initialValue: Date().timeIntervalSinceReferenceDate - 10.0)
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            let canvasWidth = proxy.size.width
            let canvasHeight = proxy.size.height
            let stageFrame = proxy.frame(in: .global)
            let viewport = !backgroundFrame.isEmpty ? backgroundFrame : stageFrame
            let particleCanvasFrame = CGRect(
                x: viewport.minX - stageFrame.minX,
                y: viewport.minY - stageFrame.minY,
                width: viewport.width,
                height: viewport.height
            )
            let effectiveSafeAreaTop = resolvedSafeAreaTop(proxyTop: proxy.safeAreaInsets.top)

            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate

                // 电影级门扉漫游进程计算 (120 FPS 高帧率自适应，毫无卡顿)
                let introProgress: Double = {
                    if isIntroSkipped || reduceMotion { return 1.0 }
                    guard let start = introStartTime else { return 0.0 }
                    let age = max(0.0, elapsed - start)
                    let holdDuration = 1.60 // 初始暗室远景驻留 1.60s 细赏斜照阳光与微尘
                    let walkDuration = 3.60 // 闪白延长 1.5 倍从容走近并穿门 3.60s
                    if age < holdDuration { return 0.0 }
                    let rawT = min(1.0, (age - holdDuration) / walkDuration)
                    return rawT
                }()

                // 镜头拉近动力学 (门洞调小 25% 对应远景微缩至 0.26)：
                // 0.00 -> 0.12: 远景微缩 (0.26)
                // 0.12 -> 0.46: 从容走近门前 (0.26 -> 0.60)
                // 0.46 -> 0.72: 视线穿门跨越，直接平滑缩放到 1.0 满屏 (0.60 -> 1.00)
                // 0.72 -> 1.00: 已经完全到位并直接接入最终页面，不再发生任何缩放或跳变！
                let gardenScale: CGFloat = {
                    if introProgress < 0.12 {
                        return 0.30
                    } else if introProgress < 0.46 {
                        let t = (introProgress - 0.12) / (0.46 - 0.12)
                        return 0.30 + 0.30 * (t * t * (3.0 - 2.0 * t))
                    } else if introProgress < 0.72 {
                        let t = (introProgress - 0.46) / (0.72 - 0.46)
                        return 0.60 + 0.40 * (t * t * (3.0 - 2.0 * t))
                    } else {
                        return 1.00 // 直接接入页面花的位置，杜绝任何尺寸跳变与渐变叠加闪出
                    }
                }()

                // 远景阶段画面尽量靠中下 (0.705)，走近过程中平滑升至 0.54 与主页面舞台无缝吻合
                let stageAnchorY: CGFloat = {
                    if introProgress < 0.12 {
                        return 0.705 // 远景画面靠中下
                    } else if introProgress < 0.72 {
                        let t = (introProgress - 0.12) / (0.72 - 0.12)
                        let smoothT = t * t * (3.0 - 2.0 * t)
                        return 0.705 - (0.705 - 0.54) * smoothT
                    } else {
                        return 0.54
                    }
                }()
                let stageAnchor = UnitPoint(x: 0.5, y: stageAnchorY)

                ZStack(alignment: .bottom) {
                    // The shared root canvas stays visible behind the garden.
                    if embedded {
                        Color.clear
                            .ignoresSafeArea()
                    } else {
                        PosyLiquidEtherealBackground()
                            .ignoresSafeArea()
                    }

                    // 2. 核心植物展示舞台 (Stage)
                    let isWindActiveFromPress = isPressingBlank && (max(0.0, elapsed - (blankTouchStartTime ?? elapsed)) >= windPressTriggerThreshold)
                    let isWindActive = isWindActiveFromPress || isContinuousWindEnabled

                    // 1. 计算长按与手指滑动蓄积的主动风力强度 (风力整体 0.5x，0.0 ~ 1.2)
                    let currentWindPower: Double = {
                            if isContinuousWindEnabled { return 0.5 }
                            let pressDuration = blankTouchStartTime != nil ? max(0.0, elapsed - blankTouchStartTime!) : 0.0
                            if isPressingBlank && pressDuration >= windPressTriggerThreshold {
                                let timeRamp = min(1.0, (pressDuration - windPressTriggerThreshold) / 0.40)
                                let dragRatio = min(1.8, Double(touchDragDistance / 90.0))
                                return max(0.0, min(1.2, timeRamp * (0.45 + 0.95 * dragRatio) * 0.5))
                            } else {
                                let relTime = max(0.0, elapsed - lastReleaseTime)
                                return lastReleaseWindIntensity * exp(-relTime * 2.2)
                            }
                        }()

                    // 2. 随机自然阵风起伏波浪 (模拟风力忽大忽小，程度不一)：
                    // 主阵风周期 ~2.4s，次谐波 ~1.1s，高频涡流 ~0.38s
                    let gustTurbulence: Double = {
                        let wave1 = 0.50 * sin(elapsed * 2.6)
                        let wave2 = 0.32 * sin(elapsed * 5.7 + 1.2)
                        let wave3 = 0.18 * sin(elapsed * 12.4 + 2.5)
                        return 0.85 + 0.45 * (wave1 + wave2 + wave3) // 动态起伏区间 0.40 ~ 1.30
                    }()

                    let smoothVector = currentSmoothWindVector(at: elapsed)
                    let activeWindVector = isWindActive ? smoothVector : lastReleaseWindVector
                    let dynamicGustWindX = currentWindPower * gustTurbulence * activeWindVector.dx
                    let dynamicGustWindY = currentWindPower * gustTurbulence * activeWindVector.dy

                    // 3. 背景微球随风 2D 位移计算 (连续流动，整体 0.5x 流速，未满 0.25 秒按压不产生位移；风停后保持在新位置，不回到原位)：
                    let (currentFlowOffsetX, currentFlowOffsetY) = currentFlowOffset(at: elapsed)

                    ZStack(alignment: .bottom) {
                        if introProgress < 0.78 {
                            // 开场漫游穿门阶段 (p < 0.78)：背后仅渲染静态快照/冻结展台，杜绝 12 株植物 120 FPS 矢量重绘计算
                            if let snapshot = cachedStageSnapshot {
                                Image(uiImage: snapshot)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: canvasWidth, height: canvasHeight)
                                    .clipped()
                                    .allowsHitTesting(false)
                            } else {
                                PosyStaticGardenStageView(
                                    canvasWidth: canvasWidth,
                                    canvasHeight: canvasHeight,
                                    growthProgress: growthProgress,
                                    isMultiBouquetMode: isMultiBouquetMode,
                                    selectedFlora: selectedFlora,
                                    studioResetToken: studioResetToken,
                                    plantProgress: plantProgress,
                                    visibleFlora: visibleFlora,
                                    plantPlacements: plantPlacements,
                                    showsAmbientBokeh: false
                                )
                                .equatable()
                                .allowsHitTesting(false)
                            }
                        } else {
                            // 满白驻留缓冲期内 (p = 0.78，此时屏幕为 100% 满白遮罩) 瞬切入实时植物物理动画，彻底掩盖视觉差！
                            liveGardenStage(
                                canvasWidth: canvasWidth,
                                canvasHeight: canvasHeight,
                                particleCanvasFrame: particleCanvasFrame,
                                elapsed: elapsed,
                                currentFlowOffsetX: currentFlowOffsetX,
                                currentFlowOffsetY: currentFlowOffsetY,
                                dynamicGustWindX: dynamicGustWindX,
                                dynamicGustWindY: dynamicGustWindY,
                                currentWindPower: currentWindPower,
                                introProgress: introProgress
                            )
                        }
                    }
                    .frame(width: canvasWidth, height: canvasHeight)
                    .background(alignment: .topLeading) {
                        if introProgress >= 0.78 {
                            PosyAmbientBokehParticles(
                                elapsed: elapsed,
                                flowOffsetX: currentFlowOffsetX,
                                flowOffsetY: currentFlowOffsetY
                            )
                            // 使用根背景的实际屏幕边界，不依赖嵌套安全区的 inset。
                            .frame(width: particleCanvasFrame.width, height: particleCanvasFrame.height)
                            .offset(x: particleCanvasFrame.minX, y: particleCanvasFrame.minY)
                            .allowsHitTesting(false)
                        }
                    }
                    .coordinateSpace(name: "GardenStudioCanvas")
                    // 空白区域触控层：短促轻点触发散花光晕粒子；手指长按与拖拽激发生动多频阵风！全屏幕触控覆盖
                    .contentShape(Path(particleCanvasFrame))
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("GardenStudioCanvas"))
                        .onChanged { value in
                            guard !isAnyFlowerDragging else { return }
                            let now = Date().timeIntervalSinceReferenceDate
                            if blankTouchStartTime == nil {
                                blankTouchStartTime = now
                                blankTouchStartPos = value.startLocation
                                lastDragPoint = value.location
                                accumulatedDragVector = .zero
                                isPressingBlank = true
                                hasTriggeredWindThisTouch = false

                                // 启动 0.25 秒长按吹风定时器（即使手指完全静止也能精准触发）
                                let startPos = value.startLocation
                                let timerItem = DispatchWorkItem {
                                    guard self.isPressingBlank, !self.hasTriggeredWindThisTouch else { return }
                                    self.hasTriggeredWindThisTouch = true
                                    self.windSound.startWindLoop(enabled: self.soundEffectsEnabled)
                                    let fireTime = Date().timeIntervalSinceReferenceDate
                                    self.flowSegmentStartTime = fireTime
                                    let initialDirX = (startPos.x < canvasWidth * 0.5) ? 1.0 : -1.0
                                    self.updateTargetWindVector(to: CGVector(dx: initialDirX, dy: 0.0), elapsed: fireTime)
                                    self.showWindHint()
                                }
                                windTriggerTimerWorkItem = timerItem
                                DispatchQueue.main.asyncAfter(deadline: .now() + windPressTriggerThreshold, execute: timerItem)
                            }
                            touchDragLocation = value.location

                            let pressDuration = now - (blankTouchStartTime ?? now)
                            let translation = value.translation
                            let dragDist = hypot(translation.width, translation.height)
                            touchDragDistance = dragDist

                            // 手指微位移累计与八向死区检测 (防抖动，不敏感情感式跟随)
                            if let prevPoint = lastDragPoint {
                                let dx = value.location.x - prevPoint.x
                                let dy = value.location.y - prevPoint.y
                                accumulatedDragVector.dx += dx
                                accumulatedDragVector.dy += dy

                                let dragMag = hypot(accumulatedDragVector.dx, accumulatedDragVector.dy)
                                if dragMag >= dragDirectionHysteresisThreshold {
                                    let dir8 = PosyWindDirection8.from(dx: accumulatedDragVector.dx, dy: accumulatedDragVector.dy)
                                    let newUnitVec = dir8.unitVector
                                    let dot = newUnitVec.dx * targetWindVector.dx + newUnitVec.dy * targetWindVector.dy
                                    if dot < 0.82 { // 夹角约 35 度以上才触发换向，防敏感
                                        updateTargetWindVector(to: newUnitVec, elapsed: now)
                                    }
                                    accumulatedDragVector = .zero
                                }
                            }
                            lastDragPoint = value.location

                            if pressDuration >= windPressTriggerThreshold {
                                if !hasTriggeredWindThisTouch {
                                    hasTriggeredWindThisTouch = true
                                    windSound.startWindLoop(enabled: soundEffectsEnabled)
                                    flowSegmentStartTime = now
                                    windTriggerTimerWorkItem?.cancel()
                                    windTriggerTimerWorkItem = nil
                                    showWindHint()

                                    // 初始风向判定
                                    if hypot(translation.width, translation.height) >= dragDirectionHysteresisThreshold {
                                        let dir8 = PosyWindDirection8.from(dx: translation.width, dy: translation.height)
                                        updateTargetWindVector(to: dir8.unitVector, elapsed: now)
                                    } else {
                                        let initialDirX = (value.location.x < canvasWidth * 0.5) ? 1.0 : -1.0
                                        updateTargetWindVector(to: CGVector(dx: initialDirX, dy: 0.0), elapsed: now)
                                    }
                                }
                            }
                        }
                        .onEnded { value in
                            windTriggerTimerWorkItem?.cancel()
                            windTriggerTimerWorkItem = nil
                            windSound.stopWindLoop()

                            guard !isAnyFlowerDragging else { return }
                            let now = Date().timeIntervalSinceReferenceDate
                            let pressDuration = now - (blankTouchStartTime ?? now)
                            let dragDist = hypot(value.translation.width, value.translation.height)

                            if pressDuration < windPressTriggerThreshold {
                                if dragDist < 12 {
                                    // 短促点击（持续按压未满 0.25 秒）：在初始触碰点精准生成浅玫红/浅橙带光晕漂浮粒子
                                    let tapOrigin = value.startLocation
                                    let (flowX, flowY) = currentFlowOffset(at: now)
                                    spawnFloatingParticles(at: tapOrigin, flowOffsetX: flowX, flowOffsetY: flowY)
                                }
                                // 未满 0.25 秒绝对不触发任何吹风与风力惯性，不修改 baseWindFlowOffset 和 lastReleaseTime
                            } else {
                                // 持续按压 >= 0.25 秒：吹风结束，计算释放惯性与风力衰减 (整体风力 0.5x)
                                let finalVector = currentSmoothWindVector(at: now)
                                let segStart = max((blankTouchStartTime ?? now) + windPressTriggerThreshold, flowSegmentStartTime)
                                let segDt = max(0.0, now - segStart)
                                let timeRamp = min(1.0, (pressDuration - windPressTriggerThreshold) / 0.40)
                                let dragRatio = min(1.8, Double(dragDist / 90.0))
                                let releasePower = max(0.0, min(1.2, timeRamp * (0.45 + 0.95 * dragRatio) * 0.5))

                                let speed = 175.0 * (1.0 + dragRatio * 0.6)
                                let pressFlowDeltaX = finalVector.dx * speed * segDt
                                let pressFlowDeltaY = finalVector.dy * speed * segDt
                                let relTime = max(0.0, now - lastReleaseTime)
                                let inertiaDecay = (1.0 - exp(-relTime * 2.2)) / 2.2 * 175.0 * lastReleaseWindIntensity

                                baseWindFlowOffsetX += (pressFlowDeltaX + inertiaDecay * lastReleaseWindVector.dx)
                                baseWindFlowOffsetY += (pressFlowDeltaY + inertiaDecay * lastReleaseWindVector.dy)

                                lastReleaseTime = now
                                lastReleaseWindIntensity = releasePower
                                lastReleaseWindVector = finalVector
                            }

                            blankTouchStartTime = nil
                            blankTouchStartPos = nil
                            isPressingBlank = false
                            touchDragLocation = nil
                            touchDragDistance = 0.0
                            lastDragPoint = nil
                            accumulatedDragVector = .zero
                            hasTriggeredWindThisTouch = false
                            flowSegmentStartTime = 0.0
                        }
                )
                .scaleEffect(gardenScale, anchor: stageAnchor)
                // The standalone scene starts at the screen origin. In the host
                // app, compensate its safe-area origin while viewing the portal;
                // resolve the correction under the existing white-light transition.
                .offset(y: embedded ? -proxy.safeAreaInsets.top * max(0, 1 - introProgress / 0.72) : 0)
                .allowsHitTesting(introProgress >= 0.92)

                // 4. 底部控制面板与轻量展开入口 (入场完成前淡隐防遮挡)
                if showControlDeck && !embedded {
                    controlDeckPanel(safeAreaBottom: proxy.safeAreaInsets.bottom)
                        .opacity(introProgress >= 0.92 ? (introProgress - 0.92) / 0.08 : 0.0)
                        .offset(y: introProgress >= 0.92 ? 0 : 50)
                        .zIndex(4000)
                } else if introProgress >= 0.90 && !embedded {
                    // 当控制面板收起时，在右下角保留轻量快捷悬浮展开胶囊，避免控制入口缺失
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showControlDeck = true
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("展开控制台")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(Color(red: 0.30, green: 0.20, blue: 0.30))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.92))
                                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                                )
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, max(34.0, proxy.safeAreaInsets.bottom) + 12.0)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(4000)
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
            // 3. 顶部独立层：标题与操作按钮严格遵守 Apple 安全范围规则，置于系统栏下方独立分层渲染
            .overlay(alignment: .top) {
                topHeaderBar(safeAreaTop: effectiveSafeAreaTop, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
                    .opacity(introProgress >= 0.90 ? (introProgress - 0.90) / 0.10 : 0.0)
                    .offset(y: introProgress >= 0.90 ? 0 : -30)
                    .zIndex(5000)
            }
            // Keep the portal out of the ZStack's layout calculation. Its
            // safe-area-spanning bounds used to move the entire live stage
            // when the portal disappeared at the end of the intro.
            .overlay {
                if introProgress < 1.0 {
                    PosyCinematicDoorIntroView(
                        usesLavenderPalette: colorTheme == .lavender,
                        progress: introProgress,
                        canvasSize: CGSize(width: canvasWidth, height: canvasHeight + proxy.safeAreaInsets.top),
                        doorLayoutHeight: canvasHeight,
                        interiorSnapshot: cachedStageSnapshot,
                        elapsed: elapsed,
                        safeAreaTop: proxy.safeAreaInsets.top,
                        onSkip: {
                            skipDoorIntro()
                        }
                    )
                    .ignoresSafeArea()
                }
            }
            .onChange(of: introProgress >= 0.98, initial: true) { _, ready in
                onIntroVisibilityChange?(!ready)
            }
        }
        .task(id: "\(canvasWidth)_\(canvasHeight)_\(growthProgress)_\(isMultiBouquetMode)_\(selectedFlora.rawValue)_\(studioResetToken)_\(colorTheme.rawValue)_\(plantProgress.sorted(by: { $0.key < $1.key }).description)") {
            updateStageSnapshot(width: canvasWidth, height: canvasHeight)
        }
        .onChange(of: colorTheme) { _, _ in
            cachedStageSnapshot = nil
            updateStageSnapshot(width: canvasWidth, height: canvasHeight)
        }
        .onAppear {
            if let lastSceneSnapshot = GardenIntroPlaybackSession.lastSceneSnapshots[colorTheme] {
                cachedStageSnapshot = lastSceneSnapshot
            }
            if CommandLine.arguments.contains("--skip-intro") {
                isIntroSkipped = true
                introStartTime = Date().timeIntervalSinceReferenceDate - 10.0
            } else if introStartTime == nil {
                if GardenIntroPlaybackSession.hasAutomaticallyPlayed {
                    isIntroSkipped = true
                } else {
                    GardenIntroPlaybackSession.hasAutomaticallyPlayed = true
                    introStartTime = Date().timeIntervalSinceReferenceDate
                }
            }
            updateStageSnapshot(width: canvasWidth, height: canvasHeight)

            if CommandLine.arguments.contains("--test-wind-right") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    triggerSimulatedWindGust(duration: 5.0, direction: 1.0)
                }
            } else if CommandLine.arguments.contains("--test-wind-left") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    triggerSimulatedWindGust(duration: 5.0, direction: -1.0)
                }
            } else if CommandLine.arguments.contains("--test-tap") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    let w = canvasWidth > 50 ? canvasWidth : 393.0
                    let h = canvasHeight > 50 ? canvasHeight : 852.0
                    spawnFloatingParticles(at: CGPoint(x: w * 0.32, y: h * 0.35))
                    spawnFloatingParticles(at: CGPoint(x: w * 0.68, y: h * 0.28))
                    spawnFloatingParticles(at: CGPoint(x: w * 0.25, y: 28.0)) // 顶栏状态栏安全区生成
                    spawnFloatingParticles(at: CGPoint(x: w * 0.75, y: h - 35.0)) // 底栏触控条安全区生成
                }
            } else if CommandLine.arguments.contains("--test-post-wind-tap") {
                // 1. 先触发 2.5 秒的右向风
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    triggerSimulatedWindGust(duration: 2.5, direction: 1.0)
                }
                // 2. 在风停且惯性完全衰减后 (5.5 秒)，精准点击屏幕中央 (0.50, 0.45) 生成光球
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                    let w = canvasWidth > 50 ? canvasWidth : 393.0
                    let h = canvasHeight > 50 ? canvasHeight : 852.0
                    spawnFloatingParticles(at: CGPoint(x: w * 0.50, y: h * 0.45))
                }
            }

            // 漫游进场完全展开后 (5.8s)，自动触发一组点击光点以即时展现生动效果
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.8) {
                let w = canvasWidth > 50 ? canvasWidth : 393.0
                let h = canvasHeight > 50 ? canvasHeight : 852.0
                spawnFloatingParticles(at: CGPoint(x: w * 0.32, y: h * 0.35))
                spawnFloatingParticles(at: CGPoint(x: w * 0.68, y: h * 0.28))
            }
        }
        .onChange(of: visibleFlora) { _, flora in
            plantPlacements = GardenPlantPlacementStore.registering(flora, in: plantPlacements)
        }
        .onChange(of: soundEffectsEnabled) { _, enabled in
            if enabled, isPressingBlank, hasTriggeredWindThisTouch {
                windSound.startWindLoop(enabled: true)
            } else if !enabled {
                windSound.stop()
            }
        }
        .onDisappear {
            windSound.stopWindLoop()
            windTriggerTimerWorkItem?.cancel()
            captureLastGardenSceneSnapshot(width: canvasWidth, height: canvasHeight)
            GardenPlantPlacementStore.save(plantPlacements)
        }
    }
    .ignoresSafeArea(.container, edges: .all)
}

    // MARK: - 实时植物舞台 (闪白达峰后正式启动 120 FPS 物理风动与粒子渲染)
    @ViewBuilder
    private func liveGardenStage(
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        particleCanvasFrame: CGRect,
        elapsed: Double,
        currentFlowOffsetX: Double,
        currentFlowOffsetY: Double,
        dynamicGustWindX: Double,
        dynamicGustWindY: Double,
        currentWindPower: Double,
        introProgress: Double
    ) -> some View {
        ZStack(alignment: .bottom) {
            // 底部发光水晶浅盘 (底部区域收窄 25%)
            PosyGlassVesselSaucer()
                .frame(width: canvasWidth * 0.66, height: 80)
                .position(x: canvasWidth * 0.5, y: canvasHeight * 0.65)

            // 植物渲染：每株植物晃动时间、弯曲弧度与回弹速度差异巨大，明显可辨
            if isMultiBouquetMode {
                multiBouquetView(
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    elapsed: elapsed
                )
                .id(studioResetToken)
            } else {
                // 单株精细调校模式
                let stemH: CGFloat = 240
                let stemCompliance = selectedFlora.stemFlexFactor * Double(stemH / 200.0)
                let singleWindForceX = dynamicGustWindX
                let singleWindForceY = dynamicGustWindY
                let singleWindAbs = hypot(singleWindForceX, singleWindForceY)
                let pressAge = max(0.0, elapsed - (blankTouchStartTime ?? elapsed))
                let isSingleWindActive = (isPressingBlank && pressAge >= windPressTriggerThreshold) || isContinuousWindEnabled

                let singleStemSwayX: Double = {
                    if isSingleWindActive {
                        let push = singleWindForceX * stemCompliance * 1.17 // 扩大至 150% (原 0.78)
                        let vibe = sin(elapsed * 3.8) * (singleWindAbs * 0.04 * stemCompliance)
                        let tremor = sin(elapsed * 18.0) * (pow(singleWindAbs, 1.45) * 0.045 * stemCompliance)
                        return max(-1.28, min(1.28, push + vibe + tremor))
                    } else {
                        return sin(elapsed * 1.2) * 0.02
                    }
                }()

                let singleStemSwayY: Double = {
                    if isSingleWindActive {
                        let pushY = singleWindForceY * stemCompliance * 0.78 // 扩大至 150% (原 0.52)
                        let vibeY = cos(elapsed * 3.4) * (singleWindAbs * 0.02 * stemCompliance)
                        return max(-0.98, min(0.98, pushY + vibeY))
                    } else {
                        return 0.0
                    }
                }()

                let (singleHeadWobbleX, singleHeadWobbleY): (Double, Double) = {
                    if isSingleWindActive {
                        let tiltX = singleWindForceX * 0.48 // 扩大至 150% (原 0.32)
                        let tiltY = singleWindForceY * 0.27 // 扩大至 150% (原 0.18)
                        let wave = sin(elapsed * selectedFlora.headWobbleFrequency) * (singleWindAbs * 0.14)
                        let flutter = sin(elapsed * 24.0) * (pow(singleWindAbs, 1.5) * 0.09)
                        return (tiltX + wave + flutter, tiltY + wave * 0.4)
                    } else {
                        let relTime = max(0.0, elapsed - lastReleaseTime)
                        let tau = selectedFlora.headWobbleDuration / 3.8
                        let decay = exp(-relTime / tau)
                        let wobble = sin(selectedFlora.headWobbleFrequency * relTime) * decay * (selectedFlora.headWobbleAmplitude * lastReleaseWindIntensity)
                        return (wobble * lastReleaseWindVector.dx, wobble * lastReleaseWindVector.dy * 0.4)
                    }
                }()

                PosyInteractiveStemFlower(
                    type: selectedFlora,
                    progress: growthProgress,
                    basePosition: CGPoint(x: canvasWidth * 0.5, y: canvasHeight * 0.65),
                    stemHeight: stemH,
                    ambientSway: singleStemSwayX,
                    windAlignment: isSingleWindActive ? singleWindForceX * 1.5 : 0,
                    headWobble: singleHeadWobbleX,
                    ambientSwayY: singleStemSwayY,
                    windAlignmentY: isSingleWindActive ? singleWindForceY * 1.5 : 0,
                    headWobbleY: singleHeadWobbleY,
                    breathingPhase: elapsed * 2.0,
                    seed: 42,
                    initialPlacement: plantPlacements[selectedFlora.rawValue] ?? .zero,
                    canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
                    elapsed: elapsed,
                    onDragStateChanged: { dragging in
                        isAnyFlowerDragging = dragging
                    },
                    onPlacementChange: { placement in
                        plantPlacements[selectedFlora.rawValue] = placement
                        GardenPlantPlacementStore.save(plantPlacements)
                    }
                )
                .id(studioResetToken)
            }

            // 点击空白处生成的浅玫红/浅橙带光晕漂浮粒子 (全屏幕渲染，忽略安全范围限制)
            PosyFloatingHaloParticlesView(
                particles: floatingHaloParticles,
                elapsed: elapsed,
                flowOffsetX: currentFlowOffsetX,
                flowOffsetY: currentFlowOffsetY,
                drawingOffset: CGSize(width: -particleCanvasFrame.minX, height: -particleCanvasFrame.minY)
            )
            .frame(width: particleCanvasFrame.width, height: particleCanvasFrame.height)
            .position(x: particleCanvasFrame.midX, y: particleCanvasFrame.midY)
            .allowsHitTesting(false)
            .zIndex(1800)

            // 互动生灵：蜜蜂与蝴蝶置于上层 (闪白渐显阶段平滑淡入，减少穿门计算负载)
            if introProgress >= 0.82 {
                let pressAge = max(0.0, elapsed - (blankTouchStartTime ?? elapsed))
                let isWindActive = (isPressingBlank && pressAge >= windPressTriggerThreshold) || isContinuousWindEnabled
                PosyCreaturesView(
                    elapsed: elapsed,
                    windSpeed: 1.0 + currentWindPower * 2.5,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    isWindActive: isWindActive,
                    windVector: CGVector(dx: dynamicGustWindX, dy: dynamicGustWindY)
                )
                .opacity(introProgress >= 0.98 ? 1.0 : (introProgress - 0.82) / 0.16)
                .zIndex(2000)
                .allowsHitTesting(!isAnyFlowerDragging)
            }
        }
    }

    // MARK: - 生成/更新静态展台高保真快照 (闪白前无开销复用)
    @MainActor
    private func updateStageSnapshot(width: CGFloat, height: CGFloat) {
        guard width > 20, height > 20 else { return }
        if let snapshot = GardenIntroPlaybackSession.lastSceneSnapshots[colorTheme] {
            cachedStageSnapshot = snapshot
            return
        }
        let stageView = ZStack {
            TodayAmbientBackground(reduceMotion: false)
            PosyStaticGardenStageView(
                canvasWidth: width,
                canvasHeight: height,
                growthProgress: growthProgress,
                isMultiBouquetMode: isMultiBouquetMode,
                selectedFlora: selectedFlora,
                studioResetToken: studioResetToken,
                plantProgress: plantProgress,
                visibleFlora: visibleFlora,
                plantPlacements: plantPlacements,
                showsAmbientBokeh: true
            )
            PosyCreaturesView(
                elapsed: Date.timeIntervalSinceReferenceDate,
                windSpeed: 1,
                canvasWidth: width,
                canvasHeight: height,
                isSnapshot: true
            )
            PosyFloatingHaloParticlesView(
                particles: floatingHaloParticles,
                elapsed: Date.timeIntervalSinceReferenceDate
            )
        }
        .frame(width: width, height: height)
        .environment(\.habitColorTheme, colorTheme)

        let renderer = ImageRenderer(content: stageView)
        renderer.scale = 3.0
        renderer.isOpaque = true
        if let image = renderer.uiImage {
            self.cachedStageSnapshot = image
        }
    }

    @MainActor
    private func captureLastGardenSceneSnapshot(width: CGFloat, height: CGFloat) {
        guard embedded, width > 20, height > 20 else { return }
        let scene = ZStack {
            TodayAmbientBackground(reduceMotion: false)
            PosyStaticGardenStageView(
                canvasWidth: width,
                canvasHeight: height,
                growthProgress: growthProgress,
                isMultiBouquetMode: isMultiBouquetMode,
                selectedFlora: selectedFlora,
                studioResetToken: studioResetToken,
                plantProgress: plantProgress,
                visibleFlora: visibleFlora,
                plantPlacements: plantPlacements,
                showsAmbientBokeh: true
            )
            PosyCreaturesView(
                elapsed: Date.timeIntervalSinceReferenceDate,
                windSpeed: 1,
                canvasWidth: width,
                canvasHeight: height,
                isSnapshot: true
            )
            PosyFloatingHaloParticlesView(
                particles: floatingHaloParticles,
                elapsed: Date.timeIntervalSinceReferenceDate
            )
        }
        .frame(width: width, height: height)
        .environment(\.habitColorTheme, colorTheme)

        let renderer = ImageRenderer(content: scene)
        renderer.scale = 3.0
        renderer.isOpaque = true
        if let image = renderer.uiImage {
            GardenIntroPlaybackSession.lastSceneSnapshots[colorTheme] = image
        }
    }

    @MainActor
    private func shareCurrentGarden(width: CGFloat, height: CGFloat) {
        guard width > 20, height > 20 else { return }
        let photoHeight = width * 1.04
        // Keep the full plant and saucer within the central 72% of the photo.
        // The focus spans the uppermost flower reach (22%) to the saucer (70%).
        let focusTop = height * 0.22
        let focusBottom = height * 0.70
        let focusCenter = (focusTop + focusBottom) * 0.5
        let stageScale = min(0.88, photoHeight * 0.72 / (focusBottom - focusTop))
        let scene = ZStack {
            TodayAmbientBackground(reduceMotion: true)
            PosyStaticGardenStageView(
                canvasWidth: width,
                canvasHeight: height,
                growthProgress: growthProgress,
                isMultiBouquetMode: isMultiBouquetMode,
                selectedFlora: selectedFlora,
                studioResetToken: studioResetToken,
                plantProgress: plantProgress,
                visibleFlora: visibleFlora,
                plantPlacements: plantPlacements,
                showsAmbientBokeh: true
            )
            .scaleEffect(stageScale)
            .position(
                x: width * 0.5,
                y: photoHeight * 0.5 + stageScale * (height * 0.5 - focusCenter)
            )
        }
        .frame(width: width, height: photoHeight)
        .clipped()
        .environment(\.habitColorTheme, colorTheme)

        let renderer = ImageRenderer(content: scene)
        renderer.scale = 3
        renderer.isOpaque = true
        guard let photograph = renderer.uiImage else { return }
        onSharePhoto?(photograph)
    }

    // MARK: - 子视图：花束组合展示（各花根据花型大小、高矮独立响应风力，晃动时间与反馈差异巨大）
    @ViewBuilder
    private func multiBouquetView(
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        elapsed: Double
    ) -> some View {
        let arrangement = PosyBouquetLayout.arrangement.filter { visibleFlora.contains($0.type.rawValue) }

        ForEach(0..<arrangement.count, id: \.self) { idx in
            let item = arrangement[idx]
            let itemProg = plantProgress[item.type.rawValue] ?? max(0.05, min(1.0, growthProgress * item.progScale))

            let isPressWindActive = isPressingBlank && (max(0.0, elapsed - (blankTouchStartTime ?? elapsed)) >= windPressTriggerThreshold)
            let isWindActive = isPressWindActive || isContinuousWindEnabled

            // 1. 空间气流延迟：根据风向计算到达该植株的延迟时间 (2D 空间麦浪效应)
            let smoothVector = currentSmoothWindVector(at: elapsed)
            let activeWindVector = isWindActive ? smoothVector : lastReleaseWindVector
            let plantSpatialDelay: Double = {
                let plantPosX = Double(item.normX) - 0.5
                let plantPosY = 0.15
                let dot = plantPosX * activeWindVector.dx + plantPosY * activeWindVector.dy
                return (dot + 0.5) * 0.32
            }()

            let localElapsed = elapsed - plantSpatialDelay

            // 2. 该植株局部的实时风力冲量 (滑动距离越长风力越强，整体 0.5x)：
            let (localWindForceX, localWindForceY): (Double, Double) = {
                if isWindActive {
                    let localPressAge = max(0.0, localElapsed - (blankTouchStartTime ?? localElapsed))
                    if localPressAge < windPressTriggerThreshold && !isContinuousWindEnabled { return (0.0, 0.0) }
                    let ramp = min(1.0, (localPressAge - windPressTriggerThreshold) / 0.40)
                    let dragRatio = min(1.8, Double(touchDragDistance / 90.0))
                    let power = isContinuousWindEnabled && !isPressingBlank ? 0.5 : ramp * (0.45 + 0.95 * dragRatio) * 0.5
                    // 阵风起伏：不同植株处感受到的阵风波幅不同
                    let localTurbulence = 0.85 + 0.45 * (
                        0.50 * sin(localElapsed * 2.6) +
                        0.32 * sin(localElapsed * 5.7 + Double(idx)) +
                        0.18 * sin(localElapsed * 12.4 + Double(idx) * 2.1)
                    )
                    return (
                        power * localTurbulence * smoothVector.dx,
                        power * localTurbulence * smoothVector.dy
                    )
                } else {
                    let localRelAge = max(0.0, localElapsed - lastReleaseTime)
                    let decay = exp(-localRelAge * 2.4)
                    let intensity = lastReleaseWindIntensity * decay
                    return (
                        intensity * lastReleaseWindVector.dx,
                        intensity * lastReleaseWindVector.dy
                    )
                }
            }()

            // 3. 茎秆弯曲动力学 (Stem Bending Dynamics in 2D):
            // 受风柔韧弯曲系数 (0.35 ~ 1.55) * 高度因子 (相差 4.4 倍)
            let heightRatio = Double(item.height / 200.0)
            let stemCompliance = item.type.stemFlexFactor * heightRatio
            let windAbs = hypot(localWindForceX, localWindForceY)
            let stemPushDisplacementX = localWindForceX * stemCompliance * 1.17 // 扩大至 150% (原 0.78)
            let stemCompressDisplacementY = localWindForceY * stemCompliance * 0.78 // 扩大至 150% (原 0.52)

            // 茎秆回弹与自振 / 强风抖动反馈 (保持晃动与倾斜基础设定，按比例体现风向位移，扩大至 150%)：
            let stemSway: Double = {
                if isWindActive {
                    // 基础随风起伏 + 强风高频微颤振 (16Hz ~ 24Hz 空气动力学湍流抖动)
                    let baseVibe = sin(localElapsed * 3.8 + Double(idx)) * (windAbs * 0.04 * stemCompliance)
                    let aeroTremor = sin(localElapsed * (16.0 + Double(idx) * 2.5) + Double(idx)) * (pow(windAbs, 1.45) * 0.045 * stemCompliance)
                    return max(-1.28, min(1.28, stemPushDisplacementX + baseVibe + aeroTremor))
                } else {
                    // Return only the ambient target; the stem integrates its rebound.
                    return sin(elapsed * 1.2 + Double(idx) * 0.5) * 0.02
                }
            }()

            let stemSwayY: Double = {
                if isWindActive {
                    let baseVibeY = cos(localElapsed * 3.4 + Double(idx)) * (windAbs * 0.02 * stemCompliance)
                    return max(-0.98, min(0.98, stemCompressDisplacementY + baseVibeY))
                } else {
                    return 0.0
                }
            }()

            // 4. 花头滞后晃动动力学 (Flower Head Decoupled Wobble Dynamics in 2D):
            // 核心规则：茎秆停下来后，花头由于转动惯量继续独立晃动！晃动持续时间 headWobbleDuration (1.1s ~ 5.5s) 差异巨大，相差 5 倍！
            let (headWobbleX, headWobbleY): (Double, Double) = {
                if isWindActive {
                    let headTiltX = localWindForceX * 0.48 // 扩大至 150% (原 0.32)
                    let headTiltY = localWindForceY * 0.27 // 扩大至 150% (原 0.18)
                    let baseWave = sin(localElapsed * item.type.headWobbleFrequency + Double(idx) * 1.4) * (windAbs * 0.14)
                    let flutterWave = sin(localElapsed * 24.0 + Double(idx) * 2.2) * (pow(windAbs, 1.5) * 0.09)
                    return (
                        headTiltX + baseWave + flutterWave,
                        headTiltY + baseWave * 0.4
                    )
                } else {
                    let relTime = max(0.0, localElapsed - lastReleaseTime)
                    let totalDuration = item.type.headWobbleDuration
                    let dampingTau = totalDuration / 3.8
                    let headDampingDecay = exp(-relTime / dampingTau)

                    let omega = item.type.headWobbleFrequency
                    let phase = Double(idx) * 1.35 + Double(item.seed) * 0.5
                    let wobble = sin(omega * relTime + phase) * headDampingDecay * (item.type.headWobbleAmplitude * lastReleaseWindIntensity)
                    return (
                        wobble * lastReleaseWindVector.dx,
                        wobble * lastReleaseWindVector.dy * 0.4
                    )
                }
            }()

            PosyInteractiveStemFlower(
                type: item.type,
                progress: itemProg,
                basePosition: CGPoint(x: canvasWidth * item.normX, y: canvasHeight * 0.65),
                stemHeight: item.height,
                ambientSway: stemSway,
                windAlignment: isWindActive ? localWindForceX * 1.5 : 0,
                headWobble: headWobbleX,
                ambientSwayY: stemSwayY,
                windAlignmentY: isWindActive ? localWindForceY * 1.5 : 0,
                headWobbleY: headWobbleY,
                breathingPhase: elapsed * 2.0 + Double(idx),
                seed: item.seed,
                initialPlacement: plantPlacements[item.type.rawValue] ?? .zero,
                canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
                elapsed: elapsed,
                habitName: habitNames[item.type.rawValue],
                onSelected: {
                    selectedFlora = item.type
                    onSelectFlora?(item.type)
                },
                onDragStateChanged: { dragging in
                    isAnyFlowerDragging = dragging
                },
                onPlacementChange: { placement in
                    plantPlacements[item.type.rawValue] = placement
                    GardenPlantPlacementStore.save(plantPlacements)
                }
            )
            .animation(.spring(response: 0.9, dampingFraction: 0.86), value: itemProg)
            .zIndex(selectedFlora == item.type ? 100 : Double(idx))
        }
    }

    // MARK: - 动态解析系统物理安全区域（严格遵循 Apple HIG 规则，防系统状态栏/灵动岛重叠）
    private func resolvedSafeAreaTop(proxyTop: CGFloat) -> CGFloat {
        if proxyTop > 20.0 {
            return proxyTop
        }
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            let windowTop = window.safeAreaInsets.top
            if windowTop > 20.0 {
                return windowTop
            }
        }
        return 59.0 // 现代全面屏 iPhone 灵动岛安全基线
    }

    // MARK: - 子视图：顶部状态条 (独立图层，严格遵守 Apple HIG 安全范围，不阻挡下方交互)
    @ViewBuilder
    private func topHeaderBar(safeAreaTop: CGFloat, canvasWidth: CGFloat, canvasHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                // 默认顶部栏：左侧标题 + 右侧按钮/菜单
                HStack(alignment: .center, spacing: 8) {
                    // 左侧品牌标题与副标题（单行防重叠）
                    VStack(alignment: .leading, spacing: 2) {
                        Text("POSY GARDEN")
                            .font(.system(size: 15, weight: .bold, design: .serif))
                            .tracking(1.6)
                            .foregroundColor(colorTheme == .lavender ? Color(red: 0.94, green: 0.89, blue: 1.0) : Color(red: 0.28, green: 0.20, blue: 0.28))
                        Text("成长花园 · 持续绽放")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .tracking(0.7)
                            .foregroundColor(colorTheme == .lavender ? Color(red: 0.82, green: 0.74, blue: 0.92) : Color(red: 0.48, green: 0.40, blue: 0.48))
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        if isActionMenuExpanded {
                            gardenActionButton("arrow.clockwise", label: "重播入场") {
                                isActionMenuExpanded = false
                                playDoorIntro()
                            }
                            gardenActionButton(isContinuousWindEnabled ? "wind.circle.fill" : "wind", label: isContinuousWindEnabled ? "关闭吹风" : "持续吹风") {
                                toggleContinuousWind()
                            }
                            gardenActionButton("square.and.arrow.up", label: "制作拍立得") {
                                isActionMenuExpanded = false
                                shareCurrentGarden(width: canvasWidth, height: canvasHeight)
                            }
                        }

                        Button {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                isActionMenuExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isActionMenuExpanded ? "xmark" : "camera.macro")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(colorTheme == .lavender ? Color(red: 0.28, green: 0.16, blue: 0.40) : Color(red: 0.36, green: 0.25, blue: 0.35))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(colorTheme == .lavender ? Color(red: 0.76, green: 0.61, blue: 0.94).opacity(0.90) : Color.white.opacity(0.75)))
                                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1))
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isActionMenuExpanded ? "收起花园操作" : "展开花园操作")
                        .accessibilityAddTraits(isActionMenuExpanded ? [.isSelected] : [])
                    }
                }
                .opacity(isWindHintVisible ? 0.0 : 1.0)
                .animation(.easeInOut(duration: 0.32), value: isWindHintVisible)

                // 吹风触发时：从右上角图标处胶囊变化浮现小提示
                if isWindHintVisible {
                    HStack(spacing: 6) {
                        Image(systemName: "wind")
                            .font(.system(size: 13, weight: .semibold))
                        Text("风慢慢地吹，会随着你指尖拖动的方向起舞")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(colorTheme == .lavender ? Color(red: 0.28, green: 0.16, blue: 0.40) : Color(red: 0.36, green: 0.25, blue: 0.35))
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(
                        Capsule()
                            .fill(colorTheme == .lavender ? Color(red: 0.76, green: 0.61, blue: 0.94).opacity(0.92) : Color.white.opacity(0.88))
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3, anchor: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, safeAreaTop + 6.0)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func gardenActionButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(colorTheme == .lavender ? Color(red: 0.28, green: 0.16, blue: 0.40) : Color(red: 0.36, green: 0.25, blue: 0.35))
                .frame(width: 34, height: 34)
                .background(Circle().fill(colorTheme == .lavender ? Color(red: 0.76, green: 0.61, blue: 0.94).opacity(0.90) : Color.white.opacity(0.82)))
                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    // MARK: - 子视图：底部控制面板
    @ViewBuilder
    private func controlDeckPanel(safeAreaBottom: CGFloat) -> some View {
        VStack(spacing: 10) {
            // 模式选择与快捷测试
            HStack(spacing: 8) {
                modePillButton(title: "💐 花束协同", isActive: isMultiBouquetMode) {
                    withAnimation(.spring()) { isMultiBouquetMode = true }
                }
                modePillButton(title: "🔍 单株甄选", isActive: !isMultiBouquetMode) {
                    withAnimation(.spring()) { isMultiBouquetMode = false }
                }
                Spacer()

                // 快捷大风测试按钮 (模拟长按 2.2 秒强风后放手)
                Button(action: {
                    triggerSimulatedWindGust(duration: 2.2, direction: 1.0)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "wind")
                            .font(.system(size: 11, weight: .bold))
                        Text(isPressingBlank ? "吹风中..." : "长按风动 (2s)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(isPressingBlank ? .white : Color(red: 0.35, green: 0.25, blue: 0.35))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isPressingBlank ? Color(red: 0.85, green: 0.40, blue: 0.45) : Color(red: 0.92, green: 0.88, blue: 0.94))
                    )
                }
            }

            // 12 种植物水平滚轮 (带独立双色标) - 无论是花束模式还是单株模式都提供，以便随时查看与切换
            floraSelectionScroll

            // 生长控制杆
            growthSliderRow

            // 数据库积分模拟
            databaseSimulationRow
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, max(34.0, safeAreaBottom) + 12.0)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func modePillButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? Color.white : Color(red: 0.4, green: 0.3, blue: 0.4))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isActive ? Color(red: 0.45, green: 0.32, blue: 0.42) : Color.white.opacity(0.6))
                )
        }
    }

    @ViewBuilder
    private var floraSelectionScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PosyFloraType.allCases) { flora in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedFlora = flora
                        }
                    }) {
                        VStack(spacing: 3) {
                            Text(flora.titleZh)
                                .font(.system(size: 11, weight: selectedFlora == flora ? .bold : .regular))
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(flora.palette.primary)
                                    .frame(width: 5, height: 5)
                                Circle()
                                    .fill(flora.palette.accent)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedFlora == flora ? Color.white : Color.white.opacity(0.45))
                                .shadow(color: selectedFlora == flora ? Color.black.opacity(0.08) : .clear, radius: 4)
                        )
                        .foregroundColor(Color(red: 0.3, green: 0.2, blue: 0.3))
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var growthSliderRow: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.4))
                        .font(.system(size: 12))
                    Text(stageDescription)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.3, green: 0.2, blue: 0.3))
                }
                Spacer()
                Text("\(Int(growthProgress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.5))
            }

            // 4个阶段快速切换与自然平滑过渡动画演示按钮
            HStack(spacing: 6) {
                stageJumpButton(title: "🌱 阶段1 萌芽", targetProgress: 0.15)
                stageJumpButton(title: "🌿 阶段2 含苞", targetProgress: 0.38)
                stageJumpButton(title: "🌸 阶段3 初绽", targetProgress: 0.65)
                stageJumpButton(title: "✨ 阶段4 全盛", targetProgress: 0.95)
            }

            Slider(value: $growthProgress, in: 0.05...1.0)
                .accentColor(selectedFlora.palette.primary)
        }
    }

    @ViewBuilder
    private func stageJumpButton(title: String, targetProgress: Double) -> some View {
        let isCurrent: Bool = {
            if targetProgress == 0.15 { return growthProgress < 0.25 }
            if targetProgress == 0.38 { return growthProgress >= 0.25 && growthProgress < 0.52 }
            if targetProgress == 0.65 { return growthProgress >= 0.52 && growthProgress < 0.78 }
            return growthProgress >= 0.78
        }()

        Button(action: {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                growthProgress = targetProgress
            }
        }) {
            Text(title)
                .font(.system(size: 10, weight: isCurrent ? .bold : .regular))
                .foregroundColor(isCurrent ? Color.white : Color(red: 0.35, green: 0.25, blue: 0.35))
                .padding(.vertical, 5)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isCurrent ? selectedFlora.palette.primary : Color.white.opacity(0.65))
                )
        }
    }

    @ViewBuilder
    private var databaseSimulationRow: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Text("习惯积分: \(simulatedPoints)")
                    .font(.system(size: 11, weight: .medium))
                Button(action: {
                    simulatedPoints = min(30, simulatedPoints + 1)
                    syncGrowthFromDatabaseMock()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.45))
                }
            }

            HStack(spacing: 6) {
                Text("连续打卡: \(simulatedCompletions) 天")
                    .font(.system(size: 11, weight: .medium))
                Button(action: {
                    simulatedCompletions = min(30, simulatedCompletions + 1)
                    syncGrowthFromDatabaseMock()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.45))
                }
            }

            Spacer()

            Button("重置") {
                withAnimation(.spring()) {
                    simulatedPoints = 0
                    simulatedCompletions = 0
                    growthProgress = 0.08
                    studioResetToken += 1
                }
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
    }

    private var stageDescription: String {
        if growthProgress < 0.25 {
            return "阶段 1 · 破土萌芽 (Sprout)"
        } else if growthProgress < 0.55 {
            return "阶段 2 · 含苞积蓄 (Young Bud)"
        } else if growthProgress < 0.82 {
            return "阶段 3 · 初绽展露 (Early Bloom)"
        } else {
            return "阶段 4 · 全盛繁盛 (Full Radiance)"
        }
    }

    private func syncGrowthFromDatabaseMock() {
        let calculated = min(1.0, Double(simulatedPoints) / 10.0 * 0.6 + Double(simulatedCompletions) / 15.0 * 0.4)
        withAnimation(.easeInOut(duration: 0.45)) {
            growthProgress = max(0.08, calculated)
        }
    }

    // MARK: - 点击空白处随机生成 1～3 个浅玫红色/浅橙色的带光晕漂浮粒子 (分散生成，碰撞游荡 20 秒后慢升消失)
    private func spawnFloatingParticles(at location: CGPoint, flowOffsetX: Double? = nil, flowOffsetY: Double? = nil) {
        let now = Date().timeIntervalSinceReferenceDate
        let (currentFlowX, currentFlowY) = currentFlowOffset(at: now)
        let birthFlowX = flowOffsetX ?? currentFlowX
        let birthFlowY = flowOffsetY ?? currentFlowY

        // 清除超出生存期的旧粒子
        floatingHaloParticles.removeAll { now - $0.birthTime > $0.lifetime }

        let count = Int.random(in: 1...3)
        var newBatch: [PosyFloatingHaloParticle] = []
        let baseAngle = Double.random(in: 0...(2 * .pi))
        let enlargedParticleIndex = Int.random(in: 0..<count)

        for i in 0..<count {
            // 环形等分扩散角 + 随机微偏移，确保粒子之间明显离散拉开空间
            let spreadAngle = baseAngle + (Double(i) * (2.0 * .pi / Double(count))) + Double.random(in: -0.32...0.32)

            // 每次随机挑一颗光点放大至基准尺寸的 3 倍，其余光点保持原有随机尺寸。
            let isEnlarged = i == enlargedParticleIndex
            let randomScale = isEnlarged ? 3.0 : CGFloat.random(in: 1.30...2.15)

            // ★ 修复起始点：粒子严格在手指点击处生成，杜绝任何预先扩散半径偏移
            let sX = location.x
            let sY = location.y

            // 初始向外柔和绽放喷射散开冲量速度 (18 ~ 38 pt/s)
            let burstSpeed = CGFloat.random(in: 18...38)
            let bVx = cos(CGFloat(spreadAngle)) * burstSpeed
            let bVy = sin(CGFloat(spreadAngle)) * burstSpeed

            // 核心微珠半径：基准尺寸 2.8...4.3pt，按对应光点尺寸因子缩放。
            let cR = CGFloat.random(in: 2.8...4.3) * randomScale
            // 三倍光点的柔光晕半径至少 48pt，保证晕轮半径超过 45pt。
            let hR = CGFloat.random(in: 16...25) * randomScale

            // 三倍光点始终使用高斯模糊光晕；其他粒子沿用原有尺寸判定。
            let isLarge = isEnlarged || cR >= 6.2

            let p = PosyFloatingHaloParticle(
                birthTime: now,
                birthFlowOffsetX: birthFlowX,
                birthFlowOffsetY: birthFlowY,
                floatDuration: 20.0,
                fadeDuration: 3.8,
                startX: sX,
                startY: sY,
                burstVx: bVx,
                burstVy: bVy,
                burstTau: 0.9,
                coreRadius: cR,
                haloRadius: hR,
                isLarge: isLarge
            )
            newBatch.append(p)
        }
        floatingHaloParticles.append(contentsOf: newBatch)
    }

    // MARK: - 模拟长按大风测试驱动 (供控制台快捷按钮调用，整体 0.5x)
    private func triggerSimulatedWindGust(duration: Double = 2.2, direction: Double = 1.0) {
        let dirVector = CGVector(dx: direction >= 0 ? 1.0 : -1.0, dy: 0.0)
        let now = Date().timeIntervalSinceReferenceDate
        let relTime = max(0.0, now - lastReleaseTime)
        let releaseInertiaDistance = (1.0 - exp(-relTime * 2.2)) / 2.2 * 175.0 * lastReleaseWindIntensity
        baseWindFlowOffsetX += releaseInertiaDistance * lastReleaseWindVector.dx
        baseWindFlowOffsetY += releaseInertiaDistance * lastReleaseWindVector.dy

        blankTouchStartTime = now
        isPressingBlank = true
        hasTriggeredWindThisTouch = true
        targetWindVector = dirVector
        directionChangeStartVector = dirVector
        directionChangeStartTime = now
        windDirection = direction
        flowSegmentStartTime = now + windPressTriggerThreshold
        showWindHint()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            let releaseNow = Date().timeIntervalSinceReferenceDate
            let t = max(0.0, duration - windPressTriggerThreshold)
            let pressFlow = 175.0 * t
            baseWindFlowOffsetX += dirVector.dx * pressFlow
            baseWindFlowOffsetY += dirVector.dy * pressFlow

            lastReleaseTime = releaseNow
            lastReleaseWindIntensity = 0.5 // 整体 0.5x
            lastReleaseWindVector = dirVector

            blankTouchStartTime = nil
            blankTouchStartPos = nil
            isPressingBlank = false
            touchDragLocation = nil
            hasTriggeredWindThisTouch = false
            flowSegmentStartTime = 0.0
        }
    }

    private func toggleContinuousWind() {
        let now = Date().timeIntervalSinceReferenceDate
        if isContinuousWindEnabled {
            let dt = max(0, now - (continuousWindStartTime ?? now))
            baseWindFlowOffsetX += targetWindVector.dx * 175.0 * dt
            baseWindFlowOffsetY += targetWindVector.dy * 175.0 * dt
            lastReleaseTime = now
            lastReleaseWindIntensity = 0.5
            lastReleaseWindVector = targetWindVector
            continuousWindStartTime = nil
        } else {
            continuousWindStartTime = now
            let defaultVec = CGVector(dx: 1.0, dy: 0.0)
            targetWindVector = defaultVec
            directionChangeStartVector = defaultVec
            directionChangeStartTime = now
            windDirection = 1.0
            showWindHint()
        }
        isContinuousWindEnabled.toggle()
    }

    // MARK: - 吹风提示与风向平滑过渡逻辑
    private func showWindHint() {
        windHintDismissWorkItem?.cancel()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
            isWindHintVisible = true
            if isActionMenuExpanded {
                isActionMenuExpanded = false
            }
        }
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.55)) {
                self.isWindHintVisible = false
            }
        }
        windHintDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }

    private func currentSmoothWindVector(at elapsed: Double) -> CGVector {
        if isContinuousWindEnabled {
            return targetWindVector
        }
        let transitionDuration: Double = 0.95 // 放缓风向转变时间为 0.95s，优雅慢转，不敏感
        let dt = max(0.0, elapsed - directionChangeStartTime)
        if dt >= transitionDuration {
            return targetWindVector
        }
        let t = dt / transitionDuration
        let smoothT = t * t * (3.0 - 2.0 * t) // S 型平滑 Hermite 插值

        // 使用 2D 最短圆弧球面插值 (Slerp)，保证单位模长恒定且旋转轨迹优雅平缓
        let angleStart = atan2(directionChangeStartVector.dy, directionChangeStartVector.dx)
        let angleTarget = atan2(targetWindVector.dy, targetWindVector.dx)
        var diffAngle = angleTarget - angleStart
        while diffAngle > .pi { diffAngle -= 2.0 * .pi }
        while diffAngle < -.pi { diffAngle += 2.0 * .pi }

        let currentAngle = angleStart + diffAngle * smoothT
        return CGVector(dx: cos(currentAngle), dy: sin(currentAngle))
    }

    private func updateTargetWindVector(to newVector: CGVector, elapsed: Double) {
        let diffX = newVector.dx - targetWindVector.dx
        let diffY = newVector.dy - targetWindVector.dy
        guard hypot(diffX, diffY) > 0.15 else { return }

        let currentVec = currentSmoothWindVector(at: elapsed)
        if flowSegmentStartTime > 0.0 {
            let segDt = max(0.0, elapsed - flowSegmentStartTime)
            let dragRatio = min(1.8, Double(touchDragDistance / 90.0))
            let speed = 175.0 * (1.0 + dragRatio * 0.6)
            baseWindFlowOffsetX += currentVec.dx * speed * segDt
            baseWindFlowOffsetY += currentVec.dy * speed * segDt
        }
        flowSegmentStartTime = elapsed

        directionChangeStartVector = currentVec
        directionChangeStartTime = elapsed
        targetWindVector = newVector
        windDirection = newVector.dx >= 0 ? 1.0 : -1.0
    }

    // MARK: - 背景与粒子连续风力位移累积计算 (风停后保持在新位置，不复位原位)
    private func currentFlowOffset(at elapsed: Double) -> (Double, Double) {
        if isContinuousWindEnabled {
            let dt = max(0, elapsed - (continuousWindStartTime ?? elapsed))
            return (
                baseWindFlowOffsetX + targetWindVector.dx * 175.0 * dt,
                baseWindFlowOffsetY + targetWindVector.dy * 175.0 * dt
            )
        }
        let pressDuration = blankTouchStartTime != nil ? max(0.0, elapsed - blankTouchStartTime!) : 0.0
        let (pressWindDeltaX, pressWindDeltaY): (Double, Double) = {
            if isPressingBlank && pressDuration >= windPressTriggerThreshold {
                let segStart = max((blankTouchStartTime ?? elapsed) + windPressTriggerThreshold, flowSegmentStartTime)
                let segDt = max(0.0, elapsed - segStart)
                let dragRatio = min(1.8, Double(touchDragDistance / 90.0))
                let speed = 175.0 * (1.0 + dragRatio * 0.6)
                let smoothVector = currentSmoothWindVector(at: elapsed)
                return (smoothVector.dx * speed * segDt, smoothVector.dy * speed * segDt)
            } else {
                return (0.0, 0.0)
            }
        }()
        let relTime = max(0.0, elapsed - lastReleaseTime)
        let inertiaDecay = (1.0 - exp(-relTime * 2.2)) / 2.2 * 175.0 * lastReleaseWindIntensity
        // ★ 规则 1：固定漂浮微粒被风吹后不需要回到原位，保留累积风力位移与自然衰减，静止后停留在新位置并持续环绕
        return (
            baseWindFlowOffsetX + pressWindDeltaX + inertiaDecay * lastReleaseWindVector.dx,
            baseWindFlowOffsetY + pressWindDeltaY + inertiaDecay * lastReleaseWindVector.dy
        )
    }

    // MARK: - 电影级开场门扉漫游控制
    private func playDoorIntro() {
        isIntroSkipped = false
        introStartTime = Date().timeIntervalSinceReferenceDate
    }

    private func skipDoorIntro() {
        isIntroSkipped = true
    }
}

// MARK: - POSY 水彩流体弥散背景
private struct PosyLiquidEtherealBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.94, blue: 0.95),
                Color(red: 0.96, green: 0.92, blue: 0.94),
                Color(red: 0.93, green: 0.90, blue: 0.96)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}



// MARK: - POSY 水晶浅盘托座 (Glass Vessel Saucer - 参考图温润浆果粉豆沙色调与立体阴影)
private struct PosyGlassVesselSaucer: View {
    @Environment(\.habitColorTheme) private var colorTheme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let saucerH: CGFloat = h * 0.62
            let saucerW: CGFloat = w

            ZStack {
                // 1. 底层环境深晕阴影 (第一层宽幅弥散柔光，参考图浆果暖豆沙色系)
                Ellipse()
                    .fill((colorTheme == .lavender ? Color(red: 0.34, green: 0.16, blue: 0.40) : Color(red: 0.60, green: 0.24, blue: 0.38)).opacity(0.18))
                    .frame(width: saucerW * 0.96, height: saucerH * 0.88)
                    .blur(radius: 18)
                    .offset(y: 12)

                // 2. 底层接地立体深色接触阴影 (第二层深邃紧凑投影)
                Ellipse()
                    .fill((colorTheme == .lavender ? Color(red: 0.27, green: 0.10, blue: 0.20) : Color(red: 0.35, green: 0.10, blue: 0.20)).opacity(0.24))
                    .frame(width: saucerW * 0.88, height: saucerH * 0.72)
                    .blur(radius: 8)
                    .offset(y: 7)

                // 3. 浅盘托座外盘主体 (参考图温润浆果粉紫/玫瑰暖豆沙磨砂质感渐变)
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                (colorTheme == .lavender ? Color(red: 0.86, green: 0.74, blue: 0.99) : Color(red: 1.00, green: 0.69, blue: 0.83)).opacity(0.86), // 顶部亮色高光
                                (colorTheme == .lavender ? Color(red: 0.60, green: 0.40, blue: 0.84) : Color(red: 0.97, green: 0.42, blue: 0.66)).opacity(0.82), // 中部主体色
                                (colorTheme == .lavender ? Color(red: 0.43, green: 0.21, blue: 0.43) : Color(red: 0.87, green: 0.26, blue: 0.54)).opacity(0.87)  // 底部深紫棕红
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: saucerW, height: saucerH)
                    // 雅致透亮高光边缘线 (仿亚克力/磨砂水晶精致切边)
                    .overlay(
                        Ellipse()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.90),
                                        Color.white.opacity(0.50),
                                        Color.white.opacity(0.25)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.4
                            )
                    )

                // 4. 浅盘内凹水波微润核心层 (内圈水面透亮反光)
                let innerW = saucerW * 0.86
                let innerH = saucerH * 0.72
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: colorTheme == .lavender ? [
                                Color.white.opacity(0.38),
                                Color(red: 0.81, green: 0.68, blue: 0.96).opacity(0.34),
                                Color(red: 0.55, green: 0.31, blue: 0.66).opacity(0.42)
                            ] : [
                                Color.white.opacity(0.38),
                                Color(red: 1.00, green: 0.75, blue: 0.88).opacity(0.34),
                                Color(red: 0.94, green: 0.42, blue: 0.68).opacity(0.42)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: innerW, height: innerH)
                    .overlay(
                        Ellipse()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.65),
                                        Color.white.opacity(0.30)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.9
                            )
                    )
            }
            .position(x: w * 0.5, y: h * 0.5)
        }
    }
}

// MARK: - 漂浮光斑微粒（增加 25%+ 密度，部分增加水彩辉光模糊光晕，随风吹出屏幕并从另一侧进入）
private struct PosyAmbientBokehParticles: View {
    let elapsed: Double
    var flowOffsetX: Double = 0.0 // 随风连续流动的水平位移
    var flowOffsetY: Double = 0.0 // 随风连续流动的垂直位移

    init(elapsed: Double, flowOffsetX: Double = 0.0, flowOffsetY: Double = 0.0) {
        self.elapsed = elapsed
        self.flowOffsetX = flowOffsetX
        self.flowOffsetY = flowOffsetY
    }

    init(elapsed: Double, flowOffset: Double) {
        self.elapsed = elapsed
        self.flowOffsetX = flowOffset
        self.flowOffsetY = 0.0
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width > 0 ? size.width : 402.0
            let h = size.height > 0 ? size.height : 874.0
            let margin: CGFloat = 45.0
            let wrapSpanX: CGFloat = w + margin * 2.0
            let wrapSpanY: CGFloat = h + margin * 2.0

            // 12 颗氛围漂浮光球 (严格 1/3 比例即 4 颗放大 2 倍，构成前中后三层景深层次)
            let particles: [(baseX: CGFloat, baseY: CGFloat, baseR: CGFloat, color: Color, hasGlow: Bool, drag: Double, speedScale: Double, isEnlarged: Bool)] = [
                // 1. 左上暖柔粉晕光球 (★ 1/3 放大 2 倍)
                (0.18, 0.28, 16, Color(red: 0.96, green: 0.62, blue: 0.68), true,  1.15, 1.00, true),
                // 2. 中左清透天蓝微球
                (0.42, 0.42, 11, Color(red: 0.50, green: 0.75, blue: 0.95), false, 0.85, 1.25, false),
                // 3. 右上温润金琥珀光球 (★ 1/3 放大 2 倍)
                (0.72, 0.22, 18, Color(red: 0.98, green: 0.82, blue: 0.45), true,  1.30, 0.85, true),
                // 4. 右侧紫红微球 (纯色半透明)
                (0.88, 0.52, 13, Color(red: 0.85, green: 0.55, blue: 0.82), false, 0.95, 1.10, false),
                // 5. 中下草本青绿微球
                (0.28, 0.65, 10, Color(red: 0.60, green: 0.86, blue: 0.68), false, 1.20, 0.95, false),
                // 6. 中下暖蜜桃粉光球 (★ 1/3 放大 2 倍)
                (0.58, 0.72, 15, Color(red: 0.98, green: 0.68, blue: 0.52), true,  1.05, 1.15, true),
                // 7. 左侧水蓝微球
                (0.08, 0.50, 12, Color(red: 0.45, green: 0.80, blue: 0.88), false, 1.25, 0.90, false),
                // 8. 中部浅粉微球
                (0.62, 0.35, 9,  Color(red: 0.95, green: 0.75, blue: 0.85), false, 0.90, 1.20, false),
                // 9. 右下薰衣草紫光球 (★ 1/3 放大 2 倍)
                (0.80, 0.78, 17, Color(red: 0.70, green: 0.65, blue: 0.92), true,  1.10, 0.85, true),
                // 10. 左上柔金小光球 (纯色半透明)
                (0.35, 0.18, 14, Color(red: 0.98, green: 0.88, blue: 0.55), false, 1.35, 1.05, false),
                // 11. 右上青碧微球
                (0.94, 0.30, 8,  Color(red: 0.65, green: 0.88, blue: 0.82), false, 0.80, 1.30, false),
                // 12. 左下薄荷浅绿微球
                (0.22, 0.82, 11, Color(red: 0.55, green: 0.82, blue: 0.75), false, 1.00, 1.05, false)
            ]

            for (idx, p) in particles.enumerated() {
                // 1. 恒定低频温润漂浮波浪 (恒定 ~0.25Hz，绝不抖动)
                let floatPhase = Double(p.baseX * 7.3 + p.baseY * 4.9)
                let ambientSpeedScale = p.isEnlarged ? 1.2 : 1.0
                let floatX = sin(elapsed * 0.28 * p.speedScale * ambientSpeedScale + floatPhase) * 16.0
                let floatY = cos(elapsed * 0.20 * p.speedScale * ambientSpeedScale + floatPhase) * 7.0

                // 2. 连续虚拟世界坐标 (含初始位置、2D风力累积位移与微风漂动)
                let worldX = Double(w * p.baseX) + flowOffsetX * p.drag + floatX
                let worldY = Double(h * p.baseY) + flowOffsetY * p.drag + floatY

                // 3. 计算 2D 循环环绕 (在 [-margin, w + margin] 和 [-margin, h + margin] 循环)
                let shiftedX = worldX + Double(margin)
                var modX = shiftedX.truncatingRemainder(dividingBy: Double(wrapSpanX))
                if modX < 0 { modX += Double(wrapSpanX) }
                let px = CGFloat(modX) - margin

                let shiftedY = worldY + Double(margin)
                var modY = shiftedY.truncatingRemainder(dividingBy: Double(wrapSpanY))
                if modY < 0 { modY += Double(wrapSpanY) }
                let py = CGFloat(modY) - margin

                // 4. 尺寸计算：1/3 比例粒子放大 2 倍
                let effectiveBaseR = p.isEnlarged ? p.baseR * 2.0 * 0.55 : p.baseR

                // 5. 绘制辉光与微粒本体 (仅大模糊光点绘制水彩高斯晕轮)
                if p.hasGlow {
                    let glowScale = 0.88 + 0.22 * CGFloat(sin(elapsed * 0.75 + Double(idx * 2)))
                    let haloR = effectiveBaseR * 2.8 * glowScale
                    let haloRect = CGRect(x: px - haloR, y: py - haloR, width: haloR * 2, height: haloR * 2)

                    let haloGradient = Gradient(colors: [
                        p.color.opacity(0.28),
                        p.color.opacity(0.10),
                        Color.clear
                    ])
                    context.fill(
                        Path(ellipseIn: haloRect),
                        with: .radialGradient(
                            haloGradient,
                            center: CGPoint(x: px, y: py),
                            startRadius: effectiveBaseR * 0.25,
                            endRadius: haloR
                        )
                    )
                }

                // 核心纯色半透明光点 (无白色圆心点)
                let dotR = effectiveBaseR * 0.55
                var dot = Path()
                dot.addEllipse(in: CGRect(x: px - dotR, y: py - dotR, width: dotR * 2, height: dotR * 2))
                context.fill(dot, with: .color(p.color.opacity(p.hasGlow ? 0.48 : 0.42)))
            }
        }
    }
}

// MARK: - 点击空白处触发的带光晕漂浮粒子 (Soft Rose / Soft Orange Floating Halo Particles)
public struct PosyFloatingHaloParticle: Identifiable {
    public let id: UUID
    public let birthTime: Double
    public let birthFlowOffsetX: Double // 生成瞬间的环境风力基准 X
    public let birthFlowOffsetY: Double // 生成瞬间的环境风力基准 Y
    public let floatDuration: Double // 浮动与碰撞飘散持续时间 (20 秒)
    public let fadeDuration: Double  // 向上慢慢升华消失持续时间 (约 3.8 秒)
    public var lifetime: Double { floatDuration + fadeDuration }

    // 初始生成与向外散开参数
    public let startX: CGFloat
    public let startY: CGFloat
    public let burstVx: CGFloat
    public let burstVy: CGFloat
    public let burstTau: Double

    // 长期布朗随机漂移分量 (微弱游荡，避免原地打转)
    public let driftVx: CGFloat
    public let driftVy: CGFloat

    // 多频有机浮动波浪参数 (模拟流体微涡流)
    public let freqX1: Double
    public let freqX2: Double
    public let ampX1: CGFloat
    public let ampX2: CGFloat
    public let phaseX: Double

    public let freqY1: Double
    public let freqY2: Double
    public let ampY1: CGFloat
    public let ampY2: CGFloat
    public let phaseY: Double

    // 碰撞反弹弹性脉冲 (模拟微粒间或气流碰撞反折)
    public let bounceFreq: Double
    public let bounceAmp: CGFloat
    public let bouncePhase: Double

    // 视觉外观与尺寸
    public let coreRadius: CGFloat
    public let haloRadius: CGFloat
    public let isRose: Bool // true: 浅玫红色, false: 浅橙色
    public let isLarge: Bool // true: 大模糊光点 (高斯晕轮), false: 纯色半透明光点

    public init(
        birthTime: Double,
        birthFlowOffsetX: Double = 0.0,
        birthFlowOffsetY: Double = 0.0,
        floatDuration: Double = 20.0,
        fadeDuration: Double = 3.8,
        startX: CGFloat,
        startY: CGFloat,
        burstVx: CGFloat = 0,
        burstVy: CGFloat = 0,
        burstTau: Double = 1.2,
        driftVx: CGFloat = CGFloat.random(in: -3.2...3.2),
        driftVy: CGFloat = CGFloat.random(in: -2.2...2.2),
        freqX1: Double = Double.random(in: 0.35...0.65),
        freqX2: Double = Double.random(in: 1.1...1.8),
        ampX1: CGFloat = CGFloat.random(in: 18...32),
        ampX2: CGFloat = CGFloat.random(in: 8...15),
        phaseX: Double = Double.random(in: 0...(Double.pi * 2)),
        freqY1: Double = Double.random(in: 0.28...0.55),
        freqY2: Double = Double.random(in: 0.9...1.6),
        ampY1: CGFloat = CGFloat.random(in: 14...24),
        ampY2: CGFloat = CGFloat.random(in: 6...12),
        phaseY: Double = Double.random(in: 0...(Double.pi * 2)),
        bounceFreq: Double = Double.random(in: 0.7...1.3),
        bounceAmp: CGFloat = CGFloat.random(in: 6...12),
        bouncePhase: Double = Double.random(in: 0...(Double.pi * 2)),
        coreRadius: CGFloat = CGFloat.random(in: 4.2...8.8),
        haloRadius: CGFloat = CGFloat.random(in: 24...52),
        isRose: Bool = Bool.random(),
        isLarge: Bool = false
    ) {
        self.id = UUID()
        self.birthTime = birthTime
        self.birthFlowOffsetX = birthFlowOffsetX
        self.birthFlowOffsetY = birthFlowOffsetY
        self.floatDuration = floatDuration
        self.fadeDuration = fadeDuration
        self.startX = startX
        self.startY = startY
        self.burstVx = burstVx
        self.burstVy = burstVy
        self.burstTau = burstTau
        self.driftVx = driftVx
        self.driftVy = driftVy
        self.freqX1 = freqX1
        self.freqX2 = freqX2
        self.ampX1 = ampX1
        self.ampX2 = ampX2
        self.phaseX = phaseX
        self.freqY1 = freqY1
        self.freqY2 = freqY2
        self.ampY1 = ampY1
        self.ampY2 = ampY2
        self.phaseY = phaseY
        self.bounceFreq = bounceFreq
        self.bounceAmp = bounceAmp
        self.bouncePhase = bouncePhase
        self.coreRadius = coreRadius
        self.haloRadius = haloRadius
        self.isRose = isRose
        self.isLarge = isLarge
    }
}

public struct PosyFloatingHaloParticlesView: View {
    public let particles: [PosyFloatingHaloParticle]
    public let elapsed: Double
    public var flowOffsetX: Double = 0.0
    public var flowOffsetY: Double = 0.0
    public var drawingOffset: CGSize = .zero

    public var body: some View {
        Canvas { context, size in
            // 过滤有效生存期的粒子
            let activeParticles: [(p: PosyFloatingHaloParticle, age: Double, alpha: Double, px: CGFloat, py: CGFloat, dissolveScale: CGFloat)] = particles.compactMap { p in
                let age = elapsed - p.birthTime
                guard age >= 0 && age <= p.lifetime else { return nil }

                // 1. 透明度演化：前 0.8s 平滑淡入，20s 内保持发光呼吸，20s 后向上消散
                let alpha: Double = {
                    if age < 0.8 {
                        return (age / 0.8)
                    } else if age <= p.floatDuration {
                        let shimmer = 0.08 * sin(age * 2.8 + p.phaseX)
                        return 0.92 + shimmer
                    } else {
                        let exitProgress = (age - p.floatDuration) / p.fadeDuration
                        return max(0.0, 1.0 - pow(exitProgress, 1.25))
                    }
                }()

                // 2. 初始向外喷射离散位移 (指数衰减阻尼，平滑舒展展开，age=0 时为 0)
                let burstDamp = 1.0 - exp(-age / p.burstTau)
                let burstDispX = p.burstVx * CGFloat(p.burstTau * burstDamp)
                let burstDispY = p.burstVy * CGFloat(p.burstTau * burstDamp)

                // 3. 20 秒内的多频有机游荡浮动 (双正弦复合波，减去 age=0 初值确保起始点与点击处完全吻合)
                let waveX0 = sin(p.phaseX) * p.ampX1 + cos(p.phaseX * 1.5) * p.ampX2
                let waveY0 = cos(p.phaseY) * p.ampY1 + sin(p.phaseY * 1.3) * p.ampY2
                let waveX = (sin(age * p.freqX1 + p.phaseX) * p.ampX1 + cos(age * p.freqX2 + p.phaseX * 1.5) * p.ampX2) - waveX0
                let waveY = (cos(age * p.freqY1 + p.phaseY) * p.ampY1 + sin(age * p.freqY2 + p.phaseY * 1.3) * p.ampY2) - waveY0

                // 4. 随机碰撞飘散微反弹 (减去 age=0 初值)
                let bounce0 = abs(sin(p.bouncePhase))
                let bounceVal = abs(sin(age * p.bounceFreq + p.bouncePhase))
                let bounceDisp = (CGFloat(bounceVal) - CGFloat(bounce0)) * p.bounceAmp

                // 5. 游荡慢漂移 (age=0 时为 0)
                let driftX = p.driftVx * CGFloat(min(age, p.floatDuration))
                let driftY = p.driftVy * CGFloat(min(age, p.floatDuration))

                // 6. 20 秒之后慢慢向上升华消失
                let exitRise: CGFloat = {
                    if age > p.floatDuration {
                        let exitP = CGFloat((age - p.floatDuration) / p.fadeDuration)
                        return pow(exitP, 1.6) * 125.0
                    }
                    return 0
                }()
                let exitSwayX: CGFloat = {
                    if age > p.floatDuration {
                        let exitP = CGFloat((age - p.floatDuration) / p.fadeDuration)
                        return sin(exitP * .pi * 2.0 + CGFloat(p.phaseX)) * 16.0 * exitP
                    }
                    return 0
                }()

                // 7. 相对风力响应位移：跟随粒子生成之后的风力位移 (以 0.65 柔和顺应比率漂移)
                // 出生瞬间 relativeWindX = 0, relativeWindY = 0，确保出生瞬间严格在点击坐标
                let relWindX = (flowOffsetX - p.birthFlowOffsetX) * 0.65
                let relWindY = (flowOffsetY - p.birthFlowOffsetY) * 0.65

                let px = p.startX + burstDispX + waveX + bounceDisp + driftX + exitSwayX + CGFloat(relWindX)
                let py = p.startY + burstDispY + waveY + bounceDisp * 0.4 + driftY - exitRise + CGFloat(relWindY)

                let dissolveScale: CGFloat = {
                    if age > p.floatDuration {
                        let exitP = CGFloat((age - p.floatDuration) / p.fadeDuration)
                        return 1.0 + 0.35 * exitP
                    }
                    return 1.0
                }()

                return (p, age, alpha, px + drawingOffset.width, py + drawingOffset.height, dissolveScale)
            }

            // MARK: - 1. 高斯模糊柔光晕层 (仅大模糊光点绘制水彩高斯光晕)
            context.drawLayer { blurLayer in
                blurLayer.addFilter(.blur(radius: 11.5))

                for item in activeParticles where item.p.isLarge {
                    let p = item.p
                    let alpha = item.alpha
                    let px = item.px
                    let py = item.py
                    let dissolveScale = item.dissolveScale

                    let haloColor: Color = p.isRose
                        ? Color(red: 0.96, green: 0.42, blue: 0.62)
                        : Color(red: 0.98, green: 0.64, blue: 0.32)

                    // 柔和弥散外晕 (尺寸随随机比例等比放大)
                    let outerR = p.haloRadius * 1.5 * dissolveScale
                    var outerHalo = Path()
                    outerHalo.addEllipse(in: CGRect(x: px - outerR, y: py - outerR, width: outerR * 2, height: outerR * 2))
                    blurLayer.fill(outerHalo, with: .color(haloColor.opacity(0.16 * alpha)))

                    // 柔和微光核 (尺寸随随机比例等比放大)
                    let midR = p.haloRadius * 0.85 * dissolveScale
                    var midHalo = Path()
                    midHalo.addEllipse(in: CGRect(x: px - midR, y: py - midR, width: midR * 2, height: midR * 2))
                    blurLayer.fill(midHalo, with: .color(haloColor.opacity(0.26 * alpha)))
                }
            }

            // MARK: - 2. 纯色半透明光点本体 (除大模糊光点外均为纯色半透明，无白色圆心点，无十字星光斑)
            for item in activeParticles {
                let p = item.p
                let alpha = item.alpha
                let px = item.px
                let py = item.py

                let coreColor: Color = p.isRose
                    ? Color(red: 0.96, green: 0.45, blue: 0.62)
                    : Color(red: 0.98, green: 0.68, blue: 0.36)

                // 核心纯色半透明微珠 (无白色圆心点，无十字星芒)
                let cR = p.coreRadius
                var core = Path()
                core.addEllipse(in: CGRect(x: px - cR, y: py - cR, width: cR * 2, height: cR * 2))
                context.fill(core, with: .color(coreColor.opacity((p.isLarge ? 0.45 : 0.52) * alpha)))
            }
        }
    }
}

// MARK: - 花束统一部局参数 (共享于静态快照与实时动态渲染，底部区域收窄 25%)
public struct PosyBouquetLayout {
    public static let arrangement: [(type: PosyFloraType, normX: CGFloat, height: CGFloat, progScale: Double, seed: Int)] = [
        (.dandelion,     0.230, 195, 0.85, 105), // 2.  珊瑚伞花
        (.cosmos,        0.275, 250, 0.95, 111), // 11. 经纬金晕葱
        (.bayWreath,     0.335, 215, 0.90, 102), // 3.  孔雀彩扇
        (.hydrangea,     0.390, 135, 0.75, 107), // 7.  青绒蒲公英
        (.cherryBlossom, 0.450, 175, 0.88, 110), // 10. 双色几何伞
        (.hawthorn,      0.500, 270, 1.00, 101), // 1.  蓝金星芒 (大 20%)
        (.nightJasmine,  0.560, 235, 0.92, 112), // 12. 极夜十二星
        (.lotusPod,      0.610, 185, 0.85, 108), // 9.  珊瑚霞光球
        (.redBerries,    0.670, 160, 0.88, 104), // 5.  垂帘浆果
        (.allium,        0.725, 245, 0.95, 109), // 8.  珊瑚晶球
        (.cornflower,    0.780, 220, 0.92, 103), // 4.  几何风车 (小 15%)
        (.mimosa,        0.820, 140, 0.75, 106)  // 6.  金琥珀阳
    ]
}

// MARK: - 静态植物展台 (开场漫游未闪白前渲染，免除 120 FPS 矢量重绘)
public struct PosyStaticGardenStageView: View, Equatable {
    public let canvasWidth: CGFloat
    public let canvasHeight: CGFloat
    public let growthProgress: Double
    public let isMultiBouquetMode: Bool
    public let selectedFlora: PosyFloraType
    public let studioResetToken: Int
    public var plantProgress: [String: Double] = [:]
    public var visibleFlora: Set<String> = Set(PosyFloraType.allCases.map(\.rawValue))
    public var plantPlacements: [String: PosyPlantPlacement] = [:]
    public var showsAmbientBokeh = true

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.canvasWidth == rhs.canvasWidth &&
        lhs.canvasHeight == rhs.canvasHeight &&
        lhs.growthProgress == rhs.growthProgress &&
        lhs.isMultiBouquetMode == rhs.isMultiBouquetMode &&
        lhs.selectedFlora == rhs.selectedFlora &&
        lhs.studioResetToken == rhs.studioResetToken &&
        lhs.plantProgress == rhs.plantProgress &&
        lhs.visibleFlora == rhs.visibleFlora &&
        lhs.plantPlacements == rhs.plantPlacements &&
        lhs.showsAmbientBokeh == rhs.showsAmbientBokeh
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // 底部发光水晶浅盘 (底部区域收窄 25%)
            PosyGlassVesselSaucer()
                .frame(width: canvasWidth * 0.66, height: 80)
                .position(x: canvasWidth * 0.5, y: canvasHeight * 0.65)

            if showsAmbientBokeh {
                // 背景漂浮微球 (初始静态位置)
                PosyAmbientBokehParticles(
                    elapsed: 0.0,
                    flowOffsetX: 0.0,
                    flowOffsetY: 0.0
                )
                .allowsHitTesting(false)
            }

            // 植物静态展示
            if isMultiBouquetMode {
                PosyMultiBouquetStaticView(
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    growthProgress: growthProgress,
                    plantProgress: plantProgress,
                    visibleFlora: visibleFlora,
                    plantPlacements: plantPlacements
                )
                .id(studioResetToken)
            } else {
                let stemH: CGFloat = 240
                PosyInteractiveStemFlower(
                    type: selectedFlora,
                    progress: growthProgress,
                    basePosition: CGPoint(x: canvasWidth * 0.5, y: canvasHeight * 0.65),
                    stemHeight: stemH,
                    ambientSway: 0.0,
                    headWobble: 0.0,
                    breathingPhase: 0.0,
                    seed: 42,
                    initialPlacement: plantPlacements[selectedFlora.rawValue] ?? .zero,
                    canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
                    elapsed: 0.0,
                    onDragStateChanged: { _ in }
                )
                .id(studioResetToken)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }
}

// MARK: - 花束静态展示容器 (12 株植物全盛静态展示，0 计算负载)
public struct PosyMultiBouquetStaticView: View, Equatable {
    public let canvasWidth: CGFloat
    public let canvasHeight: CGFloat
    public let growthProgress: Double
    public var plantProgress: [String: Double] = [:]
    public var visibleFlora: Set<String> = Set(PosyFloraType.allCases.map(\.rawValue))
    public var plantPlacements: [String: PosyPlantPlacement] = [:]

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.canvasWidth == rhs.canvasWidth &&
        lhs.canvasHeight == rhs.canvasHeight &&
        lhs.growthProgress == rhs.growthProgress &&
        lhs.plantProgress == rhs.plantProgress &&
        lhs.visibleFlora == rhs.visibleFlora &&
        lhs.plantPlacements == rhs.plantPlacements
    }

    public var body: some View {
        let arrangement = PosyBouquetLayout.arrangement.filter { visibleFlora.contains($0.type.rawValue) }

        ForEach(0..<arrangement.count, id: \.self) { idx in
            let item = arrangement[idx]
            let itemProg = plantProgress[item.type.rawValue] ?? max(0.05, min(1.0, growthProgress * item.progScale))

            PosyInteractiveStemFlower(
                type: item.type,
                progress: itemProg,
                basePosition: CGPoint(x: canvasWidth * item.normX, y: canvasHeight * 0.65),
                stemHeight: item.height,
                ambientSway: 0.0,
                headWobble: 0.0,
                breathingPhase: Double(idx),
                seed: item.seed,
                initialPlacement: plantPlacements[item.type.rawValue] ?? .zero,
                canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
                elapsed: 0.0,
                onDragStateChanged: { _ in }
            )
            .zIndex(Double(idx))
        }
    }
}
