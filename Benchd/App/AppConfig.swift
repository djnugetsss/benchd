import Foundation

/// Build-time configuration, read from the app's Info.plist.
///
/// The values arrive via `Secrets.xcconfig` (gitignored) → `Config/Shared.xcconfig`
/// → `Benchd/Resources/Info.plist`. Nothing here is ever hardcoded in Swift.
///
/// See `Secrets.example.xcconfig` for the setup steps, including why the Supabase
/// URL has to be written as `https:/$()/…` in an xcconfig file.
nonisolated enum AppConfig {

    enum ConfigError: Error, CustomStringConvertible {
        case missing(key: String)
        case malformedURL(key: String, value: String)

        var description: String {
            switch self {
            case .missing(let key):
                """
                Missing Info.plist value for "\(key)". Copy Secrets.example.xcconfig \
                to Secrets.xcconfig and fill in your Supabase project values, then \
                re-run `xcodegen generate`.
                """
            case .malformedURL(let key, let value):
                """
                Info.plist value for "\(key)" is not a valid URL: "\(value)". In an \
                .xcconfig file "//" starts a comment — write the URL as \
                https:/$()/your-ref.supabase.co so the slashes survive.
                """
            }
        }
    }

    static var supabaseURL: URL {
        get throws {
            let raw = try string(for: "SUPABASE_URL")
            guard let url = URL(string: raw), url.scheme != nil, url.host() != nil else {
                throw ConfigError.malformedURL(key: "SUPABASE_URL", value: raw)
            }
            return url
        }
    }

    static var supabaseAnonKey: String {
        get throws { try string(for: "SUPABASE_ANON_KEY") }
    }

    /// `true` once both Supabase values are present and well-formed. The app uses
    /// this to show a setup hint instead of crashing on a fresh clone.
    static var isConfigured: Bool {
        do {
            _ = try supabaseURL
            _ = try supabaseAnonKey
            return true
        } catch {
            return false
        }
    }

    private static func string(for key: String) throws -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // A placeholder from Secrets.example.xcconfig counts as not configured.
        guard !trimmed.isEmpty, !trimmed.contains("YOUR_") else {
            throw ConfigError.missing(key: key)
        }
        return trimmed
    }
}
