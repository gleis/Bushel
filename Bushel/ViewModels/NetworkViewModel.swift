import Foundation
import SwiftUI

@Observable
final class NetworkViewModel {
    var networks: [NetworkEntry] = []
    var selectedNetworkID: String?
    var isLoading = false
    var error: String?
    var showError = false
    var systemNotRunning = false

    private let service = NetworkService()

    func loadNetworks() async {
        isLoading = true
        do {
            networks = try await service.list()
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

    func createNetwork(name: String) async {
        do {
            try await service.create(name: name)
            await loadNetworks()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func deleteNetwork(_ name: String) async {
        do {
            try await service.delete(name)
            await loadNetworks()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
}
