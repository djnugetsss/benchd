import Foundation

/// One reveal in a sync's progress feed.
///
/// The message is composed server-side, in the app's voice, so a new reveal
/// ships with an edge function deploy rather than an App Store release.
struct SyncEvent: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let sleeperAccountID: UUID
    let createdAt: Date
    let kind: String
    let message: String
    let detail: JSONValue

    /// 0…1 when the event carries one.
    var progress: Double? {
        detail["progress"]?.doubleValue
    }

    var isTerminal: Bool { kind == "completed" || kind == "failed" }
    var isFailure: Bool { kind == "failed" }

    enum CodingKeys: String, CodingKey {
        case id
        case sleeperAccountID = "sleeper_account_id"
        case createdAt = "created_at"
        case kind, message, detail
    }
}
