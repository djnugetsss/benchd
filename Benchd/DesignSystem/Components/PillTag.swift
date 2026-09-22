import SwiftUI

/// A small capsule label: a position, a season, a status.
///
/// The accent tone uses `accentTint` behind `accentInk` text — never `accent`
/// itself, which is too light to carry a word.
struct PillTag: View {
    enum Tone {
        /// The default. Neutral surface, secondary text.
        case neutral
        /// Spends accent budget. Active states and key markers only.
        case accent

        var background: Color {
            switch self {
            case .neutral: Palette.surfaceSecondary
            case .accent: Palette.accentTint
            }
        }

        var foreground: Color {
            switch self {
            case .neutral: Palette.textSecondary
            case .accent: Palette.accentInk
            }
        }
    }

    let text: String
    var tone: Tone = .neutral
    /// An optional SF Symbol before the text.
    var systemImage: String? = nil

    init(_ text: String, tone: Tone = .neutral, systemImage: String? = nil) {
        self.text = text
        self.tone = tone
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: Spacing.xxs + 2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(Typography.iconSmall)
            }
            Text(text)
                .font(Typography.statLabel)
                .tracking(0.6)
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs - 1)
        .background(tone.background, in: Capsule())
    }
}

#Preview("PillTag") {
    HStack(spacing: Spacing.xs) {
        PillTag("QB")
        PillTag("2024")
        PillTag("Active", tone: .accent)
        PillTag("Questionable", tone: .neutral, systemImage: "cross.case")
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
