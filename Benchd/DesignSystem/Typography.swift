import SwiftUI

/// Every font in Benchd. Feature code must not call `.font(.system(...))` or
/// `Font.custom(...)` — use a role from this list.
///
/// Numbers are the emotional payload of this app, so the stat roles are set apart:
/// large, tightly tracked, and monospaced-digit so a changing value never reflows.
enum Typography {

    // MARK: Display — the big numbers

    /// A single hero stat: an all-time record, a championship count.
    static let statHero = Font.system(size: 56, weight: .semibold, design: .default)
        .monospacedDigit()
    /// A stat in a grid or card.
    static let statLarge = Font.system(size: 34, weight: .semibold, design: .default)
        .monospacedDigit()
    /// An inline stat next to a label.
    static let statSmall = Font.system(size: 20, weight: .medium, design: .default)
        .monospacedDigit()

    // MARK: Editorial

    /// Screen title. Used once per screen.
    static let title = Font.system(size: 28, weight: .semibold)
    /// Section heading.
    static let headline = Font.system(size: 19, weight: .semibold)
    /// Body copy.
    static let body = Font.system(size: 16, weight: .regular)
    /// Supporting copy under a heading.
    static let callout = Font.system(size: 15, weight: .regular)
    /// Metadata, timestamps, footnotes.
    static let caption = Font.system(size: 13, weight: .regular)

    /// The small uppercase label that sits above a number.
    static let statLabel = Font.system(size: 12, weight: .semibold)
}

extension View {
    /// Applies the uppercase-with-tracking treatment used for labels above stats.
    /// Keeps the tracking value out of feature code.
    func statLabelStyle() -> some View {
        self
            .font(Typography.statLabel)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Palette.inkTertiary)
    }
}

#Preview("Typography") {
    VStack(alignment: .leading, spacing: Spacing.s5) {
        Text("All-time record").statLabelStyle()
        Text("128–74").font(Typography.statHero).foregroundStyle(Palette.ink)
        Text("Career").font(Typography.title).foregroundStyle(Palette.ink)
        Text("Championships").font(Typography.headline).foregroundStyle(Palette.ink)
        Text("Six seasons across two leagues.")
            .font(Typography.body).foregroundStyle(Palette.inkSecondary)
        Text("Synced 4 minutes ago")
            .font(Typography.caption).foregroundStyle(Palette.inkTertiary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Spacing.screenMargin)
    .background(GradientBackground())
}
