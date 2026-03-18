import Foundation
import SwiftUI

@Observable
final class VolumeViewModel {
    var volumes: [VolumeEntry] = []
    var selectedVolumeName: String?
    var isLoading = false
    var error: String?
    var showError = false
    var systemNotRunning = false

    private let service = VolumeService()

    func loadVolumes() async {
        isLoading = true
        do {
            volumes = try await service.list()
            systemNotRunning = false
        } catch {
            if ShellError.isSystemNotRunningError(error) {
                systemNotRunning = true
            } else {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
        isLoading = false
    }

    func createVolume(name: String) async {
        do {
            try await service.create(name: name)
            await loadVolumes()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func deleteVolume(_ name: String) async {
        do {
            try await service.delete(name)
            await loadVolumes()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func pruneVolumes() async {
        do {
            try await service.prune()
            await loadVolumes()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
}
