import Foundation
import Testing
@testable import Benchd

/// Decoding tests use payloads shaped the way PostgREST actually returns them:
/// snake_case keys, microsecond timestamps, `date` columns as bare days.
struct ModelDecodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try PostgrestCoding.decoder.decode(type, from: Data(json.utf8))
    }

    // MARK: - Timestamps

    /// Builds an expected instant from components rather than a magic epoch
    /// number, so a wrong constant in the test cannot masquerade as a bug.
    private func utc(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0
    ) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(secondsFromGMT: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        return try #require(calendar.date(from: components))
    }

    @Test("PostgREST microsecond timestamps decode, truncated to milliseconds")
    func microsecondTimestamps() throws {
        let date = try #require(PostgrestCoding.parseTimestamp("2026-09-21T12:00:00.123456+00:00"))
        let expected = try utc(2026, 9, 21, 12, 0, 0).addingTimeInterval(0.123)
        // Truncated, not rounded, and above all not rejected.
        #expect(abs(date.timeIntervalSince(expected)) < 0.001)
    }

    @Test("Millisecond, whole-second, and Z-suffixed timestamps all decode")
    func timestampVariants() {
        #expect(PostgrestCoding.parseTimestamp("2026-09-21T12:00:00.123+00:00") != nil)
        #expect(PostgrestCoding.parseTimestamp("2026-09-21T12:00:00+00:00") != nil)
        #expect(PostgrestCoding.parseTimestamp("2026-09-21T12:00:00Z") != nil)
        #expect(PostgrestCoding.parseTimestamp("not a date") == nil)
    }

    // MARK: - Rows

    @Test("Profile decodes")
    func profile() throws {
        let profile = try decode(Profile.self, """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "display_name": "Ansh Mehta",
          "avatar_url": null,
          "created_at": "2026-09-21T12:00:00.123456+00:00",
          "updated_at": "2026-09-21T12:00:00.123456+00:00"
        }
        """)
        #expect(profile.displayName == "Ansh Mehta")
        #expect(profile.avatarURL == nil)
    }

    @Test("SleeperAccount decodes and builds a CDN avatar URL")
    func sleeperAccount() throws {
        let account = try decode(SleeperAccount.self, """
        {
          "id": "aaaaaaaa-0000-0000-0000-000000000001",
          "profile_id": "11111111-1111-1111-1111-111111111111",
          "sleeper_user_id": "12345",
          "username": "anshm",
          "display_name": "Ansh",
          "avatar": "abc123",
          "last_synced_at": "2026-09-21T12:00:00+00:00",
          "sync_status": "synced",
          "sync_error": null,
          "created_at": "2026-09-21T12:00:00+00:00",
          "updated_at": "2026-09-21T12:00:00+00:00"
        }
        """)
        #expect(account.syncStatus == .synced)
        #expect(account.avatarURL?.absoluteString == "https://sleepercdn.com/avatars/abc123")
    }

    @Test("An unrecognised sync_status degrades instead of throwing")
    func unknownSyncStatus() throws {
        let status = try decode(SyncStatus.self, "\"some_future_state\"")
        #expect(status == .unknown)
    }

    @Test("League decodes typed scoring settings and mixed-type settings")
    func league() throws {
        let league = try decode(League.self, """
        {
          "league_id": "784462448236949504",
          "name": "Dynasty Warriors",
          "season": 2024,
          "total_rosters": 12,
          "scoring_settings": {"pass_td": 4.0, "rec": 0.5},
          "roster_positions": ["QB","RB","WR"],
          "previous_league_id": null,
          "status": "in_season",
          "avatar": null,
          "settings": {"playoff_teams": 6, "name": "custom"}
        }
        """)
        #expect(league.scoringSettings["rec"] == 0.5)
        #expect(league.settings["playoff_teams"]?.intValue == 6)
        #expect(league.settings["name"]?.stringValue == "custom")
    }

    @Test("Matchup decodes and computes bench points")
    func matchup() throws {
        let matchup = try decode(Matchup.self, """
        {
          "league_id": "L1",
          "week": 3,
          "roster_id": 1,
          "matchup_id": 2,
          "points": 142.3,
          "starters": ["4046","6794"],
          "players": ["4046","6794","1234"],
          "players_points": {"4046": 28.4, "6794": 11.2, "1234": 19.5},
          "custom_points": null
        }
        """)
        #expect(matchup.points == 142.3)
        // Only the non-starter counts.
        #expect(matchup.benchPoints == 19.5)
    }

    @Test("Player decodes a bare date column via CalendarDate")
    func player() throws {
        let player = try decode(Player.self, """
        {
          "player_id": "4046",
          "full_name": "A.J. Brown",
          "first_name": "A.J.",
          "last_name": "Brown",
          "position": "WR",
          "fantasy_positions": ["WR"],
          "team": "PHI",
          "status": "Active",
          "number": 11,
          "age": 28,
          "years_exp": 6,
          "injury_status": "Questionable",
          "injury_body_part": "Hamstring",
          "injury_notes": null,
          "injury_start_date": "2026-09-01",
          "search_name": "ajbrown"
        }
        """)
        #expect(player.isInjured)
        #expect(player.searchName == "ajbrown")
        #expect(player.injuryStartDate != nil)
    }

    @Test("A player with no injury reports as healthy")
    func healthyPlayer() throws {
        let player = try decode(Player.self, """
        {
          "player_id": "6794", "full_name": "Josh Allen", "first_name": "Josh",
          "last_name": "Allen", "position": "QB", "fantasy_positions": ["QB"],
          "team": "BUF", "status": "Active", "number": 17, "age": 29,
          "years_exp": 8, "injury_status": null, "injury_body_part": null,
          "injury_notes": null, "injury_start_date": null, "search_name": "joshallen"
        }
        """)
        #expect(!player.isInjured)
        #expect(player.injuryStartDate == nil)
    }

    @Test("DraftPick metadata decodes as all-strings")
    func draftPick() throws {
        let pick = try decode(DraftPick.self, """
        {
          "draft_id": "D1", "pick_no": 1, "round": 1, "draft_slot": 1,
          "player_id": "4046", "roster_id": 3, "picked_by": "12345",
          "is_keeper": false,
          "metadata": {"first_name": "A.J.", "position": "WR", "years_exp": "6"}
        }
        """)
        #expect(pick.metadata["position"] == "WR")
        #expect(pick.metadata["years_exp"] == "6")
    }

    @Test("CareerStats decodes its headline columns and derives a record")
    func careerStats() throws {
        let stats = try decode(CareerStats.self, """
        {
          "sleeper_account_id": "aaaaaaaa-0000-0000-0000-000000000001",
          "wins": 128, "losses": 74, "ties": 2, "championships": 3,
          "seasons": 6, "leagues_count": 2,
          "points_for": 18420.55, "points_against": 17100.25,
          "details": {"version": 1, "regular_season": {"wins": 128, "losses": 74}},
          "computed_at": "2026-09-21T12:00:00.654321+00:00"
        }
        """)
        #expect(stats.recordText == "128–74–2")
        #expect(stats.gamesPlayed == 204)
        #expect(stats.details.version == 1)
        #expect(stats.details.regularSeason.wins == 128)
        let winPct = try #require(stats.winPercentage)
        #expect(abs(winPct - (129.0 / 204.0)) < 0.0001)
    }

    @Test("A career with no games has no win percentage, not zero")
    func emptyCareer() throws {
        let stats = try decode(CareerStats.self, """
        {
          "sleeper_account_id": "aaaaaaaa-0000-0000-0000-000000000001",
          "wins": 0, "losses": 0, "ties": 0, "championships": 0,
          "seasons": 0, "leagues_count": 0,
          "points_for": 0, "points_against": 0, "details": {},
          "computed_at": "2026-09-21T12:00:00+00:00"
        }
        """)
        #expect(stats.winPercentage == nil)
        #expect(stats.recordText == "0–0")
    }

    @Test("NewsItem decodes")
    func newsItem() throws {
        let item = try decode(NewsItem.self, """
        {
          "id": "cccccccc-0000-0000-0000-000000000003",
          "title": "Brown limited in practice",
          "url": "https://example.com/1",
          "source": "Feed",
          "published_at": "2026-09-21T12:00:00+00:00",
          "summary": "Limited participant Wednesday.",
          "image_url": null
        }
        """)
        #expect(item.link?.host() == "example.com")
    }

    // MARK: - Search normalization
    //
    // These must agree with the Postgres generated column:
    // lower(regexp_replace(full_name, '[^a-zA-Z0-9]+', '', 'g'))

    @Test("Client-side search normalization matches the Postgres expression")
    func searchNormalization() {
        #expect(Player.normalizeForSearch("A.J. Brown") == "ajbrown")
        #expect(Player.normalizeForSearch("aj brown") == "ajbrown")
        #expect(Player.normalizeForSearch("Josh Allen") == "joshallen")
        #expect(Player.normalizeForSearch("Amon-Ra St. Brown") == "amonrastbrown")
        // Non-ASCII is stripped, exactly as [^a-zA-Z0-9] does.
        #expect(Player.normalizeForSearch("José") == "jos")
        #expect(Player.normalizeForSearch("CJ2K") == "cj2k")
    }

    // MARK: - JSONValue

    @Test("JSONValue round-trips every case")
    func jsonValueRoundTrip() throws {
        let json = """
        {"a": 1, "b": "two", "c": true, "d": null, "e": [1, 2], "f": {"g": 3}}
        """
        let value = try decode(JSONValue.self, json)
        #expect(value["a"]?.intValue == 1)
        #expect(value["b"]?.stringValue == "two")
        #expect(value["c"]?.boolValue == true)
        #expect(value["d"] == JSONValue.null)
        #expect(value["e"]?.arrayValue?.count == 2)
        #expect(value["f"]?["g"]?.intValue == 3)

        let reEncoded = try JSONEncoder().encode(value)
        let again = try JSONDecoder().decode(JSONValue.self, from: reEncoded)
        #expect(again == value)
    }

    @Test("CalendarDate decodes a bare day as midnight UTC")
    func calendarDate() throws {
        let day = try decode(CalendarDate.self, "\"2026-09-01\"")
        #expect(day.date == (try utc(2026, 9, 1)))
    }

    @Test("CalendarDate rejects input that is not a date at all")
    func calendarDateRejectsGarbage() {
        #expect(throws: (any Error).self) {
            try decode(CalendarDate.self, "\"not-a-date\"")
        }
        #expect(throws: (any Error).self) {
            try decode(CalendarDate.self, "12345")
        }
    }

    @Test("CalendarDate tolerates a full timestamp by taking the day")
    func calendarDateTolerance() throws {
        // ISO8601DateFormatter is lenient about trailing components. Worth
        // pinning: it means a `date` column that silently became a `timestamptz`
        // would keep decoding rather than crash the app.
        let day = try decode(CalendarDate.self, "\"2026-09-01T00:00:00+00:00\"")
        #expect(day.date == (try utc(2026, 9, 1)))
    }
}
