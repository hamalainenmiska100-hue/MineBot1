import Foundation
import SwiftUI

// MARK: - App tabs

enum AppTab: Hashable {
    case bot
    case status
    case settings
}

// MARK: - Connection

enum ConnectionType: String, CaseIterable, Codable, Identifiable {
    case online
    case offline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .online: return "Online"
        case .offline: return "Offline"
        }
    }
}

// MARK: - Snackbar

enum SnackbarStyle {
    case info
    case success
    case error
}

struct SnackbarData: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: SnackbarStyle
}

// MARK: - Server

struct ServerRecord: Codable, Identifiable, Hashable {
    var id: String
    var ip: String
    var port: Int

    init(id: String = UUID().uuidString, ip: String, port: Int) {
        self.id = id
        self.ip = ip
        self.port = port
    }

    var label: String {
        "\(ip):\(port)"
    }
}

// MARK: - API envelopes

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
}

struct APIErrorEnvelope: Decodable {
    let success: Bool
    let error: String?
}

// MARK: - API errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .server(let message):
            return message
        case .decoding(let message):
            return message
        }
    }
}

// MARK: - Auth

struct AuthRedeemResponse: Decodable {
    let token: String
    let userId: String
    let linkedAccounts: [LinkedAccount]
}

struct AuthMeResponse: Decodable {
    let userId: String
    let createdAt: TimeInterval?
    let lastActive: TimeInterval?
    let connectionType: String?
    let bedrockVersion: String?
    let linkedAccounts: [LinkedAccount]
    let bot: MeBotSummary?
}

struct MeBotSummary: Decodable {
    let sessionId: String
    let status: String
    let connected: Bool
    let server: String
    let startedAt: TimeInterval?
    let uptimeMs: TimeInterval?
}

// MARK: - Accounts

struct AccountsResponse: Decodable {
    let linked: [LinkedAccount]
    let pendingLink: PendingLink?
}

struct LinkedAccount: Decodable, Identifiable, Hashable {
    let id: String
    let label: String
    let createdAt: TimeInterval?
    let tokenAcquiredAt: TimeInterval?
    let lastUsedAt: TimeInterval?
    let legacy: Bool?
}

struct PendingLink: Decodable, Hashable {
    let status: String
    let verificationUri: String?
    let userCode: String?
    let accountId: String?
    let error: String?
    let createdAt: TimeInterval?
    let expiresAt: TimeInterval?
}

// MARK: - Microsoft link

struct LinkStartResponse: Decodable {
    let status: String
    let verificationUri: String?
    let userCode: String?
    let accountId: String?
}

struct LinkStatusResponse: Decodable {
    let status: String
    let verificationUri: String?
    let userCode: String?
    let accountId: String?
    let error: String?
    let expiresAt: TimeInterval?
}

struct UnlinkResponse: Decodable {
    let removed: Bool
    let accountId: String?
}

// MARK: - Bot

struct BotStartResponse: Decodable {
    let sessionId: String
    let status: String
    let server: String
    let connectionType: String
    let bedrockVersion: String
}

struct BotActionResponse: Decodable {
    let stopped: Bool?
    let reconnected: Bool?
    let sessionId: String?
    let status: String?
}

struct BotStatusResponse: Decodable {
    let sessionId: String?
    let status: String
    let connected: Bool?
    let isReconnecting: Bool?
    let reconnectAttempt: Int?
    let server: String?
    let startedAt: TimeInterval?
    let uptimeMs: TimeInterval?
    let lastConnectedAt: TimeInterval?
    let lastError: String?
    let lastDisconnectReason: String?
    let connectionType: String?
    let accountId: String?
}

// MARK: - Health

struct HealthResponse: Decodable {
    let status: String
    let uptimeSec: Int
    let bots: Int
    let memoryMb: Int
    let maxBots: Int
}
