import SwiftUI

struct VolumeDetailView: View {
    let volume: VolumeEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Volume Info") {
                    InfoGrid {
                        InfoRow(label: "Name", value: volume.name)
                        InfoRow(label: "Driver", value: volume.driver)
                        InfoRow(label: "Format", value: volume.format)
                        InfoRow(label: "Size", value: volume.sizeFormatted)
                        InfoRow(label: "Created", value: volume.createdAt.formatted)
                        InfoRow(label: "Source", value: volume.source)
                    }
                }

                if !volume.labels.isEmpty {
                    GroupBox("Labels") {
                        InfoGrid {
                            ForEach(volume.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                InfoRow(label: key, value: value)
                            }
                        }
                    }
                }

                if !volume.options.isEmpty {
                    GroupBox("Options") {
                        InfoGrid {
                            ForEach(volume.options.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                InfoRow(label: key, value: value)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(volume.name)
    }
}
