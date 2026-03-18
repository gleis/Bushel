import Foundation

/// Entry from `container network list --format json`
struct NetworkEntry: Codable, Identifiable, Sendable {
    let id: String
    let config: NetworkConfig
    let state: String
    let status: NetworkStatus
}

struct NetworkConfig: Codable, Sendable {
    let id: String
    let mode: String
    let labels: [String: String]
    let creationDate: TimeInterval

    var createdDate: Date {
        Date(timeIntervalSinceReferenceDate: creationDate)
    }
}

struct NetworkStatus: Codable, Sendable {
    let gateway: String
    let address: String
}
