import SwiftUI

struct SettingsView: View {
    @AppStorage("containerBinaryPath") private var binaryPath = "/usr/local/bin/container"

    var body: some View {
        Form {
            Section("Container CLI") {
                HStack {
                    TextField("Binary path", text: $binaryPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button("Browse…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = false
                        panel.treatsFilePackagesAsDirectories = true
                        panel.directoryURL = URL(fileURLWithPath: binaryPath).deletingLastPathComponent()
                        if panel.runModal() == .OK, let url = panel.url {
                            binaryPath = url.path
                        }
                    }
                }

                let exists = FileManager.default.isExecutableFile(atPath: binaryPath)
                if !exists {
                    Label("Binary not found at this path", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button("Reset to Default") {
                    binaryPath = "/usr/local/bin/container"
                }
                .controlSize(.small)

                Text("Path to the Apple container CLI binary. Default: /usr/local/bin/container")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}
