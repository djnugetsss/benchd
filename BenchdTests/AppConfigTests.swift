import Testing
@testable import Benchd

/// Sanity checks on the config plumbing. These pass whether or not the developer
/// has filled in Secrets.xcconfig — they assert the *behaviour*, not the values.
struct AppConfigTests {

    @Test("isConfigured never traps, regardless of Secrets.xcconfig state")
    func isConfiguredIsSafe() {
        _ = AppConfig.isConfigured
    }

    @Test("A missing value throws rather than returning a placeholder")
    func missingValueThrows() throws {
        if AppConfig.isConfigured {
            let url = try AppConfig.supabaseURL
            #expect(url.scheme == "https")
            #expect(url.host() != nil, "The https:/$()/ escape in Secrets.xcconfig is wrong")
            #expect(try !AppConfig.supabaseAnonKey.isEmpty)
        } else {
            #expect(throws: AppConfig.ConfigError.self) { _ = try AppConfig.supabaseURL }
        }
    }
}
