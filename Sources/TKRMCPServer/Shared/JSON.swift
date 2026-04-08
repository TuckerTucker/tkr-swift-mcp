import Foundation

/// Shared ISO 8601 date formatter — thread-safe, avoids repeated allocation.
/// `ISO8601DateFormatter` is immutable after init; `nonisolated(unsafe)` is safe here.
nonisolated(unsafe) let iso8601Formatter: ISO8601DateFormatter = {
    let fmt = ISO8601DateFormatter()
    return fmt
}()

/// Encodes a `Codable` value to a pretty-printed JSON string.
func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    guard let str = String(data: data, encoding: .utf8) else {
        throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "UTF-8 encoding failed"))
    }
    return str
}
