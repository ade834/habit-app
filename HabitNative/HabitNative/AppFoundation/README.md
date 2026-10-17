# Habit app starter structure

`HabitScaffold.swift` is an isolated starter shell with four tabs, one `NavigationStack` per tab, a typed route enum, and empty-state screens for unfinished features.

`HabitDesignSystem.swift` provides semantic colors, spacing, rounded surfaces, a metric card, and the primary action treatment. The tokens use system colors so light mode, Dark Mode, and increased-contrast settings adapt without hard-coded palette values.

`HabitAppIntents.swift` exposes a deliberately safe “Open Today” App Shortcut. It makes no data changes until the persistence contract is ready.

The production `ContentView` remains the app entry UI during the existing feature build. To adopt the shell later, change `HabitNativeApp.swift` from `ContentView()` to `HabitScaffold()` after the shared integration review.
