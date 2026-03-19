import SwiftUI

struct RunContainerView: View {
    @Environment(ContainerViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var image = ""
    @State private var name = ""
    @State private var memory = ""
    @State private var cpus = ""
    @State private var portsText = ""
    @State private var volumesText = ""
    @State private var envText = ""
    @State private var network = ""
    @State private var removeOnStop = false
    @State private var argumentsText = ""
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Run Container")
                .font(.headline)
                .padding()

            Form {
                Section("Image") {
                    TextField("Image reference (e.g. nginx:latest)", text: $image)
                }

                Section("Options") {
                    TextField("Container name (optional)", text: $name)
                    TextField("Memory (e.g. 512M, 2G)", text: $memory)
                    TextField("CPUs (e.g. 2)", text: $cpus)
                    TextField("Network (optional)", text: $network)
                    Toggle("Remove when stopped", isOn: $removeOnStop)
                }

                Section("Port Mappings (one per line, e.g. 8080:80/tcp)") {
                    TextEditor(text: $portsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 60)
                }

                Section("Volume Mounts (one per line, e.g. /host:/container)") {
                    TextEditor(text: $volumesText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 60)
                }

                Section("Environment Variables (one per line, e.g. KEY=value)") {
                    TextEditor(text: $envText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 60)
                }

                Section("Arguments (space-separated)") {
                    TextField("Optional arguments", text: $argumentsText)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Run") { runContainer() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(image.isEmpty || isRunning)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }

    private func runContainer() {
        isRunning = true
        let config = RunContainerConfig(
            image: image,
            name: name.isEmpty ? nil : name,
            memory: memory.isEmpty ? nil : memory,
            cpus: Int(cpus),
            ports: portsText.components(separatedBy: .newlines).filter { !$0.isEmpty },
            volumes: volumesText.components(separatedBy: .newlines).filter { !$0.isEmpty },
            environment: envText.components(separatedBy: .newlines).filter { !$0.isEmpty },
            networks: network.isEmpty ? [] : [network],
            removeOnStop: removeOnStop,
            arguments: argumentsText.isEmpty ? [] : argumentsText.components(separatedBy: " ")
        )
        Task {
            let success = await vm.runContainer(config: config)
            isRunning = false
            if success { dismiss() }
        }
    }
}
