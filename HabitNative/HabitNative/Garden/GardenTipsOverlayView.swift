import SwiftUI

// MARK: - Garden Tips Overlay (养成花园互动玩法小 Tips — 支持中英日三语与自适应布局)
/// 视觉与交互规范：
/// 1. 半透明磨砂背板（.ultraThinMaterial），带对角线边缘高光（左上与右下对角线高光）
/// 2. 4 大互动操作：点击背景光点、长按拖拽吹风、点击花头、蜜蜂与蝴蝶
/// 3. 支持中文、英文、日文多语言无缝切换与文本行高自适应（防断句溢出）
/// 4. 交互关闭：支持点击右上角关闭按钮、轻点背景任意处，或 10 秒后自动滑出消失

public struct GardenTipsOverlayView: View {
    @Binding var isPresented: Bool
    var autoDismissDelay: Double = 10.0

    @AppStorage(AppLanguage.storageKey) private var language = "system"

    public init(isPresented: Binding<Bool>, autoDismissDelay: Double = 10.0) {
        self._isPresented = isPresented
        self.autoDismissDelay = autoDismissDelay
    }

    public var body: some View {
        ZStack {
            if isPresented {
                // 1. 半透明轻柔遮罩，点击任意处快速关闭
                Color.black.opacity(0.24)
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        dismiss()
                    }

                // 2. 核心 Tips 悬浮卡片（自适应中英日不同文案长度）
                tipsCard
                    .padding(.horizontal, 22)
                    .frame(maxWidth: 440)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.94).combined(with: .opacity).combined(with: .offset(y: 20)),
                            removal: .scale(scale: 0.96).combined(with: .opacity).combined(with: .offset(y: -16))
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .zIndex(9999)
        .animation(.spring(response: 0.46, dampingFraction: 0.82), value: isPresented)
        .task(id: isPresented) {
            guard isPresented else { return }
            try? await Task.sleep(for: .seconds(autoDismissDelay))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    // MARK: - Tips Card

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Row: 标题与关闭按钮
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.92, green: 0.45, blue: 0.62))
                        Text(AppLanguage.text("garden.tips.title"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.28, green: 0.20, blue: 0.28))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Text(AppLanguage.text("garden.tips.subtitle"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.50, green: 0.40, blue: 0.48).opacity(0.85))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                // 右上角关闭按钮
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.06))
                            .frame(width: 28, height: 28)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.42))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .accessibilityLabel(AppLanguage.text("garden.tips.close"))
            }
            .padding(.bottom, 15)

            // 4 条互动说明条目（针对不同语言行数差异自适应）
            VStack(alignment: .leading, spacing: 14) {
                TipRow(
                    icon: "sparkles",
                    iconColor: Color(red: 0.98, green: 0.70, blue: 0.38),
                    title: AppLanguage.text("garden.tips.tapBackground.title"),
                    subtitle: AppLanguage.text("garden.tips.tapBackground.desc")
                )

                TipRow(
                    icon: "wind",
                    iconColor: Color(red: 0.45, green: 0.75, blue: 0.95),
                    title: AppLanguage.text("garden.tips.windDrag.title"),
                    subtitle: AppLanguage.text("garden.tips.windDrag.desc")
                )

                TipRow(
                    icon: "flower",
                    iconColor: Color(red: 0.94, green: 0.42, blue: 0.62),
                    title: AppLanguage.text("garden.tips.tapFlower.title"),
                    subtitle: AppLanguage.text("garden.tips.tapFlower.desc")
                )

                TipRow(
                    icon: "ladybug.fill",
                    iconColor: Color(red: 0.72, green: 0.48, blue: 0.90),
                    title: AppLanguage.text("garden.tips.creatures.title"),
                    subtitle: AppLanguage.text("garden.tips.creatures.desc")
                )
            }

            // 底部轻量提示（多语言自适应居中）
            HStack {
                Spacer()
                Text(AppLanguage.text("garden.tips.dismissHint"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(red: 0.50, green: 0.40, blue: 0.48).opacity(0.55))
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(frostedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // MARK: - 半透明磨砂背板 + 对角线边缘高光
    private var frostedBackground: some View {
        ZStack {
            // 1. 磨砂玻璃基底
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)

            // 2. 浅粉暖光温润半透层
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.68),
                            Color(red: 1.0, green: 0.94, blue: 0.96).opacity(0.50),
                            Color.white.opacity(0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 3. 对角线边缘高光（对角线两端亮显：左上极亮、右下高光，中间段完全透明渐隐）
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.95), location: 0.00), // 左上角极亮
                            .init(color: Color.white.opacity(0.60), location: 0.16),
                            .init(color: Color.white.opacity(0.00), location: 0.40), // 中间透明
                            .init(color: Color.white.opacity(0.00), location: 0.60),
                            .init(color: Color.white.opacity(0.50), location: 0.84),
                            .init(color: Color.white.opacity(0.85), location: 1.00)  // 右下角高光
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.4
                )
        }
        // 柔和外阴影 + 浅玫红微发光
        .shadow(color: Color.black.opacity(0.09), radius: 24, x: 0, y: 10)
        .shadow(color: Color(red: 0.92, green: 0.42, blue: 0.62).opacity(0.12), radius: 14, x: 0, y: 4)
    }

    // MARK: - Dismiss Action
    private func dismiss() {
        withAnimation(.spring(response: 0.40, dampingFraction: 0.85)) {
            isPresented = false
        }
    }
}

// MARK: - Single Tip Row (自适应不同语言文本高度)
private struct TipRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 图标圆徽标（对齐首行文本顶部）
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .padding(.top, 1)

            // 文本信息（中英日自适应折行）
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.26, green: 0.18, blue: 0.25))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.48, green: 0.38, blue: 0.45).opacity(0.85))
                    .lineSpacing(2)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
