package dev.minebot.android.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import org.json.JSONArray
import java.io.IOException

private val Context.dataStore by preferencesDataStore(name = "minebot_store")

class AppStorage(private val context: Context) {
    private object Keys {
        val token = stringPreferencesKey("token")
        val servers = stringPreferencesKey("servers")
        val selectedServerId = stringPreferencesKey("selected_server_id")
        val tutorialSeen = stringPreferencesKey("tutorial_seen")
        val remoteClientId = stringPreferencesKey("remote_client_id")
    }

    val tokenFlow: Flow<String?> = preferenceFlow(Keys.token)
    val selectedServerIdFlow: Flow<String?> = preferenceFlow(Keys.selectedServerId)
    val tutorialSeenFlow: Flow<Boolean> = preferenceFlow(Keys.tutorialSeen).map { it == "true" }

    suspend fun saveToken(token: String?) {
        context.dataStore.edit { prefs ->
            if (token == null) prefs.remove(Keys.token) else prefs[Keys.token] = token
        }
    }

    suspend fun saveTutorialSeen(value: Boolean) {
        context.dataStore.edit { prefs -> prefs[Keys.tutorialSeen] = value.toString() }
    }

    suspend fun loadServers(): List<ServerRecord> {
        val json = readString(Keys.servers) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(json)
            buildList {
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    add(
                        ServerRecord(
                            id = obj.optString("id"),
                            ip = obj.optString("ip"),
                            port = obj.optInt("port", 19132)
                        )
                    )
                }
            }
        }.getOrElse { emptyList() }
    }

    suspend fun saveServers(servers: List<ServerRecord>) {
        val arr = JSONArray()
        servers.forEach {
            arr.put(
                org.json.JSONObject().apply {
                    put("id", it.id)
                    put("ip", it.ip)
                    put("port", it.port)
                }
            )
        }
        context.dataStore.edit { prefs -> prefs[Keys.servers] = arr.toString() }
    }

    suspend fun saveSelectedServerId(id: String) {
        context.dataStore.edit { prefs -> prefs[Keys.selectedServerId] = id }
    }

    suspend fun getRemoteClientId(): String {
        val existing = readString(Keys.remoteClientId)
        if (!existing.isNullOrBlank()) return existing
        val id = java.util.UUID.randomUUID().toString()
        context.dataStore.edit { prefs -> prefs[Keys.remoteClientId] = id }
        return id
    }

    private fun preferenceFlow(key: Preferences.Key<String>): Flow<String?> =
        context.dataStore.data
            .catch { e ->
                if (e is IOException) emit(emptyPreferences()) else throw e
            }
            .map { prefs -> prefs[key] }

    private suspend fun readString(key: Preferences.Key<String>): String? {
        return context.dataStore.data
            .catch { e -> if (e is IOException) emit(emptyPreferences()) else throw e }
            .map { it[key] }
            .first()
    }
}
