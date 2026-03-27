package dev.minebot.android.data

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

class ApiException(message: String) : Exception(message)

class ApiClient {
    private val client = OkHttpClient.Builder().build()
    private val jsonType = "application/json; charset=utf-8".toMediaType()
    private val baseUrl = "https://afkbotb.fly.dev"
    private val announcementsUrl = "https://shrill-lab-a34d.kosonenonpaska.workers.dev"

    private fun request(path: String, method: String = "GET", token: String? = null, body: JSONObject? = null): JSONObject {
        val requestBuilder = Request.Builder()
            .url("$baseUrl$path")
            .header("Accept", "application/json")

        if (!token.isNullOrBlank()) requestBuilder.header("Authorization", "Bearer $token")

        when (method) {
            "POST" -> requestBuilder.post((body ?: JSONObject()).toString().toRequestBody(jsonType))
            else -> requestBuilder.get()
        }

        client.newCall(requestBuilder.build()).execute().use { response ->
            val payload = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw ApiException(parseError(payload).ifBlank { "Request failed (${response.code})." })
            }
            val envelope = JSONObject(payload)
            if (!envelope.optBoolean("success")) {
                throw ApiException(envelope.optString("error", "Request failed."))
            }
            return envelope.optJSONObject("data") ?: JSONObject()
        }
    }

    private fun requestRemote(path: String, clientId: String): JSONObject {
        val request = Request.Builder()
            .url("$announcementsUrl$path")
            .header("Accept", "application/json")
            .header("X-Client-Id", clientId)
            .get()
            .build()

        client.newCall(request).execute().use { response ->
            val payload = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw ApiException(parseError(payload).ifBlank { "Announcement request failed." })
            }
            val envelope = JSONObject(payload)
            if (!envelope.optBoolean("success")) {
                throw ApiException(envelope.optString("error", "Announcement request failed."))
            }
            return envelope.optJSONObject("data") ?: JSONObject()
        }
    }

    fun redeemCode(code: String): String {
        val payloads = buildList {
            add(code)
            val compact = code.replace("-", "").trim()
            if (compact != code) add(compact)
        }

        var lastError: Throwable? = null
        payloads.forEach { value ->
            runCatching {
                val data = request("/auth/redeem", "POST", body = JSONObject().put("code", value))
                val token = data.optString("token").ifBlank { null } ?: data.optString("accessToken").ifBlank { null }
                if (token.isNullOrBlank()) throw ApiException("Login response did not include a token.")
                token
            }.onSuccess { return it }
                .onFailure { lastError = it }
        }

        throw (lastError ?: ApiException("Login failed."))
    }

    fun fetchAccounts(token: String): Pair<List<LinkedAccount>, PendingLink?> {
        val data = request("/accounts", token = token)
        val linked = data.optJSONArray("linked") ?: JSONArray()
        val accounts = buildList {
            for (i in 0 until linked.length()) {
                val item = linked.getJSONObject(i)
                add(LinkedAccount(item.optString("id"), item.optString("label"), item.optDouble("createdAt").takeIf { !it.isNaN() }))
            }
        }
        val pending = data.optJSONObject("pendingLink")?.let {
            PendingLink(
                status = it.optString("status"),
                verificationUri = it.optString("verificationUri").ifBlank { null },
                userCode = it.optString("userCode").ifBlank { null },
                accountId = it.optString("accountId").ifBlank { null },
                error = it.optString("error").ifBlank { null },
                expiresAt = it.optDouble("expiresAt").takeIf { num -> !num.isNaN() }
            )
        }
        return accounts to pending
    }

    fun startMicrosoftLink(token: String): PendingLink {
        val data = request("/accounts/link/start", "POST", token = token)
        return PendingLink(
            status = data.optString("status"),
            verificationUri = data.optString("verificationUri").ifBlank { null },
            userCode = data.optString("userCode").ifBlank { null },
            accountId = data.optString("accountId").ifBlank { null },
            error = null,
            expiresAt = null
        )
    }

    fun fetchMicrosoftLinkStatus(token: String): PendingLink {
        val data = request("/accounts/link/status", token = token)
        return PendingLink(
            status = data.optString("status"),
            verificationUri = data.optString("verificationUri").ifBlank { null },
            userCode = data.optString("userCode").ifBlank { null },
            accountId = data.optString("accountId").ifBlank { null },
            error = data.optString("error").ifBlank { null },
            expiresAt = data.optDouble("expiresAt").takeIf { !it.isNaN() }
        )
    }

    fun unlinkAccount(token: String, accountId: String) {
        request("/accounts/unlink", "POST", token, JSONObject().put("accountId", accountId))
    }

    fun startBot(token: String, server: ServerRecord, connectionType: ConnectionType, offlineUsername: String) {
        val body = JSONObject()
            .put("ip", server.ip)
            .put("port", server.port)
            .put("connectionType", connectionType.name.lowercase())
        if (connectionType == ConnectionType.OFFLINE && offlineUsername.isNotBlank()) {
            body.put("offlineUsername", offlineUsername.trim())
        }
        request("/bots/start", "POST", token, body)
    }

    fun stopBot(token: String) { request("/bots/stop", "POST", token) }
    fun reconnectBot(token: String) { request("/bots/reconnect", "POST", token) }
    fun logout(token: String) { request("/auth/logout", "POST", token) }

    fun fetchBotStatus(token: String): BotStatusResponse {
        val data = request("/bots", token = token)
        return BotStatusResponse(
            sessionId = data.optString("sessionId").ifBlank { null },
            status = data.optString("status", "offline"),
            connected = if (data.has("connected")) data.optBoolean("connected") else null,
            server = data.optString("server").ifBlank { null },
            uptimeMs = data.optDouble("uptimeMs").takeIf { !it.isNaN() },
            lastConnectedAt = data.optDouble("lastConnectedAt").takeIf { !it.isNaN() },
            lastError = data.optString("lastError").ifBlank { null },
            lastDisconnectReason = data.optString("lastDisconnectReason").ifBlank { null },
            connectionType = data.optString("connectionType").ifBlank { null }
        )
    }

    fun fetchHealth(): HealthResponse {
        val data = request("/health")
        return HealthResponse(
            status = data.optString("status"),
            uptimeSec = data.optInt("uptimeSec"),
            bots = data.optInt("bots"),
            memoryMb = data.optInt("memoryMb"),
            maxBots = data.optInt("maxBots")
        )
    }

    fun fetchBootstrap(clientId: String): RemoteBootstrapPayload {
        val data = requestRemote("/api/bootstrap", clientId)
        val maintenanceObj = data.optJSONObject("maintenance")
        val maintenance = maintenanceObj?.let {
            RemoteMaintenanceState(
                enabled = it.optBoolean("enabled"),
                title = it.optString("title").ifBlank { null },
                message = it.optString("message").ifBlank { null },
                buttonText = it.optString("buttonText").ifBlank { null },
                action = it.optString("action").ifBlank { null }
            )
        }
        val itemsJson = data.optJSONArray("items") ?: JSONArray()
        val items = buildList {
            for (i in 0 until itemsJson.length()) {
                val it = itemsJson.getJSONObject(i)
                val pollObj = it.optJSONObject("poll")
                add(
                    RemoteAnnouncementItem(
                        id = it.optString("id", java.util.UUID.randomUUID().toString()),
                        type = it.optString("type", "announcement"),
                        title = it.optString("title").ifBlank { null },
                        message = it.optString("message").ifBlank { null },
                        actionUrl = it.optString("actionUrl").ifBlank { null },
                        buttonText = it.optString("buttonText").ifBlank { null },
                        secondaryButtonText = it.optString("secondaryButtonText").ifBlank { null },
                        showOnce = it.optBoolean("showOnce", false),
                        priority = it.optInt("priority", 0),
                        startsAt = it.optString("startsAt").ifBlank { null },
                        endsAt = it.optString("endsAt").ifBlank { null },
                        poll = pollObj?.let { p ->
                            val options = p.optJSONArray("options") ?: JSONArray()
                            RemotePollPayload(
                                question = p.optString("question").ifBlank { null },
                                options = List(options.length()) { idx -> options.optString(idx) }
                            )
                        }
                    )
                )
            }
        }

        val activeItems = items
            .filter { item -> isRemoteActive(item) }
            .sortedByDescending { it.priority }
        return RemoteBootstrapPayload(maintenance = maintenance, items = activeItems)
    }

    private fun isRemoteActive(item: RemoteAnnouncementItem): Boolean {
        val now = Instant.now()
        item.startsAt?.let {
            if (runCatching { Instant.parse(it) }.getOrNull()?.isAfter(now) == true) return false
        }
        item.endsAt?.let {
            if (runCatching { Instant.parse(it) }.getOrNull()?.isBefore(now) == true) return false
        }
        return true
    }

    private fun parseError(payload: String): String {
        return runCatching { JSONObject(payload).optString("error") }.getOrDefault(payload)
    }
}
