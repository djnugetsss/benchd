import Foundation

/// A player news or injury story.
///
/// v1 is read-only: no comments, no reactions. Those are v2, and there is no
/// table or model for them yet.
struct NewsItem: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let url: String
    let source: String?
    let publishedAt: Date?
    let summary: String?
    let imageURL: String?

    /// `url` is stored as text because it is a dedupe key in Postgres, not
    /// because it is guaranteed parseable. Callers that need to open it go
    /// through here and handle `nil`.
    var link: URL? { URL(string: url) }

    enum CodingKeys: String, CodingKey {
        case id, title, url, source
        case publishedAt = "published_at"
        case summary
        case imageURL = "image_url"
    }
}

/// Join row: one story can mention several players.
struct NewsItemPlayer: Codable, Hashable, Sendable, Identifiable {
    let newsItemID: UUID
    let playerID: String

    var id: String { "\(newsItemID.uuidString)-\(playerID)" }

    enum CodingKeys: String, CodingKey {
        case newsItemID = "news_item_id"
        case playerID = "player_id"
    }
}
