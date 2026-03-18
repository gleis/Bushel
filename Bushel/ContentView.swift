import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case images = "Images"
    case volumes = "Volumes"
    case networks = "Networks"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .containers: return "shippingbox"
        case .images: return "internaldrive"
        case .volumes: return "externaldrive"
        case .networks: return "network"
        case .system: return "gearshape.2"
        }
    }
}

struct ContentView: View {
    @State private var selectedSection: SidebarItem = .containers

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                Text("Bushel")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()

                VStack(spacing: 2) {
                    ForEach(SidebarItem.allCases) { item in
                        SidebarButton(
                            item: item,
                            isSelected: selectedSection == item
                        ) {
                            selectedSection = item
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()
            }
            .frame(width: 180)
            .background(.ultraThinMaterial)

            Divider()

            // Main content
            Group {
                switch selectedSection {
                case .containers:
                    ContainerSectionView { selectedSection = .system }
                case .images:
                    ImageSectionView { selectedSection = .system }
                case .volumes:
                    VolumeSectionView { selectedSection = .system }
                case .networks:
                    NetworkSectionView { selectedSection = .system }
                case .system:
                    NavigationStack {
                        SystemDashboardView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct SidebarButton: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(item.rawValue, systemImage: item.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
}

// MARK: - System Not Running

struct SystemNotRunningView: View {
    let goToSystem: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Container System Not Running", systemImage: "exclamationmark.triangle")
        } description: {
            Text("The container system needs to be started before you can manage resources.")
        } actions: {
            Button(action: goToSystem) {
                Text("Go to System Settings")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Container Section

struct ContainerSectionView: View {
    @Environment(ContainerViewModel.self) private var vm
    @State private var showRunSheet = false
    var goToSystem: () -> Void

    var body: some View {
        @Bindable var vm = vm

        if vm.systemNotRunning {
            SystemNotRunningView(goToSystem: goToSystem)
                .task { await vm.initialLoad() }
        } else {
            HStack(spacing: 0) {
                // List column
                VStack(spacing: 0) {
                    HStack {
                        Text("Containers")
                            .font(.headline)
                        Spacer()
                        Button(action: { showRunSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        Button(action: { Task { await vm.loadContainers() } }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    if vm.isLoading && vm.containers.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if vm.containers.isEmpty {
                        Spacer()
                        Text("No containers")
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        List(vm.containers, selection: $vm.selectedContainerID) { container in
                            ContainerRowView(container: container)
                                .contextMenu {
                                    if container.status == .running {
                                        Button("Open Shell", systemImage: "apple.terminal") {
                                            vm.selectedContainerID = container.id
                                            vm.toggleTerminal(container.id)
                                        }
                                        Divider()
                                        Button("Stop") { Task { await vm.stop(container.id) } }
                                        Button("Restart") { Task { await vm.restart(container.id) } }
                                    } else {
                                        Button("Start") { Task { await vm.start(container.id) } }
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) { Task { await vm.delete(container.id) } }
                                }
                        }
                        .listStyle(.inset)
                    }
                }
                .frame(width: 280)

                Divider()

                // Detail column
                NavigationStack {
                    if let container = vm.selectedContainer {
                        ContainerDetailView(container: container)
                    } else {
                        ContentUnavailableView(
                            "No Container Selected",
                            systemImage: "shippingbox",
                            description: Text("Select a container from the list")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .task { await vm.initialLoad() }
            .onAppear { vm.startPeriodicRefresh() }
            .onDisappear { vm.stopPeriodicRefresh() }
            .sheet(isPresented: $showRunSheet) {
                RunContainerView()
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK") { vm.showError = false }
            } message: {
                Text(vm.error ?? "Unknown error")
            }
        }
    }
}

// MARK: - Image Section

struct ImageSectionView: View {
    @Environment(ImageViewModel.self) private var vm
    @State private var showPullSheet = false
    @State private var showBuildSheet = false
    @State private var showDeleteConfirmation = false
    @State private var imageToDelete: String?
    @State private var showPruneConfirmation = false
    var goToSystem: () -> Void

    var body: some View {
        @Bindable var vm = vm

        if vm.systemNotRunning {
            SystemNotRunningView(goToSystem: goToSystem)
                .task { await vm.loadImages() }
        } else {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Images")
                            .font(.headline)
                        Spacer()
                        Button(action: { showPullSheet = true }) {
                            Image(systemName: "arrow.down.circle")
                        }
                        .buttonStyle(.borderless)
                        Button(action: { showBuildSheet = true }) {
                            Image(systemName: "hammer")
                        }
                        .buttonStyle(.borderless)
                        Menu {
                            Button("Prune Unused") { showPruneConfirmation = true }
                            Button("Refresh") { Task { await vm.loadImages() } }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    if vm.isLoading && vm.images.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if vm.images.isEmpty {
                        Spacer()
                        Text("No images")
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        List(vm.images, selection: $vm.selectedImageRef) { image in
                            ImageRowView(image: image)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        imageToDelete = image.reference
                                        showDeleteConfirmation = true
                                    }
                                }
                        }
                        .listStyle(.inset)
                    }
                }
                .frame(width: 280)

                Divider()

                NavigationStack {
                    if let ref = vm.selectedImageRef, let image = vm.images.first(where: { $0.reference == ref }) {
                        ImageDetailView(image: image)
                    } else {
                        ContentUnavailableView(
                            "No Image Selected",
                            systemImage: "opticaldisc",
                            description: Text("Select an image from the list")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .task { await vm.loadImages() }
            .sheet(isPresented: $showPullSheet) { PullImageView() }
            .sheet(isPresented: $showBuildSheet) { BuildImageView() }
            .confirmationDialog("Delete Image", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let ref = imageToDelete {
                        Task { await vm.deleteImage(ref) }
                    }
                }
            } message: {
                Text("Delete '\(imageToDelete ?? "")'?")
            }
            .confirmationDialog("Prune Images", isPresented: $showPruneConfirmation) {
                Button("Prune Dangling") {
                    Task { await vm.pruneImages() }
                }
                Button("Prune All Unused", role: .destructive) {
                    Task { await vm.pruneImages(all: true) }
                }
            } message: {
                Text("Remove unused images?")
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK") {}
            } message: {
                Text(vm.error ?? "Unknown error")
            }
        }
    }
}

// MARK: - Volume Section

struct VolumeSectionView: View {
    @Environment(VolumeViewModel.self) private var vm
    @State private var showCreateSheet = false
    @State private var showDeleteConfirmation = false
    @State private var volumeToDelete: String?
    @State private var showPruneConfirmation = false
    var goToSystem: () -> Void

    var body: some View {
        @Bindable var vm = vm

        if vm.systemNotRunning {
            SystemNotRunningView(goToSystem: goToSystem)
                .task { await vm.loadVolumes() }
        } else {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Volumes")
                            .font(.headline)
                        Spacer()
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        Menu {
                            Button("Prune Unused") { showPruneConfirmation = true }
                            Button("Refresh") { Task { await vm.loadVolumes() } }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    if vm.isLoading && vm.volumes.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if vm.volumes.isEmpty {
                        Spacer()
                        Text("No volumes")
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        List(vm.volumes, selection: $vm.selectedVolumeName) { volume in
                            VolumeRowView(volume: volume)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        volumeToDelete = volume.name
                                        showDeleteConfirmation = true
                                    }
                                }
                        }
                        .listStyle(.inset)
                    }
                }
                .frame(width: 280)

                Divider()

                NavigationStack {
                    if let name = vm.selectedVolumeName, let volume = vm.volumes.first(where: { $0.name == name }) {
                        VolumeDetailView(volume: volume)
                    } else {
                        ContentUnavailableView(
                            "No Volume Selected",
                            systemImage: "externaldrive",
                            description: Text("Select a volume from the list")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .task { await vm.loadVolumes() }
            .sheet(isPresented: $showCreateSheet) { CreateVolumeView() }
            .confirmationDialog("Delete Volume", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let name = volumeToDelete {
                        Task { await vm.deleteVolume(name) }
                    }
                }
            } message: {
                Text("Delete volume '\(volumeToDelete ?? "")'?")
            }
            .confirmationDialog("Prune Volumes", isPresented: $showPruneConfirmation) {
                Button("Prune", role: .destructive) {
                    Task { await vm.pruneVolumes() }
                }
            } message: {
                Text("Remove all volumes not referenced by a container?")
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK") {}
            } message: {
                Text(vm.error ?? "Unknown error")
            }
        }
    }
}

// MARK: - Network Section

struct NetworkSectionView: View {
    @Environment(NetworkViewModel.self) private var vm
    @State private var showCreateSheet = false
    @State private var showDeleteConfirmation = false
    @State private var networkToDelete: String?
    var goToSystem: () -> Void

    var body: some View {
        @Bindable var vm = vm

        if vm.systemNotRunning {
            SystemNotRunningView(goToSystem: goToSystem)
                .task { await vm.loadNetworks() }
        } else {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Networks")
                            .font(.headline)
                        Spacer()
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        Button(action: { Task { await vm.loadNetworks() } }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    if vm.isLoading && vm.networks.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if vm.networks.isEmpty {
                        Spacer()
                        Text("No networks")
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        List(vm.networks, selection: $vm.selectedNetworkID) { network in
                            NetworkRowView(network: network)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        networkToDelete = network.id
                                        showDeleteConfirmation = true
                                    }
                                }
                        }
                        .listStyle(.inset)
                    }
                }
                .frame(width: 280)

                Divider()

                NavigationStack {
                    if let id = vm.selectedNetworkID, let network = vm.networks.first(where: { $0.id == id }) {
                        NetworkDetailView(network: network)
                    } else {
                        ContentUnavailableView(
                            "No Network Selected",
                            systemImage: "network",
                            description: Text("Select a network from the list")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .task { await vm.loadNetworks() }
            .sheet(isPresented: $showCreateSheet) { CreateNetworkView() }
            .confirmationDialog("Delete Network", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let name = networkToDelete {
                        Task { await vm.deleteNetwork(name) }
                    }
                }
            } message: {
                Text("Delete network '\(networkToDelete ?? "")'?")
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK") {}
            } message: {
                Text(vm.error ?? "Unknown error")
            }
        }
    }
}
