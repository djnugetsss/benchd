import Foundation
import Supabase

/// Single shared entry point to Supabase.
///
/// Services take the client from here rather than constructing their own, so there
/// is exactly one auth session in the process. Views never touch this — they go
/// through a view model, which goes through a service.
nonisolated enum SupabaseClientProvider {

    /// Throws `AppConfig.ConfigError` when `Secrets.xcconfig` hasn't been filled in.
    static func makeClient() throws -> SupabaseClient {
        SupabaseClient(
            supabaseURL: try AppConfig.supabaseURL,
            supabaseKey: try AppConfig.supabaseAnonKey
        )
    }

    /// The process-wide client, created on first use.
    ///
    /// `nil` when the app hasn't been configured yet, so a fresh clone still runs
    /// and shows the setup hint instead of trapping at launch.
    static let shared: SupabaseClient? = try? makeClient()
}
