import SwiftUI

/// Press feedback for every button in the app: a small, quick, damped scale.
/// No opacity flash, no bounce.
struct SoftPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

/// The one action on a screen.
///
/// Defaults to an **ink fill with a white label**, not accent blue. White on
/// `accent` is ~2.2:1 and unreadable, and more importantly a blue button on every
/// screen would spend the accent on the most routine element in the app. The
/// `.accent` tone exists for genuine brand moments — see `docs/DESIGN.md` §8.
struct PrimaryButton: View {
    enum Tone {
        /// The default. Near-black fill, white label.
        case ink
        /// Brand moments only. Soft accent fill with **ink** text (~9:1), never white.
        case accent

        var background: Color {
            switch self {
            case .ink: Palette.textPrimary
            case .accent: Palette.accent
            }
        }

        var foreground: Color {
            switch self {
            case .ink: Palette.textOnInk
            case .accent: Palette.textPrimary
            }
        }
    }

    let title: String
    var tone: Tone = .ink
    var systemImage: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    init(
        _ title: String,
        tone: Tone = .ink,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.tone = tone
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage).font(Typography.button)
                }
                Text(title).font(Typography.button).tracking(-0.1)
            }
            .foregroundStyle(tone.foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md + 2)
            .background(tone.background, in: RoundedRectangle.soft(Radius.md))
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!isEnabled)
    }
}

/// Everything that is not the one action: surface fill, hairline border, ink label.
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage).font(Typography.button)
                }
                Text(title).font(Typography.button).tracking(-0.1)
            }
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md + 2)
            .background(Palette.surface, in: RoundedRectangle.soft(Radius.md))
            .overlay(
                RoundedRectangle.soft(Radius.md)
                    .strokeBorder(Palette.divider, lineWidth: Stroke.border)
            )
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!isEnabled)
    }
}

#Preview("Buttons") {
    VStack(spacing: Spacing.md) {
        PrimaryButton("Connect Sleeper") {}
        PrimaryButton("Share your wrap", tone: .accent, systemImage: "square.and.arrow.up") {}
        SecondaryButton("Not now") {}
        PrimaryButton("Disabled", isEnabled: false) {}
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
