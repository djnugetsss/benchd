import Foundation

/// A calendar day with no time component, for Postgres `date` columns.
///
/// Postgres returns `date` as a bare `"2024-09-01"`, which the ISO8601 strategies
/// used for `timestamptz` cannot parse — decoding such a column straight into
/// `Date` fails at runtime. Only `players.injury_start_date` is affected today,
/// but the failure mode is silent until an injured player appears, so it gets a
/// real type rather than a `String`.
///
/// Parsing is deliberately lenient: `ISO8601DateFormatter` accepts a full
/// timestamp and keeps the day. If the column ever changed type, the app would
/// keep working rather than start throwing.
struct CalendarDate: Codable, Hashable, Sendable {
    /// Midnight UTC on the day in question.
    let date: Date

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    init(date: Date) { self.date = date }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = Self.formatter.date(from: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a yyyy-MM-dd date, got \"\(raw)\""
            )
        }
        date = parsed
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.formatter.string(from: date))
    }
}
