import Foundation

/// Schema inventory for the forthcoming sync adapter. A missing domain must block
/// enabling sync rather than being silently omitted from a user's restored data.
enum SyncDomainCatalog {
    enum Identity: Equatable {
        case natural([String])
        case localRowIDWithStableUUID(String)
        case logReference(String)
        case localMetadata
    }
    struct Domain: Equatable {
        let table: String
        let identity: Identity
    }
    static let domains: [Domain] = [
        Domain(table: "badge_review_evidence", identity: .natural(["local_date"])),
        Domain(table: "badge_plan_intervals", identity: .localRowIDWithStableUUID("id")),
        Domain(table: "badge_unlocks", identity: .natural(["badge_id"])),
        Domain(table: "custom_cards", identity: .natural(["id"])),
        Domain(table: "custom_tasks", identity: .natural(["id"])),
        Domain(table: "habit_selections", identity: .natural(["habit_id"])),
        Domain(table: "habit_logs", identity: .natural(["habit_id", "local_date"])),
        Domain(table: "point_transactions", identity: .logReference("habit_log_id")),
        Domain(table: "review_entries", identity: .natural(["local_date"])),
        Domain(table: "monthly_ai_reports", identity: .natural(["month_key"])),
        Domain(table: "weekly_ai_reports", identity: .natural(["week_key"])),
        Domain(table: "timer_sessions", identity: .localRowIDWithStableUUID("id")),
        Domain(table: "challenge_draws", identity: .natural(["local_date"])),
        Domain(table: "habit_activity_entries", identity: .natural(["habit_id", "period_key"])),
        Domain(table: "travel_plans", identity: .natural(["year"])),
        Domain(table: "missed_habit_records", identity: .natural(["habit_id", "local_date"])),
        Domain(table: "challenge_history", identity: .natural(["cycle", "card_index"])),
        Domain(table: "challenge_daily_swaps", identity: .natural(["local_date", "slot"])),
        Domain(table: "daily_selection_records", identity: .natural(["habit_id", "local_date"])),
        Domain(table: "native_metadata", identity: .localMetadata)
    ]

    /// UserDefaults data is separate from SQLite and must be deliberately mapped.
    /// Consent and device-specific presentation settings must not be silently transferred.
    static let defaultsPrefixesNeedingPolicy = [
        "review.typewriter.draft.", "review.ai.last-request.",
        "garden.plantPlacements", "garden_flower_positions_v1"
    ]

    static func unknownTables(in tables: Set<String>) -> Set<String> {
        tables.subtracting(Set(domains.map(\.table))).filter { !$0.hasPrefix("sqlite_") && !$0.hasPrefix("sync_") }
    }
}
