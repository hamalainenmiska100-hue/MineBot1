import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {

    // 🔥 UI SETTINGS (LISÄTTY TÄHÄN)
    @AppStorage("ui_theme") var uiTheme: String = "system"
    @AppStorage("dev_mode") var devMode: Bool = false
    @AppStorage("experimental_mode") var experimentalMode: Bool = false

    // 🔥 THEME HELPER (LISÄTTY)
    var colorScheme: ColorScheme? {
        switch uiTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    @Published var isLoggedIn: Bool
    @Published var selectedTab: AppTab = .bot

    @Published var linkedAccounts: [LinkedAccount] = []
    @Published var pendingLink: PendingLink?
    @Published var botStatus: BotStatusResponse?
    @Published var health: HealthResponse?
    @Published var serverLatencyMs: Int?
    @Published var snackbar: SnackbarData?

    @Published var servers: [ServerRecord]
    @Published var selectedServerID: String
    @Published var connectionType: ConnectionType = .online
    @Published var offlineUsername: String = ""

    @Published var isBusy = false
    @Published var isRefreshingStatus = false

    private var token: String?
    private var statusTimer: Timer?
    private var lastStatusValue: String?

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
    }

    func logout() {
        statusTimer?.invalidate()
        statusTimer = nil
        token = nil
        isLoggedIn = false
        linkedAccounts = []
        pendingLink = nil
        botStatus = nil
        health = nil
        serverLatencyMs = nil
        lastStatusValue = nil
        Keychain.deleteToken()
        showSnackbar("Signed out.", style: .info)
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
        guard let token else { return }

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
        guard let token else { return }
        do {
            let response = try await APIClient.shared.fetchAccounts(token: token)
            linkedAccounts = response.linked
            if let pending = response.pendingLink, pending.status.lowercased() == "success", response.linked.isEmpty == false {
                pendingLink = nil
            } else {
                pendingLink = response.pendingLink
            }
        } catch {}
    }

    func refreshHealth() async {
        let startedAt = Date()
        do {
            let response = try await APIClient.shared.fetchHealth()
            health = response
            let latency = Int(Date().timeIntervalSince(startedAt) * 1000)
            serverLatencyMs = max(latency, 1)
        } catch {}
    }

    func refreshBotStatus(showTransitionFeedback: Bool = false) async {
        guard let token else { return }
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
            }
        }
    }

    func refreshPendingLinkIfNeeded() async {
        guard let token else { return }
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
        } catch {}
    }

    func showSnackbar(_ message: String, style: SnackbarStyle) {
        switch style {
        case .success: Haptics.success()
        case .error: Haptics.error()
        case .info: Haptics.light()
        }

        let payload = SnackbarData(message: message, style: style)
        snackbar = payload

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self?.snackbar?.id == payload.id {
                self?.snackbar = nil
            }
        }
    }
}
