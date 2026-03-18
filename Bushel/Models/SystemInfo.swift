import Foundation

/// Parsed from `container system status` plain text output
struct SystemStatus: Sendable {
    let isRunning: Bool
    let version: String
    let commit: String
    let dataRoot: String
    let installRoot: String
}

/// From `container system df --format json`
struct DiskUsage: Codable, Sendable {
    let containers: DiskUsageCategory
    let images: DiskUsageCategory
    let volumes: DiskUsageCategory
}

struct DiskUsageCategory: Codable, Sendable {
    let total: Int
    let active: Int
    let sizeInBytes: Int64
    let reclaimable: Int64

    var sizeFormatted: String {
        ByteFormatter.format(sizeInBytes)
    }

    var reclaimableFormatted: String {
        ByteFormatter.format(reclaimable)
    }
}

/// From `container stats --format json --no-stream`
struct ContainerStats: Codable, Identifiable, Sendable {
    let containerID: String?
    let name: String?
    let cpuPercentage: Double?
    let memoryUsage: Int64?
    let memoryLimit: Int64?
    let memoryPercentage: Double?
    let networkInput: Int64?
    let networkOutput: Int64?
    let blockInput: Int64?
    let blockOutput: Int64?
    let pids: Int?

    var id: String { containerID ?? name ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case containerID = "ContainerID"
        case name = "Name"
        case cpuPercentage = "CPUPerc"
        case memoryUsage = "MemUsage"
        case memoryLimit = "MemLimit"
        case memoryPercentage = "MemPerc"
        case networkInput = "NetIO_in"
        case networkOutput = "NetIO_out"
        case blockInput = "BlockIO_in"
        case blockOutput = "BlockIO_out"
        case pids = "PIDs"
    }
}
