import SwiftUI

/// Shared layout for a top-level tab: a large screen title, generous margins,
/// and room at the bottom for the custom tab bar.
///
/// Exists so no tab reaches for `NavigationStack`'s default large-title chrome,
/// which arrives with its own font, spacing, and scroll behaviour and would
/// override the design system on three of the app's most visible screens.
struct TabScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    /// Clears the custom tab bar. The bar is roughly 56pt plus the home
    /// indicator inset; this keeps the last card from tucking under it.
    private let bottomInset: CGFloat = 96

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                Text(title)
                    .titleStyle()
                    // A screen title needs clearance from the status bar and the
                    // Dynamic Island; 16pt read as cramped on device.
                    .padding(.top, Spacing.xl)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, bottomInset)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    TabScaffold(title: "Career") {
        Card { Text("Content").font(Typography.body).foregroundStyle(Palette.textPrimary) }
    }
    .gradientBackground()
}
