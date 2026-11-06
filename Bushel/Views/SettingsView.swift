import SwiftUI

struct SettingsView: View {
    @AppStorage("containerBinaryPath") private var binaryPath = ""

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

                let exists = FileManager.default.isExecutableFile(atPath: containerBinaryPath)
                if !exists {
                    Label("Binary not found at this path", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button("Reset to Default") {
                    binaryPath = ""
                }
                .controlSize(.small)

                Text("Path to the Apple container CLI binary. Empty: discover from PATH, /opt/homebrew/bin, /usr/local/bin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}
