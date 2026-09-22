import SwiftUI

/// The default container: surface fill, continuous radius, hairline border, and a
/// soft diffuse shadow. All four, every time — that combination is what makes a
/// card feel like it is floating rather than drawn.
///
/// Every card in the app is this component. A hand-rolled
/// `.background(...).cornerRadius(...)` in a feature file is a bug.
struct Card<Content: View>: View {
    var padding: CGFloat = Spacing.cardPadding
    var radius: CGFloat = Radius.card
    var elevation: Elevation = .soft
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle.soft(radius))
            .overlay(
                RoundedRectangle.soft(radius)
                    .strokeBorder(Palette.divider, lineWidth: Stroke.border)
            )
            .elevation(elevation)
    }
}

#Preview("Card") {
    VStack(spacing: Spacing.md) {
        Card {
            Text("Standard card")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
        }

        Card(radius: Radius.hero, elevation: .lifted) {
            Text("Hero card, lifted")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
        }
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
