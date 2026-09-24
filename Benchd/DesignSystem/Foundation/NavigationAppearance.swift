import SwiftUI
import UIKit

/// The navigation bar, brought inside the design system.
///
/// SwiftUI gives no way to set a navigation bar's type, so the one UIKit
/// appearance proxy in the app lives here — in `DesignSystem/`, where raw design
/// values are allowed, rather than leaking `UIFont` and `UIColor` into a feature.
///
/// Two states, matching `BenchdTabBar` at the other end of the screen:
///
/// - **At the scroll edge**, fully transparent, so the gradient runs unbroken
///   from the status bar to the tab bar. A bar drawn as a grey slab over a
///   gradient is the thing `DESIGN.md` §3 calls a bug.
/// - **Once content is underneath it**, the system material plus a `divider`
///   hairline — the same treatment the tab bar uses, so the two edges of the
///   screen are visibly the same system.
///
/// The large title is `Typography.title`'s size and weight, not the system's
/// 34pt bold, so a pushed screen's heading matches `TabScaffold`'s.
enum NavigationAppearance {

    /// Applied once, before any bar is created. Called from `BenchdApp.init`.
    static func apply() {
        let transparent = UINavigationBarAppearance()
        transparent.configureWithTransparentBackground()
        transparent.titleTextAttributes = inlineTitle
        transparent.largeTitleTextAttributes = largeTitle
        transparent.setBackIndicatorImage(backChevron, transitionMaskImage: backChevron)

        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.titleTextAttributes = inlineTitle
        scrolled.largeTitleTextAttributes = largeTitle
        // The system's default separator is darker than anything else in the
        // app; `divider` is the hairline every other edge uses.
        scrolled.shadowColor = UIColor(Palette.divider)
        scrolled.setBackIndicatorImage(backChevron, transitionMaskImage: backChevron)

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = scrolled
        bar.compactAppearance = scrolled
        bar.scrollEdgeAppearance = transparent
        bar.compactScrollEdgeAppearance = transparent
        // The one place accent is spent in the chrome: a back chevron and any
        // bar button. System blue would be the single most out-of-palette thing
        // on screen.
        bar.tintColor = UIColor(Palette.accentInk)
    }

    private static var inlineTitle: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor(Palette.textPrimary),
        ]
    }

    private static var largeTitle: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: UIColor(Palette.textPrimary),
            // Matches `titleStyle()`'s tracking. Without it a large title reads
            // looser than the same words rendered by `TabScaffold`.
            .kern: -0.4,
        ]
    }

    /// A lighter chevron than the system's, to sit with the app's line weights.
    private static var backChevron: UIImage? {
        UIImage(
            systemName: "chevron.backward",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )
    }
}
