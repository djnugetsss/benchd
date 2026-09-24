import SwiftUI

/// A quiet inline notice beneath a field or action.
///
/// Errors here are intentionally understated. DESIGN.md bans a red fill, so the
/// message sits on the neutral recessed surface and only the small glyph carries
/// the muted clay tone. A failed username lookup should read as information, not
/// as an alarm.
struct InlineMessage: View {
    enum Tone {
        case info
        case error

        var glyph: String {
            switch self {
            case .info: "info.circle"
            case .error: "exclamationmark.circle"
            }
        }

        var glyphColor: Color {
            switch self {
            case .info: Palette.textTertiary
            case .error: Palette.negative
            }
        }
    }

    let text: String
    var tone: Tone = .error

    init(_ text: String, tone: Tone = .error) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: tone.glyph)
                .font(Typography.iconSmall)
                .foregroundStyle(tone.glyphColor)

            Text(text)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(Palette.surfaceSecondary, in: RoundedRectangle.soft(Radius.sm))
        .accessibilityElement(children: .combine)
    }
}

#Preview("InlineMessage") {
    VStack(spacing: Spacing.sm) {
        InlineMessage("We couldn't find that username on Sleeper. Check the spelling and try again.")
        InlineMessage("You're offline. Reconnect and try again.")
        InlineMessage("Passwords need at least 8 characters.", tone: .info)
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
