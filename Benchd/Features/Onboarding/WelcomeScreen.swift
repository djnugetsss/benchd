import SwiftUI

/// The first thing anyone sees.
///
/// One focal point: the headline. The card cluster above it is illustrative —
/// it shows what a Benchd profile *is* faster than a sentence can, and it is the
/// screen's single animated element.
///
/// The cards settle and stop. DESIGN.md allows no looping motion outside the
/// loading shimmer, so there is no perpetual drift here — the movement is an
/// arrival, not an ambience.
struct WelcomeScreen: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Fixed top inset rather than a Spacer: an even top/bottom split
            // left the content stranded mid-screen with a void beneath it.
            // Anchoring the group high and the action low fills the page.
            Spacer(minLength: Spacing.lg)
                .frame(maxHeight: Spacing.huge)

            FloatingStatCards()
                .padding(.bottom, Spacing.sectionGapLarge)

            VStack(spacing: Spacing.md) {
                Text("Your fantasy career,\nin one place.")
                    .titleStyle()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Every season, every league, every questionable draft pick — collected into one profile worth showing off.")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.xl)

            PrimaryButton("Get started", action: onContinue)

            Text("Free, and always will be.")
                .font(Typography.caption)
                .foregroundStyle(Palette.textTertiary)
                .padding(.top, Spacing.md)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.xl)
    }
}

/// Three specimen cards that arrive in a gentle stagger.
private struct FloatingStatCards: View {
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Specimen: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let rotation: Double
        let xOffset: CGFloat
        let delay: Double
    }

    private let specimens: [Specimen] = [
        .init(label: "All-time record", value: "128–74", rotation: -2.5, xOffset: -14, delay: 0.00),
        .init(label: "Championships", value: "3", rotation: 1.5, xOffset: 18, delay: 0.10),
        .init(label: "Best pick", value: "Round 7", rotation: -1.0, xOffset: -6, delay: 0.20),
    ]

    var body: some View {
        VStack(spacing: -Spacing.xs) {
            ForEach(Array(specimens.enumerated()), id: \.element.id) { index, specimen in
                card(specimen)
                    .zIndex(Double(specimens.count - index))
                    .rotationEffect(.degrees(hasAppeared ? specimen.rotation : 0))
                    .offset(
                        x: hasAppeared ? specimen.xOffset : 0,
                        y: hasAppeared ? 0 : 28
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.94)
                    .animation(
                        reduceMotion ? nil : Motion.soft.delay(specimen.delay),
                        value: hasAppeared
                    )
            }
        }
        .onAppear { hasAppeared = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example profile stats: all-time record 128 and 74, 3 championships, best pick in round 7")
    }

    private func card(_ specimen: Specimen) -> some View {
        HStack(spacing: Spacing.md) {
            Text(specimen.label)
                .statLabelStyle()
                // "ALL-TIME RECORD" wrapped to two lines, making the first card
                // taller than the others and breaking the stack's rhythm.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: Spacing.sm)

            Text(specimen.value)
                .displayStyle(.small)
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: 286)
        .background(Palette.surface, in: RoundedRectangle.soft(Radius.md))
        .overlay(
            RoundedRectangle.soft(Radius.md)
                .strokeBorder(Palette.divider, lineWidth: Stroke.border)
        )
        .elevation(.soft)
    }
}

#Preview("Welcome") {
    ZStack {
        GradientBackground(showsBloom: true)
        WelcomeScreen {}
    }
}
