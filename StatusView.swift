import SwiftUI

struct StatusView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Bot Status")
                            .font(.headline)

                        StatusBadge(status: appModel.botStatus?.status ?? "offline")

                        MetricRow(title: "Server", value: appModel.botStatus?.server ?? "-")
                        MetricRow(title: "Uptime", value: formattedUptime(appModel.botStatus?.uptimeMs))
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Server Metrics")
                            .font(.headline)

                        MetricRow(title: "Server Latency", value: appModel.serverLatencyMs.map { "\($0) ms" } ?? "-")
                        MetricRow(title: "Memory Usage", value: appModel.health.map { "\($0.memoryMb) MB" } ?? "-")
                        MetricRow(title: "Global Memory Usage", value: appModel.health.map { "\($0.memoryMb) MB / \(appModel.maxGlobalMemoryMb) MB" } ?? "-")
                        MetricRow(title: "Active Bots", value: appModel.health.map { "\($0.bots) / \($0.maxBots)" } ?? "-")
                    }
                }
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .navigationTitle("Status")
        .task {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
        .refreshable {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
    }

    private func formattedUptime(_ uptimeMs: TimeInterval?) -> String {
        guard let uptimeMs else { return "-" }
        let totalSeconds = Int(uptimeMs / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}
