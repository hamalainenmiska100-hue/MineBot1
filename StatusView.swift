import SwiftUI

struct StatusView: View {
    @EnvironmentObject var appModel: AppModel

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                heroCard
                sessionCard
                metricsCard
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Status")
        .task {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
        .refreshable {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
    }

    private var heroCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusTitle)
                            .font(.headline)

                        Text(statusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    StatusBadge(status: appModel.botStatus?.status ?? "offline")
                }

                Divider()
                    .overlay(Color.white.opacity(0.06))

                LazyVGrid(columns: columns, spacing: 10) {
                    statusMetricTile(
                        title: "Server",
                        value: appModel.botStatus?.server ?? "Not connected"
                    )

                    statusMetricTile(
                        title: "Uptime",
                        value: formattedUptime(appModel.botStatus?.uptimeMs)
                    )
                }
            }
        }
    }

    private var sessionCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Session")
                    .font(.headline)

                MetricRow(
                    title: "Connection",
                    value: readableConnectionType(appModel.botStatus?.connectionType)
                )

                MetricRow(
                    title: "Last Connected",
                    value: formattedTimestamp(appModel.botStatus?.lastConnectedAt)
                )

                if let reason = appModel.botStatus?.lastDisconnectReason,
                   reason.isEmpty == false {
                    MetricRow(title: "Last Disconnect", value: reason)
                }

                if let error = appModel.botStatus?.lastError,
                   error.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Error")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private var metricsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Server Metrics")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 10) {
                    statusMetricTile(
                        title: "Latency",
                        value: appModel.serverLatencyMs.map { "\($0) ms" } ?? "-"
                    )

                    statusMetricTile(
                        title: "Memory",
                        value: appModel.health.map { "\($0.memoryMb) MB" } ?? "-"
                    )

                    statusMetricTile(
                        title: "Global Memory",
                        value: appModel.health.map { "\($0.memoryMb) / \(appModel.maxGlobalMemoryMb) MB" } ?? "-"
                    )

                    statusMetricTile(
                        title: "Active Bots",
                        value: appModel.health.map { "\($0.bots) / \($0.maxBots)" } ?? "-"
                    )
                }

                if let health = appModel.health {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Memory Load")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(memoryPercentage(health.memoryMb))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: memoryProgressValue(health.memoryMb))
                            .tint(memoryTintColor(health.memoryMb))
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func statusMetricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statusTitle: String {
        let status = appModel.botStatus?.status.lowercased() ?? "offline"

        switch status {
        case "connected":
            return "Bot is online"
        case "starting":
            return "Bot is starting"
        case "reconnecting":
            return "Bot is reconnecting"
        case "error":
            return "Bot error"
        case "disconnected":
            return "Bot disconnected"
        default:
            return "Bot is offline"
        }
    }

    private var statusSubtitle: String {
        let status = appModel.botStatus?.status.lowercased() ?? "offline"

        switch status {
        case "connected":
            return "Everything looks stable right now."
        case "starting":
            return "The bot is still joining the server."
        case "reconnecting":
            return "Trying to restore the connection."
        case "error":
            return appModel.botStatus?.lastError ?? "Something went wrong."
        case "disconnected":
            return "The session exists, but the connection is down."
        default:
            return "No active bot session."
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

    private func formattedTimestamp(_ timestamp: TimeInterval?) -> String {
        guard let timestamp else { return "-" }

        let seconds = timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp
        let date = Date(timeIntervalSince1970: seconds)

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func readableConnectionType(_ type: String?) -> String {
        guard let type else { return "-" }

        switch type.lowercased() {
        case "online":
            return "Online"
        case "offline":
            return "Offline"
        default:
            return type.capitalized
        }
    }

    private func memoryProgressValue(_ memoryMb: Int) -> Double {
        guard appModel.maxGlobalMemoryMb > 0 else { return 0 }
        return min(max(Double(memoryMb) / Double(appModel.maxGlobalMemoryMb), 0), 1)
    }

    private func memoryPercentage(_ memoryMb: Int) -> Int {
        Int(memoryProgressValue(memoryMb) * 100)
    }

    private func memoryTintColor(_ memoryMb: Int) -> Color {
        let ratio = memoryProgressValue(memoryMb)

        if ratio >= 0.85 { return .red }
        if ratio >= 0.65 { return .orange }
        return .green
    }
}
