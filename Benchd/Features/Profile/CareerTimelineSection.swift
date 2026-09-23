import SwiftUI

/// The career, season by season, most recent first.
///
/// One row per league-season, because that is the granularity a record actually has
/// — someone in three leagues in 2023 played three different seasons that year, and
/// averaging them into one row would describe a season nobody played.
struct CareerTimelineSection: View {
    /// Already ordered newest first by ``CareerDetails/timeline``.
    let seasons: [SeasonSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Season by season", subtitle: medianNote)

            RowCard(data: seasons) { season in
                StatRow(title: season.leagueName, subtitle: subtitle(for: season)) {
                    Text(String(season.season))
                        .displayStyle(.small)
                        .foregroundStyle(Palette.textSecondary)
                } trailing: {
                    // The second and last accent on this screen, and only on a
                    // title: a year someone won is the one row worth marking.
                    StatRowValue(season.finishText ?? "–", accented: season.champion)
                }
            }
        }
    }

    /// Median leagues settle two results a week, so a 14-week season can read 20–8.
    /// Disclosed once here rather than crowding every row that needs it.
    private var medianNote: String? {
        seasons.contains(where: \.medianScoring)
            ? "Median leagues count the weekly median as a second result"
            : nil
    }

    private func subtitle(for season: SeasonSummary) -> String {
        if season.isUnplayed { return "Not started" }
        // A season in progress gets no weekly average: it would look like a final
        // number for a season that has four weeks in it.
        if season.inProgress { return "\(season.recordText) · in progress" }
        guard let perWeek = season.perWeekText else { return season.recordText }
        return "\(season.recordText) · \(perWeek) a week"
    }
}

#Preview("Timeline") {
    ScrollView {
        CareerTimelineSection(seasons: CareerDetails.sample.timeline)
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Timeline — one season, not started") {
    ScrollView {
        CareerTimelineSection(seasons: [.sampleUnplayed])
            .padding(Spacing.screen)
    }
    .gradientBackground()
}
