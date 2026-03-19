import Foundation
import SwiftUI

@Observable
final class ImageViewModel {
    var images: [ImageListEntry] = []
    var selectedImageRef: String?
    var isLoading = false
    var error: String?
    var showError = false
    var systemNotRunning = false
    var binaryNotFound = false

    // Pull progress
    var isPulling = false
    var pullOutput: [String] = []
    @ObservationIgnored private var pullCancelFn: (@Sendable () -> Void)?

    // Build progress
    var isBuilding = false
    var buildOutput: [String] = []
    @ObservationIgnored private var buildCancelFn: (@Sendable () -> Void)?

    private let service = ImageService()

    func loadImages() async {
        isLoading = true
        do {
            images = try await service.list()
            systemNotRunning = false
            binaryNotFound = false
        } catch {
            if ShellError.isBinaryNotFoundError(error) {
                binaryNotFound = true
            } else if ShellError.isSystemNotRunningError(error) {
                systemNotRunning = true
            } else {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
        isLoading = false
    }

    func deleteImage(_ reference: String) async {
        do {
            try await service.delete(reference)
            await loadImages()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func tagImage(source: String, target: String) async {
        do {
            try await service.tag(source: source, target: target)
            await loadImages()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func pruneImages(all: Bool = false) async {
        do {
            try await service.prune(all: all)
            await loadImages()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    // MARK: - Pull

    func pullImage(_ reference: String) {
        isPulling = true
        pullOutput = []
        let (stream, cancel) = service.pull(reference)
        pullCancelFn = cancel

        Task { @MainActor [weak self] in
            for await line in stream {
                self?.pullOutput.append(line)
            }
            self?.isPulling = false
            await self?.loadImages()
        }
    }

    func cancelPull() {
        pullCancelFn?()
        pullCancelFn = nil
        isPulling = false
    }

    // MARK: - Build

    func buildImage(tag: String, contextDir: String, dockerfile: String?) {
        isBuilding = true
        buildOutput = []
        let (stream, cancel) = service.build(tag: tag, contextDir: contextDir, dockerfile: dockerfile)
        buildCancelFn = cancel

        Task { @MainActor [weak self] in
            for await line in stream {
                self?.buildOutput.append(line)
            }
            self?.isBuilding = false
            await self?.loadImages()
        }
    }

    func cancelBuild() {
        buildCancelFn?()
        buildCancelFn = nil
        isBuilding = false
    }
}
