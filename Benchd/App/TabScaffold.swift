import SwiftUI

/// Shared layout for a top-level tab: a large screen title, generous margins,
/// and room at the bottom for the custom tab bar.
///
/// Each tab does sit in a `NavigationStack` — that is what lets a screen push a
/// detail and put a button in the bar — but the bar itself is left transparent
/// and untitled, and the title is drawn here instead. `NavigationStack`'s own
/// large-title chrome arrives with its own font, spacing and scroll behaviour,
/// and would override the design system on the app's three most visible screens.
///
/// A tab wanting a toolbar button applies `.toolbar` itself; see `ProfileScreen`.
struct TabScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    private var spacerItem: some View {
        Color.clear
            .frame(width: 1, height: Spacing.lg)
            .accessibilityHidden(true)
    }

    /// Clears the custom tab bar. The bar is roughly 56pt plus the home
    /// indicator inset; this keeps the last card from tucking under it.
    private let bottomInset: CGFloat = 96

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                Text(title)
                    .titleStyle()
                    // Small, because each tab now sits in a `NavigationStack`
                    // whose (transparent, empty) bar already provides the
                    // clearance from the status bar and the Dynamic Island.
                    .padding(.top, Spacing.xs)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, bottomInset)
        }
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Reserves the navigation bar on every tab.
            //
            // A bar with nothing in it collapses to no height, so Profile — which
            // puts a gear in its bar — would sit 44 points lower than Players and
            // Wraps, and the screen title would jump as you moved between tabs.
            // An empty leading item is the least invasive way to make the three
            // bars the same height; it is declared here, once, rather than in
            // each tab.
            //
            // iOS 26 would otherwise draw its filled container around the empty
            // item, which renders as a white disc in the corner of every screen.
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) { spacerItem }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) { spacerItem }
            }
        }
    }
}

#Preview {
    TabScaffold(title: "Career") {
        Card { Text("Content").font(Typography.body).foregroundStyle(Palette.textPrimary) }
    }
    .gradientBackground()
}
