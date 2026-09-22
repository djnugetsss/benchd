import SwiftUI

/// Animation curves. Gentle, damped, never bouncy — see `docs/DESIGN.md` §7.
///
/// Damping is always ≥ 0.85. If something visibly overshoots, it is wrong.
enum Motion {
    /// Default for state changes.
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.86)
    /// Large surfaces, sheets.
    static let soft = Animation.spring(response: 0.7, dampingFraction: 0.92)
    /// Button press, toggle.
    static let quick = Animation.spring(response: 0.28, dampingFraction: 0.9)
    /// Opacity only.
    static let fade = Animation.easeOut(duration: 0.28)
    /// The hero number count-up. Decelerates into the final value.
    static let countUp = Animation.easeOut(duration: 1.1)

    /// How long a count-up runs. Kept alongside the curve so the two never drift.
    static let countUpDuration: Double = 1.1

    /// The app's content-entrance transition: fade with a slight scale.
    /// Never a slide — slides read as chrome.
    static let appear = AnyTransition.opacity.combined(with: .scale(scale: 0.98))
}
