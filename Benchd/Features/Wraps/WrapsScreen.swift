import SwiftUI

/// Placeholder for the weekly wrap cards.
struct WrapsScreen: View {
    var body: some View {
        TabScaffold(title: "Wraps") {
            Card(radius: Radius.hero, elevation: .lifted) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    StatBlock(label: "This week", value: .pending, style: .large)
                    SoftDivider()
                    VStack(spacing: Spacing.sm) {
                        SkeletonBlock(height: 12)
                        SkeletonBlock(width: 240, height: 12)
                        SkeletonBlock(width: 180, height: 12)
                    }
                }
            }

            EmptyState(
                title: "No wraps yet",
                message: "Your first weekly wrap appears once a week of games is final."
            )
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    WrapsScreen().gradientBackground()
}
