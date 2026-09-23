import Foundation

/// A freeform JSON value, for `jsonb` columns whose shape is deliberately not
/// fixed: `sync_events.detail`, and the `settings` blobs Sleeper owns on
/// `leagues` and `drafts`.
///
/// Defined here rather than using the Supabase SDK's `AnyJSON` so that `Models/`
/// stays free of any dependency on the transport layer: these types must be
/// decodable from a fixture in a unit test with nothing but Foundation.
///
/// Most `jsonb` columns do *not* need this. Where the shape is known, the model
/// uses a concrete type instead — `[String: Double]` for scoring settings and
/// weekly player points, `[String: String]` for Sleeper's draft pick metadata.
enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Value is not valid JSON"
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

// MARK: - Convenience accessors

extension JSONValue {
    var stringValue: String? { if case .string(let v) = self { v } else { nil } }
    var doubleValue: Double? { if case .number(let v) = self { v } else { nil } }
    var intValue: Int? { if case .number(let v) = self { Int(v) } else { nil } }
    var boolValue: Bool? { if case .bool(let v) = self { v } else { nil } }
    var arrayValue: [JSONValue]? { if case .array(let v) = self { v } else { nil } }
    var objectValue: [String: JSONValue]? { if case .object(let v) = self { v } else { nil } }

    /// Reads a key from an object value. Returns `nil` for any other case.
    subscript(key: String) -> JSONValue? { objectValue?[key] }
}
