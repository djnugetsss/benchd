import SwiftUI

/// A hairline separator. Named to avoid colliding with SwiftUI's `Divider`, whose
/// default color and thickness are both wrong for this app.
struct SoftDivider: View {
    /// Inset from both leading and trailing edges.
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Palette.divider)
            .frame(height: Stroke.hairline)
            .padding(.horizontal, inset)
            .accessibilityHidden(true)
    }
}

#Preview("SoftDivider") {
    VStack(spacing: Spacing.lg) {
        SoftDivider()
        SoftDivider(inset: Spacing.xl)
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
