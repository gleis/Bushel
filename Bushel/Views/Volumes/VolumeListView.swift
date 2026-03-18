import SwiftUI

struct VolumeRowView: View {
    let volume: VolumeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(volume.name)
                .font(.headline)
            HStack {
                Text(volume.driver)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(volume.format)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(volume.sizeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
