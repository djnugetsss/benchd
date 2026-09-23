import SwiftUI

/// The career profile.
///
/// Reloads whenever `AppSession.syncGeneration` changes — the session bumps it
/// when a sync finishes and when the app returns to the foreground. That is what
/// makes the page fill itself in rather than needing a force-quit.
struct ProfileScreen: View {
    @Environment(AppSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: ProfileViewModel?

    var body: some View {
        TabScaffold(title: "Career") {
            if let model {
                ProfileContent(model: model)
            } else {
                // Still resolving which account this is.
                ProfileSkeleton()
            }
        }
        .refreshable {
            await model?.refresh()
        }
        // Keyed on both the account and the sync generation: a finished sync
        // re-runs this, and switching accounts rebuilds instead of showing the
        // previous one's numbers.
        .task(id: reloadKey) {
            await prepareAndLoad()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // A background sync may have finished while we were away.
            Task { await session.refreshAfterForeground() }
        }
    }

    private var reloadKey: String {
        "\(session.connectedAccount?.id.uuidString ?? "none")-\(session.syncGeneration)"
    }

    private func prepareAndLoad() async {
        guard let account = session.connectedAccount else {
            AppLog.profile.debug("profile: no connected account yet")
            return
        }

        if model?.account.id != account.id {
            AppLog.profile.debug("profile: building model for \(account.id.uuidString, privacy: .public)")
            let created = ProfileViewModel(account: account)
            model = created
            await created.load()
        } else {
            // Same account, newer generation — refresh in place so the numbers
            // update without the page flashing back to skeletons.
            AppLog.profile.debug("profile: refreshing for generation \(session.syncGeneration)")
            await model?.refresh()
        }
    }
}

// MARK: - Body

/// The state-driven body. Split out so previews can drive it directly without
/// the session plumbing.
struct ProfileContent: View {
    let model: ProfileViewModel

    /// Facts the rest of the page already carries, so the Moments card does not say
    /// the same thing twice: titles and seasons are in the hero card, the all-time
    /// points total is in the points card, and the win streak has its own.
    ///
    /// Any fact the server adds that is *not* in this set appears automatically —
    /// which is the reason the payload carries a label and a unit for each one.
    static let factsShownElsewhere: Set<String> = [
        CareerFact.Key.seasonsPlayed,
        CareerFact.Key.championships,
        CareerFact.Key.pointsFor,
        CareerFact.Key.longestWinStreak,
    ]

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProfileSkeleton()

            case .ready(let stats):
                career(stats)

            case .awaitingFirstSync:
                ProfileSkeleton()
                EmptyState(
                    title: "Your career is syncing",
                    message: "We're pulling your Sleeper history. This page fills in as it lands."
                )
                .frame(maxWidth: .infinity)

            case .failed(let message):
                EmptyState(
                    title: "We couldn't load your career",
                    message: message
                ) {
                    SecondaryButton("Try again") {
                        Task { await model.load() }
                    }
                    .frame(maxWidth: 220)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(Motion.gentle, value: model.state)
    }

    /// The populated page.
    ///
    /// Every section below the hero card is conditional on its own data, so a career
    /// with no draft history, no rivalries, or no details at all degrades to a
    /// shorter page rather than to a row of zeroes. An account whose `details` could
    /// not be read renders exactly the two cards at the top.
    @ViewBuilder
    private func career(_ stats: CareerStats) -> some View {
        let details = stats.details
        let facts = details.facts(excluding: Self.factsShownElsewhere)

        // A synced account with nothing in it gets a sentence, not a card of
        // zeroes. "0–0" at 64pt is a designed screen saying nothing happened.
        if stats.leaguesCount == 0 {
            EmptyState(
                title: "No leagues on this account yet",
                message: "We couldn't find any Sleeper leagues for @\(model.account.username ?? "this account"). Join one and pull to refresh — your career builds itself from there.",
                systemImage: "person.crop.circle"
            )
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                CareerCard(stats: stats, account: model.account)
                CareerPointsCard(stats: stats, record: details.regularSeason)

                if !facts.isEmpty {
                    CareerMomentsCard(facts: facts)
                }
                if !details.playoffs.isEmpty {
                    CareerPostseasonCard(playoffs: details.playoffs)
                }
                if !details.streaks.isEmpty {
                    CareerStreaksCard(streaks: details.streaks)
                }
                if !details.draft.isEmpty {
                    CareerDraftSection(draft: details.draft)
                }
                if !details.rivalries.highlights.isEmpty {
                    CareerRivalsSection(rivalries: details.rivalries)
                }
                if !details.seasons.isEmpty {
                    CareerTimelineSection(seasons: details.timeline)
                }

                footer(details)
            }
        }
    }

    /// When the numbers were last rebuilt, and what the sync could not find.
    private func footer(_ details: CareerDetails) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let lastSynced = model.account.lastSyncedAt {
                Text("Updated \(lastSynced.formatted(.relative(presentation: .named)))")
            }
            // Said plainly rather than left as a gap in the draft section: Sleeper
            // does not keep draft data for every league, and a missing steal reads
            // as a bug otherwise.
            if details.draft.leaguesMissingDraftData > 0 {
                Text(missingDraftText(details.draft.leaguesMissingDraftData))
            }
        }
        .font(Typography.caption)
        .foregroundStyle(Palette.textTertiary)
    }

    private func missingDraftText(_ count: Int) -> String {
        count == 1
            ? "One of your seasons has no draft on Sleeper, so its picks aren't graded."
            : "\(count) of your seasons have no draft on Sleeper, so their picks aren't graded."
    }
}

// MARK: - Loading

/// Sketches the shape of the loaded page — the hero card and the first list — so the
/// layout does not jump when the real numbers arrive. Never a spinner.
struct ProfileSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            Card(radius: Radius.hero, elevation: .lifted) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(spacing: Spacing.sm) {
                        SkeletonBlock(width: 44, height: 44, radius: 22)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            SkeletonBlock(width: 120, height: 12)
                            SkeletonBlock(width: 80, height: 10)
                        }
                        Spacer(minLength: 0)
                    }

                    StatBlock(label: "All-time record", value: .pending, style: .hero)
                        .padding(.vertical, Spacing.xs)

                    SoftDivider()

                    HStack(alignment: .top, spacing: Spacing.md) {
                        StatBlock(label: "Titles", value: .pending, style: .medium)
                        StatBlock(label: "Seasons", value: .pending, style: .medium)
                        StatBlock(label: "Leagues", value: .pending, style: .medium)
                    }
                }
            }

            Card {
                HStack(alignment: .top, spacing: Spacing.md) {
                    StatBlock(label: "Points for", value: .pending, style: .medium)
                    StatBlock(label: "Points against", value: .pending, style: .medium)
                    StatBlock(label: "A week", value: .pending, style: .medium)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Profile — ready") {
    ScrollView {
        ProfileContent(model: .preview(state: .ready(.sample)))
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Profile — first season, no history yet") {
    ScrollView {
        ProfileContent(model: .preview(state: .ready(.sampleFirstSeason)))
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Profile — details unreadable") {
    // What an older build shows for a payload it cannot parse, and what every row
    // computed before the details existed still looks like.
    ScrollView {
        ProfileContent(model: .preview(state: .ready(.sampleWithoutDetails)))
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Profile — no leagues found") {
    ScrollView {
        ProfileContent(model: .preview(state: .ready(.sampleNoLeagues)))
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Profile — loading") {
    ScrollView {
        ProfileContent(model: .preview(state: .loading))
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Profile — awaiting first sync") {
    ScrollView {
        ProfileContent(model: .preview(state: .awaitingFirstSync))
            .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Profile — failed") {
    ScrollView {
        ProfileContent(model: .preview(state: .failed("You're offline. Pull to refresh once you reconnect.")))
            .padding(Spacing.screen)
    }
    .gradientBackground()
}
