import Foundation

/// Encodes a `Codable` value to a pretty-printed JSON string.
func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? "{}"
}
