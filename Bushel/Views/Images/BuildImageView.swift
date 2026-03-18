import SwiftUI

struct BuildImageView: View {
    @Environment(ImageViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var tag = ""
    @State private var contextDir = ""
    @State private var dockerfile = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Build Image")
                .font(.headline)

            Form {
                TextField("Tag (e.g. myapp:latest)", text: $tag)
                TextField("Context directory path", text: $contextDir)
                TextField("Dockerfile path (optional)", text: $dockerfile)
            }
            .formStyle(.grouped)

            if vm.isBuilding {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(vm.buildOutput.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            HStack {
                Button("Cancel") {
                    vm.cancelBuild()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if vm.isBuilding {
                    ProgressView()
                        .controlSize(.small)
                    Button("Cancel Build") {
                        vm.cancelBuild()
                    }
                } else {
                    Button("Build") {
                        vm.buildImage(
                            tag: tag,
                            contextDir: contextDir,
                            dockerfile: dockerfile.isEmpty ? nil : dockerfile
                        )
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(tag.isEmpty || contextDir.isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 500)
        .onChange(of: vm.isBuilding) { old, new in
            if old && !new {
                dismiss()
            }
        }
    }
}
