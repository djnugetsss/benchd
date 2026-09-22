import SwiftUI

/// Temporary launch surface. Exists so the shell runs before any feature does.
///
/// - Note: Not currently reachable — `RootView` is pinned to `DesignGalleryView`
///   while the design system is being reviewed. Delete both this file and that
///   pin when Onboarding ships.
///
/// It is scaffolding, not a design reference, but it does obey the rules:
/// gradient canvas, tokens only, no default chrome.
struct PlaceholderScreen: View {
    private let configurationError = AppConfig.configurationError
    private var isConfigured: Bool { configurationError == nil }

    var body: some View {
        ZStack {
            GradientBackground(showsBloom: true)

            VStack(spacing: Spacing.md) {
                Spacer()

                Text("Benchd")
                    .displayStyle(.hero)
                    .foregroundStyle(Palette.textPrimary)

                Text("Your fantasy career, in one place.")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)

                Spacer()

                statusPill
                    .padding(.bottom, Spacing.xxl)
            }
            .padding(.horizontal, Spacing.screen)
            .multilineTextAlignment(.center)
        }
    }

    private var statusPill: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(isConfigured ? Palette.positive : Palette.textTertiary)
                .frame(width: 6, height: 6)

            Text(configurationError?.shortDescription ?? "Supabase configured")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Palette.surface.opacity(0.7), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.divider, lineWidth: Stroke.border))
    }
}

#Preview {
    PlaceholderScreen()
}
