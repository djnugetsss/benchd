import SwiftUI

/// A slow, low-contrast highlight sweep for loading placeholders.
///
/// This is the only looping animation allowed in the app. It is deliberately
/// gentle — a fast, high-contrast shimmer reads as a cheap web skeleton.
/// Reduce Motion turns it into a plain static fill.
private struct ShimmerModifier: ViewModifier {
    var isActive: Bool

    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            content
                .overlay {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                Palette.surface.opacity(0),
                                Palette.surface.opacity(0.9),
                                Palette.surface.opacity(0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.55)
                        .offset(x: phase * proxy.size.width * 1.5)
                    }
                    .allowsHitTesting(false)
                }
                // Masking to the content keeps the sweep inside the placeholder's
                // own shape, so a rounded skeleton does not get a square highlight.
                .mask { content }
                .onAppear {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    /// Adds the loading shimmer. Pass `isActive: false` to freeze it.
    func shimmering(_ isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

/// A single loading placeholder bar. Compose several to sketch a screen's shape
/// while it loads — never a centered spinner.
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var radius: CGFloat = Radius.sm

    var body: some View {
        RoundedRectangle.soft(radius)
            .fill(Palette.surfaceSecondary)
            .frame(width: width, height: height)
            .shimmering()
            .accessibilityHidden(true)
    }
}

#Preview("Shimmer") {
    Card {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SkeletonBlock(width: 90, height: 11)
            SkeletonBlock(width: 160, height: 40)
            SkeletonBlock(height: 11)
            SkeletonBlock(width: 220, height: 11)
        }
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
