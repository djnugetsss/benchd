import Foundation
import Supabase

/// Reads and writes the caller's own profile row.
struct ProfileService: Sendable {
    private let client: SupabaseClient?

    init(client: SupabaseClient? = SupabaseClientProvider.shared) {
        self.client = client
    }

    private struct LastSeenUpdate: Encodable {
        let lastSeenAt: Date
        enum CodingKeys: String, CodingKey { case lastSeenAt = "last_seen_at" }
    }

    /// Records that the person opened the app.
    ///
    /// Deliberately silent on failure: this is housekeeping for the scheduler,
    /// and there is nothing useful to tell someone whose "last seen" stamp did
    /// not land. The cost of a miss is one skipped hourly refresh.
    func touchLastSeen(profileID: UUID) async {
        guard let client else { return }
        _ = try? await client
            .from("profiles")
            .update(LastSeenUpdate(lastSeenAt: Date()))
            .eq("id", value: profileID)
            .execute()
    }
}
