import Foundation
import Testing
import UIKit
@testable import Benchd

/// Decoding the `weekly_wrap` payload.
///
/// The fixture is **real output**: the JSON the `weekly_wrap` Postgres function
/// returned from a seeded database, captured verbatim. The manager put up the top
/// score in one league and lost by four tenths of a point in another, which is
/// the week this whole feature exists for.
struct WeeklyWrapDecodingTests {

    private static let payload = """
    {"week":5,"record":{"ties":0,"wins":1,"losses":1},"season":2026,"leagues":[{"teams":\
    12,"margin":18.22,"points":148.62,"result":"W","league_id":"784462448236949504","tea\
    m_name":"Bench Mob","league_high":true,"league_name":"Dynasty \
    Dads","league_rank":1,"opponent_name":"Dana Mode","opponent_points":130.4},{"teams":\
    10,"margin":-0.4,"points":96.4,"result":"L","league_id":"917461823049281536","team_n\
    ame":"Bench Mob","league_high":false,"league_name":"Work \
    League","league_rank":9,"opponent_name":"Priya FC","opponent_points":96.8}],"highlig\
    ht":{"kind":"league_high","value":148.62,"caption":"Dynasty Dads","headline":"Top \
    score in the league"},"performers":[{"name":"Puka Nacua","team":"LAR","points":34.2,\
    "position":"WR","player_id":"9493","league_name":"Dynasty Dads"},{"name":"Josh Allen\
    ","team":"BUF","points":28.6,"position":"QB","player_id":"5849","league_name":"Dynas\
    ty Dads"},{"name":"Bijan Robinson","team":"ATL","points":24.4,"position":"RB","playe\
    r_id":"8138","league_name":"Dynasty \
    Dads"}],"points_for":245.02,"points_against":227.2}
    """

    private static func decoded() throws -> WeeklyWrap {
        try PostgrestCoding.decoder.decode(WeeklyWrap.self, from: Data(payload.utf8))
    }

    @Test("The payload the database returns decodes whole")
    func decodesRealPayload() throws {
        let wrap = try Self.decoded()

        #expect(wrap.season == 2026)
        #expect(wrap.week == 5)
        #expect(wrap.record.wins == 1)
        #expect(wrap.record.losses == 1)
        #expect(wrap.recordText == "1–1")
        #expect(wrap.pointsFor == 245.02)
        #expect(wrap.pointsAgainst == 227.20)
        #expect(wrap.leagues.count == 2)
        #expect(wrap.performers.count == 3)
        #expect(wrap.isMultiLeague)
        #expect(wrap.id == "2026-5")
    }

    @Test("League results carry the scoreline, the margin, and who it was against")
    func leagues() throws {
        let wrap = try Self.decoded()
        // Ordered by points, so the best league of the week leads.
        let best = try #require(wrap.leagues.first)
        let worst = try #require(wrap.leagues.last)

        #expect(best.leagueName == "Dynasty Dads")
        #expect(best.points == 148.62)
        #expect(best.opponentName == "Dana Mode")
        #expect(best.opponentPoints == 130.40)
        #expect(best.result == .win)
        #expect(best.margin == 18.22)
        #expect(best.leagueHigh)
        #expect(best.leagueRank == 1)
        #expect(best.teams == 12)
        #expect(best.scoreline == "148.6 – 130.4")

        #expect(worst.result == .loss)
        #expect(worst.margin == -0.40)
        #expect(worst.leagueHigh == false)
    }

    @Test("Performers arrive ranked, with the position and team for the card")
    func performers() throws {
        let performers = try Self.decoded().performers

        #expect(performers.map(\.name) == ["Puka Nacua", "Josh Allen", "Bijan Robinson"])
        #expect(performers[0].points == 34.20)
        #expect(performers[0].position == "WR")
        #expect(performers[0].subtitle == "WR · LAR")
        // Already sorted by the database — the card does not re-rank them.
        #expect(performers[0].points >= performers[1].points)
        #expect(performers[1].points >= performers[2].points)
    }

    @Test("The highlight carries a phrase the card can print as-is")
    func highlight() throws {
        let highlight = try #require(try Self.decoded().highlight)

        #expect(highlight.kind == WrapHighlight.Kind.leagueHigh)
        #expect(highlight.headline == "Top score in the league")
        #expect(highlight.caption == "Dynasty Dads")
        #expect(highlight.value == 148.62)
        #expect(highlight.valueIsPoints)
    }

    @Test("A result the database has not sent before does not take the card down")
    func unknownResult() throws {
        // A newer server, or a value nobody has thought of. The badge goes
        // missing; the card still loads on the day someone wanted to post it.
        let json = """
        {"league_id":"1","league_name":"Work League","team_name":"Bench Mob",
         "points":96.4,"opponent_name":"Priya FC","opponent_points":96.8,
         "result":"FORFEIT","margin":-0.4,"league_rank":9,"teams":10,
         "league_high":false}
        """
        let league = try PostgrestCoding.decoder.decode(
            WrapLeagueResult.self, from: Data(json.utf8)
        )

        #expect(league.result == nil)
        #expect(league.points == 96.4)
        #expect(league.opponentName == "Priya FC")
    }

    @Test("A bye decodes with no opponent and no result")
    func byeWeek() throws {
        let json = """
        {"league_id":"1","league_name":"Dynasty Dads","team_name":"Bench Mob",
         "points":124.66,"opponent_name":null,"opponent_points":null,
         "result":null,"margin":null,"league_rank":1,"teams":1,"league_high":false}
        """
        let league = try PostgrestCoding.decoder.decode(
            WrapLeagueResult.self, from: Data(json.utf8)
        )

        #expect(league.result == nil)
        #expect(league.opponentPoints == nil)
        #expect(league.scoreline == nil)
    }

    // MARK: - The null the function returns for an unplayed week

    @Test("A week that has not been played reads as no wrap, not as an error")
    func nullIsNotAnError() {
        // PostgREST hands back a literal `null` body. Decoding that as a wrap
        // throws, and a throw here would look exactly like a real failure.
        #expect(WrapService.nonNull(Data("null".utf8)) == nil)
        #expect(WrapService.nonNull(Data("  null\n".utf8)) == nil)
        #expect(WrapService.nonNull(Data("".utf8)) == nil)
        #expect(WrapService.nonNull(Data("{\"week\":5}".utf8)) != nil)
        #expect(WrapService.nonNull(Data("[]".utf8)) != nil)
    }
}

// MARK: - What the card reads off the payload

@MainActor
struct WeeklyWrapPresentationTests {

    @Test("Scores are always quoted to a tenth, the way fantasy quotes them")
    func pointsFormatting() {
        // "148" reads as a different sport.
        #expect(148.62.wrapPoints == "148.6")
        #expect(96.4.wrapPoints == "96.4")
        #expect(100.0.wrapPoints == "100.0")
        #expect(0.4.wrapPoints == "0.4")
    }

    @Test("The points label says how many leagues it is counting")
    func pointsLabel() {
        #expect(WeeklyWrap.sample.pointsLabel == "Points across 2 leagues")
        #expect(WeeklyWrap.sampleSingleLeague.pointsLabel == "Points")
    }

    @Test("One league names the opponent; several give the record instead")
    func resultLine() {
        #expect(WeeklyWrap.sampleSingleLeague.resultLine == "Lost to Priya FC")
        #expect(WeeklyWrap.sample.resultLine == "1–1 across 2 leagues")
    }

    @Test("A tie shows in the record, and only then")
    func recordText() {
        #expect(WeeklyWrap.sample.recordText == "1–1")
        #expect(WeeklyWrap.sampleWide.recordText == "2–0–1")
    }

    @Test("A performer with no position or team still has a subtitle to print")
    func performerSubtitle() {
        let bare = WrapPerformer(
            playerID: "1", name: "Unknown player", position: nil,
            team: nil, points: 12.0, leagueName: nil
        )
        #expect(bare.subtitle.isEmpty)

        let positionOnly = WrapPerformer(
            playerID: "1", name: "Someone", position: "TE",
            team: nil, points: 12.0, leagueName: nil
        )
        #expect(positionOnly.subtitle == "TE")
    }

    @Test("VoiceOver gets a sentence, because the card is a picture")
    func accessibilitySummary() {
        let summary = WrapCardScaled.summary(.sample)

        #expect(summary.contains("Week 5"))
        #expect(summary.contains("1–1"))
        #expect(summary.contains("Top score in the league"))
        #expect(summary.contains("Puka Nacua"))
    }
}

// MARK: - The export contract

@MainActor
struct WrapExportTests {

    @Test("Rendering at 3x lands exactly on the sizes Instagram stores")
    func exportDimensions() {
        // The whole reason the card is laid out at a fixed point size. Anything
        // else gets resampled on upload, and resampling is what makes light type
        // on a light background look muddy.
        let scale = WrapExporter.renderScale

        let story = WrapFormat.story.size
        #expect(story.width * scale == 1080)
        #expect(story.height * scale == 1920)

        let post = WrapFormat.post.size
        #expect(post.width * scale == 1080)
        #expect(post.height * scale == 1350)
    }

    @Test("Both formats are the aspect ratios they claim to be")
    func aspectRatios() {
        #expect(abs(WrapFormat.story.aspectRatio - 9.0 / 16.0) < 0.0001)
        #expect(abs(WrapFormat.post.aspectRatio - 4.0 / 5.0) < 0.0001)
    }

    @Test("A shared file is named after the week it is about")
    func filename() {
        let image = WrapImage(image: UIImage(), wrap: .sample, format: .story)

        #expect(image.filename == "Benchd-Week-5-2026.png")
        #expect(image.title == "Week 5 · Top score in the league")
    }

    @Test("Every layout renders at both formats, at full export size")
    func rendersEveryLayout() throws {
        // Cheap insurance against a layout that compiles and then produces
        // nothing — which is precisely what a card that is never looked at does.
        for style in WrapCardStyle.allCases {
            for format in WrapFormat.allCases {
                let image = try #require(
                    WrapExporter.render(.sample, style: style, format: format),
                    "\(style.label) at \(format.label) did not render"
                )
                #expect(image.size.width == format.size.width)
                #expect(image.size.height == format.size.height)
                #expect(image.scale == WrapExporter.renderScale)
            }
        }
    }

    @Test("A card holds up against long names and three leagues")
    func awkwardData() throws {
        let image = try #require(
            WrapExporter.render(.sampleWide, style: .cover, format: .post)
        )
        #expect(image.size.width == WrapFormat.post.size.width)
    }
}

// MARK: - The tab

@MainActor
struct WrapsViewModelTests {

    @Test("The newest week is the one on the showpiece")
    func defaultSelection() {
        let model = WrapsViewModel.preview(state: .ready(WeeklyWrap.sampleHistory))

        #expect(model.selected?.week == 5)
        #expect(model.history.count == WeeklyWrap.sampleHistory.count - 1)
        #expect(!model.history.contains { $0.id == model.selected?.id })
    }

    @Test("Choosing an earlier week moves it to the showpiece")
    func selectingAWeek() throws {
        let model = WrapsViewModel.preview(state: .ready(WeeklyWrap.sampleHistory))
        let earlier = try #require(WeeklyWrap.sampleHistory.last)

        model.selectedID = earlier.id

        #expect(model.selected?.id == earlier.id)
        #expect(model.history.first?.week == 5)
    }

    @Test("States are distinguishable, so the view can switch on them")
    func states() {
        #expect(WrapsViewModel.preview(state: .loading).selected == nil)
        #expect(WrapsViewModel.preview(state: .empty).wraps.isEmpty)
        #expect(WrapsViewModel.preview(state: .failed("x")).selected == nil)
        #expect(WrapsViewModel.State.loading != .empty)
    }

    @Test("The format the tab is showing is the format that gets exported")
    func formatFollowsTheToggle() {
        let model = WrapsViewModel.preview(state: .ready([.sample]), format: .post)
        #expect(model.format == .post)
        #expect(model.format.size == CGSize(width: 360, height: 450))
    }
}
