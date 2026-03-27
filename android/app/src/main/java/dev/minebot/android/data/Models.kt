package dev.minebot.android.data

enum class AppTab { BOT, STATUS, SETTINGS }
enum class ConnectionType { ONLINE, OFFLINE }
enum class SnackbarStyle { INFO, SUCCESS, ERROR }

data class SnackbarData(val message: String, val style: SnackbarStyle)

data class ServerRecord(
    val id: String,
    val ip: String,
    val port: Int
) {
    val label: String = "$ip:$port"
}

data class LinkedAccount(
    val id: String,
    val label: String,
    val createdAt: Double?
)

data class PendingLink(
    val status: String,
    val verificationUri: String?,
    val userCode: String?,
    val accountId: String?,
    val error: String?,
    val expiresAt: Double?
)

data class BotStatusResponse(
    val sessionId: String?,
    val status: String,
    val connected: Boolean?,
    val server: String?,
    val uptimeMs: Double?,
    val lastConnectedAt: Double?,
    val lastError: String?,
    val lastDisconnectReason: String?,
    val connectionType: String?
)

data class HealthResponse(
    val status: String,
    val uptimeSec: Int,
    val bots: Int,
    val memoryMb: Int,
    val maxBots: Int
)

data class RemoteMaintenanceState(
    val enabled: Boolean,
    val title: String?,
    val message: String?,
    val buttonText: String?,
    val action: String?
)

data class RemotePollPayload(
    val question: String?,
    val options: List<String>
)

data class RemoteAnnouncementItem(
    val id: String,
    val type: String,
    val title: String?,
    val message: String?,
    val actionUrl: String?,
    val buttonText: String?,
    val secondaryButtonText: String?,
    val showOnce: Boolean,
    val priority: Int,
    val startsAt: String?,
    val endsAt: String?,
    val poll: RemotePollPayload?
)

data class RemoteBootstrapPayload(
    val maintenance: RemoteMaintenanceState?,
    val items: List<RemoteAnnouncementItem>
)

data class UiState(
    val tutorialSeen: Boolean = false,
    val isLoggedIn: Boolean = false,
    val selectedTab: AppTab = AppTab.BOT,
    val linkedAccounts: List<LinkedAccount> = emptyList(),
    val pendingLink: PendingLink? = null,
    val botStatus: BotStatusResponse? = null,
    val health: HealthResponse? = null,
    val serverLatencyMs: Int? = null,
    val servers: List<ServerRecord> = emptyList(),
    val selectedServerId: String = "",
    val connectionType: ConnectionType = ConnectionType.ONLINE,
    val offlineUsername: String = "",
    val snackbar: SnackbarData? = null,
    val isBusy: Boolean = false,
    val maintenance: RemoteMaintenanceState? = null,
    val announcement: RemoteAnnouncementItem? = null,
    val codeInput: String = ""
)
