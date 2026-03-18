import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var isLoggedIn: Bool
    @Published var selectedTab: AppTab = .bot

    @Published var linkedAccounts: [LinkedAccount] = []
    @Published var pendingLink: PendingLink?
    @Published var botStatus: BotStatusResponse?
    @Published var health: HealthResponse?
    @Published var serverLatencyMs: Int?
    @Published var snackbar: SnackbarData?
    @Published var remoteMaintenance: RemoteMaintenanceState?
    @Published var remoteAnnouncements: [RemoteAnnouncementItem] = []
    @Published var presentedRemoteAnnouncement: RemoteAnnouncementItem?

    @Published var servers: [ServerRecord]
    @Published var selectedServerID: String
    @Published var connectionType: ConnectionType = .online
    @Published var offlineUsername: String = ""

    @Published var isBusy = false
    @Published var isRefreshingStatus = false

    private var token: String?
    private var statusTimer: Timer?
    private var lastStatusValue: String?
    private let remoteClientIDKey = "remoteBootstrapClientID"
    private let remoteSeenItemIDsKey = "remoteSeenItemIDs"
    private var remoteSessionDismissedItemIDs: Set<String> = []
    private let remoteDateFormatter = ISO8601DateFormatter()

    let maxGlobalMemoryMb = 512

    init() {
        let savedToken = Keychain.load()
        self.token = savedToken
        self.isLoggedIn = savedToken != nil
        self.servers = ServerStore.loadServers()
        self.selectedServerID = ServerStore.loadSelectedServerID()

        if servers.isEmpty == false, selectedServerID.isEmpty {
            selectedServerID = servers[0].id
        }

        if isLoggedIn {
            startPolling()
            Task {
                await refreshAll(showTransitionFeedback: false)
            }
        }

        Task {
            await refreshRemoteBootstrap(silent: true)
        }
    }

    var activeRemoteMaintenance: RemoteMaintenanceState? {
        guard let remoteMaintenance, remoteMaintenance.enabled else { return nil }
        return remoteMaintenance
    }

    private var remoteClientID: String {
        if let existing = UserDefaults.standard.string(forKey: remoteClientIDKey), !existing.isEmpty {
            return existing
        }

        let newValue = UUID().uuidString
        UserDefaults.standard.set(newValue, forKey: remoteClientIDKey)
        return newValue
    }

    private var seenRemoteItemIDs: Set<String> {
        let saved = UserDefaults.standard.array(forKey: remoteSeenItemIDsKey) as? [String] ?? []
        return Set(saved)
    }

    var selectedServer: ServerRecord? {
        servers.first(where: { $0.id == selectedServerID })
    }

    var firstLinkedAccount: LinkedAccount? {
        linkedAccounts.first
    }

    var isBotRunning: Bool {
        guard let botStatus else { return false }

        if botStatus.connected == true {
            return true
        }

        let status = botStatus.status.lowercased()
        return status == "connected"
            || status == "starting"
            || status == "reconnecting"
            || status == "disconnected"
    }

    func completeLogin(with token: String) {
        self.token = token
        self.isLoggedIn = true
        Keychain.save(token: token)
        startPolling()

        Task {
            await refreshRemoteBootstrap(silent: true)
        }
    }

    func logout() async {
        statusTimer?.invalidate()
        statusTimer = nil

        let currentToken = token

        if !isBusy {
            isBusy = true
        }
        defer { isBusy = false }

        if let currentToken {
            do {
                _ = try await APIClient.shared.logout(token: currentToken)
            } catch {
                // Even if backend logout fails, continue local sign-out.
            }
        }

        performLocalLogout()
        showSnackbar("Signed out.", style: .info)
    }

    private func performLocalLogout() {
        token = nil
        isLoggedIn = false
        linkedAccounts = []
        pendingLink = nil
        botStatus = nil
        health = nil
        serverLatencyMs = nil
        lastStatusValue = nil
        presentedRemoteAnnouncement = nil
        Keychain.deleteToken()
    }

    func login(code: String) async {
        let cleanedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanedCode.count == 14 else {
            showSnackbar("Please enter a valid access code.", style: .error)
            return
        }

        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let response = try await APIClient.shared.redeemCode(cleanedCode)
            completeLogin(with: response.token)
            showSnackbar("Login successful.", style: .success)
            await refreshAll(showTransitionFeedback: false)
        } catch {
            showSnackbar(error.localizedDescription, style: .error)
        }
    }

    func refreshAll(showTransitionFeedback: Bool = false) async {
        guard token != nil else { return }

        isRefreshingStatus = true
        defer { isRefreshingStatus = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.refreshBotStatus(showTransitionFeedback: showTransitionFeedback)
            }
            group.addTask { [weak self] in
                await self?.refreshHealth()
            }
            group.addTask { [weak self] in
                await self?.refreshAccounts()
            }
        }
    }

    func refreshAccounts() async {
        guard let token = self.token else { return }
        do {
            let response = try await APIClient.shared.fetchAccounts(token: token)
            linkedAccounts = response.linked
            if let pending = response.pendingLink,
               pending.status.lowercased() == "success",
               response.linked.isEmpty == false {
                pendingLink = nil
            } else {
                pendingLink = response.pendingLink
            }
        } catch {
            // silent; status polling should not spam users
        }
    }

    func refreshHealth() async {
        let startedAt = Date()
        do {
            let response = try await APIClient.shared.fetchHealth()
            health = response
            let latency = Int(Date().timeIntervalSince(startedAt) * 1000)
            serverLatencyMs = max(latency, 1)
        } catch {
            // silent to avoid noisy polling UX
        }
    }

    func refreshBotStatus(showTransitionFeedback: Bool = false) async {
        guard let token = self.token else { return }
        do {
            let response = try await APIClient.shared.fetchBotStatus(token: token)
            let previous = lastStatusValue
            botStatus = response
            lastStatusValue = response.status.lowercased()

            guard showTransitionFeedback, previous != response.status.lowercased() else { return }
            handleStatusTransition(to: response)
        } catch {
            if showTransitionFeedback {
                showSnackbar(error.localizedDescription, style: .error)
            }
        }
    }

    private func handleStatusTransition(to status: BotStatusResponse) {
        switch status.status.lowercased() {
        case "connected":
            showSnackbar("Bot connected.", style: .success)
        case "reconnecting":
            showSnackbar("Bot reconnecting...", style: .info)
        case "error":
            showSnackbar(status.lastError ?? "Bot error.", style: .error)
        case "offline":
            showSnackbar("Bot offline.", style: .info)
        default:
            break
        }
    }

    func startPolling() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.refreshAll(showTransitionFeedback: true)
                await self.refreshPendingLinkIfNeeded()
                await self.refreshRemoteBootstrap(silent: true)
            }
        }
    }

    func refreshPendingLinkIfNeeded() async {
        guard let token = self.token else { return }
        guard let pendingLink else { return }
        guard pendingLink.status == "starting" || pendingLink.status == "pending" else { return }

        do {
            let response = try await APIClient.shared.fetchMicrosoftLinkStatus(token: token)
            self.pendingLink = PendingLink(
                status: response.status,
                verificationUri: response.verificationUri,
                userCode: response.userCode,
                accountId: response.accountId,
                error: response.error,
                createdAt: nil,
                expiresAt: response.expiresAt
            )

            if response.status == "success" {
                showSnackbar("Microsoft account linked.", style: .success)
                await refreshAccounts()
            } else if response.status == "error", let error = response.error {
                showSnackbar(error, style: .error)
            }
        } catch {
            // silent while polling
        }
    }

    func beginMicrosoftLink() async {
        guard let token = self.token else { return }
        guard !isBusy else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            let response = try await APIClient.shared.startMicrosoftLink(token: token)
            pendingLink = PendingLink(
                status: response.status,
                verificationUri: response.verificationUri,
                userCode: response.userCode,
                accountId: response.accountId,
                error: nil,
                createdAt: Date().timeIntervalSince1970,
                expiresAt: nil
            )
            showSnackbar("Microsoft login started.", style: .success)
        } catch {
            showSnackbar(error.localizedDescription, style: .error)
        }
    }

    func refreshMicrosoftLinkStatus() async {
        guard let token = self.token else { return }
        do {
            let response = try await APIClient.shared.fetchMicrosoftLinkStatus(token: token)
            pendingLink = PendingLink(
                status: response.status,
                verificationUri: response.verificationUri,
                userCode: response.userCode,
                accountId: response.accountId,
                error: response.error,
                createdAt: pendingLink?.createdAt,
                expiresAt: response.expiresAt
            )

            if response.status == "success" {
                showSnackbar("Microsoft account linked.", style: .success)
                await refreshAccounts()
            } else if response.status == "error" {
                showSnackbar(response.error ?? "Microsoft link failed.", style: .error)
            }
        } catch {
            showSnackbar(error.localizedDescription, style: .error)
        }
    }

    func unlinkFirstAccount() async {
        guard let token = self.token, let firstLinkedAccount else { return }
        guard !isBusy else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            _ = try await APIClient.shared.unlinkAccount(token: token, accountId: firstLinkedAccount.id)
            showSnackbar("Account unlinked.", style: .success)
            await refreshAccounts()
        } catch {
            showSnackbar(error.localizedDescription, style: .error)
        }
    }

    func addServer(ip: String, port: Int) {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty else {
            showSnackbar("Please enter an IP address.", style: .error)
            return
        }

        let server = ServerRecord(ip: trimmedIP, port: port)
        servers.append(server)
        ServerStore.saveServers(servers)

        if selectedServerID.isEmpty {
            selectedServerID = server.id
            ServerStore.saveSelectedServerID(server.id)
        }

        showSnackbar("Server added.", style: .success)
    }

    func removeServers(at offsets: IndexSet) {
        let idsToDelete = offsets.map { servers[$0].id }
        servers.remove(atOffsets: offsets)

        if idsToDelete.contains(selectedServerID) {
            selectedServerID = servers.first?.id ?? ""
        }

        ServerStore.saveServers(servers)
        ServerStore.saveSelectedServerID(selectedServerID)
        showSnackbar("Server removed.", style: .info)
    }

    func selectServer(id: String) {
        selectedServerID = id
        ServerStore.saveSelectedServerID(id)
        Haptics.light()
    }

    func startBot() async {
        guard let token = self.token else { return }
        guard let selectedServer else {
            showSnackbar("Add a server first in Settings.", style: .error)
            selectedTab = .settings
            return
        }

        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        if connectionType == .online, linkedAccounts.isEmpty {
            showSnackbar("Link a Microsoft account first.", style: .error)
            return
        }

        do {
            _ = try await APIClient.shared.startBot(
                token: token,
                server: selectedServer,
                connectionType: connectionType,
                offlineUsername: offlineUsername
            )
            showSnackbar("Bot starting...", style: .success)
            await refreshAll(showTransitionFeedback: false)
        } catch {
            showSnackbar(error.localizedDescription, style: .error)
        }
    }

    func stopBot() async {
        guard let token = self.token else { return }
        guard !isBusy else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            _ = try await APIClient.shared.stopBot(token: token)
            showSnackbar("Bot stopped.", style: .info)
            await refreshAll(showTransitionFeedback: false)
        } catch {
            showSnackbar(error.localizedDescription, style: .error)
        }
    }

    func reconnectBot() async {
        guard let token = self.token else { return }
        guard !isBusy else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            _ = try await APIClient.shared.reconnectBot(token: token)
            showSnackbar("Reconnect requested.", style: .success)
            await refreshAll(showTransitionFeedback: false)
        } catch {
            showSnackbar(error.localizedDescription, style: .error)
        }
    }

    func openDiscord() {
        guard let url = URL(string: "https://discord.gg/CNZsQDBYvw") else { return }
        UIApplication.shared.open(url)
        Haptics.light()
    }

    func openLinkURL() {
        guard let urlString = pendingLink?.verificationUri,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
        Haptics.light()
    }

    func copyLinkCode() {
        guard let code = pendingLink?.userCode, !code.isEmpty else { return }
        UIPasteboard.general.string = code
        showSnackbar("Code copied.", style: .success)
    }

    func appDidBecomeActive() async {
        remoteSessionDismissedItemIDs.removeAll()
        await refreshRemoteBootstrap(silent: true)
    }

    func refreshRemoteBootstrap(silent: Bool) async {
        do {
            let payload = try await APIClient.shared.fetchBootstrap(clientId: remoteClientID)
            applyRemoteBootstrap(payload)
        } catch {
            if !silent {
                let funnyMessage = remoteMaintenance?.message
                    ?? "Uh oh.. the announcement goblin tripped over the Wi-Fi cable."
                showSnackbar(funnyMessage, style: .error)
            }
        }
    }

    func dismissPresentedRemoteAnnouncement(markSeen: Bool = true) {
        guard let presentedRemoteAnnouncement else { return }

        remoteSessionDismissedItemIDs.insert(presentedRemoteAnnouncement.id)

        if markSeen && presentedRemoteAnnouncement.showOnce {
            storeSeenRemoteItemID(presentedRemoteAnnouncement.id)
            Task {
                await APIClient.shared.markAnnouncementsSeen(
                    itemIDs: [presentedRemoteAnnouncement.id],
                    clientId: remoteClientID
                )
            }
        }

        self.presentedRemoteAnnouncement = nil
        presentNextRemoteAnnouncementIfPossible()
    }

    func handleRemotePrimaryAction() {
        guard let item = presentedRemoteAnnouncement else { return }

        if item.poll?.options.isEmpty == false {
            showSnackbar("Pick an option below to vote.", style: .info)
            return
        }

        if let actionURL = item.actionUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: actionURL),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }

        dismissPresentedRemoteAnnouncement(markSeen: true)
    }

    func handleRemotePollSelection(_ option: String) {
        showSnackbar("Vote locked in: \(option)", style: .success)
        dismissPresentedRemoteAnnouncement(markSeen: true)
    }

    func handleRemoteMaintenanceAction() {
        let message = activeRemoteMaintenance?.resolvedMessage ?? "Uh oh.. Maintenance Time!"
        showSnackbar(message, style: .error)
    }

    private func applyRemoteBootstrap(_ payload: RemoteBootstrapPayload) {
        remoteMaintenance = payload.maintenance

        remoteAnnouncements = payload.items
            .filter { isRemoteItemActive($0) }
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.id > rhs.id
                }
                return lhs.priority > rhs.priority
            }

        if activeRemoteMaintenance != nil {
            presentedRemoteAnnouncement = nil
            return
        }

        presentNextRemoteAnnouncementIfPossible()
    }

    private func presentNextRemoteAnnouncementIfPossible() {
        guard presentedRemoteAnnouncement == nil else { return }

        let seen = seenRemoteItemIDs

        if let nextItem = remoteAnnouncements.first(where: { item in
            if remoteSessionDismissedItemIDs.contains(item.id) {
                return false
            }
            if item.showOnce && seen.contains(item.id) {
                return false
            }
            return true
        }) {
            presentedRemoteAnnouncement = nextItem
        }
    }

    private func storeSeenRemoteItemID(_ id: String) {
        var seen = seenRemoteItemIDs
        seen.insert(id)
        UserDefaults.standard.set(Array(seen), forKey: remoteSeenItemIDsKey)
    }

    private func isRemoteItemActive(_ item: RemoteAnnouncementItem) -> Bool {
        let now = Date()

        if let startsAt = item.startsAt,
           let startDate = remoteDate(from: startsAt),
           startDate > now {
            return false
        }

        if let endsAt = item.endsAt,
           let endDate = remoteDate(from: endsAt),
           endDate < now {
            return false
        }

        return true
    }

    private func remoteDate(from value: String) -> Date? {
        remoteDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = remoteDateFormatter.date(from: value) {
            return date
        }

        remoteDateFormatter.formatOptions = [.withInternetDateTime]
        return remoteDateFormatter.date(from: value)
    }

    func showSnackbar(_ message: String, style: SnackbarStyle) {
        switch style {
        case .success:
            Haptics.success()
        case .error:
            Haptics.error()
        case .info:
            Haptics.light()
        }

        let payload = SnackbarData(message: message, style: style)
        snackbar = payload

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self else { return }
            if self.snackbar?.id == payload.id {
                self.snackbar = nil
            }
        }
    }
}
