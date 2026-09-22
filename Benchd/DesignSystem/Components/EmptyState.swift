import SwiftUI

/// A quiet centered empty state: a small mark, a title, a message, and at most one
/// action.
///
/// The mark is deliberately small and `textTertiary` — a large tinted glyph in a
/// circle is the single most templated empty state on iOS, and it would be the most
/// generic thing in this app.
struct EmptyState<Action: View>: View {
    let title: String
    let message: String
    var systemImage: String? = nil
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: Spacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(Typography.iconMedium)
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.bottom, Spacing.xxs)
            }

            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)

            Text(message)
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            action
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
        .accessibilityElement(children: .contain)
    }
}

extension EmptyState where Action == EmptyView {
    init(title: String, message: String, systemImage: String? = nil) {
        self.init(title: title, message: message, systemImage: systemImage) { EmptyView() }
    }
}

#Preview("EmptyState — with action") {
    EmptyState(
        title: "No leagues yet",
        message: "Connect your Sleeper account and we'll build your career profile from it.",
        systemImage: "person.crop.circle"
    ) {
        SecondaryButton("Connect Sleeper") {}
            .frame(maxWidth: 220)
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}

#Preview("EmptyState — bare") {
    EmptyState(
        title: "Nothing this week",
        message: "Weekly wraps appear once the games are final."
    )
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
