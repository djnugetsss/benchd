import Foundation
import Testing
@testable import Benchd

struct CareerStatsDecodingTests {

    /// The exact row PostgREST returns for the real synced account, captured
    /// with `row_to_json` against the live database. Two fractional digits on
    /// the timestamp, and `numeric` as an unquoted JSON number.
    private static let liveRow = """
    {"sleeper_account_id":"a4acd87b-557e-4b81-92ac-19d5b9129822","wins":7,"losses":7,\
    "ties":0,"championships":0,"seasons":5,"leagues_count":6,"points_for":1953.28,\
    "points_against":1741.74,"details":{},"computed_at":"2026-09-22T23:26:50.33+00:00"}
    """

    @Test("The live career_stats row decodes")
    func decodesLiveRow() throws {
        let stats = try PostgrestCoding.decoder.decode(
            CareerStats.self, from: Data(Self.liveRow.utf8)
        )
        #expect(stats.wins == 7)
        #expect(stats.losses == 7)
        #expect(stats.seasons == 5)
        #expect(stats.leaguesCount == 6)
        #expect(stats.pointsFor == 1953.28)
        #expect(stats.recordText == "7–7")
    }

    @Test("Timestamps decode at every fractional-second width Postgres emits")
    func fractionalSecondWidths() {
        // Postgres trims trailing zeros, so the width varies row to row. A
        // parser that only handles three digits works until the first row whose
        // microseconds happen to end in a zero — and then the whole fetch
        // throws and the screen sits on skeletons with no error anywhere.
        let widths = [
            "2026-09-22T23:26:50+00:00",        // none
            "2026-09-22T23:26:50.3+00:00",      // one
            "2026-09-22T23:26:50.33+00:00",     // two  <- the live row
            "2026-09-22T23:26:50.336+00:00",    // three
            "2026-09-22T23:26:50.3361+00:00",   // four
            "2026-09-22T23:26:50.336123+00:00", // six
        ]
        for raw in widths {
            #expect(
                PostgrestCoding.parseTimestamp(raw) != nil,
                "failed to parse \(raw)"
            )
        }
    }

    @Test("A win rate of exactly .500 reads correctly")
    func evenRecord() throws {
        let stats = try PostgrestCoding.decoder.decode(
            CareerStats.self, from: Data(Self.liveRow.utf8)
        )
        let rate = try #require(stats.winPercentage)
        #expect(abs(rate - 0.5) < 0.0001)
    }
}

@MainActor
struct ProfileViewModelTests {

    @Test("A transient empty read does not wipe data already on screen")
    func emptyReadKeepsData() {
        // Guards the refresh path: a blip that returns no row must not knock a
        // populated profile back to the syncing placeholder.
        let model = ProfileViewModel.preview(state: .ready(.sample))
        #expect(model.stats != nil)
        #expect(model.state == .ready(.sample))
    }

    @Test("States are distinguishable, so the view can switch on them")
    func stateEquality() {
        #expect(ProfileViewModel.State.loading != .awaitingFirstSync)
        #expect(ProfileViewModel.State.ready(.sample) != .loading)
        #expect(ProfileViewModel.State.failed("a") != .failed("b"))
    }

    @Test("stats is nil in every non-ready state")
    func statsOnlyWhenReady() {
        #expect(ProfileViewModel.preview(state: .loading).stats == nil)
        #expect(ProfileViewModel.preview(state: .awaitingFirstSync).stats == nil)
        #expect(ProfileViewModel.preview(state: .failed("x")).stats == nil)
        #expect(ProfileViewModel.preview(state: .ready(.sample)).stats != nil)
    }
}
