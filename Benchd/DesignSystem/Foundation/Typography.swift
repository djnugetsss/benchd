import SwiftUI

/// Every font in Benchd. SF Pro, via the system font — no custom type files.
///
/// The scale rests on one idea: **display sizes are light and tight, text sizes are
/// normal.** A 64pt number at `.light` with negative tracking reads as editorial;
/// the same number at `.bold` reads as a scoreboard.
///
/// Tracking cannot be baked into a `Font`, so each display role pairs with a
/// `.tracking()` value. Use the `.displayStyle(_:)` modifier (or `StatBlock`) so the
/// two never get separated. See `docs/DESIGN.md` §4.
enum Typography {

    // MARK: - Display — numbers only
    //
    // All monospaced-digit so a counting number never reflows the layout.

    /// The one number a screen is about.
    static let displayHero = Font.system(size: 64, weight: .light).monospacedDigit()
    /// Hero number inside a card; wrap card figures.
    static let displayLarge = Font.system(size: 44, weight: .light).monospacedDigit()
    /// A stat in a multi-stat row.
    static let displayMedium = Font.system(size: 32, weight: .regular).monospacedDigit()
    /// Inline stat beside a label.
    static let displaySmall = Font.system(size: 22, weight: .medium).monospacedDigit()

    // MARK: - Text

    /// Screen title. Once per screen.
    static let title = Font.system(size: 28, weight: .semibold)
    /// Section heading, card heading.
    static let headline = Font.system(size: 17, weight: .semibold)
    /// Body copy.
    static let body = Font.system(size: 16, weight: .regular)
    /// Supporting copy under a heading.
    static let callout = Font.system(size: 15, weight: .regular)
    /// Metadata, timestamps, footnotes.
    static let caption = Font.system(size: 13, weight: .regular)
    /// Button labels.
    static let button = Font.system(size: 16, weight: .semibold)

    /// The small tracked uppercase label above a number.
    static let statLabel = Font.system(size: 11, weight: .semibold)

    // MARK: - Icons
    //
    // SF Symbols do not inherit a text role cleanly — a symbol set with
    // `Typography.caption` optically reads larger than the text beside it. Two
    // explicit glyph sizes keep icons from becoming an excuse for raw values.

    /// Inline glyph beside small text, e.g. inside a `PillTag`.
    static let iconSmall = Font.system(size: 10, weight: .semibold)
    /// The standalone mark in an `EmptyState`. Light weight, never filled.
    static let iconMedium = Font.system(size: 22, weight: .light)
}

/// The four display roles, carrying their tracking with them.
///
/// A display role is meaningless without its tracking — at 64pt, default tracking
/// looks loose and generic. Bundling them makes the correct thing the easy thing.
enum DisplayStyle: CaseIterable {
    case hero, large, medium, small

    var font: Font {
        switch self {
        case .hero: Typography.displayHero
        case .large: Typography.displayLarge
        case .medium: Typography.displayMedium
        case .small: Typography.displaySmall
        }
    }

    var tracking: CGFloat {
        switch self {
        case .hero: -2.0
        case .large: -1.2
        case .medium: -0.6
        case .small: -0.2
        }
    }

    var name: String {
        switch self {
        case .hero: "displayHero"
        case .large: "displayLarge"
        case .medium: "displayMedium"
        case .small: "displaySmall"
        }
    }
}

extension View {
    /// Applies a display role with its matching tracking.
    func displayStyle(_ style: DisplayStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }

    /// The uppercase tracked label that sits above every big number.
    /// Always `textTertiary` — the label is the setup, the number is the payoff.
    func statLabelStyle() -> some View {
        font(Typography.statLabel)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(Palette.textTertiary)
    }

    /// `title`, with its tracking.
    func titleStyle() -> some View {
        font(Typography.title)
            .tracking(-0.4)
            .foregroundStyle(Palette.textPrimary)
    }
}
