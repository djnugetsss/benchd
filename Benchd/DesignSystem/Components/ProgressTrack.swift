import SwiftUI

/// A slim determinate progress line.
///
/// Determinate on purpose: DESIGN.md allows no looping motion outside the
/// loading shimmer, which rules out a spinner. It also rules out an
/// indeterminate bar, since that is a loop by another name. If progress cannot
/// be measured, this is the wrong component.
struct ProgressTrack: View {
    /// 0…1. Values outside the range are clamped.
    var value: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.divider)

                Capsule()
                    .fill(Palette.accent)
                    .frame(width: max(proxy.size.width * clamped, clamped > 0 ? 6 : 0))
            }
        }
        .frame(height: 4)
        .animation(reduceMotion ? nil : Motion.soft, value: clamped)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sync progress")
        .accessibilityValue("\(Int(clamped * 100)) percent")
    }
}

#Preview("ProgressTrack") {
    VStack(spacing: Spacing.lg) {
        ProgressTrack(value: 0)
        ProgressTrack(value: 0.08)
        ProgressTrack(value: 0.46)
        ProgressTrack(value: 1)
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
