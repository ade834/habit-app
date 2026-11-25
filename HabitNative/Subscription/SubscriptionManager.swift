import Foundation
import StoreKit
import SwiftUI
import Combine

/// 会员订阅方案等级
public enum SubscriptionTier: String, CaseIterable, Identifiable, Sendable {
    case free = "free"
    case monthly = "monthly"
    case yearly = "yearly"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .free: return "免费方案"
        case .monthly: return "月度会员"
        case .yearly: return "年度会员"
        }
    }

    public var badge: String {
        switch self {
        case .free: return "基础体验"
        case .monthly: return "灵活进阶"
        case .yearly: return "超值全能"
        }
    }

    /// 自定义卡片数量上限
    public var maxCustomCards: Int {
        switch self {
        case .free: return 1
        case .monthly: return 2
        case .yearly: return 4
        }
    }

    /// 自定义任务创建额度说明
    public var taskCreationLimitDescription: String {
        switch self {
        case .free: return "累计创建 2 次"
        case .monthly: return "每个周期合计 12 次"
        case .yearly: return "不限次数"
        }
    }

    /// 每日习惯在原有规则（最多 3 普通 + 1 星标）之外的额外增加名额
    public var extraDailyHabitsQuota: Int {
        switch self {
        case .free: return 0
        case .monthly: return 2
        case .yearly: return 2
        }
    }

    /// 植物庭院展示数量上限（免费版 2 株，月度会员 14 株，年度会员 16 株全量）
    public var gardenPlantLimit: Int {
        switch self {
        case .free: return 2
        case .monthly: return 14
        case .yearly: return 16
        }
    }

    /// 植物庭院是否完整展示全部植物（免费版仅展示最近互动的 2 株）
    public var hasFullGardenAccess: Bool {
        switch self {
        case .free: return false
        case .monthly: return true
        case .yearly: return true
        }
    }

    /// 是否支持跨设备数据同步（免费版不提供通过服务器转存）
    public var hasSyncAccess: Bool {
        switch self {
        case .free: return false
        case .monthly: return true
        case .yearly: return true
        }
    }

    /// AI 周复盘权限说明
    public var aiReviewDescription: String {
        switch self {
        case .free: return "免费体验 1 次"
        case .monthly, .yearly: return "按现有冷却规则持续使用"
        }
    }
}

/// StoreKit 2 原生会员订阅管理器
@MainActor
public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()

    // MARK: - 商品标识符（留待 App Store Connect 后续配置）
    public static let monthlyProductID = "com.habitnative.subscription.monthly"
    public static let yearlyProductID = "com.habitnative.subscription.yearly"

    public static let allProductIDs: Set<String> = [
        monthlyProductID,
        yearlyProductID
    ]

    // MARK: - 持久化存储键名
    private enum StorageKeys {
        static let freeLifetimeTaskCreations = "habitnative.sub.free_lifetime_tasks_created"
        static let monthlyPeriodTaskCreations = "habitnative.sub.monthly_period_tasks_created"
        static let monthlyPeriodStartDate = "habitnative.sub.monthly_period_start_date"
        static let freeAIReviewUsed = "habitnative.sub.free_ai_review_used"
        static let cachedTier = "habitnative.sub.cached_tier"
        static let debugTierOverride = "habitnative.sub.debug_tier_override"
    }

    // MARK: - 发布的界面状态
    @Published public private(set) var currentTier: SubscriptionTier = .free
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isLoadingProducts: Bool = false
    @Published public private(set) var isPurchasing: Bool = false
    @Published public private(set) var isRestoring: Bool = false
    @Published public private(set) var expirationDate: Date? = nil
    @Published public var errorMessage: String? = nil
    @Published public var purchaseSuccessNotice: String? = nil

    #if DEBUG
    @Published public var debugTierOverride: SubscriptionTier? {
        didSet {
            if let override = debugTierOverride {
                UserDefaults.standard.set(override.rawValue, forKey: StorageKeys.debugTierOverride)
            } else {
                UserDefaults.standard.removeObject(forKey: StorageKeys.debugTierOverride)
            }
            updateEffectiveTier()
        }
    }
    #endif

    // MARK: - 额度状态
    @Published public private(set) var freeLifetimeCreatedTasksCount: Int = 0
    @Published public private(set) var monthlyPeriodCreatedTasksCount: Int = 0
    @Published public private(set) var freeAIWeeklyReviewUsed: Bool = false

    private var transactionListener: Task<Void, Error>? = nil
    private var actualSubscribedTier: SubscriptionTier = .free

    private init() {
        let defaults = UserDefaults.standard
        self.freeLifetimeCreatedTasksCount = defaults.integer(forKey: StorageKeys.freeLifetimeTaskCreations)
        self.monthlyPeriodCreatedTasksCount = defaults.integer(forKey: StorageKeys.monthlyPeriodTaskCreations)
        self.freeAIWeeklyReviewUsed = defaults.bool(forKey: StorageKeys.freeAIReviewUsed)

        if let cached = defaults.string(forKey: StorageKeys.cachedTier),
           let tier = SubscriptionTier(rawValue: cached) {
            self.actualSubscribedTier = tier
        }

        #if DEBUG
        if let overrideRaw = defaults.string(forKey: StorageKeys.debugTierOverride),
           let tier = SubscriptionTier(rawValue: overrideRaw) {
            self.debugTierOverride = tier
        }
        #endif

        updateEffectiveTier()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - 启动与监听
    public func start() {
        guard transactionListener == nil else { return }
        transactionListener = Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if let self {
                    await self.handleTransactionUpdate(result)
                }
            }
        }

        Task {
            await loadProducts()
            await updateCustomerProductStatus()
        }
    }

    // MARK: - 加载 StoreKit 2 商品
    public func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil
        do {
            let fetchedProducts = try await Product.products(for: Self.allProductIDs)
            self.products = fetchedProducts.sorted { productA, productB in
                if productA.id == Self.monthlyProductID { return true }
                return false
            }
        } catch {
            // 真实商品尚未配置在 App Store Connect 时，优雅容错，保持 products 为空
            self.products = []
            self.errorMessage = "商品信息读取中或尚未在 App Store 配置"
        }
        isLoadingProducts = false
    }

    // MARK: - 购买商品
    public func purchase(_ product: Product) async throws {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            purchaseSuccessNotice = "已成功开启\(currentTier.title)"
        case .userCancelled:
            break
        case .pending:
            purchaseSuccessNotice = "购买正在等待批准"
        @unknown default:
            break
        }
    }

    // MARK: - 恢复购买
    public func restorePurchases() async {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
            if currentTier != .free {
                purchaseSuccessNotice = "已恢复\(currentTier.title)权益"
            } else {
                errorMessage = "未查询到有效的会员订阅记录"
            }
        } catch {
            errorMessage = "恢复购买失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 验证与更新会员状态
    public func updateCustomerProductStatus() async {
        var highestTier: SubscriptionTier = .free
        var latestExpiration: Date? = nil

        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }

            if let expiration = transaction.expirationDate, expiration < Date() {
                continue
            }

            if transaction.productID == Self.yearlyProductID {
                highestTier = .yearly
                latestExpiration = transaction.expirationDate
                break
            } else if transaction.productID == Self.monthlyProductID {
                highestTier = .monthly
                latestExpiration = transaction.expirationDate
            }
        }

        self.actualSubscribedTier = highestTier
        self.expirationDate = latestExpiration
        UserDefaults.standard.set(highestTier.rawValue, forKey: StorageKeys.cachedTier)

        checkAndRefreshMonthlyPeriod(latestExpiration: latestExpiration)
        updateEffectiveTier()
    }

    private func checkAndRefreshMonthlyPeriod(latestExpiration: Date?) {
        guard actualSubscribedTier == .monthly else { return }
        let defaults = UserDefaults.standard
        let lastPeriodStart = defaults.object(forKey: StorageKeys.monthlyPeriodStartDate) as? Date
        let now = Date()

        if let lastStart = lastPeriodStart {
            // 月订阅每 30 天或续期周期刷新一次
            if now.timeIntervalSince(lastStart) >= 30 * 86400 {
                monthlyPeriodCreatedTasksCount = 0
                defaults.set(0, forKey: StorageKeys.monthlyPeriodTaskCreations)
                defaults.set(now, forKey: StorageKeys.monthlyPeriodStartDate)
            }
        } else {
            defaults.set(now, forKey: StorageKeys.monthlyPeriodStartDate)
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        await updateCustomerProductStatus()
        await transaction.finish()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.networkError(URLError(.cannotDecodeContentData))
        case .verified(let safe):
            return safe
        }
    }

    private func updateEffectiveTier() {
        #if DEBUG
        if let override = debugTierOverride {
            currentTier = override
            return
        }
        #endif
        currentTier = actualSubscribedTier
    }

    // MARK: - 跨线程安全便捷属性
    nonisolated public static var currentExtraDailyHabitsQuota: Int {
        #if DEBUG
        if let overrideRaw = UserDefaults.standard.string(forKey: StorageKeys.debugTierOverride),
           let tier = SubscriptionTier(rawValue: overrideRaw) {
            return tier.extraDailyHabitsQuota
        }
        #endif
        if let cached = UserDefaults.standard.string(forKey: StorageKeys.cachedTier),
           let tier = SubscriptionTier(rawValue: cached) {
            return tier.extraDailyHabitsQuota
        }
        return SubscriptionTier.free.extraDailyHabitsQuota
    }

    nonisolated public static var currentGardenPlantLimit: Int {
        #if DEBUG
        if let overrideRaw = UserDefaults.standard.string(forKey: StorageKeys.debugTierOverride),
           let tier = SubscriptionTier(rawValue: overrideRaw) {
            return tier.gardenPlantLimit
        }
        #endif
        if let cached = UserDefaults.standard.string(forKey: StorageKeys.cachedTier),
           let tier = SubscriptionTier(rawValue: cached) {
            return tier.gardenPlantLimit
        }
        return SubscriptionTier.free.gardenPlantLimit
    }

    nonisolated public static var isGardenFullAccess: Bool {
        #if DEBUG
        if let overrideRaw = UserDefaults.standard.string(forKey: StorageKeys.debugTierOverride),
           let tier = SubscriptionTier(rawValue: overrideRaw) {
            return tier.hasFullGardenAccess
        }
        #endif
        if let cached = UserDefaults.standard.string(forKey: StorageKeys.cachedTier),
           let tier = SubscriptionTier(rawValue: cached) {
            return tier.hasFullGardenAccess
        }
        return SubscriptionTier.free.hasFullGardenAccess
    }

    // MARK: - 自定义任务创建额度规则校验（规范第二节）
    public var canCreateCustomTask: Bool {
        switch currentTier {
        case .free:
            return freeLifetimeCreatedTasksCount < 2
        case .monthly:
            return monthlyPeriodCreatedTasksCount < 12
        case .yearly:
            return true
        }
    }

    public var remainingCustomTaskCreationsDescription: String {
        switch currentTier {
        case .free:
            let remaining = max(0, 2 - freeLifetimeCreatedTasksCount)
            return "剩余 \(remaining) 次（累计上限 2 次）"
        case .monthly:
            let remaining = max(0, 12 - monthlyPeriodCreatedTasksCount)
            return "本期剩余 \(remaining) 次（合计 12 次/期）"
        case .yearly:
            return "无限次创建"
        }
    }

    /// 成功保存新任务后调用（消耗一次额度，规范第二节：取消/失败/修改不消耗）
    public func recordCustomTaskCreationSuccess() {
        let defaults = UserDefaults.standard
        switch currentTier {
        case .free:
            freeLifetimeCreatedTasksCount += 1
            defaults.set(freeLifetimeCreatedTasksCount, forKey: StorageKeys.freeLifetimeTaskCreations)
        case .monthly:
            monthlyPeriodCreatedTasksCount += 1
            defaults.set(monthlyPeriodCreatedTasksCount, forKey: StorageKeys.monthlyPeriodTaskCreations)
        case .yearly:
            break
        }
    }

    // MARK: - AI 周复盘权限校验（规范第五节）
    public var canUseAIWeeklyReview: Bool {
        switch currentTier {
        case .free:
            return !freeAIWeeklyReviewUsed
        case .monthly, .yearly:
            return true
        }
    }

    /// 免费体验成功生成周复盘后调用（失败或取消不消耗）
    public func recordAIWeeklyReviewSuccess() {
        guard currentTier == .free else { return }
        freeAIWeeklyReviewUsed = true
        UserDefaults.standard.set(true, forKey: StorageKeys.freeAIReviewUsed)
    }

    /// 数据重置时重置试用（配合设置中的“清除本地数据并重新开始”）
    public func resetQuotasOnDataClear() {
        let defaults = UserDefaults.standard
        freeLifetimeCreatedTasksCount = 0
        monthlyPeriodCreatedTasksCount = 0
        freeAIWeeklyReviewUsed = false
        defaults.removeObject(forKey: StorageKeys.freeLifetimeTaskCreations)
        defaults.removeObject(forKey: StorageKeys.monthlyPeriodTaskCreations)
        defaults.removeObject(forKey: StorageKeys.monthlyPeriodStartDate)
        defaults.removeObject(forKey: StorageKeys.freeAIReviewUsed)
    }

    // MARK: - 会员到期自定义卡片保留算法（规范第四节）
    /// 依据等级优先、最近互动并列排序，决定处于活跃状态的卡片 ID 集合
    public func resolveActiveCardIDs(from cards: [(id: String, plantLevel: Int, lastInteractedAt: Date)]) -> Set<String> {
        let sortedCards = cards.sorted { a, b in
            if a.plantLevel != b.plantLevel {
                return a.plantLevel > b.plantLevel
            }
            if a.lastInteractedAt != b.lastInteractedAt {
                return a.lastInteractedAt > b.lastInteractedAt
            }
            return a.id < b.id // 稳定可解释的并列降级排序
        }

        let allowedCount = currentTier.maxCustomCards
        let activePrefix = sortedCards.prefix(allowedCount)
        return Set(activePrefix.map(\.id))
    }
}
