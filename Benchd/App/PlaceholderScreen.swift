import SwiftUI

/// Temporary launch surface. Exists so the shell runs before any feature does.
///
/// Delete this once Onboarding ships — it is scaffolding, not a design reference.
/// It does, however, obey the rules: gradient canvas, tokens only, no default chrome.
struct PlaceholderScreen: View {
    private let isConfigured = AppConfig.isConfigured

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: Spacing.s5) {
                Spacer()

                Text("Benchd")
                    .font(Typography.statHero)
                    .foregroundStyle(Palette.ink)
                    .tracking(-1.5)

                Text("Your fantasy career, in one place.")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.inkSecondary)

                Spacer()

                statusPill
                    .padding(.bottom, Spacing.s8)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .multilineTextAlignment(.center)
        }
    }

    private var statusPill: some View {
        HStack(spacing: Spacing.s3) {
            Circle()
                .fill(isConfigured ? Palette.positive : Palette.inkTertiary)
                .frame(width: 6, height: 6)

            Text(isConfigured ? "Supabase configured" : "Add Secrets.xcconfig to connect")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.vertical, Spacing.s4)
        .background(Palette.surface.opacity(0.7), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.divider, lineWidth: 1))
    }
}

#Preview {
    PlaceholderScreen()
}
