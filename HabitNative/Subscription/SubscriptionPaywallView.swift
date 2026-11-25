import SwiftUI
import StoreKit

/// 会员订阅付费墙视图
public struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscription = SubscriptionManager.shared

    @State private var selectedPlan: SubscriptionTier = .yearly
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false

    // Morandi 配色基调，与项目设计规范高度协调
    private let ink = Color(red: 0.17, green: 0.15, blue: 0.19)
    private let muted = Color(red: 0.45, green: 0.42, blue: 0.48)
    private let accentPurple = Color(red: 0.58, green: 0.38, blue: 0.68)
    private let cardBackground = Color.white.opacity(0.68)
    private let cardBorder = Color.white.opacity(0.85)

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // 背景：柔和 Morandi 渐变背景光晕
                backgroundGlow

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 顶部品牌与标语
                        headerSection

                        // 当前会员状态胶囊（若已是会员）
                        currentTierBadge

                        // 订阅方案卡片选择器
                        planSelectionSection

                        // 权益对比表格（免费 vs 月度 vs 年度）
                        benefitsComparisonSection

                        // 到期与数据安全说明（规范第四节）
                        expirationSafetyNotice

                        // 购买与恢复操作区域
                        actionButtonsSection

                        // 法律条款说明与链接
                        legalTermsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(red: 0.48, green: 0.44, blue: 0.52).opacity(0.65))
                    }
                    .accessibilityLabel(AppLanguage.text("关闭付费墙"))
                }
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                policySheet(title: AppLanguage.text("privacy.policy.title"), content: AppLanguage.text("privacy.policy.body"))
            }
            .sheet(isPresented: $showingTermsOfService) {
                policySheet(title: AppLanguage.text("使用条款 (EULA)"), content: termsOfServiceContent)
            }
            .alert(AppLanguage.text("购买提示"), isPresented: Binding(
                get: { subscription.purchaseSuccessNotice != nil || subscription.errorMessage != nil },
                set: { if !$0 { subscription.purchaseSuccessNotice = nil; subscription.errorMessage = nil } }
            )) {
                Button(AppLanguage.text("好的"), role: .cancel) {
                    subscription.purchaseSuccessNotice = nil
                    subscription.errorMessage = nil
                }
            } message: {
                Text(subscription.purchaseSuccessNotice ?? subscription.errorMessage ?? "")
            }
        }
    }

    // MARK: - 背景微光晕
    private var backgroundGlow: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.97),
                    Color(red: 0.92, green: 0.93, blue: 0.96),
                    Color(red: 0.96, green: 0.94, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.78, green: 0.65, blue: 0.88).opacity(0.25))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -120, y: -200)

            Circle()
                .fill(Color(red: 0.92, green: 0.72, blue: 0.68).opacity(0.20))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: 130, y: 150)
        }
    }

    // MARK: - 头部区域
    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.86, green: 0.55, blue: 0.28))
                Text(AppLanguage.text("MAYBII Habit会员计划"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.42, green: 0.38, blue: 0.48))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.white.opacity(0.7), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1))

            Text(AppLanguage.text("解锁更深层的习惯成长"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)

            Text(AppLanguage.text("更充裕的自定义卡片、全量 16 株植物庭院、多设备互通与完整 AI 复盘支持，\n提供分析和指导 帮助完成人生蜕变 重启人生。"))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.top, 4)
    }

    // MARK: - 当前会员标签
    @ViewBuilder
    private var currentTierBadge: some View {
        if subscription.currentTier != .free {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color(red: 0.40, green: 0.70, blue: 0.48))
                Text(String(format: AppLanguage.text("当前生效中：%@"), AppLanguage.text(subscription.currentTier.title)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ink)
                if let exp = subscription.expirationDate {
                    Text(String(format: AppLanguage.text("（到期时间：%@）"), formattedDate(exp)))
                        .font(.system(size: 12))
                        .foregroundStyle(muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white, lineWidth: 1.2))
        }
    }

    // MARK: - 方案选择器
    private var planSelectionSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 月度方案卡片（先展示月度）
                planCard(
                    tier: .monthly,
                    title: "月度会员",
                    subtitle: "每期 12 次创建 · 2 张自定义卡片",
                    badgeText: "按月灵活",
                    product: productForTier(.monthly)
                )

                // 年度方案卡片（后展示年度）
                planCard(
                    tier: .yearly,
                    title: "年度会员",
                    subtitle: "无限次任务创建 · 4 张自定义卡片",
                    badgeText: "推荐 · 最具深度",
                    product: productForTier(.yearly)
                )
            }

            // 价格合规提示：未配置商品时明确显示暂不可购买，不显示虚构价格，不提供试用
            if subscription.products.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.65, green: 0.45, blue: 0.35))
                    Text(AppLanguage.text("正式商品与价格正在 App Store Connect 审核配置中，暂不提供真实购买。"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.35))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.98, green: 0.94, blue: 0.90).opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - 单个方案卡片
    private func planCard(
        tier: SubscriptionTier,
        title: String,
        subtitle: String,
        badgeText: String,
        product: Product?
    ) -> some View {
        let isSelected = selectedPlan == tier
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                selectedPlan = tier
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(AppLanguage.text(badgeText))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white : muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            isSelected ? Color(red: 0.58, green: 0.38, blue: 0.68) : Color.black.opacity(0.06),
                            in: Capsule()
                        )
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? accentPurple : Color.gray.opacity(0.4))
                }

                Text(AppLanguage.text(title))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)

                if let product = product {
                    // 真实读取 StoreKit 价格
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.displayPrice)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(ink)
                        Text(tier == .yearly ? AppLanguage.text("/ 年") : AppLanguage.text("/ 月"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(muted)
                    }
                } else {
                    // 未配置时明确提示，杜绝虚构价格
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppLanguage.text("价格待配置"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(red: 0.55, green: 0.40, blue: 0.45))
                        Text(AppLanguage.text("暂不可购买"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(muted)
                    }
                }

                Text(AppLanguage.text(subtitle))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 28, alignment: .topLeading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? accentPurple : cardBorder, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? accentPurple.opacity(0.18) : Color.black.opacity(0.03), radius: isSelected ? 10 : 4, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 权益对比矩阵表格（严格依据规范第一节）
    private var benefitsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppLanguage.text("方案权益详细对比"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // 表头
                HStack(spacing: 8) {
                    Text(AppLanguage.text("权益项"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(AppLanguage.text("免费用户"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(muted)
                        .frame(width: 80, alignment: .center)

                    Text(AppLanguage.text("月度会员"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(selectedPlan == .monthly ? accentPurple : muted)
                        .frame(width: 82, alignment: .center)

                    Text(AppLanguage.text("年度会员"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(selectedPlan == .yearly ? accentPurple : muted)
                        .frame(width: 82, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.45))

                Divider().opacity(0.5)

                comparisonRow(icon: "rectangle.stack", name: "自定义卡片", free: "1 张", monthly: "2 张", yearly: "4 张")
                Divider().opacity(0.3)
                comparisonRow(icon: "pencil.and.list.clipboard", name: "任务创建次数", free: "累计 2 次", monthly: "12 次/期", yearly: "不限次数")
                Divider().opacity(0.3)
                comparisonRow(icon: "sun.max", name: "每日习惯名额", free: "3+1星标", monthly: "+2 额外名额", yearly: "+2 额外名额")
                Divider().opacity(0.3)
                comparisonRow(icon: "sparkle.magnifyingglass", name: "AI 周复盘", free: "体验 1 次", monthly: "按规则使用", yearly: "按规则使用")
                Divider().opacity(0.3)
                comparisonRow(icon: "leaf", name: "植物庭院展示", free: "最近 2 株", monthly: "14 株全展示", yearly: "16 株全展示")
                Divider().opacity(0.3)
                comparisonRow(icon: "arrow.triangle.2.circlepath", name: "跨设备同步", free: "仅限本地", monthly: "支持已实现平台", yearly: "支持已实现平台")
            }
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(cardBorder, lineWidth: 1))
        }
    }

    private func comparisonRow(
        icon: String,
        name: String,
        free: String,
        monthly: String,
        yearly: String
    ) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(accentPurple)
                Text(AppLanguage.text(name))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(AppLanguage.text(free))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(muted)
                .frame(width: 80, alignment: .center)

            Text(AppLanguage.text(monthly))
                .font(.system(size: 12, weight: selectedPlan == .monthly ? .semibold : .medium))
                .foregroundStyle(selectedPlan == .monthly ? accentPurple : ink)
                .frame(width: 82, alignment: .center)

            Text(AppLanguage.text(yearly))
                .font(.system(size: 12, weight: selectedPlan == .yearly ? .bold : .medium))
                .foregroundStyle(selectedPlan == .yearly ? accentPurple : ink)
                .frame(width: 82, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - 会员到期与数据安心保障（严格依据规范第四节）
    private var expirationSafetyNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 0.45))
                Text(AppLanguage.text("数据与到期安心保障"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
            }

            VStack(alignment: .leading, spacing: 6) {
                bulletPoint(AppLanguage.text("到期不删数据：所有历史打卡记录、AI 周复盘、植物成长值、名称及外观均永久保留，绝不会因会员到期而枯萎或死亡。"))
                bulletPoint(AppLanguage.text("卡片智能保留：到期后自动保留成长等级最高（或最近互动）的 1 张卡片继续使用，其余卡片完整冻结保留。"))
                bulletPoint(AppLanguage.text("庭院平滑过渡：到期后庭院展示最近互动的 2 株植物；重新订阅即可立刻按原有数据完整恢复展示。"))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.8), lineWidth: 1))
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(muted)
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(muted)
                .lineSpacing(3)
        }
    }

    // MARK: - 操作按钮区域
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            let targetProduct = productForTier(selectedPlan)
            let isPurchasable = targetProduct != nil

            Button {
                if let product = targetProduct {
                    Task { try? await subscription.purchase(product) }
                }
            } label: {
                HStack(spacing: 8) {
                    if subscription.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: isPurchasable ? "sparkles" : "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(isPurchasable ? String(format: AppLanguage.text("立即开启%@"), AppLanguage.text(selectedPlan.title)) : AppLanguage.text("价格待配置（暂不可购买）"))
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isPurchasable
                        ? LinearGradient(colors: [Color(red: 0.65, green: 0.42, blue: 0.76), Color(red: 0.48, green: 0.30, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: isPurchasable ? accentPurple.opacity(0.35) : Color.clear, radius: 10, y: 4)
            }
            .disabled(!isPurchasable || subscription.isPurchasing)

            // 恢复购买按钮
            Button {
                Task { await subscription.restorePurchases() }
            } label: {
                HStack(spacing: 6) {
                    if subscription.isRestoring {
                        ProgressView().scaleEffect(0.8)
                    }
                    Text(AppLanguage.text("恢复已购买的会员"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.38, green: 0.35, blue: 0.42))
                }
                .padding(.vertical, 6)
            }
            .disabled(subscription.isRestoring)
        }
    }

    // MARK: - 法律条款与隐私
    private var legalTermsSection: some View {
        VStack(spacing: 8) {
            Text(AppLanguage.text("订阅说明：月度与年度订阅均不提供试用期。确认购买后将从您的 Apple ID 账户扣款。订阅将自动续费，除非在当前计费周期结束前至少 24 小时关闭自动续订。您可以前往 App Store 账户设置中管理或取消订阅。"))
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color.gray.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 16) {
                Button(AppLanguage.text("使用条款")) { showingTermsOfService = true }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(muted)

                Text("·").font(.system(size: 11)).foregroundStyle(muted)

                Button(AppLanguage.text("隐私政策")) { showingPrivacyPolicy = true }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(muted)
            }
        }
        .padding(.horizontal, 10)
    }

    private func productForTier(_ tier: SubscriptionTier) -> Product? {
        let id = tier == .yearly ? SubscriptionManager.yearlyProductID : SubscriptionManager.monthlyProductID
        return subscription.products.first { $0.id == id }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func policySheet(title: String, content: String) -> some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.system(size: 14))
                    .foregroundStyle(ink)
                    .lineSpacing(5)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        showingPrivacyPolicy = false
                        showingTermsOfService = false
                    }
                }
            }
        }
    }

    private var termsOfServiceContent: String {
        """
        HabitNative 订阅使用条款 (EULA)

        1. 订阅服务内容
        HabitNative 提供月度会员与年度会员自动续订服务。会员享有更多的自定义卡片名额、额度扩充、植物庭院进阶展示以及多设备同步支持。

        2. 试用与扣费规则
        根据规范，月度与年度订阅均不提供订阅免费试用。用户确认购买后，费用将由 Apple 通过您的 Apple ID 账户收取。

        3. 自动续订与取消
        订阅将在每个周期到期前 24 小时内自动续订并扣费。您可以随时在 iOS「设置」-「Apple ID」-「订阅」中管理或关闭自动续费。

        4. 会员到期权益与数据保留
        会员订阅到期后，您的打卡记录、AI 周复盘、植物成长数据永久保留，系统将依据规则自动平滑保留免费基础额度。

        5. 政策与联系
        我们严格遵守苹果 App Store 开发者审核指南与隐私规范。
        """
    }
}
