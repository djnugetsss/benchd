import SwiftUI

/// Placeholder for player pages and news.
struct PlayersScreen: View {
    var body: some View {
        TabScaffold(title: "Players") {
            VStack(spacing: Spacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    Card(padding: Spacing.md) {
                        HStack(spacing: Spacing.sm) {
                            SkeletonBlock(width: 40, height: 40, radius: 20)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                SkeletonBlock(width: 140, height: 12)
                                SkeletonBlock(width: 70, height: 10)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            EmptyState(
                title: "Player pages are on the way",
                message: "Every NFL player gets a page, with news and injury updates as they break."
            )
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    PlayersScreen().gradientBackground()
}
