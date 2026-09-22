import SwiftUI

/// The app's base surface: a soft vertical wash from white down to the faintest
/// cool gray, with a single low-opacity accent bloom in the upper third.
///
/// Every full screen in Benchd sits on this. A flat `Color.white` or a default
/// `.background(.background)` is never correct.
struct GradientBackground: View {
    /// When `true`, adds the accent bloom. Turn it off behind dense content where
    /// the tint would fight the data.
    var showsBloom: Bool = true

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Palette.canvasTop, location: 0.0),
                .init(color: Palette.canvasMid, location: 0.45),
                .init(color: Palette.canvasBottom, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            if showsBloom {
                RadialGradient(
                    colors: [Palette.accent.opacity(0.10), Palette.accent.opacity(0)],
                    center: .top,
                    startRadius: 0,
                    endRadius: 460
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Places the view on the app's gradient canvas.
    func gradientBackground(showsBloom: Bool = true) -> some View {
        background(GradientBackground(showsBloom: showsBloom))
    }
}

#Preview("With bloom") {
    GradientBackground()
}

#Preview("Without bloom") {
    GradientBackground(showsBloom: false)
}
