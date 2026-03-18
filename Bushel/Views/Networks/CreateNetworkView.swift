import SwiftUI

struct CreateNetworkView: View {
    @Environment(NetworkViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Network")
                .font(.headline)

            TextField("Network name", text: $name)
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
                        await vm.createNetwork(name: name)
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
