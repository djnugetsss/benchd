import Foundation

/// A Benchd user. One row per `auth.users` row, created automatically by the
/// `on_auth_user_created` trigger.
///
/// Private to its owner: RLS exposes only the row whose `id` matches the caller.
struct Profile: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let displayName: String?
    let avatarURL: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
