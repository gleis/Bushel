import SwiftUI

struct ContainerLogsView: View {
    let containerID: String
    let isRunning: Bool
    @Environment(ContainerViewModel.self) private var vm
    @State private var scrollToBottom = true
    @State private var searchText = ""

    private var filteredLines: [(id: Int, text: String)] {
        if searchText.isEmpty { return vm.logLines }
        return vm.logLines.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.logLines.isEmpty && !vm.isStreamingLogs {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text",
                    description: Text(isRunning ? "Waiting for log output..." : "Start the container to see logs")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredLines, id: \.id) { line in
                                Text(line.text)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.green)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .background(.black)
                    .onChange(of: vm.logLines.count) { _, _ in
                        if scrollToBottom, let last = filteredLines.last?.id {
                            withAnimation(.none) {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()

            // Bottom toolbar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)

                Spacer()

                Text("\(vm.logLines.count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Auto-scroll", isOn: $scrollToBottom)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                if vm.isStreamingLogs {
                    Button("Stop") {
                        vm.stopLogStream()
                    }
                    .controlSize(.small)

                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Stream") {
                        vm.startLogStream(for: containerID)
                    }
                    .controlSize(.small)
                    .disabled(!isRunning)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .task(id: containerID) {
            if isRunning {
                vm.startLogStream(for: containerID, lines: 200)
            }
        }
    }
}
