import SwiftUI

struct BotView: View {
    @EnvironmentObject var appModel: AppModel

    private let actionColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard
                controlsCard
                accountCard
                actionCard
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Bot")
        .task {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
        .refreshable {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
    }

    private var summaryCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bot")
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

                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 12) {
                    summaryMetric(
                        title: "Server",
                        value: appModel.botStatus?.server ?? appModel.selectedServer?.label ?? "Not selected"
                    )

                    summaryMetric(
                        title: "Uptime",
                        value: formattedUptime(appModel.botStatus?.uptimeMs)
                    )

                    summaryMetric(
                        title: "Connection",
                        value: appModel.connectionType.title
                    )

                    summaryMetric(
                        title: "Latency",
                        value: appModel.serverLatencyMs.map { "\($0) ms" } ?? "-"
                    )
                }
            }
        }
    }

    private var controlsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Server")
                        .font(.headline)

                    Spacer()

                    if appModel.servers.isEmpty == false {
                        Text("\(appModel.servers.count) saved")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if appModel.servers.isEmpty {
                    Text("No saved servers yet.")
                        .foregroundStyle(.secondary)

                    Button("Open Settings") {
                        appModel.selectedTab = .settings
                    }
                    .buttonStyle(SecondaryButtonStyle(color: .blue))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Selected Server")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Saved Server", selection: Binding(
                            get: { appModel.selectedServerID },
                            set: { appModel.selectServer(id: $0) }
                        )) {
                            ForEach(appModel.servers) { server in
                                Text(server.label).tag(server.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(appModel.isBotRunning)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    VStack(spacing: 10) {
                        compactRow("IP Address", appModel.selectedServer?.ip ?? "-")
                        compactRow("Port", appModel.selectedServer.map { String($0.port) } ?? "-")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Connection Type")
                            .font(.subheadline.weight(.semibold))

                        Picker("Connection Type", selection: $appModel.connectionType) {
                            ForEach(ConnectionType.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(appModel.isBotRunning)
                    }

                    if appModel.connectionType == .offline {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Offline Username")
                                .font(.subheadline.weight(.semibold))

                            TextField("Steve", text: $appModel.offlineUsername)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .disabled(appModel.isBotRunning)
                        }
                    }
                }
            }
        }
    }

    private var accountCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Microsoft Account")
                    .font(.headline)

                if let pending = appModel.pendingLink,
                   pending.status == "starting" || pending.status == "pending" || pending.status == "error" {

                    compactRow("Status", pending.status.capitalized)

                    if let userCode = pending.userCode, !userCode.isEmpty {
                        compactRow("Code", userCode)
                    }

                    if pending.status == "pending" || pending.status == "starting" {
                        LazyVGrid(columns: actionColumns, spacing: 10) {
                            Button("Open Link") {
                                appModel.openLinkURL()
                            }
                            .buttonStyle(PrimaryButtonStyle(color: .blue))

                            Button("Copy Code") {
                                appModel.copyLinkCode()
                            }
                            .buttonStyle(SecondaryButtonStyle(color: .blue))
                        }

                        Button("Refresh Link Status") {
                            Task { await appModel.refreshMicrosoftLinkStatus() }
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))
                    } else {
                        Text(pending.error ?? "Link failed.")
                            .font(.subheadline)
                            .foregroundStyle(.red)

                        Button("Try Again") {
                            Task { await appModel.beginMicrosoftLink() }
                        }
                        .buttonStyle(PrimaryButtonStyle(color: .blue))
                    }

                } else if let account = appModel.firstLinkedAccount {
                    compactRow("Linked", account.label)

                    Button("Unlink Account") {
                        Task { await appModel.unlinkFirstAccount() }
                    }
                    .buttonStyle(SecondaryButtonStyle(color: .blue))
                } else {
                    Text("No linked Microsoft account.")
                        .foregroundStyle(.secondary)

                    Button("Link Microsoft Account") {
                        Task { await appModel.beginMicrosoftLink() }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .blue))
                }
            }
        }
    }

    private var actionCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Actions")
                        .font(.headline)

                    Spacer()

                    if appModel.isBusy {
                        Text("Working...")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if appModel.isBotRunning {
                    Button("Stop Bot") {
                        Task { await appModel.stopBot() }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .red))
                    .disabled(appModel.isBusy)

                    LazyVGrid(columns: actionColumns, spacing: 10) {
                        Button("Reconnect") {
                            Task { await appModel.reconnectBot() }
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))
                        .disabled(appModel.isBusy)

                        Button("Refresh") {
                            Task { await appModel.refreshAll(showTransitionFeedback: false) }
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))
                        .disabled(appModel.isBusy)
                    }
                } else {
                    Button(appModel.isBusy ? "Working..." : "Start Bot") {
                        Task { await appModel.startBot() }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .green))
                    .disabled(appModel.isBusy)

                    LazyVGrid(columns: actionColumns, spacing: 10) {
                        Button("Refresh") {
                            Task { await appModel.refreshAll(showTransitionFeedback: false) }
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))
                        .disabled(appModel.isBusy)

                        Button("Settings") {
                            appModel.selectedTab = .settings
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))
                        .disabled(appModel.isBusy)
                    }
                }
            }
        }
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func compactRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var statusSubtitle: String {
        let status = appModel.botStatus?.status.lowercased() ?? "offline"

        switch status {
        case "connected":
            return "Your bot is currently active."
        case "starting":
            return "The bot is still joining the server."
        case "reconnecting":
            return "Trying to restore the connection."
        case "error":
            return appModel.botStatus?.lastError ?? "The bot ran into an error."
        default:
            return "Ready to start a new session."
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
