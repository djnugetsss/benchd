import SwiftUI

/// The Benchd wordmark, for surfaces that leave the app.
///
/// Small on purpose. A wrap card is something a person posts about *their* week;
/// a logo competing with their score would make it an advertisement, and nobody
/// shares an advertisement. The mark earns its place by being the quietest thing
/// on the card — which, on a feed full of loud graphics, is the thing that reads
/// as considered.
///
/// The dot is the one place the accent is spent on a wrap card.
struct Wordmark: View {
    /// Slightly heavier on an exported image than on screen, where the card is
    /// already surrounded by the app.
    var tone: Tone = .quiet

    enum Tone {
        case quiet
        case solid

        var color: Color {
            switch self {
            case .quiet: Palette.textTertiary
            case .solid: Palette.textSecondary
            }
        }
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Palette.accent)
                .frame(width: Spacing.xs, height: Spacing.xs)

            Text("Benchd")
                .font(Typography.statLabel)
                .textCase(.uppercase)
                .tracking(2.0)
                .foregroundStyle(tone.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Benchd")
    }
}

#Preview("Wordmark") {
    VStack(spacing: Spacing.lg) {
        Wordmark()
        Wordmark(tone: .solid)
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
