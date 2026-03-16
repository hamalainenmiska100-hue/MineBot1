import Foundation

final class APIClient {
    static let shared = APIClient()

    // Change this if your Fly URL changes.
    private let baseURL = "https://afkbotb.fly.dev"
    private let jsonDecoder = JSONDecoder()

    private init() {}

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        token: String? = nil,
        body: [String: Any]? = nil,
        timeout: TimeInterval = 20
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if !(200 ..< 300).contains(httpResponse.statusCode) {
            if let errorEnvelope = try? jsonDecoder.decode(APIErrorEnvelope.self, from: data),
               let message = errorEnvelope.error,
               !message.isEmpty {
                throw APIError.server(message)
            }

            if let message = String(data: data, encoding: .utf8), !message.isEmpty {
                throw APIError.server(message)
            }

            throw APIError.server("Request failed with status code \(httpResponse.statusCode).")
        }

        do {
            let envelope = try jsonDecoder.decode(APIEnvelope<T>.self, from: data)
            if envelope.success, let payload = envelope.data {
                return payload
            }
            throw APIError.server(envelope.error ?? "Request failed.")
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.decoding("Failed to decode server response.")
        }
    }

    func redeemCode(_ code: String) async throws -> AuthRedeemResponse {
        try await request(path: "/auth/redeem", method: "POST", body: ["code": code])
    }

    func fetchMe(token: String) async throws -> AuthMeResponse {
        try await request(path: "/auth/me", token: token)
    }

    func fetchAccounts(token: String) async throws -> AccountsResponse {
        try await request(path: "/accounts", token: token)
    }

    func startMicrosoftLink(token: String) async throws -> LinkStartResponse {
        try await request(path: "/accounts/link/start", method: "POST", token: token)
    }

    func fetchMicrosoftLinkStatus(token: String) async throws -> LinkStatusResponse {
        try await request(path: "/accounts/link/status", token: token)
    }

    func unlinkAccount(token: String, accountId: String? = nil) async throws -> UnlinkResponse {
        var body: [String: Any]? = nil
        if let accountId {
            body = ["accountId": accountId]
        }
        return try await request(path: "/accounts/unlink", method: "POST", token: token, body: body)
    }

    func startBot(token: String, server: ServerRecord, connectionType: ConnectionType, offlineUsername: String) async throws -> BotStartResponse {
        var body: [String: Any] = [
            "ip": server.ip,
            "port": server.port,
            "connectionType": connectionType.rawValue
        ]

        if connectionType == .offline, !offlineUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["offlineUsername"] = offlineUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return try await request(path: "/bots/start", method: "POST", token: token, body: body)
    }

    func stopBot(token: String) async throws -> BotActionResponse {
        try await request(path: "/bots/stop", method: "POST", token: token)
    }

    func reconnectBot(token: String) async throws -> BotActionResponse {
        try await request(path: "/bots/reconnect", method: "POST", token: token)
    }

    func fetchBotStatus(token: String) async throws -> BotStatusResponse {
        try await request(path: "/bots", token: token)
    }

    func fetchHealth() async throws -> HealthResponse {
        try await request(path: "/health")
    }
}
