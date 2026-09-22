import SwiftUI

/// Every color in Benchd.
///
/// **This file is the only place in the codebase where a raw color value may
/// appear.** The `Color(hex:)` initializer below is deliberately `fileprivate` so
/// that rule enforces itself — nothing outside this file can construct a color
/// from components.
///
/// See `docs/DESIGN.md` §3 for the usage rules behind each token.
enum Palette {

    // MARK: - Base

    /// Top of the app background wash.
    static let gradientTop = Color(hex: 0xFFFFFF)
    /// Bottom of the app background wash.
    static let gradientBottom = Color(hex: 0xF4F6F9)

    /// Cards and raised content.
    static let surface = Color(hex: 0xFFFFFF)
    /// Recessed surfaces: inputs, skeletons, grouped rows, neutral pills.
    static let surfaceSecondary = Color(hex: 0xF1F3F6)
    /// Hairlines and separators. Never text, never a fill.
    static let divider = Color(hex: 0xE5E8EC)

    // MARK: - Text
    //
    // Three levels is the whole system. There is no fourth.

    static let textPrimary = Color(hex: 0x111827)
    static let textSecondary = Color(hex: 0x6B7280)
    static let textTertiary = Color(hex: 0x9CA3AF)

    /// Text placed on an ink-filled surface (`PrimaryButton`).
    static let textOnInk = Color(hex: 0xFFFFFF)

    // MARK: - Accent
    //
    // Appears at most twice per screen, often zero times.

    /// Fills, strokes, dots, rings, indicators. **Never text** — 2.2:1 on white.
    static let accent = Color(hex: 0x7FB2E5)
    /// The accent at a legible weight (~5.1:1). For text and icons only.
    static let accentInk = Color(hex: 0x2B6CA3)
    /// Pill and badge backgrounds, soft highlight fills.
    static let accentTint = Color(hex: 0xEAF3FC)

    // MARK: - Semantic (restricted)
    //
    // Deliberately desaturated. Never a background fill, never a hero number,
    // never more than two per screen. Prefer a glyph in `textSecondary` instead.

    static let positive = Color(hex: 0x5B8C73)
    static let negative = Color(hex: 0xB07C6E)

    // MARK: - Depth

    /// Tinted slate, never pure black. Used at 5–7% — see `Elevation`.
    static let shadow = Color(hex: 0x1F2A37)

    // MARK: - Gradients

    /// The app's base wash. Near-invisible by design.
    static let backgroundGradient = LinearGradient(
        colors: [gradientTop, gradientBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    /// A soft neutral wash for avatar initials fallbacks.
    static let avatarGradient = LinearGradient(
        colors: [surfaceSecondary, Color(hex: 0xE8EBF0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    /// Token-only initializer. Intentionally `fileprivate`: if you need a new
    /// color, add a named token above rather than reaching for this.
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
