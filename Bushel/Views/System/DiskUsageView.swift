import SwiftUI

struct DiskUsageView: View {
    let diskUsage: DiskUsage

    var body: some View {
        GroupBox("Disk Usage") {
            VStack(spacing: 16) {
                DiskUsageCategoryRow(
                    title: "Containers",
                    icon: "shippingbox",
                    category: diskUsage.containers
                )

                DiskUsageCategoryRow(
                    title: "Images",
                    icon: "opticaldisc",
                    category: diskUsage.images
                )

                DiskUsageCategoryRow(
                    title: "Volumes",
                    icon: "externaldrive",
                    category: diskUsage.volumes
                )
            }
        }
    }
}

struct DiskUsageCategoryRow: View {
    let title: String
    let icon: String
    let category: DiskUsageCategory

    private var usedBytes: Int64 {
        category.sizeInBytes - category.reclaimable
    }

    private var usageRatio: Double {
        guard category.sizeInBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(category.sizeInBytes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(category.total) total, \(category.active) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: max(0, geo.size.width * usageRatio))
                }
            }
            .frame(height: 8)

            HStack {
                Text("Used: \(ByteFormatter.format(usedBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Reclaimable: \(category.reclaimableFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Total: \(category.sizeFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
