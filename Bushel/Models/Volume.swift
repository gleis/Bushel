import Foundation

/// Entry from `container volume list --format json`
struct VolumeEntry: Codable, Identifiable, Sendable {
    let name: String
    let driver: String
    let sizeInBytes: Int64
    let format: String
    let createdAt: FlexibleDate
    let source: String
    let labels: [String: String]
    let options: [String: String]

    var id: String { name }

    var sizeFormatted: String {
        ByteFormatter.format(sizeInBytes)
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
