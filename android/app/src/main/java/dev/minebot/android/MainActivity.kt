package dev.minebot.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.minebot.android.data.AppTab
import dev.minebot.android.data.ConnectionType
import dev.minebot.android.data.UiState
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : ComponentActivity() {
    private val vm by viewModels<MineBotViewModel>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { MineBotApp(vm) } }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MineBotApp(vm: MineBotViewModel) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.snackbar?.message) {
        state.snackbar?.let {
            snackbarHostState.showSnackbar(it.message)
            vm.consumeSnackbar()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        bottomBar = {
            if (state.tutorialSeen && state.isLoggedIn) {
                NavigationBar {
                    NavigationBarItem(selected = state.selectedTab == AppTab.BOT, onClick = { vm.setTab(AppTab.BOT) }, label = { Text("Bot") }, icon = {})
                    NavigationBarItem(selected = state.selectedTab == AppTab.STATUS, onClick = { vm.setTab(AppTab.STATUS) }, label = { Text("Status") }, icon = {})
                    NavigationBarItem(selected = state.selectedTab == AppTab.SETTINGS, onClick = { vm.setTab(AppTab.SETTINGS) }, label = { Text("Settings") }, icon = {})
                }
            }
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                !state.tutorialSeen -> TutorialScreen(onContinue = vm::finishTutorial)
                !state.isLoggedIn -> LoginScreen(state = state, onCodeChange = vm::updateCode, onLogin = vm::login)
                state.selectedTab == AppTab.BOT -> BotScreen(state = state, vm = vm)
                state.selectedTab == AppTab.STATUS -> StatusScreen(state = state)
                else -> SettingsScreen(state = state, vm = vm)
            }
        }

        if (state.maintenance?.enabled == true) {
            AlertDialog(
                onDismissRequest = {},
                confirmButton = { TextButton(onClick = {}) { Text(state.maintenance?.buttonText ?: "Close App") } },
                title = { Text(state.maintenance?.title ?: "Maintenance") },
                text = { Text(state.maintenance?.message ?: "Uh oh.. Maintenance Time!") }
            )
        }

        state.announcement?.let { ann ->
            AlertDialog(
                onDismissRequest = vm::dismissAnnouncement,
                confirmButton = {
                    TextButton(onClick = {
                        ann.actionUrl?.let { vm.openPendingLink() }
                        vm.dismissAnnouncement()
                    }) { Text(ann.buttonText ?: "OK") }
                },
                dismissButton = { TextButton(onClick = vm::dismissAnnouncement) { Text(ann.secondaryButtonText ?: "Later") } },
                title = { Text(ann.title ?: "Announcement") },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(ann.message ?: "Something new just dropped.")
                        ann.poll?.options?.forEach { option ->
                            OutlinedButton(onClick = vm::dismissAnnouncement) { Text(option) }
                        }
                    }
                }
            )
        }
    }
}

@Composable
private fun TutorialScreen(onContinue: () -> Unit) {
    Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Welcome to MineBot", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text("Manage your bot, servers, accounts, and live status from Android.")
        Button(onClick = onContinue) { Text("Get Started") }
    }
}

@Composable
private fun LoginScreen(state: UiState, onCodeChange: (String) -> Unit, onLogin: () -> Unit) {
    Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("MineBot", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        Text("Enter your access code")
        OutlinedTextField(value = state.codeInput, onValueChange = onCodeChange, label = { Text("XXXX-XXXX-XXXX") }, modifier = Modifier.fillMaxWidth())
        Button(onClick = onLogin, enabled = !state.isBusy, modifier = Modifier.fillMaxWidth()) { Text(if (state.isBusy) "Loading..." else "Login") }
    }
}

@Composable
private fun BotScreen(state: UiState, vm: MineBotViewModel) {
    val selected = state.servers.firstOrNull { it.id == state.selectedServerId }
    val isBotRunning = state.botStatus?.status?.lowercase() in setOf("connected", "starting", "reconnecting", "disconnected") || state.botStatus?.connected == true

    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Bot", fontWeight = FontWeight.Bold)
                Text("Status: ${state.botStatus?.status ?: "offline"}")
                Text("Server: ${state.botStatus?.server ?: selected?.label ?: "Not selected"}")
                Text("Latency: ${state.serverLatencyMs?.let { "$it ms" } ?: "-"}")
            }}
        }
        item {
            Card { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Connection", fontWeight = FontWeight.Bold)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = state.connectionType == ConnectionType.ONLINE, onClick = { vm.setConnectionType(ConnectionType.ONLINE) }, label = { Text("Online") })
                    FilterChip(selected = state.connectionType == ConnectionType.OFFLINE, onClick = { vm.setConnectionType(ConnectionType.OFFLINE) }, label = { Text("Offline") })
                }
                if (state.connectionType == ConnectionType.OFFLINE) {
                    OutlinedTextField(value = state.offlineUsername, onValueChange = vm::setOfflineUsername, label = { Text("Offline Username") }, modifier = Modifier.fillMaxWidth())
                }
            }}
        }
        item {
            Card { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Microsoft Account", fontWeight = FontWeight.Bold)
                when {
                    state.pendingLink != null && (state.pendingLink.status == "starting" || state.pendingLink.status == "pending") -> {
                        Text("Code: ${state.pendingLink.userCode ?: "-"}")
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = vm::openPendingLink) { Text("Open Link") }
                            OutlinedButton(onClick = vm::refreshMicrosoftLinkStatus) { Text("Refresh") }
                        }
                    }
                    state.linkedAccounts.isNotEmpty() -> {
                        Text("Linked: ${state.linkedAccounts.first().label}")
                        OutlinedButton(onClick = vm::unlinkFirstAccount) { Text("Unlink Account") }
                    }
                    else -> Button(onClick = vm::beginMicrosoftLink) { Text("Link Microsoft Account") }
                }
            }}
        }
        item {
            Card { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Actions", fontWeight = FontWeight.Bold)
                if (isBotRunning) {
                    Button(onClick = vm::stopBot, modifier = Modifier.fillMaxWidth()) { Text("Stop Bot") }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = vm::reconnectBot) { Text("Reconnect") }
                        OutlinedButton(onClick = vm::refreshAll) { Text("Refresh") }
                    }
                } else {
                    Button(onClick = vm::startBot, modifier = Modifier.fillMaxWidth()) { Text(if (state.isBusy) "Working..." else "Start Bot") }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = vm::refreshAll) { Text("Refresh") }
                        OutlinedButton(onClick = { vm.setTab(AppTab.SETTINGS) }) { Text("Settings") }
                    }
                }
            }}
        }
    }
}

@Composable
private fun StatusScreen(state: UiState) {
    val fmt = remember { SimpleDateFormat("MMM d, yyyy h:mm a", Locale.US) }
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Status", fontWeight = FontWeight.Bold)
                Text("Session: ${state.botStatus?.status ?: "offline"}")
                Text("Uptime: ${formatUptime(state.botStatus?.uptimeMs)}")
                Text("Last connected: ${state.botStatus?.lastConnectedAt?.let { fmt.format(Date((if (it > 10_000_000_000) it else it * 1000).toLong())) } ?: "-"}")
            }}
        }
        item {
            Card { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Server Metrics", fontWeight = FontWeight.Bold)
                Text("Latency: ${state.serverLatencyMs?.let { "$it ms" } ?: "-"}")
                Text("Memory: ${state.health?.memoryMb?.let { "$it MB" } ?: "-"}")
                Text("Global Memory: ${state.health?.memoryMb ?: "-"} / 512 MB")
                Text("Active Bots: ${state.health?.bots ?: "-"} / ${state.health?.maxBots ?: "-"}")
            }}
        }
    }
}

@Composable
private fun SettingsScreen(state: UiState, vm: MineBotViewModel) {
    var ip by remember { mutableStateOf("") }
    var port by remember { mutableStateOf("19132") }

    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Servers", fontWeight = FontWeight.Bold)
                    state.servers.forEach { server ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Column {
                                Text(server.ip, fontWeight = FontWeight.Medium)
                                Text("Port ${server.port}")
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedButton(onClick = { vm.selectServer(server.id) }) { Text(if (state.selectedServerId == server.id) "Selected" else "Select") }
                                TextButton(onClick = { vm.removeServer(server.id) }) { Text("Delete") }
                            }
                        }
                    }
                    OutlinedTextField(value = ip, onValueChange = { ip = it }, label = { Text("IP Address") }, modifier = Modifier.fillMaxWidth())
                    OutlinedTextField(value = port, onValueChange = { port = it.filter(Char::isDigit) }, label = { Text("Port") }, modifier = Modifier.fillMaxWidth())
                    Button(onClick = { vm.addServer(ip, port.toIntOrNull() ?: 19132) }, modifier = Modifier.fillMaxWidth()) { Text("Add Server") }
                }
            }
        }
        item {
            Card {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Community", fontWeight = FontWeight.Bold)
                    OutlinedButton(onClick = vm::openDiscord) { Text("Join our Discord") }
                    OutlinedButton(onClick = vm::logout) { Text("Sign Out") }
                }
            }
        }
    }
}

private fun formatUptime(uptimeMs: Double?): String {
    val ms = uptimeMs ?: return "-"
    val seconds = (ms / 1000).toInt()
    val hours = seconds / 3600
    val minutes = (seconds % 3600) / 60
    val secs = seconds % 60
    return when {
        hours > 0 -> "${hours}h ${minutes}m"
        minutes > 0 -> "${minutes}m ${secs}s"
        else -> "${secs}s"
    }
}
