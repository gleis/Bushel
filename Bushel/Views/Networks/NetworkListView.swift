import SwiftUI

struct NetworkRowView: View {
    let network: NetworkEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(network.id)
                    .font(.headline)
                Spacer()
                Text(network.state)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        network.state == "running"
                        ? Color.green.opacity(0.15)
                        : Color.gray.opacity(0.15)
                    )
                    .clipShape(Capsule())
            }
            HStack {
                Text(network.config.mode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(network.status.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
