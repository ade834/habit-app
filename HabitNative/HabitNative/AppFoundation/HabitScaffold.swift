import SwiftUI

/// A small, standalone SwiftUI shell for future feature work.
/// It intentionally doesn't replace the existing ContentView while the current product UI is in active development.
struct HabitScaffold: View {
    @State private var selectedTab: HabitScaffoldTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            HabitTodayPlaceholder()
                .tabItem { HabitScaffoldTab.today.label }
                .tag(HabitScaffoldTab.today)

            HabitProgressPlaceholder()
                .tabItem { HabitScaffoldTab.progress.label }
                .tag(HabitScaffoldTab.progress)

            HabitLibraryPlaceholder()
                .tabItem { HabitScaffoldTab.library.label }
                .tag(HabitScaffoldTab.library)

            HabitSettingsPlaceholder()
                .tabItem { HabitScaffoldTab.settings.label }
                .tag(HabitScaffoldTab.settings)
        }
        .tint(HabitDesignSystem.Color.primaryAction)
    }
}

enum HabitScaffoldTab: String, CaseIterable, Hashable, Identifiable {
    case today
    case progress
    case library
    case settings

    var id: String { rawValue }

    @ViewBuilder
    var label: some View {
        switch self {
        case .today: Label("Today", systemImage: "checkmark.circle")
        case .progress: Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
        case .library: Label("Habits", systemImage: "square.grid.2x2")
        case .settings: Label("Settings", systemImage: "gearshape")
        }
    }
}

enum HabitRoute: Hashable {
    case habitDetail(id: String)
    case editHabit(id: String)
}

private struct HabitTodayPlaceholder: View {
    @State private var path: [HabitRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: HabitDesignSystem.Spacing.large) {
                    VStack(alignment: .leading, spacing: HabitDesignSystem.Spacing.xSmall) {
                        Text("Today")
                            .font(.largeTitle.bold())
                        Text("A focused plan for October 12")
                            .foregroundStyle(HabitDesignSystem.Color.subdued)
                    }

                    HStack(spacing: HabitDesignSystem.Spacing.small) {
                        HabitMetricCard(title: "Streak", value: "7 days", symbol: "flame.fill", tint: .orange)
                        HabitMetricCard(title: "Done", value: "2 of 3", symbol: "checkmark.seal.fill", tint: HabitDesignSystem.Color.success)
                    }

                    HabitSectionCard {
                        VStack(alignment: .leading, spacing: HabitDesignSystem.Spacing.medium) {
                            Label("Read for 20 minutes", systemImage: "book.closed.fill")
                                .font(.headline)
                            Text("Placeholder for the next habit due today.")
                                .foregroundStyle(HabitDesignSystem.Color.subdued)
                            HabitPrimaryButton(title: "Mark complete") {}
                        }
                    }
                }
                .padding(HabitDesignSystem.Spacing.medium)
            }
            .background(HabitDesignSystem.Color.canvas)
            .navigationDestination(for: HabitRoute.self) { route in
                HabitRoutePlaceholder(route: route)
            }
        }
    }
}

private struct HabitProgressPlaceholder: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Progress is ready for your data", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("Weekly trends and milestones will appear here.")
            }
            .navigationTitle("Progress")
        }
    }
}

private struct HabitLibraryPlaceholder: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No habits yet", systemImage: "square.grid.2x2")
            } description: {
                Text("Create a habit to start shaping your daily routine.")
            } actions: {
                Button("Create habit") {}
                    .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Habits")
        }
    }
}

private struct HabitSettingsPlaceholder: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Reminders") {
                    Toggle("Daily reminder", isOn: .constant(false))
                    Text("Placeholder for notification scheduling.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Appearance") {
                    Label("Follows your device appearance", systemImage: "circle.lefthalf.filled")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct HabitRoutePlaceholder: View {
    let route: HabitRoute

    var body: some View {
        ContentUnavailableView {
            Label("Feature placeholder", systemImage: "hammer")
        } description: {
            switch route {
            case .habitDetail:
                Text("Habit details will be added here.")
            case .editHabit:
                Text("Habit editing will be added here.")
            }
        }
    }
}

#Preview("Starter shell") {
    HabitScaffold()
}
