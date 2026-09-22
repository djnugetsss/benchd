import SwiftUI

/// A circular avatar with an initials fallback.
///
/// The fallback is a soft neutral wash, never a color derived from a team or a
/// username — saturated team color is explicitly banned, and a "random but
/// consistent" hue would smuggle it back in.
struct Avatar: View {
    enum Size {
        case small, medium, large, hero

        var diameter: CGFloat {
            switch self {
            case .small: 32
            case .medium: 44
            case .large: 64
            case .hero: 88
            }
        }

        var font: Font {
            switch self {
            case .small: Typography.caption
            case .medium: Typography.body
            case .large: Typography.displaySmall
            case .hero: Typography.displayMedium
            }
        }
    }

    let name: String
    var imageURL: URL? = nil
    var size: Size = .medium
    /// A thin accent ring. An active/selected marker — spends accent budget.
    var showsRing: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(Palette.avatarGradient)

            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initials
                }
            } else {
                initials
            }
        }
        .frame(width: size.diameter, height: size.diameter)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Palette.divider, lineWidth: Stroke.hairline)
        )
        .overlay {
            if showsRing {
                Circle()
                    .strokeBorder(Palette.accent, lineWidth: 2)
                    .padding(-3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }

    private var initials: some View {
        Text(Self.initials(from: name))
            .font(size.font)
            .foregroundStyle(Palette.textSecondary)
    }

    /// Up to two initials. Falls back to "?" rather than rendering an empty circle.
    static func initials(from name: String) -> String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
        return parts.isEmpty ? "?" : parts.joined().uppercased()
    }
}

#Preview("Avatar") {
    VStack(spacing: Spacing.lg) {
        HStack(spacing: Spacing.md) {
            Avatar(name: "Ansh Mehta", size: .small)
            Avatar(name: "Ansh Mehta", size: .medium)
            Avatar(name: "Ansh Mehta", size: .large)
            Avatar(name: "Ansh Mehta", size: .hero)
        }
        HStack(spacing: Spacing.md) {
            Avatar(name: "Ansh Mehta", size: .large, showsRing: true)
            Avatar(name: "singlename", size: .large)
            Avatar(name: "", size: .large)
        }
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
