import SwiftUI

struct NetworkDetailView: View {
    let network: NetworkEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Network Info") {
                    InfoGrid {
                        InfoRow(label: "ID", value: network.id)
                        InfoRow(label: "Mode", value: network.config.mode)
                        InfoRow(label: "State", value: network.state)
                    }
                }

                GroupBox("Status") {
                    InfoGrid {
                        InfoRow(label: "Gateway", value: network.status.gateway)
                        InfoRow(label: "Subnet", value: network.status.address)
                    }
                }

                if !network.config.labels.isEmpty {
                    GroupBox("Labels") {
                        InfoGrid {
                            ForEach(network.config.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                InfoRow(label: key, value: value)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(network.id)
    }
}
