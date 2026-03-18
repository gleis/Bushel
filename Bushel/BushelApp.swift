import SwiftUI

@main
struct BushelApp: App {
    @State private var containerVM = ContainerViewModel()
    @State private var imageVM = ImageViewModel()
    @State private var volumeVM = VolumeViewModel()
    @State private var networkVM = NetworkViewModel()
    @State private var systemVM = SystemViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(containerVM)
                .environment(imageVM)
                .environment(volumeVM)
                .environment(networkVM)
                .environment(systemVM)
        }
        .defaultSize(width: 1100, height: 700)
    }
}
