import SwiftUI

/// Semantic, system-aware tokens shared by the starter screens.
/// Keep feature copy and data out of this layer so it stays reusable.
enum HabitDesignSystem {
    enum Color {
        static let canvas = SwiftUI.Color(.systemGroupedBackground)
        static let surface = SwiftUI.Color(.secondarySystemGroupedBackground)
        static let primaryAction = SwiftUI.Color.accentColor
        static let success = SwiftUI.Color.green
        static let subdued = SwiftUI.Color.secondary
    }

    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 20
        static let control: CGFloat = 14
    }
}

struct HabitSectionCard<Content: View>: View {
    @ViewBuilder private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(HabitDesignSystem.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HabitDesignSystem.Color.surface, in: .rect(cornerRadius: HabitDesignSystem.Radius.card))
    }
}

struct HabitMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    let tint: SwiftUI.Color

    var body: some View {
        HabitSectionCard {
            HStack(alignment: .top, spacing: HabitDesignSystem.Spacing.small) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(HabitDesignSystem.Color.subdued)
                    Text(value)
                        .font(.title2.weight(.bold))
                        .contentTransition(.numericText())
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct HabitPrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(HabitDesignSystem.Color.primaryAction)
        .controlSize(.large)
    }
}

#Preview("Design system") {
    VStack(spacing: HabitDesignSystem.Spacing.medium) {
        HabitMetricCard(title: "Current streak", value: "7 days", symbol: "flame.fill", tint: .orange)
        HabitPrimaryButton(title: "Complete habit") {}
    }
    .padding()
    .background(HabitDesignSystem.Color.canvas)
}
