import SwiftUI

struct CreateVolumeView: View {
    @Environment(VolumeViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Volume")
                .font(.headline)

            TextField("Volume name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Create") {
                    isCreating = true
                    Task {
                        await vm.createVolume(name: name)
                        isCreating = false
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || isCreating)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
