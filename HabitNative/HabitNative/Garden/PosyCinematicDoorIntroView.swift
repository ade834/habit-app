import SwiftUI
import UIKit

// MARK: - 电影级门扉漫游入场转场 (Cinematic Doorway Portal Intro)
/// 场景设计与视觉动线：
/// 1. 全深色暗室：深邃炭黑/夜幕虚空 (#050408 ~ #0E0C15)，地面带深邃木纹纵向与横向真实透视；
/// 2. 纯粹拱门（无门扇阻隔）：经典罗马石拱框架，门洞完全通透，从暗室远景静赏花海；
/// 3. 斜着照到地面的阳光 (Ground Diagonal Sunlight Projection)：
///    - 阳光自开阔门洞斜切射入，以真实透视梯形投射在地板平面上；
///    - 横向木纹板缝与纵向拼缝在受光区域被照亮为金琥珀色掠射高光；
///    - 空中伴有丁达尔体积极光与飞扬微尘，地面与空间光影层次分明；
/// 4. 镜头走近与穿门 (Walk-In & Fly-Through)：
///    - 动态矢量门洞：随进阶从远景走近 (1.0 -> 2.4)，再极速放大穿透视线 (2.4 -> 14.0+)；
/// 5. 穿门时门框边缘高度模糊变化 (Extreme Edge Depth-of-Field Blur)：
///    - 贴近门框并穿过的瞬间，门框边缘景深虚化自 14pt 剧烈飙升至 66pt+ 极大光学弥散，带金色边缘光晕横掠视野；
/// 6. 穿门后晨曦金光漫射，丝滑展现当前花园页面；点击即刻跳过，支持右上角重播。

public struct PosyCinematicDoorIntroView: View {
    public let usesLavenderPalette: Bool
    public let progress: Double             // 0.0 (远景暗室门扉) -> 1.0 (完全穿门展开)
    public let canvasSize: CGSize
    public let doorLayoutHeight: CGFloat?
    public let interiorSnapshot: UIImage?
    public let elapsed: Double
    public let safeAreaTop: CGFloat
    public let onSkip: () -> Void

    // 门扉基准尺寸 (门洞调小 25%，暗室宏大感与空间纵深倍增)
    private let baseDoorWidth: CGFloat = 102   // 原 136 * 0.75 = 102
    private let baseDoorHeight: CGFloat = 180  // 原 240 * 0.75 = 180
    private let baseArchRadius: CGFloat = 51   // 102 / 2 = 51

    public init(
        usesLavenderPalette: Bool,
        progress: Double,
        canvasSize: CGSize,
        doorLayoutHeight: CGFloat? = nil,
        interiorSnapshot: UIImage? = nil,
        elapsed: Double,
        safeAreaTop: CGFloat = 54,
        onSkip: @escaping () -> Void
    ) {
        self.usesLavenderPalette = usesLavenderPalette
        self.progress = progress
        self.canvasSize = canvasSize
        self.doorLayoutHeight = doorLayoutHeight
        self.interiorSnapshot = interiorSnapshot
        self.elapsed = elapsed
        self.safeAreaTop = safeAreaTop
        self.onSkip = onSkip
    }

    public var body: some View {
        let p = max(0.0, min(1.0, progress))
        // 地平线压低：远景阶段画面尽量靠中下 (0.60)，走近过程中平滑过渡至 0.54 与主页面舞台无缝对齐
        let doorCenterYRatio: CGFloat = {
            if p < 0.12 {
                return 0.60 // 远景阶段画面尽量靠中下
            } else if p < 0.72 {
                let t = (p - 0.12) / (0.72 - 0.12)
                let smoothT = t * t * (3.0 - 2.0 * t)
                return 0.60 - (0.60 - 0.54) * smoothT // 从容升至 0.54
            } else {
                return 0.54
            }
        }()
        let doorCenter = CGPoint(x: canvasSize.width * 0.5, y: (doorLayoutHeight ?? canvasSize.height) * doorCenterYRatio)

        // 1. 动态门扉缩放动力学：
        // 0.00 -> 0.12: 远景静止驻留 (1.00x，宽度 102pt)
        // 0.12 -> 0.46: 从容走近门前 (1.00x -> 2.35x，宽度 102pt -> 240pt)
        // 0.46 -> 0.72: 视线穿门跨越 (2.35x -> 6.80x，门框平滑掠过屏幕两侧 240pt -> 693pt)
        // 0.72 -> 1.00: 穿透后完全没入视野 (6.80x -> 13.0x)
        let doorScale: CGFloat = {
            if p < 0.12 {
                return 1.0
            } else if p < 0.46 {
                let t = (p - 0.12) / (0.46 - 0.12)
                return 1.0 + 1.35 * (t * t * (3.0 - 2.0 * t))
            } else if p < 0.72 {
                let t = (p - 0.46) / (0.72 - 0.46)
                return 2.35 + 2.10 * t + 2.35 * t * t
            } else {
                let t = (p - 0.72) / (1.0 - 0.72)
                return 6.80 + 6.20 * t
            }
        }()

        let currentDoorWidth = baseDoorWidth * doorScale
        let currentDoorHeight = baseDoorHeight * doorScale
        let currentArchRadius = currentDoorWidth * 0.5

        let currentDoorRect = CGRect(
            x: doorCenter.x - currentDoorWidth * 0.5,
            y: doorCenter.y - currentDoorHeight * 0.5,
            width: currentDoorWidth,
            height: currentDoorHeight
        )

        // 2. 门洞内部高斯模糊逆光强度计算 (越近越强烈，非线性加速达峰)
        // 0.00 -> 0.18: 远景阶段，清透自然 (closeness = 0.0)
        // 0.18 -> 0.46: 从容走近，门洞内部晨曦逆光雾气柔和充盈 (closeness: 0.0 -> 0.45)
        // 0.46 -> 0.72: 临近门洞，门内高斯逆光急剧增强形成通透日光洗礼 (closeness: 0.45 -> 1.00)
        let frameCloseness: Double = {
            if p < 0.18 {
                return 0.0
            } else if p < 0.46 {
                let t = (p - 0.18) / (0.46 - 0.18)
                return t * 0.45
            } else if p <= 0.72 {
                let t = (p - 0.46) / (0.72 - 0.46)
                return 0.45 + 0.55 * pow(t, 0.78) // 越近越强烈
            } else {
                return 1.0
            }
        }()

        // 3. 暗室墙体与门框淡出 (0.52 -> 0.72)：在闪白升起时纯净消隐
        let darkRoomOpacity: Double = {
            if p < 0.52 { return 1.0 }
            if p > 0.72 { return 0.0 }
            return (0.72 - p) / (0.72 - 0.52)
        }()

        // 4. 闪白时间变长 1.5 倍并增加满白驻留缓冲，彻底掩盖静态快照到实时物理组件的切换视觉差：
        let whiteBloomOpacity: Double = {
            if p < 0.52 {
                return 0.0
            } else if p < 0.72 {
                let t = (p - 0.52) / (0.72 - 0.52)
                return t * t * (3.0 - 2.0 * t) // 从容平滑升至满白
            } else if p <= 0.84 {
                return 1.0 // 满白驻留缓冲，100% 绝对遮罩，杜绝任何切换跳变
            } else {
                let t = (p - 0.84) / (1.00 - 0.84)
                return (1.0 - t) * (1.0 - t)   // 闪白缓缓消融，柔和渐显植物界面
            }
        }()

        ZStack {
            if darkRoomOpacity > 0.001 {
                ZStack {
                    // 1. 全深色暗室墙体 (纯黑极简，带胶片颗粒质感)
                    darkRoomWallWithCutout(doorRect: currentDoorRect, archRadius: currentArchRadius)

                    // Paint the saved scene inside the arch itself. A scaled
                    // full-screen stage can leave a rectangular edge here.
                    Group {
                        if let interiorSnapshot {
                            Image(uiImage: interiorSnapshot)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.white
                        }
                    }
                    .frame(width: currentDoorRect.width, height: currentDoorRect.height)
                    .clipShape(ArchedDoorInteriorShape(archRadius: currentArchRadius))
                    .position(x: currentDoorRect.midX, y: currentDoorRect.midY)
                    .allowsHitTesting(false)

                    // 2. 地面斜照夕阳透视光斑 (仅保留在斜地面上，浓郁暖橙色)
                    diagonalFloorSunlight(doorCenter: doorCenter, doorScale: doorScale, p: p)

                    // 3. 门洞内部高斯模糊逆光 (严格位于门洞内，非发光灯带，越近越强烈)
                    doorwayInteriorBacklight(
                        doorRect: currentDoorRect,
                        archRadius: currentArchRadius,
                        closeness: frameCloseness
                    )

                    // 4. 纯粹拱门建筑切口细边 (带极细切口轮廓，杜绝发光灯带)
                    architecturalDoorwayFrame(
                        doorRect: currentDoorRect,
                        archRadius: currentArchRadius,
                        doorScale: doorScale
                    )

                    // A faint carved wordmark follows the wall just outside the arch.
                    ForEach(Array("POSY GARDEN".enumerated()), id: \.offset) { index, character in
                        // Wider angular spacing lets the wordmark wrap farther around the arch crown.
                        let angle = (Double(index) - 5.0) * 0.20
                        let radius = currentArchRadius + 13 * doorScale
                        Text(String(character))
                            .font(.system(size: 10.5 * doorScale, weight: .black, design: .serif))
                            .foregroundStyle(.white.opacity(0.34))
                            .rotationEffect(.radians(angle))
                            .position(
                                x: doorCenter.x + radius * sin(angle),
                                y: currentDoorRect.minY + currentArchRadius - radius * cos(angle)
                            )
                    }
                }
                .opacity(darkRoomOpacity)
            }

            // 6. 右上角跳过按钮 (入场进行中常驻，闪白升起时随之隐去，杜绝浮于纯白之上)
            if p < 0.60 {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onSkip) {
                            HStack(spacing: 4) {
                                Text("跳过")
                                    .font(.system(size: 11, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(Color.white.opacity(0.88))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
                                    )
                            )
                        }
                        .padding(.trailing, 20)
                        .padding(.top, max(56.0, safeAreaTop + 8.0))
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            // 7. 全屏纯白闪白遮罩 (100% 纯白无边距全覆盖，彻底消除边缘发暗与色差)
            if whiteBloomOpacity > 0.001 {
                Color.white
                    .opacity(whiteBloomOpacity)
                    .ignoresSafeArea()
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .contentShape(Rectangle())
        .onTapGesture {
            if p < 0.88 {
                onSkip()
            }
        }
        .allowsHitTesting(p < 0.92)
    }

    // MARK: - 1. 带镂空拱门的暗室墙体、平滑地面与胶片颗粒质感 (高级极简纯黑室内)
    @ViewBuilder
    private func darkRoomWallWithCutout(doorRect: CGRect, archRadius: CGFloat) -> some View {
        // 1. 室内背景墙：紫色模式采用参考图中的深棕柔焦层次，原色模式保持原有暗室。
        InvertedArchedDoorShape(doorRect: doorRect, archRadius: archRadius)
            .fill(
                LinearGradient(
                    colors: usesLavenderPalette ? HabitColorTheme.lavender.floatingOrbAtmosphere.gradientStops : [
                        Color(red: 0.040, green: 0.040, blue: 0.045),
                        Color(red: 0.025, green: 0.025, blue: 0.028),
                        Color(red: 0.012, green: 0.012, blue: 0.015)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: FillStyle(eoFill: true, antialiased: true)
            )

        // 2. 室内地面底色：紫色模式改为深棕到中棕的柔和过渡。
        let floorY = doorRect.maxY
        Path { path in
            path.move(to: CGPoint(x: -250, y: floorY))
            path.addLine(to: CGPoint(x: canvasSize.width + 250, y: floorY))
            path.addLine(to: CGPoint(x: canvasSize.width + 250, y: canvasSize.height + 250))
            path.addLine(to: CGPoint(x: -250, y: canvasSize.height + 250))
            path.closeSubpath()
        }
            .fill(
            LinearGradient(
                colors: usesLavenderPalette ? HabitColorTheme.lavender.floatingOrbAtmosphere.gradientStops : [
                    Color(red: 0.022, green: 0.022, blue: 0.025),
                    Color(red: 0.010, green: 0.010, blue: 0.012),
                    Color(red: 0.004, green: 0.004, blue: 0.006)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )

        // 3. 室内极细微地平线基准刻线 (门槛与暗室地面的交界线，低反差极简灰调)
        Path { path in
            path.move(to: CGPoint(x: -250, y: floorY))
            path.addLine(to: CGPoint(x: canvasSize.width + 250, y: floorY))
        }
        .stroke(Color.white.opacity(0.05), lineWidth: 1.0)

        // 4. 室内专属胶片微晶颗粒质感 (严格限制在门外暗室内，绝不污染拱门内的室外花海)
        if let grain = PosyFilmGrainTexture.shared.image(for: elapsed) {
            Image(uiImage: grain)
                .resizable(resizingMode: .tile)
                .opacity(0.14)
                .blendMode(.screen)
                .clipShape(InvertedArchedDoorShape(doorRect: doorRect, archRadius: archRadius))
                .allowsHitTesting(false)
        }
    }

    // MARK: - 2. 地面斜照夕阳透视光斑 (仅保留在斜地面上，夕阳晚霞暮色)
    @ViewBuilder
    private func diagonalFloorSunlight(doorCenter: CGPoint, doorScale: CGFloat, p: Double) -> some View {
        let currentW = baseDoorWidth * doorScale
        let currentH = baseDoorHeight * doorScale
        let doorLeft = doorCenter.x - currentW * 0.5
        let doorRight = doorCenter.x + currentW * 0.5
        let doorBottom = doorCenter.y + currentH * 0.5
        // Keep the beam's edge outside the viewport at every door scale.
        // Its last color is opaque floor black, so the light fades into the room
        // instead of ending as a transparent, visible polygon edge.
        let beamTailY = max(canvasSize.height + 180, doorBottom + 270 * min(2.0, doorScale))
        let beamLength = beamTailY - doorBottom
        let beamSpread = beamLength / 270
        // Path gradients use the full canvas as their coordinate space. Anchor
        // the lavender ramp to the sill so it does not start in the brown stop.
        let lavenderLightStart = UnitPoint(x: 0.5, y: doorBottom / canvasSize.height)
        let lavenderLightEnd = UnitPoint(x: 0.5, y: beamTailY / canvasSize.height)

        // 地面斜射夕阳光池多边形 (真实的地面透视投影，阳光斜着照在左边，严格限制在地面区域)：
        let floorPool = Path { path in
            path.move(to: CGPoint(x: doorLeft + 4, y: doorBottom))
            path.addLine(to: CGPoint(x: doorRight - 4, y: doorBottom))
            path.addLine(to: CGPoint(x: doorLeft + 35 * min(1.8, doorScale) * beamSpread, y: beamTailY))
            path.addLine(to: CGPoint(x: doorLeft - 220 * min(2.0, doorScale) * beamSpread, y: beamTailY))
            path.closeSubpath()
        }

        ZStack {
        // 1. 地面暖橙色柔和漫射基底 (第一层：宽幅柔光暖橙霞光，浓郁温润，不偏红)
        floorPool
            .fill(
                LinearGradient(
                    colors: usesLavenderPalette ? [
                        Color(red: 0.85, green: 0.75, blue: 1.00).opacity(0.72),
                        Color(red: 0.69, green: 0.52, blue: 0.87).opacity(0.58),
                        Color(red: 0.48, green: 0.31, blue: 0.23),
                        Color(red: 0.075, green: 0.032, blue: 0.030)
                    ] : [
                        Color(red: 1.00, green: 0.60, blue: 0.16).opacity(0.75), // 门槛处浓郁暖橙 (#FF9929)
                        Color(red: 1.00, green: 0.68, blue: 0.22).opacity(0.46), // 中部金橙 (#FFAD38)
                        Color(red: 0.47, green: 0.28, blue: 0.13), // 尾部向暗室地面渐隐
                        Color(red: 0.010, green: 0.010, blue: 0.012)
                    ],
                    startPoint: usesLavenderPalette ? lavenderLightStart : .topTrailing,
                    endPoint: usesLavenderPalette ? lavenderLightEnd : .bottomLeading
                )
            )
            .blur(radius: 9.0)

        // 2. 地面主受光纯正暖橙光毯 (第二层：斜照在左侧地面上的透亮鲜活暖橙光束)
        floorPool
            .fill(
                LinearGradient(
                    colors: usesLavenderPalette ? [
                        Color(red: 0.84, green: 0.73, blue: 1.00).opacity(0.84),
                        Color(red: 0.73, green: 0.57, blue: 0.93).opacity(0.70),
                        Color(red: 0.52, green: 0.35, blue: 0.26),
                        Color(red: 0.075, green: 0.032, blue: 0.030)
                    ] : [
                        Color(red: 1.00, green: 0.66, blue: 0.18).opacity(0.88), // 主受光暖橙 (#FFA82E)
                        Color(red: 1.00, green: 0.72, blue: 0.26).opacity(0.62), // 透亮金橙
                        Color(red: 0.50, green: 0.30, blue: 0.13), // 尾部保持不透明
                        Color(red: 0.010, green: 0.010, blue: 0.012)
                    ],
                    startPoint: usesLavenderPalette ? lavenderLightStart : .topTrailing,
                    endPoint: usesLavenderPalette ? lavenderLightEnd : .bottomLeading
                )
            )
            .blur(radius: 5.0)

        // 3. 地面暖橙色聚光高亮亮核 (第三层：斜切入射角最集中的琥珀暖橙镜面高光带)
        Path { path in
            path.move(to: CGPoint(x: doorLeft + 12, y: doorBottom + 2))
            path.addLine(to: CGPoint(x: doorRight - 20 * min(1.8, doorScale), y: doorBottom + 2))
            path.addLine(to: CGPoint(x: doorLeft - 30 * min(1.8, doorScale) * beamSpread, y: beamTailY))
            path.addLine(to: CGPoint(x: doorLeft - 150 * min(2.0, doorScale) * beamSpread, y: beamTailY))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: usesLavenderPalette ? [
                    Color(red: 0.94, green: 0.86, blue: 1.0).opacity(0.88),
                    Color(red: 0.79, green: 0.65, blue: 0.96).opacity(0.68),
                    Color(red: 0.57, green: 0.39, blue: 0.29),
                    Color(red: 0.075, green: 0.032, blue: 0.030)
                ] : [
                    Color(red: 1.00, green: 0.84, blue: 0.45).opacity(0.95), // 高亮带中心亮金橙 (#FFD673)
                    Color(red: 1.00, green: 0.70, blue: 0.22).opacity(0.76), // 亮核主体暖橙 (#FFB238)
                    Color(red: 0.53, green: 0.32, blue: 0.14), // 尾部深暖橙渐隐
                    Color(red: 0.010, green: 0.010, blue: 0.012)
                ],
                startPoint: usesLavenderPalette ? lavenderLightStart : .topTrailing,
                endPoint: usesLavenderPalette ? lavenderLightEnd : .bottomLeading
            )
        )
        .blur(radius: 3.0)
        }
        .opacity(usesLavenderPalette ? 0.5 : 1.0)

        // 4. 门槛紧贴地面的投影刻线 (Threshold Contact Shadow)
        Path { path in
            path.move(to: CGPoint(x: doorLeft - 15, y: doorBottom))
            path.addLine(to: CGPoint(x: doorRight + 15, y: doorBottom))
        }
        .stroke(
            (usesLavenderPalette ? Color(red: 0.075, green: 0.032, blue: 0.030) : Color.black).opacity(0.65),
            lineWidth: 2.2
        )
    }

    // MARK: - 3. 门洞内部高斯模糊逆光 (严格位于门洞内，避免发光灯带，越近越强烈)
    @ViewBuilder
    private func doorwayInteriorBacklight(
        doorRect: CGRect,
        archRadius: CGFloat,
        closeness: Double
    ) -> some View {
        if closeness > 0.01 {
            let pCloseness = CGFloat(closeness)
            ZStack {
                // 1. 门洞上部自然晨曦逆光漫射层 (从拱门顶端向下漫射的柔和晨曦金霞，随走近自然泛起)
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.90, blue: 0.70).opacity(0.38 * closeness),
                        Color(red: 1.00, green: 0.76, blue: 0.38).opacity(0.22 * closeness),
                        Color(red: 1.00, green: 0.62, blue: 0.22).opacity(0.08 * closeness),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blur(radius: 12.0 * pCloseness + 3.0)

                // 2. 门洞上方圆拱处高斯逆光光晕核心 (太阳自然入射形成的柔和散斑，越近越充盈)
                RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.96, blue: 0.85).opacity(0.42 * closeness),
                        Color(red: 1.00, green: 0.82, blue: 0.46).opacity(0.18 * closeness),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.20),
                    startRadius: 0,
                    endRadius: doorRect.width * (0.40 + 0.35 * pCloseness)
                )
                .blur(radius: 15.0 * pCloseness + 4.0)
            }
            .clipShape(ArchedDoorInteriorShape(archRadius: archRadius))
            .frame(width: doorRect.width, height: doorRect.height)
            .position(x: doorRect.midX, y: doorRect.midY)
            .blendMode(.plusLighter)
        }
    }

    // MARK: - 4. 纯粹拱门建筑切口边缘 (极细极简边缘，避免发光灯带感)
    @ViewBuilder
    private func architecturalDoorwayFrame(
        doorRect: CGRect,
        archRadius: CGFloat,
        doorScale: CGFloat
    ) -> some View {
        let rimStrokeW = 1.0 * min(1.6, pow(doorScale, 0.35))
        let sillScale = min(1.6, pow(doorScale, 0.38))

        ZStack {
            // 纯粹逆光极细切口线 (低调极简，避免发光灯带)
            ArchedDoorContourShape(archRadius: archRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.40),
                            Color(red: 1.00, green: 0.92, blue: 0.82).opacity(0.30),
                            Color(red: 1.00, green: 0.78, blue: 0.55).opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: rimStrokeW
                )

            // 门槛边缘细线
            Path { path in
                path.move(to: CGPoint(x: -4 * sillScale, y: doorRect.height))
                path.addLine(to: CGPoint(x: doorRect.width + 4 * sillScale, y: doorRect.height))
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.45),
                        Color(red: 1.00, green: 0.80, blue: 0.60).opacity(0.30),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 1.0 * sillScale
            )
        }
        .frame(width: doorRect.width, height: doorRect.height)
        .position(x: doorRect.midX, y: doorRect.midY)
    }
}

// MARK: - 形状辅助：拱门内部封闭形状 (用于门洞内逆光遮罩与裁剪)
public struct ArchedDoorInteriorShape: Shape {
    public let archRadius: CGFloat

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let archCenter = CGPoint(x: rect.midX, y: rect.minY + archRadius)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + archRadius))
        path.addArc(
            center: archCenter,
            radius: archRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 形状辅助：拱门镂空暗室外墙 (Even-Odd Masking Shape)
public struct InvertedArchedDoorShape: Shape {
    public let doorRect: CGRect
    public let archRadius: CGFloat

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        // 1. 完整全屏外接矩形 (大幅外扩，确保覆盖各机型圆角、状态栏及刘海区域)
        let expanded = CGRect(
            x: -250,
            y: -250,
            width: rect.width + 500,
            height: rect.height + 500
        )
        path.addRect(expanded)

        // 2. 居中拱门镂空路径
        var doorPath = Path()
        let archCenter = CGPoint(x: doorRect.midX, y: doorRect.minY + archRadius)
        doorPath.move(to: CGPoint(x: doorRect.minX, y: doorRect.maxY))
        doorPath.addLine(to: CGPoint(x: doorRect.minX, y: doorRect.minY + archRadius))
        doorPath.addArc(
            center: archCenter,
            radius: archRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        doorPath.addLine(to: CGPoint(x: doorRect.maxX, y: doorRect.maxY))
        doorPath.closeSubpath()

        path.addPath(doorPath)
        return path
    }
}

// MARK: - 形状辅助：拱门单圈轮廓形状
public struct ArchedDoorContourShape: Shape {
    public let archRadius: CGFloat

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let archCenter = CGPoint(x: rect.midX, y: rect.minY + archRadius)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + archRadius))
        path.addArc(
            center: archCenter,
            radius: archRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

// MARK: - 电影级胶片微晶颗粒质感生成器 (Analog 35mm Film Grain Engine)
public final class PosyFilmGrainTexture {
    public static let shared = PosyFilmGrainTexture()
    private let frames: [UIImage]

    private init() {
        let size = 160 // 160x160 硬件极速平铺纹理
        var generated: [UIImage] = []
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        for frameIdx in 0..<4 {
            var pixels = [UInt8](repeating: 0, count: size * size * 4)
            var rng = UInt64(1337 + frameIdx * 19937)
            func nextRand() -> Double {
                rng = rng &* 6364136223846793005 &+ 1442695040888963407
                return Double((rng >> 32) & 0xFFFFFFFF) / Double(0xFFFFFFFF)
            }

            for y in 0..<size {
                for x in 0..<size {
                    let idx = (y * size + x) * 4
                    // 模拟经典银盐胶片颗粒分布：双重随机混合逼近高斯分布
                    let r1 = nextRand()
                    let r2 = nextRand()
                    let grain = (r1 * 0.65 + r2 * 0.35)
                    let brightness = UInt8(clamping: Int(grain * 200.0 + 40.0))

                    pixels[idx] = brightness     // R
                    pixels[idx + 1] = brightness // G
                    pixels[idx + 2] = brightness // B
                    // 随机微晶透明度，形成有机细腻触感
                    let alpha = UInt8(clamping: Int((0.30 + 0.70 * nextRand()) * 255.0))
                    pixels[idx + 3] = alpha
                }
            }

            if let context = CGContext(
                data: &pixels,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ), let cgImage = context.makeImage() {
                generated.append(UIImage(cgImage: cgImage))
            }
        }
        self.frames = generated
    }

    public func image(for elapsed: Double) -> UIImage? {
        guard !frames.isEmpty else { return nil }
        // 14 FPS 经典电影放映机颗粒流速，生动自然绝不僵硬
        let idx = Int(elapsed * 14.0) % frames.count
        return frames[idx]
    }
}
