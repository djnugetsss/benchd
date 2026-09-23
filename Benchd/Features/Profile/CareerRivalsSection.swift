import SwiftUI

/// The rivals worth naming: most played, most beaten, and whoever owns this manager.
///
/// Rivalries follow the person rather than the roster, so the same rival survives a
/// league rolling over to a new id with new roster numbers. One opponent very often
/// holds two of the three roles at once, and ``RivalrySummary/highlights`` merges
/// those onto one row — listing the same person three times would read as a bug.
///
/// The role sits *above* each rival as a stat label rather than beside their name:
/// two merged roles plus a name and a record do not fit on one line at this width,
/// and a truncated "Most played · Yo…" is worse than a second line.
struct CareerRivalsSection: View {
    let rivalries: RivalrySummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Rivals", subtitle: subtitle)

            RowCard(data: rivalries.highlights) { highlight in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(roleText(highlight.roles))
                        .statLabelStyle()

                    StatRow(
                        title: highlight.rivalry.name,
                        subtitle: meetings(highlight.rivalry),
                        value: highlight.rivalry.recordText
                    ) {
                        Avatar(name: highlight.rivalry.name, size: .small)
                    }
                }
            }
        }
    }

    private var subtitle: String? {
        guard rivalries.threshold > 0 else { return nil }
        return "Anyone you have faced at least \(rivalries.threshold) times"
    }

    private func roleText(_ roles: [RivalryHighlight.Role]) -> String {
        roles.map { role in
            switch role {
            case .mostPlayed: "Most played"
            case .beatenMost: "You beat most"
            case .losesTo: "Beats you most"
            }
        }
        .joined(separator: " · ")
    }

    private func meetings(_ rivalry: Rivalry) -> String {
        let games = "\(rivalry.games) meeting\(rivalry.games == 1 ? "" : "s")"
        guard let first = rivalry.firstSeason else { return games }
        return "\(games) since \(first)"
    }
}

#Preview("Rivals") {
    ScrollView {
        CareerRivalsSection(rivalries: CareerDetails.sample.rivalries)
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Rivals — one person holds every role") {
    ScrollView {
        CareerRivalsSection(
            rivalries: RivalrySummary(
                threshold: 4,
                all: [.sampleNemesis],
                mostPlayed: .sampleNemesis,
                best: .sampleNemesis,
                worst: .sampleNemesis
            )
        )
        .padding(Spacing.screen)
    }
    .gradientBackground()
}
