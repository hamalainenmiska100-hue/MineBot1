package dev.minebot.android

import android.app.Application
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dev.minebot.android.data.ApiClient
import dev.minebot.android.data.AppStorage
import dev.minebot.android.data.AppTab
import dev.minebot.android.data.ConnectionType
import dev.minebot.android.data.RemoteAnnouncementItem
import dev.minebot.android.data.ServerRecord
import dev.minebot.android.data.SnackbarData
import dev.minebot.android.data.SnackbarStyle
import dev.minebot.android.data.UiState
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import kotlin.math.max

class MineBotViewModel(application: Application) : AndroidViewModel(application) {
    companion object {
        private const val TAG = "MineBotViewModel"
    }

    private val api = ApiClient()
    private val storage = AppStorage(application)
    private var token: String? = null

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            token = storage.tokenFlow.first()
            val servers = storage.loadServers()
            val selected = storage.selectedServerIdFlow.first().orEmpty()
            val tutorialSeen = storage.tutorialSeenFlow.first()

            _uiState.value = _uiState.value.copy(
                tutorialSeen = tutorialSeen,
                isLoggedIn = !token.isNullOrBlank(),
                servers = servers,
                selectedServerId = if (selected.isBlank() && servers.isNotEmpty()) servers.first().id else selected
            )

            if (!token.isNullOrBlank()) refreshAll()
            refreshBootstrap(silent = true)
        }
    }

    fun finishTutorial() = viewModelScope.launch {
        storage.saveTutorialSeen(true)
        _uiState.value = _uiState.value.copy(tutorialSeen = true)
    }

    fun updateCode(input: String) {
        val clean = input.uppercase().filter { it.isLetterOrDigit() || it == '-' }.take(32)
        _uiState.value = _uiState.value.copy(codeInput = clean)
    }

    fun login() = viewModelScope.launch {
        val code = _uiState.value.codeInput.trim().uppercase()
        val compactCode = code.replace("-", "")
        if (compactCode.length < 10) {
            return@launch showSnackbar("Please enter a valid access code.", SnackbarStyle.ERROR)
        }
        withBusy {
            runCatching { api.redeemCode(code) }
                .onSuccess {
                    token = it
                    storage.saveToken(it)
                    _uiState.value = _uiState.value.copy(isLoggedIn = true, codeInput = "")
                    showSnackbar("Login successful.", SnackbarStyle.SUCCESS)
                    refreshAll()
                }
                .onFailure {
                    Log.e(TAG, "Login request failed", it)
                    showSnackbar(it.message ?: "Login failed.", SnackbarStyle.ERROR)
                }
        }
    }

    fun logout() = viewModelScope.launch {
        withBusy {
            token?.let { runCatching { api.logout(it) } }
            token = null
            storage.saveToken(null)
            _uiState.value = UiState(tutorialSeen = _uiState.value.tutorialSeen)
            showSnackbar("Signed out.", SnackbarStyle.INFO)
        }
    }

    fun refreshAll() = viewModelScope.launch {
        val auth = token ?: return@launch
        refreshBotStatus(auth)
        refreshHealth()
        refreshAccounts(auth)
    }

    private suspend fun refreshAccounts(auth: String) {
        runCatching { api.fetchAccounts(auth) }
            .onSuccess { (linked, pending) ->
                _uiState.value = _uiState.value.copy(linkedAccounts = linked, pendingLink = pending)
            }
    }

    private suspend fun refreshHealth() {
        val started = System.currentTimeMillis()
        runCatching { api.fetchHealth() }
            .onSuccess {
                _uiState.value = _uiState.value.copy(
                    health = it,
                    serverLatencyMs = max(1, (System.currentTimeMillis() - started).toInt())
                )
            }
    }

    private suspend fun refreshBotStatus(auth: String) {
        runCatching { api.fetchBotStatus(auth) }
            .onSuccess { _uiState.value = _uiState.value.copy(botStatus = it) }
    }

    fun beginMicrosoftLink() = viewModelScope.launch {
        val auth = token ?: return@launch
        withBusy {
            runCatching { api.startMicrosoftLink(auth) }
                .onSuccess {
                    _uiState.value = _uiState.value.copy(pendingLink = it)
                    showSnackbar("Microsoft login started.", SnackbarStyle.SUCCESS)
                }
                .onFailure { showSnackbar(it.message ?: "Failed to start link.", SnackbarStyle.ERROR) }
        }
    }

    fun refreshMicrosoftLinkStatus() = viewModelScope.launch {
        val auth = token ?: return@launch
        runCatching { api.fetchMicrosoftLinkStatus(auth) }
            .onSuccess {
                _uiState.value = _uiState.value.copy(pendingLink = it)
                if (it.status == "success") refreshAccounts(auth)
            }
            .onFailure { showSnackbar(it.message ?: "Status refresh failed.", SnackbarStyle.ERROR) }
    }

    fun unlinkFirstAccount() = viewModelScope.launch {
        val auth = token ?: return@launch
        val account = _uiState.value.linkedAccounts.firstOrNull() ?: return@launch
        withBusy {
            runCatching { api.unlinkAccount(auth, account.id) }
                .onSuccess {
                    showSnackbar("Account unlinked.", SnackbarStyle.SUCCESS)
                    refreshAccounts(auth)
                }
                .onFailure { showSnackbar(it.message ?: "Failed to unlink account.", SnackbarStyle.ERROR) }
        }
    }

    fun addServer(ip: String, port: Int) = viewModelScope.launch {
        if (ip.isBlank()) return@launch showSnackbar("Please enter an IP address.", SnackbarStyle.ERROR)
        val list = _uiState.value.servers + ServerRecord(UUID.randomUUID().toString(), ip.trim(), port)
        storage.saveServers(list)
        val selectedId = _uiState.value.selectedServerId.ifBlank { list.first().id }
        storage.saveSelectedServerId(selectedId)
        _uiState.value = _uiState.value.copy(servers = list, selectedServerId = selectedId)
        showSnackbar("Server added.", SnackbarStyle.SUCCESS)
    }

    fun removeServer(id: String) = viewModelScope.launch {
        val list = _uiState.value.servers.filterNot { it.id == id }
        val nextSelected = if (_uiState.value.selectedServerId == id) list.firstOrNull()?.id.orEmpty() else _uiState.value.selectedServerId
        storage.saveServers(list)
        storage.saveSelectedServerId(nextSelected)
        _uiState.value = _uiState.value.copy(servers = list, selectedServerId = nextSelected)
    }

    fun selectServer(id: String) = viewModelScope.launch {
        storage.saveSelectedServerId(id)
        _uiState.value = _uiState.value.copy(selectedServerId = id)
    }

    fun setTab(tab: AppTab) { _uiState.value = _uiState.value.copy(selectedTab = tab) }
    fun setConnectionType(type: ConnectionType) { _uiState.value = _uiState.value.copy(connectionType = type) }
    fun setOfflineUsername(value: String) { _uiState.value = _uiState.value.copy(offlineUsername = value) }

    fun startBot() = viewModelScope.launch {
        val auth = token ?: return@launch
        val state = _uiState.value
        val server = state.servers.firstOrNull { it.id == state.selectedServerId }
        if (server == null) {
            setTab(AppTab.SETTINGS)
            return@launch showSnackbar("Add a server first in Settings.", SnackbarStyle.ERROR)
        }
        if (state.connectionType == ConnectionType.ONLINE && state.linkedAccounts.isEmpty()) {
            return@launch showSnackbar("Link a Microsoft account first.", SnackbarStyle.ERROR)
        }

        withBusy {
            runCatching { api.startBot(auth, server, state.connectionType, state.offlineUsername) }
                .onSuccess {
                    showSnackbar("Bot starting...", SnackbarStyle.SUCCESS)
                    refreshAll()
                }
                .onFailure { showSnackbar(it.message ?: "Failed to start bot.", SnackbarStyle.ERROR) }
        }
    }

    fun stopBot() = doBotAction("Bot stopped.") { auth -> api.stopBot(auth) }
    fun reconnectBot() = doBotAction("Reconnect requested.") { auth -> api.reconnectBot(auth) }

    private fun doBotAction(message: String, action: (String) -> Unit) = viewModelScope.launch {
        val auth = token ?: return@launch
        withBusy {
            runCatching { action(auth) }
                .onSuccess {
                    showSnackbar(message, SnackbarStyle.INFO)
                    refreshAll()
                }
                .onFailure { showSnackbar(it.message ?: "Action failed.", SnackbarStyle.ERROR) }
        }
    }

    fun refreshBootstrap(silent: Boolean = false) = viewModelScope.launch {
        val clientId = storage.getRemoteClientId()
        runCatching { api.fetchBootstrap(clientId) }
            .onSuccess {
                _uiState.value = _uiState.value.copy(
                    maintenance = it.maintenance?.takeIf { m -> m.enabled },
                    announcement = it.items.firstOrNull()
                )
            }
            .onFailure {
                if (!silent) showSnackbar("Announcement sync failed.", SnackbarStyle.ERROR)
            }
    }

    fun dismissAnnouncement() {
        _uiState.value = _uiState.value.copy(announcement = null)
    }

    fun consumeSnackbar() {
        _uiState.value = _uiState.value.copy(snackbar = null)
    }

    fun openDiscord() {
        openUrl("https://discord.gg/CNZsQDBYvw")
    }

    fun openPendingLink() {
        _uiState.value.pendingLink?.verificationUri?.let(::openUrl)
    }

    private fun openUrl(url: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        getApplication<Application>().startActivity(intent)
    }

    private suspend fun withBusy(block: suspend () -> Unit) {
        _uiState.value = _uiState.value.copy(isBusy = true)
        block()
        _uiState.value = _uiState.value.copy(isBusy = false)
    }

    private fun showSnackbar(message: String, style: SnackbarStyle) {
        _uiState.value = _uiState.value.copy(snackbar = SnackbarData(message, style))
        viewModelScope.launch {
            delay(2500)
            if (_uiState.value.snackbar?.message == message) {
                consumeSnackbar()
            }
        }
    }
}
