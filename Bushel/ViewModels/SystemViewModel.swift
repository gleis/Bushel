import Foundation
import SwiftUI

@Observable
final class SystemViewModel {
    var status: SystemStatus?
    var diskUsage: DiskUsage?
    var isLoading = false
    var error: String?
    var showError = false

    private let service = SystemService()

    func loadAll() async {
        isLoading = true
        await loadStatus()
        await loadDiskUsage()
        isLoading = false
    }

    func loadStatus() async {
        do {
            status = try await service.status()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func loadDiskUsage() async {
        do {
            diskUsage = try await service.diskUsage()
        } catch {
            // Disk usage may fail if system isn't running; non-critical
        }
    }

    func startSystem() async {
        isLoading = true
        do {
            try await service.start()
            await loadAll()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
        isLoading = false
    }

    func stopSystem() async {
        isLoading = true
        do {
            try await service.stop()
            await loadStatus()
            diskUsage = nil
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
        isLoading = false
    }
}
