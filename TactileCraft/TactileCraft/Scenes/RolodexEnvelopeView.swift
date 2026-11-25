import SwiftUI

// MARK: - 信封数据模型
struct EnvelopeItem: Identifiable {
    let id = UUID()
    let recipient: String
    let subtitle: String
    let date: String
    let stampColor: Color
    let stampIcon: String
    let postmarkLocation: String
    let letterContent: String
}

// MARK: - 3D 机械滚轮信封翻页视图 (Rolodex)
struct RolodexEnvelopeView: View {
    let items: [EnvelopeItem] = [
        .init(
            recipient: "to Amara",
            subtitle: "from the old flat",
            date: "14 OCT 1984",
            stampColor: Color(red: 0.22, green: 0.45, blue: 0.65),
            stampIcon: "sailboat.fill",
            postmarkLocation: "EDINBURGH",
            letterContent: "亲爱的 Amara：\n\n旧公寓里的老唱片机还能转动，窗外的雨落了一整夜。信箱里塞满了旧报纸，随信寄去你落在抽屉里的铜钥匙。"
        ),
        .init(
            recipient: "to Léa",
            subtitle: "Montréal",
            date: "28 NOV 1986",
            stampColor: Color(red: 0.75, green: 0.28, blue: 0.24),
            stampIcon: "leaf.fill",
            postmarkLocation: "MONTRÉAL QC",
            letterContent: "Chère Léa,\n\n蒙特利尔的第一场雪比往年要早。圣劳伦斯河的薄冰倒映着港口的灯塔，愿壁炉的柴火温暖你的冬夜。"
        ),
        .init(
            recipient: "to Sam",
            subtitle: "from the desk",
            date: "03 MAR 1991",
            stampColor: Color(red: 0.30, green: 0.55, blue: 0.38),
            stampIcon: "mountain.2.fill",
            postmarkLocation: "OXFORD",
            letterContent: "Sam,\n\n书桌上的打字机齿轮已经重新校准好。你要找的那篇手稿我放在第三个抽屉里，记得在周五前回复。"
        ),
        .init(
            recipient: "to Nia",
            subtitle: "from Lisbon",
            date: "19 JUN 1995",
            stampColor: Color(red: 0.85, green: 0.58, blue: 0.18),
            stampIcon: "sun.max.fill",
            postmarkLocation: "LISBOA",
            letterContent: "Querida Nia,\n\n里斯本的电车穿过石板路，空气中弥漫着烤沙丁鱼和海风的味道。为你挑选了一枚蓝色瓷砖的明信片。"
        ),
        .init(
            recipient: "to Papa",
            subtitle: "Kinshasa",
            date: "05 SEP 1998",
            stampColor: Color(red: 0.55, green: 0.35, blue: 0.65),
            stampIcon: "globe.europe.africa.fill",
            postmarkLocation: "KINSHASA",
            letterContent: "爸爸：\n\n这里的雨季快要结束了，庭院里的芒果树结了第一批果实。一切安好，盼复。"
        )
    ]

    @State private var selectedEnvelope: EnvelopeItem?
    @State private var isShowingLetter: Bool = false

    var body: some View {
        GeometryReader { outerGeo in
            let screenHeight = outerGeo.size.height > 0 ? outerGeo.size.height : UIScreen.main.bounds.height
            let centerY = screenHeight / 2

            ZStack {
                // 拟物复古背景（厚卡纸灰底色）
                TactilePalette.rolodexBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部提示标签
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ROLODEX ARCHIVE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(white: 0.35))
                            Text("上下滑动翻阅 3D 机械滚轮信封，点击信封阅读内文")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(white: 0.45))
                        }
                        Spacer()
                        Image(systemName: "tray.full.fill")
                            .foregroundColor(Color(white: 0.4))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    // 滚轮信封滚动区域
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: -38) { // 负间距让上下折叠卡片紧凑排列
                            ForEach(items) { item in
                                EnvelopeCard(item: item, screenCenterY: centerY) {
                                    TactileFeedbackManager.shared.playTypewriterKeyStrike()
                                    selectedEnvelope = item
                                    isShowingLetter = true
                                }
                                .frame(height: 250)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, centerY - 125)
                    }
                    .scrollTargetBehavior(.viewAligned) // 精准吸附居中
                }
            }
            .sheet(item: $selectedEnvelope) { item in
                LetterDetailSheet(item: item)
            }
        }
    }
}

// MARK: - 3D 翻页单张信封卡片
struct EnvelopeCard: View {
    let item: EnvelopeItem
    let screenCenterY: CGFloat
    var onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let midY = geo.frame(in: .global).midY
            let safeCenterY = screenCenterY > 0 ? screenCenterY : (UIScreen.main.bounds.height / 2)
            // 归一化距离：0 在屏幕正中心，负值在上方，正值在下方 (-1.0 ... 1.0)
            let progress = ((midY - safeCenterY) / 220).clamped(to: -1.0...1.0)
            let absProgress = abs(progress)

            ZStack {
                if progress > 0.42 {
                    // 处于下方倾斜视角：展示信封背面的三角折翼与火漆封蜡
                    EnvelopeBackView(item: item)
                } else {
                    // 处于正中心或上方仰视视角：展示信封正面、邮票、邮戳与手写收件人
                    EnvelopeFrontView(item: item)
                }
            }
            // 纸张表面颗粒噪点
            .paperTexture(intensity: 0.035)
            // 根据翻转角度叠加动态环境阴影（模拟背光面变暗）
            .overlay(
                Color.black.opacity(absProgress * 0.28)
                    .allowsHitTesting(false)
            )
            // 核心 3D 机械滚轮矩阵翻转：
            // progress < 0 (滑到上方)：绕底部边框向后仰 (anchor: .bottom)
            // progress > 0 (滑到下方)：绕顶部边框向前倾 (anchor: .top)
            .rotation3DEffect(
                .degrees(progress * -72),
                axis: (x: 1, y: 0, z: 0),
                anchor: progress < 0 ? .bottom : .top,
                perspective: 0.45
            )
            .scaleEffect(x: 1.0 - absProgress * 0.08, y: 1.0 - absProgress * 0.15)
            .zIndex(1.0 - absProgress) // 正中间卡片层级最高
            .onTapGesture {
                onTap()
            }
        }
        .padding(.horizontal, 22)
    }
}

// MARK: - 信封正面组件 (Envelope Front)
struct EnvelopeFrontView: View {
    let item: EnvelopeItem

    var body: some View {
        ZStack {
            // 信封米黄纸底
            RoundedRectangle(cornerRadius: 14)
                .fill(TactilePalette.envelopeFront)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 6)

            // 航空信封红蓝斑马斜纹边框
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    Color.black.opacity(0.06),
                    lineWidth: 1
                )

            // 信封内容布局
            VStack(alignment: .leading, spacing: 0) {
                // 顶部：航空标志与邮票、邮戳
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PAR AVION / BY AIR MAIL")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.blue.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.08))
                            )

                        Text("PRIORITY POST")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding(.leading, 2)
                    }

                    Spacer()

                    // 复古环形波浪邮戳
                    PostmarkView(location: item.postmarkLocation, date: item.date)
                        .offset(x: -6, y: 2)

                    // 复古打孔邮票
                    VintageStampView(
                        color: item.stampColor,
                        icon: item.stampIcon,
                        price: "45¢"
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                Spacer()

                // 中央偏右：手写风格收件人与地址
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.recipient)
                        .font(.custom("Snell Roundhand", size: 28))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.22))

                    Text(item.subtitle)
                        .font(.custom("Courier", size: 14))
                        .foregroundColor(Color.black.opacity(0.65))

                    // 虚线收件地址下划线
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 180, height: 1)
                }
                .padding(.leading, 32)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - 信封背面组件 (Envelope Back)
struct EnvelopeBackView: View {
    let item: EnvelopeItem

    var body: some View {
        ZStack {
            // 信封背面纸底
            RoundedRectangle(cornerRadius: 14)
                .fill(TactilePalette.envelopeBack)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)

            // 三角折翼剪影与阴影 (Flap)
            EnvelopeFlapShape()
                .fill(
                    LinearGradient(
                        colors: [TactilePalette.envelopeBack, Color(red: 0.86, green: 0.84, blue: 0.80)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.15), radius: 4, y: 3)

            // 折缝描边
            EnvelopeFlapShape()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)

            // 中央火漆蜡封 (Wax Seal)
            VStack {
                Spacer()
                WaxSealBadgeView(icon: item.stampIcon)
                    .offset(y: 6)
                Spacer()
            }

            // 底部细小地址标注
            VStack {
                Spacer()
                Text("DISPATCHED VIA ROLLING ARCHIVE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.black.opacity(0.35))
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - 邮票视图 (Vintage Stamp)
struct VintageStampView: View {
    let color: Color
    let icon: String
    let price: String

    var body: some View {
        ZStack {
            // 邮票打孔外底
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.98, green: 0.96, blue: 0.90))
                .frame(width: 54, height: 64)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .foregroundColor(Color.black.opacity(0.25))
                )

            // 邮票内部印刷彩色图框
            VStack(spacing: 3) {
                HStack {
                    Text(price)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                }

                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.white)

                Text("POSTAGE")
                    .font(.system(size: 6, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(5)
            .frame(width: 46, height: 56)
            .background(color)
            .cornerRadius(2)
        }
    }
}

// MARK: - 邮戳组件 (Postmark)
struct PostmarkView: View {
    let location: String
    let date: String

    var body: some View {
        ZStack {
            // 外圈圆环
            Circle()
                .stroke(Color.black.opacity(0.38), lineWidth: 1.2)
                .frame(width: 58, height: 58)

            // 内圈圆环
            Circle()
                .stroke(Color.black.opacity(0.38), lineWidth: 0.8)
                .frame(width: 42, height: 42)

            // 地点与日期
            VStack(spacing: 2) {
                Text(location)
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.black.opacity(0.55))

                Text(date)
                    .font(.system(size: 6, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.black.opacity(0.55))
            }

            // 邮戳右侧波浪线
            HStack(spacing: 2) {
                Spacer().frame(width: 52)
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 14, height: 1)
                }
            }
        }
        .rotationEffect(.degrees(-12))
    }
}

// MARK: - 火漆蜡封组件 (Wax Seal)
struct WaxSealBadgeView: View {
    let icon: String

    var body: some View {
        ZStack {
            // 外圈不规则蜡液厚边
            Circle()
                .fill(TactilePalette.envelopeWax)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 3)

            // 内圈烫金/压痕
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: 34, height: 34)

            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.98, green: 0.92, blue: 0.80).opacity(0.85))
        }
    }
}

// MARK: - 信封三角折翼几何形状 (Flap Shape)
struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        // 向下延展三角尖端
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.62))
        path.closeSubpath()
        return path
    }
}

// MARK: - 展开信件详情内页 (Letter Detail Sheet)
struct LetterDetailSheet: View {
    let item: EnvelopeItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TactilePalette.typewriterPaper.ignoresSafeArea()
                    .paperTexture(intensity: 0.04)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.recipient)
                                    .font(.custom("Snell Roundhand", size: 32))
                                    .fontWeight(.bold)
                                Text(item.subtitle + " • " + item.date)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VintageStampView(color: item.stampColor, icon: item.stampIcon, price: "45¢")
                        }
                        .padding(.bottom, 10)

                        Divider()

                        Text(item.letterContent)
                            .font(.custom("Hiragino Mincho ProN", size: 18))
                            .lineSpacing(12)
                            .foregroundColor(Color.black.opacity(0.85))

                        Spacer().frame(height: 40)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("信件归档")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 扩展辅助
private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
