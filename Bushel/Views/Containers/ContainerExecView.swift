import SwiftUI

struct ContainerExecView: View {
    let containerID: String
    let isRunning: Bool
    @Environment(ContainerViewModel.self) private var vm
    @State private var command = ""

    var body: some View {
        VStack(spacing: 0) {
            // Output area
            ScrollViewReader { proxy in
                ScrollView {
                    Text(vm.execOutput.isEmpty ? "Execute commands inside the running container.\nOutput will appear here." : vm.execOutput)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(vm.execOutput.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("output")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: vm.execOutput) { _, _ in
                    proxy.scrollTo("output", anchor: .bottom)
                }
            }

            Divider()

            // Command input
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                TextField("Enter command...", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { sendCommand() }
                    .disabled(!isRunning || vm.isExecuting)

                Button("Run") { sendCommand() }
                    .disabled(!isRunning || command.isEmpty || vm.isExecuting)
                    .keyboardShortcut(.return, modifiers: [])

                if vm.isExecuting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Clear", systemImage: "trash") {
                    vm.clearExecOutput()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .overlay {
            if !isRunning {
                ContentUnavailableView(
                    "Container Not Running",
                    systemImage: "terminal",
                    description: Text("Start the container to execute commands")
                )
                .background(.regularMaterial)
            }
        }
    }

    private func sendCommand() {
        guard !command.isEmpty, isRunning else { return }
        let cmd = command
        command = ""
        Task { await vm.exec(containerID, command: cmd) }
    }
}
