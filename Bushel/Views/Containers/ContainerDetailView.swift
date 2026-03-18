import SwiftUI

struct ContainerDetailView: View {
    let container: ContainerEntry
    @Environment(ContainerViewModel.self) private var vm
    @State private var selectedTab = "info"
    @State private var showDeleteConfirmation = false
    @State private var terminalHeight: CGFloat = 250
    @State private var dragOffset: CGFloat = 0

    private let minTerminalHeight: CGFloat = 120
    private let maxTerminalHeight: CGFloat = 600

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                ContainerInfoTab(container: container)
                    .tabItem { Label("Info", systemImage: "info.circle") }
                    .tag("info")

                ContainerLogsView(containerID: container.id, isRunning: container.status == .running)
                    .tabItem { Label("Logs", systemImage: "doc.text") }
                    .tag("logs")

                ContainerExecView(containerID: container.id, isRunning: container.status == .running)
                    .tabItem { Label("Exec", systemImage: "terminal") }
                    .tag("exec")
            }
            .frame(maxHeight: .infinity)

            // Terminal panel
            if vm.isTerminalOpen, let session = vm.terminalSession {
                // Drag handle
                TerminalDragHandle(dragOffset: $dragOffset) { finalOffset in
                    terminalHeight = max(minTerminalHeight, min(maxTerminalHeight, terminalHeight - finalOffset))
                    dragOffset = 0
                }

                TerminalView(session: session) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.closeTerminal()
                    }
                }
                .frame(height: max(minTerminalHeight, min(maxTerminalHeight, terminalHeight - dragOffset)))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isTerminalOpen)
        .navigationTitle(container.configuration.id)
        .toolbar {
            ToolbarItemGroup {
                if container.status == .stopped {
                    Button("Start", systemImage: "play.fill") {
                        Task { await vm.start(container.id) }
                    }
                } else {
                    Button("Shell", systemImage: "apple.terminal") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.toggleTerminal(container.id)
                        }
                    }
                    .help("Toggle interactive shell")

                    Button("Stop", systemImage: "stop.fill") {
                        Task { await vm.stop(container.id) }
                    }
                    Button("Restart", systemImage: "arrow.clockwise") {
                        Task { await vm.restart(container.id) }
                    }
                }

                Button("Delete", systemImage: "trash") {
                    showDeleteConfirmation = true
                }
            }
        }
        .confirmationDialog("Delete Container", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await vm.delete(container.id) }
            }
        } message: {
            Text("Are you sure you want to delete '\(container.configuration.id)'? This action cannot be undone.")
        }
        .onDisappear {
            vm.closeTerminal()
        }
    }
}

// MARK: - Info Tab

struct ContainerInfoTab: View {
    let container: ContainerEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // General Info
                GroupBox("General") {
                    InfoGrid {
                        InfoRow(label: "ID", value: container.configuration.id)
                        InfoRow(label: "Status", value: container.status.rawValue.capitalized)
                        InfoRow(label: "Image", value: container.configuration.image.reference)
                        InfoRow(label: "Platform", value: "\(container.configuration.platform.os)/\(container.configuration.platform.architecture)")
                        InfoRow(label: "Runtime", value: container.configuration.runtimeHandler)
                    }
                }

                // Resources
                GroupBox("Resources") {
                    InfoGrid {
                        InfoRow(label: "CPUs", value: "\(container.configuration.resources.cpus)")
                        InfoRow(label: "Memory", value: container.configuration.resources.memoryFormatted)
                    }
                }

                // Process
                GroupBox("Process") {
                    InfoGrid {
                        InfoRow(label: "Executable", value: container.configuration.initProcess.executable)
                        if !container.configuration.initProcess.arguments.isEmpty {
                            InfoRow(label: "Arguments", value: container.configuration.initProcess.arguments.joined(separator: " "))
                        }
                        InfoRow(label: "Working Dir", value: container.configuration.initProcess.workingDirectory)
                        InfoRow(label: "User", value: container.configuration.initProcess.user.displayString)
                    }
                }

                // Ports
                if !container.configuration.publishedPorts.isEmpty {
                    GroupBox("Published Ports") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(container.configuration.publishedPorts) { port in
                                Text(port.displayString)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Mounts
                if !container.configuration.mounts.isEmpty {
                    GroupBox("Mounts") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(container.configuration.mounts) { mount in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mount.type.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(mount.source) → \(mount.destination)")
                                        .font(.system(.body, design: .monospaced))
                                        .lineLimit(2)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Environment
                if !container.configuration.initProcess.environment.isEmpty {
                    GroupBox("Environment") {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(container.configuration.initProcess.environment, id: \.self) { env in
                                Text(env)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Networks
                if !container.configuration.networks.isEmpty {
                    GroupBox("Networks") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(container.configuration.networks, id: \.network) { net in
                                HStack {
                                    Text(net.network)
                                        .font(.body)
                                    if let hostname = net.options.hostname {
                                        Text("(\(hostname))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // DNS
                GroupBox("DNS") {
                    InfoGrid {
                        if let domain = container.configuration.dns.domain {
                            InfoRow(label: "Domain", value: domain)
                        }
                        if !container.configuration.dns.nameservers.isEmpty {
                            InfoRow(label: "Nameservers", value: container.configuration.dns.nameservers.joined(separator: ", "))
                        }
                    }
                }

                // Flags
                GroupBox("Flags") {
                    InfoGrid {
                        InfoRow(label: "Rosetta", value: container.configuration.rosetta ? "Enabled" : "Disabled")
                        InfoRow(label: "SSH", value: container.configuration.ssh ? "Enabled" : "Disabled")
                        InfoRow(label: "Virtualization", value: container.configuration.virtualization ? "Enabled" : "Disabled")
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Helper Views

struct InfoGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}

// MARK: - Terminal Drag Handle

struct TerminalDragHandle: View {
    @Binding var dragOffset: CGFloat
    var onDragEnd: (CGFloat) -> Void

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .overlay {
                // Wider hit target with pill indicator
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 36, height: 4)
            }
            .frame(height: 8)
            .contentShape(Rectangle())
            .cursor(.resizeUpDown)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        onDragEnd(value.translation.height)
                    }
            )
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
