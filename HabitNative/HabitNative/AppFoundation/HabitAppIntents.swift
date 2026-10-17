import AppIntents

/// The first shortcut is intentionally small: it opens the app to the current day.
/// Add data-changing intents only after the habit persistence contract is finalized.
struct OpenTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Today"
    static let description = IntentDescription("Open today's habits in HabitNative.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct HabitAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenTodayIntent(),
            phrases: [
                "Open today's habits in \(.applicationName)",
                "Show my habits in \(.applicationName)"
            ],
            shortTitle: "Open Today",
            systemImageName: "checkmark.circle"
        )
    }
}
