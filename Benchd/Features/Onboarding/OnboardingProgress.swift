import SwiftUI

/// Three small marks showing where you are. The current step is a short accent
/// capsule; the others are neutral dots.
///
/// This is one of the two accent uses permitted per screen, and the only one on
/// the welcome screen.
struct OnboardingProgress: View {
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step == current ? Palette.accent : Palette.divider)
                    .frame(width: step == current ? 20 : 6, height: 6)
            }
        }
        .animation(Motion.gentle, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current.displayIndex) of \(OnboardingStep.allCases.count)")
    }
}

#Preview("Progress") {
    VStack(spacing: Spacing.lg) {
        OnboardingProgress(current: .welcome)
        OnboardingProgress(current: .signIn)
        OnboardingProgress(current: .connectSleeper)
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
