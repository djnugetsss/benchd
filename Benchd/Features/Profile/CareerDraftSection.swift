import SwiftUI

/// Draft grades: the three best calls and the three worst.
///
/// A pick's number is what the player scored **in this manager's starting lineup**
/// that season, and the caption is how that compares with the rest of the same round
/// of the same draft. Raw points alone would rank every first-rounder above every
/// last-rounder, which is not a verdict on anything.
///
/// The surplus is deliberately **not** coloured. A list of numbers in green and red
/// is the sportsbook look this app is defined against — the sign carries the
/// direction, and `DESIGN.md` §3 reserves the semantic pair for cases where nothing
/// else can.
struct CareerDraftSection: View {
    let draft: DraftGrades

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            if !draft.bestPicks.isEmpty {
                group(
                    title: "Best draft picks",
                    subtitle: "What each pick returned in your lineup, against the rest of its round",
                    picks: draft.bestPicks
                )
            }

            if !draft.worstPicks.isEmpty {
                group(title: "Worst draft picks", subtitle: nil, picks: draft.worstPicks)
            }
        }
    }

    private func group(title: String, subtitle: String?, picks: [DraftPickGrade]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title, subtitle: subtitle)

            RowCard(data: picks) { pick in
                StatRow(
                    title: pick.displayName,
                    subtitle: "\(pick.slotText) · \(pick.season) · \(pick.leagueName)",
                    value: pick.pointsText,
                    valueCaption: pick.surplusText
                ) {
                    // Falls back to the round so the rows stay aligned when Sleeper
                    // recorded no position for a pick.
                    PillTag(pick.position ?? "R\(pick.round)")
                }
            }
        }
    }
}

#Preview("Draft grades") {
    ScrollView {
        CareerDraftSection(draft: CareerDetails.sample.draft)
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Draft — best picks only") {
    ScrollView {
        CareerDraftSection(
            draft: DraftGrades(
                bestPicks: CareerDetails.sample.draft.bestPicks,
                worstPicks: [],
                scoredPicks: 3,
                leaguesMissingDraftData: 2
            )
        )
        .padding(Spacing.screen)
    }
    .gradientBackground()
}
