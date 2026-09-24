import UIKit

/// The app's haptics, in one place so "subtle" stays subtle.
///
/// `DESIGN.md` §2 says nothing is loud, and that governs touch as much as motion:
/// a success notification buzz for saving an image would be the haptic equivalent
/// of confetti. There is exactly one feedback in Benchd, and it is soft.
@MainActor
enum Haptics {
    /// A quiet confirmation that something completed — a card saved to Photos.
    ///
    /// `.soft` at reduced intensity: felt if the phone is in your hand, ignorable
    /// if it is on a table.
    static func confirm() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.65)
    }
}
