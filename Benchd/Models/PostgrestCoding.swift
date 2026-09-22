import Foundation

/// The JSON coders used for every Supabase row in this app.
///
/// These are supplied explicitly to `SupabaseClient` rather than relying on the
/// SDK's defaults, because PostgREST's timestamp format is not something to leave
/// to chance: `timestamptz` comes back with **microsecond** precision
/// (`2026-09-21T12:00:00.123456+00:00`), and `ISO8601DateFormatter` with
/// `.withFractionalSeconds` only handles milliseconds. A naive decoder works
/// against every row whose microseconds happen to be zero and then fails in
/// production.
///
/// Models declare plain `Date`, so this is the single place that has to be right.
/// Declared `nonisolated` so it can be reached from `SupabaseClientProvider`,
/// which is itself nonisolated. Under this project's
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, a plain enum would otherwise be
/// MainActor-isolated and unusable from there.
nonisolated enum PostgrestCoding {

    /// Computed rather than a stored `static let`: `JSONDecoder` is not
    /// `Sendable`, so a shared instance in a nonisolated type is not expressible
    /// without an unsafe opt-out. Decoders are cheap and this is built once per
    /// client, so there is nothing to gain by caching one.
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = parseTimestamp(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognised PostgREST timestamp: \"\(raw)\""
                )
            }
            return date
        }
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractional.string(from: date))
        }
        return encoder
    }

    // MARK: - Parsing

    // `ISO8601DateFormatter` has been documented as thread-safe since iOS 7 but
    // is still not marked `Sendable`. These are immutable after construction and
    // only ever read, so the opt-out is sound — and unlike the coders above,
    // these are hit once per timestamp, so caching them actually matters.
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Accepts what PostgREST actually emits, in rough order of likelihood.
    static func parseTimestamp(_ raw: String) -> Date? {
        // Postgres emits up to 6 fractional digits; ISO8601DateFormatter accepts
        // at most 3. Truncate rather than reject — sub-millisecond precision is
        // meaningless for anything this app displays.
        if let truncated = truncatingFractionalSeconds(raw),
           let date = fractional.date(from: truncated) {
            return date
        }
        if let date = fractional.date(from: raw) { return date }
        if let date = plain.date(from: raw) { return date }
        return nil
    }

    /// `...T12:00:00.123456+00:00` -> `...T12:00:00.123+00:00`.
    /// Returns `nil` when there is no fractional part to trim.
    private static func truncatingFractionalSeconds(_ raw: String) -> String? {
        guard let dot = raw.firstIndex(of: ".") else { return nil }
        let afterDot = raw.index(after: dot)
        guard let endOfDigits = raw[afterDot...].firstIndex(where: { !$0.isNumber })
        else { return nil }

        let digits = raw[afterDot..<endOfDigits]
        guard digits.count > 3 else { return nil }

        let keep = raw.index(afterDot, offsetBy: 3)
        return String(raw[..<keep]) + String(raw[endOfDigits...])
    }
}
