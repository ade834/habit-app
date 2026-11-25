import SwiftUI
import UIKit

// MARK: - 1. 精确光标定位与中文拼音上屏检测的透明输入层
struct TypewriterTextView: UIViewRepresentable {
    @Binding var confirmedText: String
    @Binding var caretPosition: CGPoint
    var onCharacterTyped: () -> Void
    var onCarriageReturn: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        // 使用系统明朝体或标准衬线体，兼顾中英文字体美感
        if let customFont = UIFont(name: "Hiragino Mincho ProN", size: 20) {
            tv.font = customFont
        } else {
            tv.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        }
        tv.textColor = .clear // 隐藏原生文字，由外部纸张视图渲染
        tv.tintColor = .clear // 隐藏系统默认蓝色光标
        tv.text = confirmedText
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        tv.autocorrectionType = .no
        tv.spellCheckingType = .no
        
        // 自动呼起键盘
        DispatchQueue.main.async {
            tv.becomeFirstResponder()
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != confirmedText {
            uiView.text = confirmedText
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TypewriterTextView
        private var previousLength: Int = 0

        init(_ parent: TypewriterTextView) {
            self.parent = parent
            self.previousLength = parent.confirmedText.count
        }

        func textViewDidChange(_ textView: UITextView) {
            // 关键：检测中文拼音是否还在候选阶段（markedTextRange 非空则表示还在拼音输入中）
            guard textView.markedTextRange == nil else { return }

            let currentText = textView.text ?? ""
            let didAddCharacter = currentText.count > previousLength

            // 检查是否刚刚输入了换行符
            let didEnterNewline = currentText.hasSuffix("\n") && didAddCharacter

            if parent.confirmedText != currentText {
                parent.confirmedText = currentText
                previousLength = currentText.count

                if didEnterNewline {
                    parent.onCarriageReturn()
                } else if didAddCharacter {
                    parent.onCharacterTyped()
                }
            }

            // 获取当前光标精确像素位置
            if let selectedRange = textView.selectedTextRange {
                let rect = textView.caretRect(for: selectedRange.end)
                DispatchQueue.main.async {
                    self.parent.caretPosition = CGPoint(x: rect.midX, y: rect.maxY)
                }
            }
        }
    }
}

// MARK: - 2. 拟物打字机主界面
struct TypewriterSceneView: View {
    @State private var text: String = "雨轻轻落在屋顶，\n夜色浸润了字迹。"
    @State private var caretPos: CGPoint = CGPoint(x: 140, y: 56)
    @State private var isNightMode: Bool = false
    @State private var isStriking: Bool = false

    private let samplePhrases = [
        "白日依山尽，黄河入海流。",
        "星光不问赶路人，时光不负有心人。",
        "The quick brown fox jumps over the lazy dog."
    ]

    var body: some View {
        ZStack {
            // 桌面环境底色
            Color(red: 0.10, green: 0.10, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部状态栏与控制面板
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VINTAGE TYPEWRITER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.9))
                        Text(isNightMode ? "黑夜追光模式 (双击纸张切换)" : "明亮工作室模式 (双击纸张切换)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    // 昼夜切换按钮
                    Button {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            isNightMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isNightMode ? "moon.stars.fill" : "sun.max.fill")
                                .foregroundColor(isNightMode ? .yellow : .orange)
                            Text(isNightMode ? "黑夜" : "白昼")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer().frame(height: 20)

                // 打字机中央舞台
                ZStack {
                    // --- 滚筒背景机身槽 ---
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.15), Color(white: 0.08), Color(white: 0.20)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(maxWidth: .infinity, maxHeight: 520)
                        .padding(.horizontal, 12)
                        .shadow(color: .black.opacity(0.7), radius: 20, y: 12)

                    // --- 纸张层 ---
                    ZStack(alignment: .topLeading) {
                        // 1. 米黄色复古信纸底色
                        RoundedRectangle(cornerRadius: 12)
                            .fill(TactilePalette.typewriterPaper)
                            .paperTexture(intensity: 0.04)

                        // 2. 纸张顶部圆筒卷曲阴影（模拟卷入滚轴的暗角效果）
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.75),
                                        Color.black.opacity(0.20),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .init(x: 0.5, y: 0.28)
                                )
                            )

                        // 3. 渲染已敲出的文字（根据光标 Y 轴反向平移，模拟纸张自动上滚）
                        Text(text.isEmpty ? "敲击键盘开始打字..." : text)
                            .font(.custom("Hiragino Mincho ProN", size: 20))
                            .foregroundColor(text.isEmpty ? .black.opacity(0.3) : .black.opacity(0.85))
                            .lineSpacing(10)
                            .padding(.horizontal, 36)
                            .padding(.top, 40)
                            .offset(y: max(-300, 240 - caretPos.y))
                            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: caretPos.y)

                        // 4. 透明输入层（处理系统键盘事件与精准光标）
                        TypewriterTextView(
                            confirmedText: $text,
                            caretPosition: $caretPos,
                            onCharacterTyped: {
                                triggerKeyStrike()
                            },
                            onCarriageReturn: {
                                triggerCarriageReturn()
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .frame(height: 480)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 480)
                    .padding(.horizontal, 24)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    // 黑夜模式下纸张整体深暗化
                    .brightness(isNightMode ? -0.58 : 0)

                    // --- 黑夜模式锥形追光 (Cone Light / Spotlight) ---
                    if isNightMode {
                        LightConeShape()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.94, blue: 0.76).opacity(0.82),
                                        Color(red: 1.0, green: 0.90, blue: 0.70).opacity(0.25),
                                        Color.clear
                                    ],
                                    center: .bottom,
                                    startRadius: 8,
                                    endRadius: 240
                                )
                            )
                            .frame(width: 280, height: 280)
                            // 动态追随打字头光标 X 轴
                            .position(x: min(max(caretPos.x + 40, 80), 320), y: 175)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.8), value: caretPos.x)
                    }

                    // --- 机械金属导轨与移动打字头 ---
                    ZStack(alignment: .leading) {
                        // 黑色金属滑轨
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.black, Color(white: 0.40), Color.black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 16)
                            .shadow(color: .black.opacity(0.6), radius: 8, y: 5)

                        // 导轨刻度线装饰
                        HStack(spacing: 12) {
                            ForEach(0..<20) { _ in
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 1, height: 8)
                            }
                        }
                        .padding(.horizontal, 20)

                        // 移动打字头组件
                        VStack(spacing: 0) {
                            // 金属 T 型击锤
                            Image(systemName: "t.square.fill")
                                .resizable()
                                .frame(width: 20, height: 24)
                                .foregroundColor(.init(white: 0.75))
                                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                                .offset(y: isStriking ? -8 : 4)

                            // 经典橙色印花滑块主体
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.55, blue: 0.22), Color(red: 0.88, green: 0.38, blue: 0.12)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 88, height: 46)
                                .overlay(
                                    HStack(spacing: 6) {
                                        // 指示灯
                                        Circle()
                                            .fill(isNightMode ? Color.yellow : Color.orange.opacity(0.5))
                                            .frame(width: 7, height: 7)
                                            .shadow(color: isNightMode ? .yellow : .clear, radius: 4)
                                        Circle()
                                            .fill(isNightMode ? Color.orange : Color.white.opacity(0.25))
                                            .frame(width: 7, height: 7)
                                        Spacer()
                                        // 品牌徽标装饰
                                        Text("ROYAL")
                                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                    .padding(.horizontal, 10)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
                        }
                        .offset(x: min(max(caretPos.x - 24, 16), 280), y: -10)
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: caretPos.x)
                    }
                    .offset(y: 80)
                }
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        isNightMode.toggle()
                    }
                }

                // 底部辅助输入工具栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("清空纸张") {
                            text = ""
                            caretPos = CGPoint(x: 20, y: 20)
                            TactileFeedbackManager.shared.playCarriageReturnSound()
                        }
                        .buttonStyle(AuxiliaryButtonStyle(icon: "trash"))

                        ForEach(samplePhrases, id: \.self) { phrase in
                            Button("插入: \(phrase.prefix(6))...") {
                                appendSamplePhrase(phrase)
                            }
                            .buttonStyle(AuxiliaryButtonStyle(icon: "pencil.and.scribble"))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - 敲击动作与反馈
    private func triggerKeyStrike() {
        TactileFeedbackManager.shared.playTypewriterKeyStrike()
        withAnimation(.easeIn(duration: 0.04)) {
            isStriking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.08)) {
                isStriking = false
            }
        }
    }

    private func triggerCarriageReturn() {
        TactileFeedbackManager.shared.playTypewriterCarriageReturn()
    }

    private func appendSamplePhrase(_ phrase: String) {
        if text.isEmpty {
            text = phrase
        } else {
            text += "\n" + phrase
        }
        triggerKeyStrike()
    }
}

// MARK: - 扇形光束几何形状 (Light Cone)
struct LightConeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // 底部光源起点（对应滑块灯口）
        path.move(to: CGPoint(x: rect.midX - 16, y: rect.maxY))
        // 向上展开成扇形射入纸张
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 20))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 20),
            control: CGPoint(x: rect.midX, y: rect.minY - 30)
        )
        path.addLine(to: CGPoint(x: rect.midX + 16, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 辅助按钮样式
struct AuxiliaryButtonStyle: ButtonStyle {
    var icon: String

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            configuration.label
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(configuration.isPressed ? 0.25 : 0.12))
        )
        .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}

private extension TactileFeedbackManager {
    func playCarriageReturnSound() {
        playTypewriterCarriageReturn()
    }
}
