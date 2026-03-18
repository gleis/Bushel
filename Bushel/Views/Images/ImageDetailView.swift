import SwiftUI

struct ImageDetailView: View {
    let image: ImageListEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Image Info") {
                    InfoGrid {
                        InfoRow(label: "Reference", value: image.reference)
                        InfoRow(label: "Short Name", value: image.shortName)
                        InfoRow(label: "Digest", value: image.descriptor.digest)
                        InfoRow(label: "Size", value: image.sizeFormatted)
                        InfoRow(label: "Media Type", value: image.descriptor.mediaType)
                    }
                }

                if let annotations = image.descriptor.annotations, !annotations.isEmpty {
                    GroupBox("Annotations") {
                        InfoGrid {
                            ForEach(annotations.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                InfoRow(label: key, value: value)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(image.shortName)
    }
}
