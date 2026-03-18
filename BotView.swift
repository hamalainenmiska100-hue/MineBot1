import SwiftUI

struct BotView: View {
    @EnvironmentObject var appModel: AppModel

    private let actionColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                summaryCard
                controlsCard
                accountCard
                actionCard
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .navigationTitle("Bot")
        .task {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
        .refreshable {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
    }

    // MARK: - SUMMARY

    private var summaryCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bot")
                            .font(.headline)

                        Text(statusSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    StatusBadge(status: appModel.botStatus?.status ?? "offline")
                }

                Divider().opacity(0.1)

                LazyVGrid(columns: actionColumns, spacing: 8) {
                    summaryMetric("Server", appModel.botStatus?.server ?? appModel.selectedServer?.label ?? "Not selected")
                    summaryMetric("Uptime", formattedUptime(appModel.botStatus?.uptimeMs))
                    summaryMetric("Connection", appModel.connectionType.title)
                    summaryMetric("Latency", appModel.serverLatencyMs.map { "\($0) ms" } ?? "-")
                }
            }
        }
    }

    // MARK: - CONTROLS

    private var controlsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {

                HStack {
                    Text("Server")
                        .font(.headline)

                    Spacer()

                    if !appModel.servers.isEmpty {
                        Text("\(appModel.servers.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if appModel.servers.isEmpty {
                    Text("No servers")
                        .foregroundStyle(.secondary)

                    Button("Settings") {
                        appModel.selectedTab = .settings
                    }
                    .buttonStyle(SecondaryButtonStyle(color: .blue))

                } else {
                    Picker("Server", selection: Binding(
                        get: { appModel.selectedServerID },
                        set: { appModel.selectServer(id: $0) }
                    )) {
                        ForEach(appModel.servers) { server in
                            Text(server.label).tag(server.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(appModel.isBotRunning)

                    VStack(spacing: 6) {
                        compactRow("IP", appModel.selectedServer?.ip ?? "-")
                        compactRow("Port", appModel.selectedServer.map { String($0.port) } ?? "-")
                    }

                    Picker("Connection", selection: $appModel.connectionType) {
                        ForEach(ConnectionType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(appModel.isBotRunning)

                    if appModel.connectionType == .offline {
                        TextField("Username", text: $appModel.offlineUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - ACCOUNT

    private var accountCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {

                Text("Account")
                    .font(.headline)

                if let pending = appModel.pendingLink,
                   ["starting","pending","error"].contains(pending.status) {

                    compactRow("Status", pending.status.capitalized)

                    if let code = pending.userCode, !code.isEmpty {
                        compactRow("Code", code)
                    }

                    if pending.status != "error" {
                        LazyVGrid(columns: actionColumns, spacing: 8) {
                            Button("Open") { appModel.openLinkURL() }
                                .buttonStyle(PrimaryButtonStyle(color: .blue))

                            Button("Copy") { appModel.copyLinkCode() }
                                .buttonStyle(SecondaryButtonStyle(color: .blue))
                        }

                        Button("Refresh") {
                            Task { await appModel.refreshMicrosoftLinkStatus() }
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))

                    } else {
                        Text(pending.error ?? "Failed")
                            .foregroundStyle(.red)

                        Button("Retry") {
                            Task { await appModel.beginMicrosoftLink() }
                        }
                        .buttonStyle(PrimaryButtonStyle(color: .blue))
                    }

                } else if let account = appModel.firstLinkedAccount {
                    compactRow("Linked", account.label)

                    Button("Unlink") {
                        Task { await appModel.unlinkFirstAccount() }
                    }
                    .buttonStyle(SecondaryButtonStyle(color: .blue))

                } else {
                    Text("No account")
                        .foregroundStyle(.secondary)

                    Button("Link Account") {
                        Task { await appModel.beginMicrosoftLink() }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .blue))
                }
            }
        }
    }

    // MARK: - ACTIONS

    private var actionCard: some View {
        CardView {
            VStack(spacing: 10) {

                if appModel.isBotRunning {
                    Button("Stop Bot") {
                        Task { await appModel.stopBot() }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .red))

                    LazyVGrid(columns: actionColumns, spacing: 8) {
                        Button("Reconnect") {
                            Task { await appModel.reconnectBot() }
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))

                        Button("Refresh") {
                            Task { await appModel.refreshAll(showTransitionFeedback: false) }
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))
                    }

                } else {
                    Button("Start Bot") {
                        Task { await appModel.startBot() }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .green))

                    LazyVGrid(columns: actionColumns, spacing: 8) {
                        Button("Refresh") {
                            Task { await appModel.refreshAll(showTransitionFeedback: false) }
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))

                        Button("Settings") {
                            appModel.selectedTab = .settings
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))
                    }
                }
            }
        }
    }

    // MARK: - SMALL COMPONENTS

    private func summaryMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func compactRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
        }
        .font(.caption)
    }

    private var statusSubtitle: String {
        switch appModel.botStatus?.status.lowercased() {
        case "connected": return "Bot is active"
        case "starting": return "Joining server..."
        case "reconnecting": return "Bot Online"
        case "error": return appModel.botStatus?.lastError ?? "Error occurred"
        default: return "Ready"
        }
    }

    private func formattedUptime(_ uptimeMs: TimeInterval?) -> String {
        guard let uptimeMs else { return "-" }
        let s = Int(uptimeMs / 1000)
        return s >= 3600 ? "\(s/3600)h \(s%3600/60)m"
             : s >= 60 ? "\(s/60)m \(s%60)s"
             : "\(s)s"
    }
}
