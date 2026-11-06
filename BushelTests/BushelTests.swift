import Foundation
import Testing
@testable import Bushel

struct BushelTests {
    @Test func explicitBinaryOverrideWins() {
        #expect(resolveContainerBinaryPath(override: "/custom/container", searchPath: "/bin") { _ in false } == "/custom/container")
    }
    @Test func discoversPathAndHomebrew() {
        #expect(resolveContainerBinaryPath(override: "", searchPath: "/test:/bin") { $0 == "/test/container" } == "/test/container")
        #expect(resolveContainerBinaryPath(override: nil, searchPath: "") { $0 == "/opt/homebrew/bin/container" } == "/opt/homebrew/bin/container")
    }
    @Test func rejectsUnsupportedCLIVersions() {
        #expect(isSupportedContainerVersion("container CLI version 1.6.1 (build: release)"))
        #expect(isSupportedContainerVersion("container CLI version 1.2.0"))
        #expect(!isSupportedContainerVersion("container CLI version 0.10.0"))
        #expect(!isSupportedContainerVersion("container CLI version 2.0.0"))
    }
    @Test func currentResourceDecoding() throws {
        let image = try JSONDecoder().decode(ImageListEntry.self, from: Data(#"{"configuration":{"name":"docker.io/library/alpine:latest","descriptor":{"digest":"sha256:abcd","size":42,"mediaType":"test"}},"variants":[]}"#.utf8))
        #expect(image.shortName == "alpine:latest")
        let volume = try JSONDecoder().decode(VolumeEntry.self, from: Data(#"{"configuration":{"name":"data","driver":"local","format":"ext4","source":"/tmp/data","creationDate":123}}"#.utf8))
        #expect(volume.name == "data")
        #expect(volume.sizeInBytes == nil)
        let network = try JSONDecoder().decode(NetworkEntry.self, from: Data(#"{"id":"default","configuration":{"name":"default","mode":"nat","labels":{},"creationDate":123},"status":{"ipv4Gateway":"192.168.64.1","ipv4Subnet":"192.168.64.0/24"}}"#.utf8))
        #expect(network.config.id == "default")
        #expect(network.status.gateway == "192.168.64.1")
        let status = try SystemService.decodeStatus(Data(#"{"status":"running","server":{"version":"1.6.1","commit":"abc"},"paths":{"appRoot":"/data","installRoot":"/usr/local"}}"#.utf8))
        #expect(status.isRunning)
        #expect(status.version == "1.6.1")
        #expect(!(try SystemService.decodeStatus(Data(#"{"status":"unregistered"}"#.utf8))).isRunning)
    }
    @Test func legacyResourceDecoding() throws {
        let volume = try JSONDecoder().decode(VolumeEntry.self, from: Data(#"{"name":"legacy","driver":"local","format":"ext4","source":"/tmp/data","createdAt":123,"sizeInBytes":42,"labels":{},"options":{}}"#.utf8))
        #expect(volume.sizeInBytes == 42)
        let network = try JSONDecoder().decode(NetworkEntry.self, from: Data(#"{"id":"legacy","config":{"id":"legacy","mode":"nat","labels":{},"creationDate":123},"state":"running","status":{"gateway":"192.168.64.1","address":"192.168.64.0/24"}}"#.utf8))
        #expect(network.state == "running")
        #expect(network.config.id == "legacy")
    }
    @Test func containerNestedAndLegacyStatus() throws {
        let config: [String: Any] = ["id": "fixture", "image": ["reference": "alpine", "descriptor": ["digest": "sha256:abc", "size": 1, "mediaType": "test"]], "resources": ["cpus": 2, "memoryInBytes": 1024], "initProcess": ["executable": "/bin/sh", "arguments": [], "environment": [], "workingDirectory": "/", "terminal": false, "user": ["id": ["uid": 0, "gid": 0]], "supplementalGroups": [], "rlimits": []], "platform": ["os": "linux", "architecture": "arm64"]]
        let legacy = try JSONSerialization.data(withJSONObject: ["configuration": config, "networks": [], "status": "running"])
        let current = try JSONSerialization.data(withJSONObject: ["configuration": config, "status": ["state": "stopping", "networks": []]])
        #expect(try JSONDecoder().decode(ContainerEntry.self, from: legacy).status == .running)
        #expect(try JSONDecoder().decode(ContainerEntry.self, from: current).status == .stopping)
    }
    @Test func shellDrainsLargeOutputAndValidatesVersion() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let binary = directory.appendingPathComponent("container")
        let script = "#!/bin/sh\nif [ \"$1\" = --version ]; then echo 'container CLI version 1.6.1'; else /usr/bin/awk 'BEGIN { for(i=0;i<20000;i++) print \"fixture output line\" }'; fi\n"
        try script.write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        let shell = ShellService(binaryPath: binary.path)
        let output = try await shell.run(["list"])
        #expect(output.split(separator: "\n").count == 20000)
    }
}
