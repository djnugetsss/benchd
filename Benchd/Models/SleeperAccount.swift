import Foundation

/// How far along a Sleeper account's data pull is.
///
/// Mirrors the `public.sync_status` Postgres enum. Decoding falls back to
/// `unknown` instead of throwing: if the backend ever gains a state that a
/// shipped build does not know about, the profile should degrade, not crash.
enum SyncStatus: String, Codable, Hashable, Sendable {
    case neverSynced = "never_synced"
    case syncing
    case synced
    case failed
    case unknown

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SyncStatus(rawValue: raw) ?? .unknown
    }
}

/// A Sleeper account connected to a profile.
struct SleeperAccount: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let profileID: UUID
    /// Sleeper's own user id, as a string.
    let sleeperUserID: String
    let username: String?
    let displayName: String?
    /// A Sleeper avatar **id**, not a URL — see `avatarURL`.
    let avatar: String?
    let lastSyncedAt: Date?
    let syncStatus: SyncStatus
    /// Present only when `syncStatus == .failed`.
    let syncError: String?
    let createdAt: Date
    let updatedAt: Date

    /// Sleeper serves avatars from a fixed CDN path rather than returning URLs.
    var avatarURL: URL? {
        guard let avatar, !avatar.isEmpty else { return nil }
        return URL(string: "https://sleepercdn.com/avatars/\(avatar)")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case profileID = "profile_id"
        case sleeperUserID = "sleeper_user_id"
        case username
        case displayName = "display_name"
        case avatar
        case lastSyncedAt = "last_synced_at"
        case syncStatus = "sync_status"
        case syncError = "sync_error"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
