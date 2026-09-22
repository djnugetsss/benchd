import SwiftUI

/// Placeholder for the career profile.
///
/// Deliberately not "coming soon" on a blank page — it sketches the shape of
/// what is coming, so the tab reads as unfinished rather than broken.
struct ProfileScreen: View {
    var body: some View {
        TabScaffold(title: "Career") {
            Card(radius: Radius.hero, elevation: .lifted) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(spacing: Spacing.sm) {
                        SkeletonBlock(width: 44, height: 44, radius: 22)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            SkeletonBlock(width: 120, height: 12)
                            SkeletonBlock(width: 80, height: 10)
                        }
                        Spacer(minLength: 0)
                    }

                    StatBlock(
                        label: "All-time record",
                        value: .pending,
                        style: .hero,
                        caption: "Once your first sync finishes"
                    )
                    .padding(.vertical, Spacing.xs)

                    SoftDivider()

                    HStack(alignment: .top, spacing: Spacing.md) {
                        StatBlock(label: "Titles", value: .pending, style: .medium)
                        StatBlock(label: "Seasons", value: .pending, style: .medium)
                        StatBlock(label: "Leagues", value: .pending, style: .medium)
                    }
                }
            }

            EmptyState(
                title: "Your career is syncing",
                message: "We're pulling your Sleeper history. This page fills in as it lands."
            )
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ProfileScreen().gradientBackground()
}
