import SwiftUI

/// The app's base surface: a near-invisible wash from white to the faintest cool
/// gray. Every full screen in Benchd sits on this.
///
/// A flat `Color.white` or a default `.background(.background)` screen is a bug.
struct GradientBackground: View {
    /// Adds a very low-opacity accent bloom at the top. Reserved for brand moments
    /// — onboarding, a wrap card backdrop. Off by default, because on a normal
    /// screen the bloom spends accent budget on decoration.
    var showsBloom: Bool = false

    var body: some View {
        Palette.backgroundGradient
            .overlay(alignment: .top) {
                if showsBloom {
                    RadialGradient(
                        colors: [Palette.accent.opacity(0.14), Palette.accent.opacity(0)],
                        center: .top,
                        startRadius: 0,
                        endRadius: 420
                    )
                    .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
    }
}

extension View {
    /// Places the view on the app's gradient canvas.
    func gradientBackground(showsBloom: Bool = false) -> some View {
        background(GradientBackground(showsBloom: showsBloom))
    }
}

#Preview("Plain") {
    GradientBackground()
}

#Preview("With bloom") {
    GradientBackground(showsBloom: true)
}
