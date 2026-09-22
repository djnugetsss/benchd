import Foundation

/// A user as returned by Sleeper's public API.
///
/// Distinct from `SleeperAccount`, which is our own database row. This is the
/// wire shape of `GET /v1/user/{username}` and nothing more.
struct SleeperUser: Codable, Hashable, Sendable, Identifiable {
    let userID: String
    let username: String?
    let displayName: String?
    /// A Sleeper avatar id, not a URL.
    let avatar: String?

    var id: String { userID }

    /// What to show a person when confirming "that's me".
    var bestName: String {
        displayName?.nilIfBlank ?? username?.nilIfBlank ?? userID
    }

    var avatarURL: URL? {
        guard let avatar, !avatar.isEmpty else { return nil }
        return URL(string: "https://sleepercdn.com/avatars/\(avatar)")
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case displayName = "display_name"
        case avatar
    }
}

extension String {
    /// `nil` when the string is empty or only whitespace.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
