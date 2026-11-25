import Foundation

@MainActor
func testSubscriptionTiersAndQuotas() {
    print("Testing subscription tiers and quotas...")
    let manager = SubscriptionManager.shared

    // Test Free Tier Quotas
    manager.debugTierOverride = .free
    assert(manager.currentTier == .free, "Tier should be free")
    assert(manager.currentTier.maxCustomCards == 1, "Free allows 1 custom card")
    assert(manager.currentTier.extraDailyHabitsQuota == 0, "Free has 0 extra habit slots")
    assert(manager.currentTier.hasFullGardenAccess == false, "Free garden access is limited to 2 plants")
    assert(manager.currentTier.hasSyncAccess == false, "Free has no server sync")

    // Test Monthly Tier Quotas
    manager.debugTierOverride = .monthly
    assert(manager.currentTier == .monthly, "Tier should be monthly")
    assert(manager.currentTier.maxCustomCards == 2, "Monthly allows 2 custom cards")
    assert(manager.currentTier.extraDailyHabitsQuota == 2, "Monthly has +2 extra habit slots")
    assert(manager.currentTier.hasFullGardenAccess == true, "Monthly has full garden access")
    assert(manager.currentTier.hasSyncAccess == true, "Monthly has sync access")

    // Test Yearly Tier Quotas
    manager.debugTierOverride = .yearly
    assert(manager.currentTier == .yearly, "Tier should be yearly")
    assert(manager.currentTier.maxCustomCards == 4, "Yearly allows 4 custom cards")
    assert(manager.currentTier.extraDailyHabitsQuota == 2, "Yearly has +2 extra habit slots")
    assert(manager.currentTier.hasFullGardenAccess == true, "Yearly has full garden access")
    assert(manager.currentTier.hasSyncAccess == true, "Yearly has sync access")
    assert(manager.canCreateCustomTask == true, "Yearly has unlimited custom task creations")

    print("✓ Subscription tiers and quotas passed")
}

@MainActor
func testCustomCardStoreAndQuotas() {
    print("Testing custom cards and task creation quotas...")
    let manager = SubscriptionManager.shared
    manager.resetQuotasOnDataClear()
    manager.debugTierOverride = .free

    UserDefaults.standard.removeObject(forKey: "habitnative.custom_cards.v1")
    let cardStore = CustomCardStore.shared
    cardStore.loadCards()

    // Free tier allows 1 card
    assert(cardStore.canCreateNewCard == true, "Should allow creating 1st card")
    let card1 = cardStore.createCard(title: "英语晨读", plantSpecies: "peony")
    assert(card1 != nil, "Card 1 created")
    assert(cardStore.canCreateNewCard == false, "Free tier cannot create 2nd card")

    // Free tier allows 2 task creations
    assert(manager.canCreateCustomTask == true, "Should allow task 1")
    let task1 = cardStore.createTask(in: card1!.id, title: "朗读 10 分钟", promptQuestion: "今天读了哪篇文章？")
    assert(task1 != nil, "Task 1 created")
    assert(manager.freeLifetimeCreatedTasksCount == 1, "Quota consumed 1")

    assert(manager.canCreateCustomTask == true, "Should allow task 2")
    let task2 = cardStore.createTask(in: card1!.id, title: "背诵 5 个生词", promptQuestion: "学到了哪个词？")
    assert(task2 != nil, "Task 2 created")
    assert(manager.freeLifetimeCreatedTasksCount == 2, "Quota consumed 2")

    // 3rd attempt must be blocked
    assert(manager.canCreateCustomTask == false, "Free tier blocked after 2 creations")
    let task3 = cardStore.createTask(in: card1!.id, title: "语法练习", promptQuestion: "体会？")
    assert(task3 == nil, "Task 3 must not be created")
    assert(manager.freeLifetimeCreatedTasksCount == 2, "Quota still 2")

    // Editing task does NOT consume quota
    cardStore.updateTask(cardId: card1!.id, taskId: task1!.id, newTitle: "精读 15 分钟", newPrompt: "改写句子？")
    assert(manager.freeLifetimeCreatedTasksCount == 2, "Editing must not consume quota")

    // Deleting task does NOT refund quota
    cardStore.deleteTask(cardId: card1!.id, taskId: task2!.id)
    assert(manager.freeLifetimeCreatedTasksCount == 2, "Deleting must not refund quota")
    assert(manager.canCreateCustomTask == false, "Still blocked after delete")

    // Upgrade to Monthly: quota expands to 12
    manager.debugTierOverride = .monthly
    assert(manager.canCreateCustomTask == true, "Monthly allows task creation up to 12")
    assert(cardStore.canCreateNewCard == true, "Monthly allows 2nd card")
    let card2 = cardStore.createCard(title: "冥想专注", plantSpecies: "lotus")
    assert(card2 != nil, "Card 2 created")
    assert(cardStore.canCreateNewCard == false, "Monthly card limit 2 reached")

    print("✓ Custom cards and task creation quotas passed")
}

@MainActor
func testCardDowngradeRetentionAlgorithm() {
    print("Testing card downgrade retention resolution...")
    let manager = SubscriptionManager.shared

    let now = Date()
    let cardA = (id: "CardA", plantLevel: 2, lastInteractedAt: now.addingTimeInterval(-3600)) // Level 2, older
    let cardB = (id: "CardB", plantLevel: 4, lastInteractedAt: now.addingTimeInterval(-7200)) // Level 4, older
    let cardC = (id: "CardC", plantLevel: 4, lastInteractedAt: now)                           // Level 4, recent
    let cardD = (id: "CardD", plantLevel: 1, lastInteractedAt: now)                           // Level 1, recent

    let allCards = [cardA, cardB, cardC, cardD]

    // Downgrade to Free: exactly 1 card kept (priority: highest plant level, then most recent)
    // Between CardB (level 4, -7200) and CardC (level 4, now): CardC wins!
    manager.debugTierOverride = .free
    let freeActive = manager.resolveActiveCardIDs(from: allCards)
    assert(freeActive.count == 1, "Free keeps 1 card")
    assert(freeActive.contains("CardC"), "CardC has highest level and most recent interaction")

    // Restore to Monthly: 2 cards kept (CardC and CardB, both level 4)
    manager.debugTierOverride = .monthly
    let monthlyActive = manager.resolveActiveCardIDs(from: allCards)
    assert(monthlyActive.count == 2, "Monthly keeps 2 cards")
    assert(monthlyActive.contains("CardC") && monthlyActive.contains("CardB"), "Top 2 level 4 cards kept")

    // Restore to Yearly: all 4 cards active
    manager.debugTierOverride = .yearly
    let yearlyActive = manager.resolveActiveCardIDs(from: allCards)
    assert(yearlyActive.count == 4, "Yearly keeps up to 4 cards")

    print("✓ Card downgrade retention resolution passed")
}

@MainActor
func testAIWeeklyReviewRules() {
    print("Testing AI weekly review trial and clear rules...")
    let manager = SubscriptionManager.shared
    manager.resetQuotasOnDataClear()
    manager.debugTierOverride = .free

    // Initial state: free trial available
    assert(manager.canUseAIWeeklyReview == true, "Free user should have 1 free trial")
    assert(manager.freeAIWeeklyReviewUsed == false, "Trial not yet used")

    // Successful generation: trial is consumed
    manager.recordAIWeeklyReviewSuccess()
    assert(manager.freeAIWeeklyReviewUsed == true, "Trial marked used")
    assert(manager.canUseAIWeeklyReview == false, "Free user cannot generate second review")

    // Subscribed user can always generate (subject to cooldown)
    manager.debugTierOverride = .monthly
    assert(manager.canUseAIWeeklyReview == true, "Monthly subscriber can generate review")

    // Reset on clearing all local data
    manager.debugTierOverride = .free
    manager.resetQuotasOnDataClear()
    assert(manager.freeAIWeeklyReviewUsed == false, "Trial reset after data clear")
    assert(manager.canUseAIWeeklyReview == true, "Free trial restored after clear")

    print("✓ AI weekly review trial and clear rules passed")
}

@main
struct SubscriptionTestMain {
    @MainActor
    static func main() {
        testSubscriptionTiersAndQuotas()
        testCustomCardStoreAndQuotas()
        testCardDowngradeRetentionAlgorithm()
        testAIWeeklyReviewRules()
        SubscriptionManager.shared.debugTierOverride = nil
        SubscriptionManager.shared.resetQuotasOnDataClear()
        UserDefaults.standard.removeObject(forKey: "habitnative.custom_cards.v1")
        CustomCardStore.shared.loadCards()
        print("ALL SUBSCRIPTION TESTS PASSED!")
    }
}
