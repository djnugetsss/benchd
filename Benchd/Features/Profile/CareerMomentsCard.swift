import SwiftUI

/// The featured facts: the handful of numbers a career is remembered by.
///
/// The server decides which facts exist and what they are called, so a new one can
/// ship without an App Store release. This view decides only how they are ranked on
/// screen: the first fact gets `.large` and the rest sit under it in a two-column
/// grid, so the section has its own focal point instead of four equal numbers
/// competing inside one card.
///
/// Facts already shown elsewhere on the profile are filtered out before they arrive
/// here — see ``ProfileContent``.
struct CareerMomentsCard: View {
    let facts: [CareerFact]

    private let columns = [
        GridItem(.flexible(), alignment: .topLeading),
        GridItem(.flexible(), alignment: .topLeading),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Moments")

            Card {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let lead = facts.first {
                        factBlock(lead, style: .large)
                    }

                    let rest = Array(facts.dropFirst())
                    if !rest.isEmpty {
                        SoftDivider()

                        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.lg) {
                            ForEach(rest) { factBlock($0, style: .medium) }
                        }
                    }
                }
            }
        }
    }

    private func factBlock(_ fact: CareerFact, style: DisplayStyle) -> some View {
        StatBlock(
            label: fact.label,
            value: .number(fact.value, decimals: fact.decimals),
            style: style,
            caption: fact.context
        )
    }
}

#Preview("Moments") {
    ScrollView {
        CareerMomentsCard(facts: CareerDetails.sample.facts(excluding: ProfileContent.factsShownElsewhere))
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Moments — a single fact") {
    ScrollView {
        CareerMomentsCard(facts: Array(CareerDetails.sample.facts.prefix(1)))
            .padding(Spacing.screen)
    }
    .gradientBackground()
}
