import SwiftUI

/// The spacing scale. Base unit is 4; everything is a multiple.
///
/// Never write a raw number into `.padding()` or `spacing:` in a feature file.
/// When in doubt, go up a step — see `docs/DESIGN.md` §5.
enum Spacing {
    /// The scale's base unit. All tokens are multiples of this.
    static let unit: CGFloat = 4

    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
    static let xxxl: CGFloat = 56
    static let huge: CGFloat = 72

    // MARK: - Semantic

    /// Horizontal padding on every screen.
    static let screen: CGFloat = lg
    /// Interior padding of a `Card`.
    static let cardPadding: CGFloat = lg
    /// Between sections.
    static let sectionGap: CGFloat = xl
    /// Between major blocks, or above a hero stat.
    static let sectionGapLarge: CGFloat = xxl

    /// Every value on the scale, smallest first. Used by tests and the gallery.
    static let scale: [CGFloat] = [xxs, xs, sm, md, lg, xl, xxl, xxxl, huge]
}

/// Corner radii. **Always paired with `style: .continuous`** — the `Shape`
/// helpers below make that the path of least resistance.
enum Radius {
    /// Small controls, skeleton blocks.
    static let sm: CGFloat = 12
    /// Buttons, inputs, compact tiles.
    static let md: CGFloat = 16
    /// Standard card.
    static let card: CGFloat = 20
    /// Prominent card.
    static let cardLarge: CGFloat = 24
    /// Wrap cards and hero surfaces.
    static let hero: CGFloat = 28

    static let scale: [CGFloat] = [sm, md, card, cardLarge, hero]
}

/// Stroke widths. Never heavier than 1pt.
enum Stroke {
    /// Separators.
    static let hairline: CGFloat = 0.5
    /// Card and control outlines.
    static let border: CGFloat = 1
}

extension RoundedRectangle {
    /// A continuous-corner rounded rectangle. Use this instead of the initializer
    /// so a circular corner can never slip in by accident.
    static func soft(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
