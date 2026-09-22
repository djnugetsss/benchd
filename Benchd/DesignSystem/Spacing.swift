import SwiftUI

/// The only spacing values allowed in the app. Feature code never writes a raw
/// number into `.padding(_:)` or `spacing:`.
///
/// The scale is deliberately coarse — generous white space is a design rule in
/// this app, not a preference, so there is no 6pt or 10pt escape hatch.
enum Spacing {
    /// 2 — hairline nudges only.
    static let s1: CGFloat = 2
    /// 4
    static let s2: CGFloat = 4
    /// 8
    static let s3: CGFloat = 8
    /// 12
    static let s4: CGFloat = 12
    /// 16 — the default gutter between related elements.
    static let s5: CGFloat = 16
    /// 24 — the standard screen margin.
    static let s6: CGFloat = 24
    /// 32 — between sections.
    static let s7: CGFloat = 32
    /// 48 — between major blocks.
    static let s8: CGFloat = 48
    /// 64 — breathing room above a hero stat.
    static let s9: CGFloat = 64

    /// Horizontal inset for full-width screen content.
    static let screenMargin: CGFloat = s6
}

/// Corner radii. Benchd uses continuous (squircle) corners everywhere; a
/// circular corner reads as cheap next to iOS system chrome.
enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 14
    static let card: CGFloat = 20
    /// Wrap cards and other hero surfaces.
    static let hero: CGFloat = 28
    /// Use with `Capsule()` rather than a literal.
    static let pill: CGFloat = 999
}
