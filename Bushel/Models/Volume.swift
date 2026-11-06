import Foundation

/// Entry from `container volume list --format json`
struct VolumeEntry: Codable, Identifiable, Sendable {
    let name: String
    let driver: String
    let sizeInBytes: Int64?
    let format: String
    let createdAt: FlexibleDate
    let source: String
    let labels: [String: String]
    let options: [String: String]

    private enum Envelope: String, CodingKey { case configuration }
    private enum DateKeys: String, CodingKey { case creationDate }
    private enum CodingKeys: String, CodingKey { case name, driver, sizeInBytes, format, createdAt, source, labels, options }
    init(from decoder: Decoder) throws {
        let envelope = try decoder.container(keyedBy: Envelope.self)
        let sourceDecoder = envelope.contains(.configuration) ? try envelope.superDecoder(forKey: .configuration) : decoder
        let c = try sourceDecoder.container(keyedBy: CodingKeys.self)
        let dates = try sourceDecoder.container(keyedBy: DateKeys.self)
        name = try c.decode(String.self, forKey: .name)
        driver = try c.decode(String.self, forKey: .driver)
        format = try c.decode(String.self, forKey: .format)
        source = try c.decode(String.self, forKey: .source)
        sizeInBytes = try c.decodeIfPresent(Int64.self, forKey: .sizeInBytes)
        labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        options = try c.decodeIfPresent([String: String].self, forKey: .options) ?? [:]
        createdAt = try dates.decodeIfPresent(FlexibleDate.self, forKey: .creationDate)
            ?? c.decodeIfPresent(FlexibleDate.self, forKey: .createdAt) ?? .timeInterval(0)
    }

    var id: String { name }

    var sizeFormatted: String {
        sizeInBytes.map { ByteFormatter.format($0) } ?? "Unknown"
    }
}

/// Handles createdAt as either TimeInterval (from list) or ISO8601 string (from inspect)
enum FlexibleDate: Codable, Sendable {
    case timeInterval(TimeInterval)
    case iso8601(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let interval = try? container.decode(TimeInterval.self) {
            self = .timeInterval(interval)
        } else if let string = try? container.decode(String.self) {
            self = .iso8601(string)
        } else {
            self = .timeInterval(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .timeInterval(let t): try container.encode(t)
        case .iso8601(let s): try container.encode(s)
        }
    }

    var date: Date {
        switch self {
        case .timeInterval(let t):
            return Date(timeIntervalSinceReferenceDate: t)
        case .iso8601(let s):
            return ISO8601DateFormatter().date(from: s) ?? Date.distantPast
        }
    }

    var formatted: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
