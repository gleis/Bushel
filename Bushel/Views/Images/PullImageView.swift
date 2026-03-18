import SwiftUI

struct PullImageView: View {
    @Environment(ImageViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var reference = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Pull Image")
                .font(.headline)

            TextField("Image reference (e.g. nginx:latest, ghcr.io/owner/repo:tag)", text: $reference)
                .textFieldStyle(.roundedBorder)

            if vm.isPulling {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.linear)

                    Text("Pulling \(reference)…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !vm.pullOutput.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(Array(vm.pullOutput.enumerated()), id: \.offset) { index, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .lineLimit(1)
                                        .id(index)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 120)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .onChange(of: vm.pullOutput.count) {
                            if let last = vm.pullOutput.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    vm.cancelPull()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if vm.isPulling {
                    Button("Cancel Pull") {
                        vm.cancelPull()
                    }
                } else {
                    Button("Pull") {
                        vm.pullImage(reference)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(reference.isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 500)
        .onChange(of: vm.isPulling) { old, new in
            if old && !new {
                dismiss()
            }
        }
    }
}
