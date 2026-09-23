import SwiftUI

/// The top of the profile: who this is, and the one number the screen is about.
///
/// This card holds the screen's single focal point — the all-time record at `.hero`.
/// Nothing below it uses a display role that large, which is what keeps the page
/// from becoming a scoreboard of competing numbers.
struct CareerCard: View {
    let stats: CareerStats
    let account: SleeperAccount

    var body: some View {
        Card(radius: Radius.hero, elevation: .lifted) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header

                StatBlock(
                    label: "All-time record",
                    value: .text(stats.recordText),
                    style: .hero,
                    caption: winRateCaption
                )
                .padding(.vertical, Spacing.xs)

                SoftDivider()

                HStack(alignment: .top, spacing: Spacing.md) {
                    // The one accented number on the screen, and only once there
                    // is a title to accent. A zero in blue would spend the app's
                    // scarcest ink on the absence of the thing.
                    StatBlock(
                        label: "Titles",
                        value: .number(stats.championships),
                        style: .medium,
                        accented: stats.championships > 0
                    )
                    StatBlock(label: "Seasons", value: .number(stats.seasons), style: .medium)
                    StatBlock(label: "Leagues", value: .number(stats.leaguesCount), style: .medium)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Avatar(name: displayName, imageURL: account.avatarURL, size: .medium)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(displayName)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var displayName: String {
        account.displayName ?? account.username ?? "Your profile"
    }

    private var subtitle: String {
        var parts: [String] = []
        if let username = account.username { parts.append("@\(username)") }
        if stats.seasons > 0 {
            parts.append("\(stats.seasons) season\(stats.seasons == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    private var winRateCaption: String? {
        guard let rate = stats.winPercentage else { return nil }
        return "\(rate.formatted(.percent.precision(.fractionLength(1)))) win rate"
    }
}

// MARK: - Points

/// Points for, against, and the weekly average that produced them.
///
/// The section header carries the noun so the three labels can stay short. A stat
/// label long enough to wrap pushes its number below its neighbours', and a row of
/// numbers that do not share a baseline reads as broken — at three across, "Points
/// against" is already too long.
struct CareerPointsCard: View {
    let stats: CareerStats
    /// Supplies the per-week average, which only the details payload carries.
    let record: CareerRecord

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Points")

            Card {
                HStack(alignment: .top, spacing: Spacing.md) {
                    StatBlock(
                        label: "For",
                        value: .number(stats.pointsFor, decimals: 1),
                        style: .medium
                    )
                    StatBlock(
                        label: "Against",
                        value: .number(stats.pointsAgainst, decimals: 1),
                        style: .medium
                    )
                    if let perWeek = record.pointsPerGame {
                        StatBlock(
                            label: "A week",
                            value: .number(perWeek, decimals: 1),
                            style: .medium
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Postseason

/// Playoff results. Titles live in the hero card, so this card carries the rest of
/// the postseason rather than repeating the headline.
struct CareerPostseasonCard: View {
    let playoffs: PlayoffRecord

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Postseason", subtitle: subtitle)

            Card {
                HStack(alignment: .top, spacing: Spacing.md) {
                    // Suppressed when no bracket has been stored: a league synced
                    // before the winners bracket landed knows the title but not
                    // the round-by-round record, and "0–0" would read as a loss.
                    if playoffs.games > 0 {
                        StatBlock(
                            label: "Record",
                            value: .text(playoffs.recordText),
                            style: .medium
                        )
                    }
                    StatBlock(
                        label: "Appearances",
                        value: .number(playoffs.appearances),
                        style: .medium
                    )
                }
            }
        }
    }

    /// Finals reached and finals lost, said in words rather than spent as a third
    /// column — two numbers side by side read better than three crowded ones.
    private var subtitle: String? {
        var parts: [String] = []
        if playoffs.finals > 0 {
            parts.append("\(playoffs.finals) final\(playoffs.finals == 1 ? "" : "s")")
        }
        if playoffs.runnerUps > 0 {
            let times = playoffs.runnerUps == 1 ? "once" : "\(playoffs.runnerUps) times"
            parts.append("runner-up \(times)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Streaks

/// The longest runs, each inside a single league-season — parallel leagues are never
/// merged into one streak, so a run here is a run that actually happened.
struct CareerStreaksCard: View {
    let streaks: CareerStreaks

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Streaks")

            Card {
                HStack(alignment: .top, spacing: Spacing.md) {
                    if let win = streaks.longestWin {
                        StatBlock(
                            label: "Won in a row",
                            value: .number(win.length),
                            style: .medium,
                            caption: win.context
                        )
                    }
                    if let loss = streaks.longestLoss {
                        StatBlock(
                            label: "Lost in a row",
                            value: .number(loss.length),
                            style: .medium,
                            caption: loss.context
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Summary cards") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            CareerCard(stats: .sample, account: .sample)
            CareerPointsCard(stats: .sample, record: CareerDetails.sample.regularSeason)
            CareerPostseasonCard(playoffs: CareerDetails.sample.playoffs)
            CareerStreaksCard(streaks: CareerDetails.sample.streaks)
        }
        .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Summary — no titles, one streak") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            CareerCard(stats: .sampleWinless, account: .sample)
            CareerStreaksCard(
                streaks: CareerStreaks(longestWin: nil, longestLoss: CareerDetails.sample.streaks.longestLoss)
            )
        }
        .padding(Spacing.screen)
    }
    .gradientBackground()
}
