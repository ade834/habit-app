import SwiftUI
import AudioToolbox

// MARK: - 1. 底部带撕纸锯齿的热敏小票形状
struct ReceiptPaperShape: Shape {
    var toothWidth: CGFloat = 10
    var toothHeight: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - toothHeight))

        // 绘制底部连续锯齿
        let count = max(1, Int(rect.width / toothWidth))
        let actualWidth = rect.width / CGFloat(count)
        for i in (0..<count).reversed() {
            let x = CGFloat(i) * actualWidth
            path.addLine(to: CGPoint(x: x + actualWidth / 2, y: rect.height))
            path.addLine(to: CGPoint(x: x, y: rect.height - toothHeight))
        }

        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - 2. 灵动岛热敏小票打印机主视图
struct DynamicIslandReceiptView: View {
    @State private var isSlotExpanded: Bool = false
    @State private var printProgress: CGFloat = 0.0
    @State private var isTornOff: Bool = false
    @State private var hapticTimer: Timer?
    @State private var showSummarySheet: Bool = false
    @State private var printedCount: Int = 1

    private let receiptHeight: CGFloat = 540

    var body: some View {
        ZStack(alignment: .top) {
            // 底层环境背景
            Color(red: 0.94, green: 0.94, blue: 0.92).ignoresSafeArea()

            // 页面主控制区域
            VStack(spacing: 24) {
                Spacer().frame(height: 120)

                // 拟物仪表盘状态卡片
                VStack(spacing: 12) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0.20, green: 0.20, blue: 0.24))

                    Text("DYNAMIC ISLAND PRINTER")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.50))

                    Text("灵动岛热敏小票机")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.15))

                    Text("体验应用内伪装灵动岛展开出纸口、连续锯齿热敏纸吐纸、步进电机微震动以及物理撕纸脱离动效。")
                        .font(.system(size: 13, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.40))
                        .padding(.horizontal, 24)

                    // 打印触发按钮
                    Button {
                        startPrintingSequence()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                            Text(isSlotExpanded ? "正在出纸打印..." : "打印账单小票 #\(printedCount)")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(isSlotExpanded ? Color.gray : Color(red: 0.15, green: 0.15, blue: 0.18))
                        )
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
                    }
                    .disabled(isSlotExpanded)
                    .padding(.top, 8)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
                )
                .padding(.horizontal, 20)

                // 打印说明提示
                VStack(alignment: .leading, spacing: 10) {
                    Label("顶部黑色胶囊与真机灵动岛 1:1 重合贴紧", systemImage: "checkmark.circle.fill")
                    Label("步进电机吐纸带齿轮连续微触感与声音反馈", systemImage: "checkmark.circle.fill")
                    Label("打印完成 0.75s 后倾斜撕下并高速坠落", systemImage: "checkmark.circle.fill")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.40))
                .padding(.horizontal, 30)

                Spacer()
            }

            // 全屏暗色背景遮罩（打印时逐渐加深）
            Color.black.opacity(isSlotExpanded ? 0.32 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: isSlotExpanded)
                .allowsHitTesting(isSlotExpanded)

            // --- 顶部伪装灵动岛与出纸机构 ---
            ZStack(alignment: .top) {
                // 1. 伪装灵动岛黑色外壳（与真机灵动岛位置完全对齐）
                Capsule()
                    .fill(Color.black)
                    .frame(
                        width: isSlotExpanded ? 365 : 126,
                        height: isSlotExpanded ? 54 : 37
                    )
                    .padding(.top, 11)
                    .zIndex(3)
                    .overlay(
                        // 展开时的金属出纸槽高光与指示灯
                        HStack(spacing: 8) {
                            if isSlotExpanded {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: .green, radius: 4)
                                Text("PRINTING")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text("FEED ▶")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 11)
                    )
                    .animation(.spring(response: 0.36, dampingFraction: 0.76), value: isSlotExpanded)

                // 2. 出纸裁剪区与小票本尊
                ZStack(alignment: .top) {
                    ReceiptContentView(billNumber: printedCount)
                        .frame(width: 335, height: receiptHeight)
                        .background(
                            ReceiptPaperShape(toothWidth: 10, toothHeight: 7)
                                .fill(TactilePalette.receiptPaper)
                                .paperTexture(intensity: 0.03)
                                .shadow(color: .black.opacity(0.24), radius: 18, y: 12)
                        )
                        // 出纸口顶部阴影（模拟深邃的内部出纸缝）
                        .overlay(alignment: .top) {
                            LinearGradient(
                                colors: [.black.opacity(0.45), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 22)
                        }
                        // 吐纸推进阶段：Y 轴从 -receiptHeight 线性推到 0
                        .offset(y: -receiptHeight + (receiptHeight * printProgress))
                        // 撕纸阶段：斜向旋转 -14° + 向右下方抛飞坠落
                        .rotationEffect(.degrees(isTornOff ? -14 : 0), anchor: .topLeading)
                        .offset(x: isTornOff ? 110 : 0, y: isTornOff ? 920 : 0)
                }
                .padding(.top, 38) // 对齐黑色胶囊中偏下位置
                .clipShape(Rectangle().offset(y: 38)) // 裁掉高于出纸缝的上半部分
                .zIndex(2)
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showSummarySheet) {
            ReceiptSummarySheet(billNumber: printedCount) {
                showSummarySheet = false
                printedCount += 1
            }
        }
    }

    // MARK: - 完整打印时间轴时序
    private func startPrintingSequence() {
        // 重置状态
        isTornOff = false
        printProgress = 0.0

        // 第 1 步 (0.0s)：灵动岛撑开
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            isSlotExpanded = true
        }

        // 第 2 步 (0.25s)：开始步进电机匀速吐纸 + 连续微触感
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            startPrinterHaptics()
            withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 2.6)) {
                printProgress = 1.0
            }
        }

        // 第 3 步 (2.85s)：出纸完成，停顿供用户看清
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.85) {
            stopPrinterHaptics()
        }

        // 第 4 步 (3.6s)：触发撕纸、高速抛落脱离，灵动岛缩回
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            TactileFeedbackManager.shared.playTearOffPaper()

            withAnimation(.easeIn(duration: 0.48)) {
                isTornOff = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.18)) {
                isSlotExpanded = false
            }

            // 撕断后弹起账单结算 Sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                showSummarySheet = true
            }
        }
    }

    // 步进电机微触感循环
    private func startPrinterHaptics() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { _ in
            generator.impactOccurred(intensity: 0.55)
        }
    }

    private func stopPrinterHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
}

// MARK: - 3. 热敏收据票据内容 (Receipt Content)
struct ReceiptContentView: View {
    let billNumber: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // 店铺 LOGO 与店名
            VStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 26))
                    .foregroundColor(TactilePalette.thermalInk)

                Text("TACTILE COFFEE ROASTERS")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(TactilePalette.thermalInk)

                Text("NO. 104 GUILDHALL STREET")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(TactilePalette.thermalInk.opacity(0.7))
            }
            .padding(.bottom, 14)

            // 虚线分割线
            DashedSeparator()

            // 交易信息
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("ORDER #0\(billNumber)")
                    Spacer()
                    Text("TABLE 07")
                }
                HStack {
                    Text("DATE: 2026-10-22")
                    Spacer()
                    Text("TIME: 15:42")
                }
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(TactilePalette.thermalInk.opacity(0.8))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            DashedSeparator()

            // 消费项目明细
            VStack(spacing: 8) {
                ReceiptItemRow(title: "Dirty Coffee (Oat)", qty: "1", price: "¥ 32.00")
                ReceiptItemRow(title: "Pain au Chocolat", qty: "2", price: "¥ 52.00")
                ReceiptItemRow(title: "Vintage Stamp Card", qty: "1", price: "¥ 18.00")
                ReceiptItemRow(title: "Hand Drip Ethiopia", qty: "1", price: "¥ 38.00")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            DashedSeparator()

            // 金额结算汇总
            VStack(spacing: 6) {
                HStack {
                    Text("SUBTOTAL")
                    Spacer()
                    Text("¥ 140.00")
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))

                HStack {
                    Text("DISCOUNT (MEMBER)")
                    Spacer()
                    Text("- ¥ 14.00")
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))

                HStack {
                    Text("TOTAL AMOUNT")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                    Spacer()
                    Text("¥ 126.00")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                }
                .padding(.top, 4)
            }
            .foregroundColor(TactilePalette.thermalInk)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            DashedSeparator()

            // 模拟条形码与尾部祝福语
            VStack(spacing: 8) {
                BarcodeView()
                    .frame(height: 38)
                    .padding(.horizontal, 24)

                Text("* THANK YOU FOR VISITING *")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(TactilePalette.thermalInk.opacity(0.75))
            }
            .padding(.top, 14)

            Spacer()
        }
    }
}

// MARK: - 虚线分割线组件
struct DashedSeparator: View {
    var body: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            .frame(height: 1)
            .foregroundColor(TactilePalette.thermalInk.opacity(0.35))
            .padding(.horizontal, 16)
    }
}

// MARK: - 单行消费项目
struct ReceiptItemRow: View {
    let title: String
    let qty: String
    let price: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
            Spacer()
            Text("x\(qty)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
            Text(price)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(width: 68, alignment: .trailing)
        }
        .foregroundColor(TactilePalette.thermalInk)
    }
}

// MARK: - 条形码组件 (Barcode)
struct BarcodeView: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<28) { i in
                Rectangle()
                    .fill(TactilePalette.thermalInk)
                    .frame(width: (i % 3 == 0) ? 3 : (i % 2 == 0 ? 1.5 : 2.2))
            }
        }
    }
}

// MARK: - 撕纸后账单结算 Sheet
struct ReceiptSummarySheet: View {
    let billNumber: Int
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
                .padding(.top, 30)

            Text("账单小票已撕下！")
                .font(.title2)
                .fontWeight(.bold)

            Text("小票 #0\(billNumber) 已打印并完成物理下落。\n可在历史单据中随时复印与导出。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)

            Divider().padding(.vertical, 10)

            Button("完成并准备下一张") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .presentationDetents([.fraction(0.4)])
    }
}
