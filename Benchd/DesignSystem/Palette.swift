import SwiftUI

/// Every color in Benchd. Nothing outside `DesignSystem/` may construct a `Color`
/// from raw components — add a token here instead.
///
/// The palette follows the brief: a gradient white base, light gray for secondary
/// surfaces and dividers, and a single light blue accent used sparingly for active
/// states, key data points, and brand moments.
///
/// > Provisional: these values are a starting point. `docs/DESIGN.md` is the
/// > authority once it lands, and this file should be reconciled against it.
enum Palette {

    // MARK: Canvas
    // The app background is never flat — it is a soft vertical wash from pure
    // white down to the faintest cool gray. See `GradientBackground`.

    static let canvasTop = Color(hex: 0xFFFFFF)
    static let canvasMid = Color(hex: 0xFAFBFD)
    static let canvasBottom = Color(hex: 0xEFF3F8)

    // MARK: Surfaces

    /// Cards and raised content sitting on the canvas.
    static let surface = Color(hex: 0xFFFFFF)
    /// Recessed / secondary surfaces: inputs, empty states, grouped rows.
    static let surfaceMuted = Color(hex: 0xF5F6F9)
    /// Hairlines and separators. Never use for text.
    static let divider = Color(hex: 0xE5E9F0)

    // MARK: Ink

    /// Primary text and the large stat numbers.
    static let ink = Color(hex: 0x14171C)
    /// Supporting copy, labels above numbers.
    static let inkSecondary = Color(hex: 0x5B636F)
    /// Metadata, timestamps, disabled states.
    static let inkTertiary = Color(hex: 0x99A1AD)

    // MARK: Accent
    // Used sparingly. If more than one accent element is visible on a screen,
    // that is a design smell worth a second look.

    static let accent = Color(hex: 0x4F98D9)
    static let accentSoft = Color(hex: 0xE8F1FA)

    // MARK: Semantic

    static let positive = Color(hex: 0x3F9C6D)
    static let negative = Color(hex: 0xC5563F)
}

extension Color {
    /// Token-only initializer. Feature code must not call this — use `Palette`.
    fileprivate init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

#Preview("Palette") {
    let swatches: [(String, Color)] = [
        ("canvasTop", Palette.canvasTop),
        ("canvasMid", Palette.canvasMid),
        ("canvasBottom", Palette.canvasBottom),
        ("surface", Palette.surface),
        ("surfaceMuted", Palette.surfaceMuted),
        ("divider", Palette.divider),
        ("ink", Palette.ink),
        ("inkSecondary", Palette.inkSecondary),
        ("inkTertiary", Palette.inkTertiary),
        ("accent", Palette.accent),
        ("accentSoft", Palette.accentSoft),
        ("positive", Palette.positive),
        ("negative", Palette.negative),
    ]

    return ScrollView {
        VStack(spacing: Spacing.s2) {
            ForEach(swatches, id: \.0) { name, color in
                HStack(spacing: Spacing.s4) {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(color)
                        .frame(width: 56, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                .strokeBorder(Palette.divider, lineWidth: 1)
                        )
                    Text(name).font(Typography.body).foregroundStyle(Palette.ink)
                    Spacer()
                }
            }
        }
        .padding(Spacing.s5)
    }
    .background(GradientBackground())
}
