import SwiftUI

struct ImageRowView: View {
    let image: ImageListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(image.shortName)
                .font(.headline)
                .lineLimit(1)

            HStack {
                Text(image.shortDigest)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(image.sizeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
