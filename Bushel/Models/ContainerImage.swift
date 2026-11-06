import Foundation

/// Entry from `container image list --format json`
struct ImageListEntry: Codable, Identifiable, Sendable {
    let reference: String
    let descriptor: ImageDescriptor

    private enum CodingKeys: String, CodingKey { case reference, descriptor }
    private enum Envelope: String, CodingKey { case configuration }
    private enum CurrentKeys: String, CodingKey { case name, descriptor }
    init(from decoder: Decoder) throws {
        let envelope = try decoder.container(keyedBy: Envelope.self)
        if envelope.contains(.configuration) {
            let c = try envelope.nestedContainer(keyedBy: CurrentKeys.self, forKey: .configuration)
            reference = try c.decode(String.self, forKey: .name)
            descriptor = try c.decode(ImageDescriptor.self, forKey: .descriptor)
        } else {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            reference = try c.decode(String.self, forKey: .reference)
            descriptor = try c.decode(ImageDescriptor.self, forKey: .descriptor)
        }
    }

    var id: String { reference }

    var shortName: String {
        var name = reference
        if name.hasPrefix("docker.io/library/") {
            name = String(name.dropFirst("docker.io/library/".count))
        } else if name.hasPrefix("docker.io/") {
            name = String(name.dropFirst("docker.io/".count))
        } else if name.hasPrefix("ghcr.io/") {
            name = String(name.dropFirst("ghcr.io/".count))
        }
        return name
    }

    var shortDigest: String {
        let digest = descriptor.digest
        if let idx = digest.firstIndex(of: ":") {
            let start = digest.index(after: idx)
            let end = digest.index(start, offsetBy: min(12, digest.distance(from: start, to: digest.endIndex)))
            return String(digest[start..<end])
        }
        return String(digest.prefix(12))
    }

    var sizeFormatted: String {
        ByteFormatter.format(descriptor.size)
    }
}
