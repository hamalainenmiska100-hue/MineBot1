import SwiftUI

struct BotView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                statusCard
                serverCard
                accountCard
                actionButtons
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .navigationTitle("Bot")
        .task {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
        .refreshable {
            await appModel.refreshAll(showTransitionFeedback: false)
        }
    }

    private var statusCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Bot Status")
                    .font(.headline)

                StatusBadge(status: appModel.botStatus?.status ?? "offline")

                MetricRow(title: "Server", value: appModel.botStatus?.server ?? appModel.selectedServer?.label ?? "Not selected")
                MetricRow(title: "Uptime", value: formattedUptime(appModel.botStatus?.uptimeMs))
            }
        }
    }

    private var serverCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Server")
                    .font(.headline)

                if appModel.servers.isEmpty {
                    Text("No saved servers yet. Add one in Settings.")
                        .foregroundStyle(.secondary)

                    Button("Open Settings") {
                        appModel.selectedTab = .settings
                    }
                    .buttonStyle(SecondaryButtonStyle(color: .blue))
                } else {
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

                    MetricRow(title: "IP Address", value: appModel.selectedServer?.ip ?? "-")
                    MetricRow(title: "Port", value: appModel.selectedServer.map { String($0.port) } ?? "-")

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

                    MetricRow(title: "Status", value: pending.status.capitalized)

                    if let verificationUri = pending.verificationUri, !verificationUri.isEmpty {
                        MetricRow(title: "Link", value: verificationUri)
                    }

                    if let userCode = pending.userCode, !userCode.isEmpty {
                        MetricRow(title: "Code", value: userCode)
                    }

                    if pending.status == "pending" || pending.status == "starting" {
                        Button("Open Microsoft Link") {
                            appModel.openLinkURL()
                        }
                        .buttonStyle(PrimaryButtonStyle(color: .blue))

                        Button("Copy Code") {
                            appModel.copyLinkCode()
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))

                        Button("Refresh Link Status") {
                            Task { await appModel.refreshMicrosoftLinkStatus() }
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .blue))
                    } else if pending.status == "error" {
                        Text(pending.error ?? "Link failed.")
                            .font(.subheadline)
                            .foregroundStyle(.red)

                        Button("Try Again") {
                            Task { await appModel.beginMicrosoftLink() }
                        }
                        .buttonStyle(PrimaryButtonStyle(color: .blue))
                    }
                } else if let account = appModel.firstLinkedAccount {
                    MetricRow(title: "Linked", value: account.label)

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

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(appModel.isBusy ? "Working..." : "Start Bot") {
                Task { await appModel.startBot() }
            }
            .buttonStyle(PrimaryButtonStyle(color: .green))
            .disabled(appModel.isBusy)

            Button("Reconnect") {
                Task { await appModel.reconnectBot() }
            }
            .buttonStyle(PrimaryButtonStyle(color: .blue))
            .disabled(appModel.isBusy || !appModel.isBotRunning)

            Button("Stop Bot") {
                Task { await appModel.stopBot() }
            }
            .buttonStyle(PrimaryButtonStyle(color: .red))
            .disabled(appModel.isBusy || !appModel.isBotRunning)
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
