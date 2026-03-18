import SwiftUI

struct ContainerRowView: View {
    let container: ContainerEntry

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(container.status == .running ? .green : .red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.configuration.id)
                    .font(.headline)
                    .lineLimit(1)

                Text(container.configuration.image.reference)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(container.status.rawValue.capitalized)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    container.status == .running
                    ? Color.green.opacity(0.15)
                    : Color.red.opacity(0.15)
                )
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}
