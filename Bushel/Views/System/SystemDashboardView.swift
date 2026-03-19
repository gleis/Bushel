import SwiftUI

struct SystemDashboardView: View {
    @Environment(SystemViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Card
                GroupBox {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(vm.status?.isRunning == true ? .green : .red)
                                    .frame(width: 12, height: 12)
                                Text(vm.status?.isRunning == true ? "Running" : "Stopped")
                                    .font(.title2.bold())
                            }
                            if let version = vm.status?.version, !version.isEmpty {
                                Text(version)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if vm.isLoading {
                            ProgressView()
                        } else if vm.status?.isRunning == true {
                            Button("Stop System") {
                                Task { await vm.stopSystem() }
                            }
                            .controlSize(.large)
                        } else {
                            Button("Start System") {
                                Task { await vm.startSystem() }
                            }
                            .controlSize(.large)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } label: {
                    Text("Container System")
                }

                // System Info
                if let status = vm.status, status.isRunning {
                    GroupBox("System Details") {
                        InfoGrid {
                            if !status.dataRoot.isEmpty {
                                InfoRow(label: "Data Root", value: status.dataRoot)
                            }
                            if !status.installRoot.isEmpty {
                                InfoRow(label: "Install Root", value: status.installRoot)
                            }
                            if !status.commit.isEmpty {
                                InfoRow(label: "Commit", value: String(status.commit.prefix(12)))
                            }
                        }
                    }
                }

                // Disk Usage
                if let usage = vm.diskUsage {
                    DiskUsageView(diskUsage: usage)
                }
            }
            .padding()
        }
        .navigationTitle("System")
        .toolbar {
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await vm.loadAll() }
                }
                .help("Refresh system info")
            }
        }
        .task { await vm.loadAll() }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK") {}
        } message: {
            Text(vm.error ?? "Unknown error")
        }
    }
}
