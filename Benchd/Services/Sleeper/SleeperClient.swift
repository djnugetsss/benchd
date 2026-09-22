import Foundation

/// What can go wrong looking a person up on Sleeper.
///
/// Deliberately small and user-facing: every case maps to a message the
/// onboarding screen can show without leaking a raw `URLError` at anyone.
enum SleeperError: Error, Equatable, Sendable {
    /// Empty or obviously malformed input — caught before a request is sent.
    case invalidUsername
    /// Sleeper has no such user.
    case userNotFound
    /// Offline, timed out, DNS failure.
    case network
    /// Sleeper is up but answered with something unusable.
    case unexpectedResponse
    /// Sleeper is rate limiting or having an outage.
    case serviceUnavailable
}

/// Looking up a Sleeper user. A protocol so onboarding can be tested without
/// touching the network.
protocol SleeperUserLookup: Sendable {
    func user(username: String) async throws -> SleeperUser
}

/// Read-only client for Sleeper's public API. No auth, no OAuth — Sleeper does
/// not offer either, which is why onboarding asks for a username and then makes
/// the person confirm the result.
struct SleeperClient: SleeperUserLookup {
    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.sleeper.app/v1")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func user(username: String) async throws -> SleeperUser {
        guard let cleaned = Self.sanitize(username) else {
            throw SleeperError.invalidUsername
        }

        // Percent-encode: usernames are user input and can contain characters
        // that would otherwise break the path.
        guard
            let escaped = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "\(baseURL.absoluteString)/user/\(escaped)")
        else {
            throw SleeperError.invalidUsername
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw SleeperError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw SleeperError.unexpectedResponse
        }

        switch http.statusCode {
        case 200:
            break
        case 404:
            throw SleeperError.userNotFound
        case 429, 500...599:
            throw SleeperError.serviceUnavailable
        default:
            throw SleeperError.unexpectedResponse
        }

        // Sleeper's quirk: an unknown username comes back as HTTP 200 with a
        // body of literally `null`, not a 404. Decoding that into SleeperUser
        // would throw a confusing "expected Dictionary" error, so it is checked
        // explicitly and mapped to the same case as a real 404.
        if Self.isJSONNull(data) {
            throw SleeperError.userNotFound
        }

        do {
            return try JSONDecoder().decode(SleeperUser.self, from: data)
        } catch {
            throw SleeperError.unexpectedResponse
        }
    }

    /// Trims, drops a leading `@` people habitually type, and rejects blanks.
    static func sanitize(_ username: String) -> String? {
        var trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasPrefix("@") { trimmed.removeFirst() }
        trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func isJSONNull(_ data: Data) -> Bool {
        let trimmed = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "null" || trimmed.isEmpty
    }
}
