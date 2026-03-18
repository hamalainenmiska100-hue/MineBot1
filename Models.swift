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


// MARK: - Remote announcements

struct RemoteBootstrapPayload: Decodable {
    let maintenance: RemoteMaintenanceState?
    let items: [RemoteAnnouncementItem]
    let funnyErrors: RemoteFunnyErrors?
    let now: String?
}

struct RemoteFunnyErrors: Decodable, Equatable {
    let maintenance: String?
    let generic: String?
    let offline: String?
}

struct RemoteMaintenanceState: Decodable, Equatable {
    let enabled: Bool
    let title: String?
    let message: String?
    let buttonText: String?
    let action: String?

    var resolvedTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return "Maintenance"
    }

    var resolvedMessage: String {
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        return "Uh oh.. Maintenance Time!"
    }

    var resolvedButtonText: String {
        if let buttonText, !buttonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return buttonText
        }
        return "Close App"
    }
}

struct RemoteAnnouncementItem: Decodable, Identifiable, Equatable {
    let id: String
    let type: String
    let title: String?
    let message: String?
    let imageUrl: String?
    let buttonText: String?
    let secondaryButtonText: String?
    let actionUrl: String?
    let showOnce: Bool
    let priority: Int
    let startsAt: String?
    let endsAt: String?
    let poll: RemotePollPayload?
    let customScreen: RemoteCustomScreenPayload?
    let createdAt: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "announcement"
        title = try container.decodeIfPresent(String.self, forKey: .title)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        buttonText = try container.decodeIfPresent(String.self, forKey: .buttonText)
        secondaryButtonText = try container.decodeIfPresent(String.self, forKey: .secondaryButtonText)
        actionUrl = try container.decodeIfPresent(String.self, forKey: .actionUrl)
        showOnce = try container.decodeIfPresent(Bool.self, forKey: .showOnce) ?? false
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        startsAt = try container.decodeIfPresent(String.self, forKey: .startsAt)
        endsAt = try container.decodeIfPresent(String.self, forKey: .endsAt)
        poll = try container.decodeIfPresent(RemotePollPayload.self, forKey: .poll)
        customScreen = try container.decodeIfPresent(RemoteCustomScreenPayload.self, forKey: .customScreen)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case message
        case imageUrl
        case buttonText
        case secondaryButtonText
        case actionUrl
        case showOnce
        case priority
        case startsAt
        case endsAt
        case poll
        case customScreen
        case createdAt
    }

    var resolvedTitle: String {
        if let customTitle = title, !customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customTitle
        }

        switch type.lowercased() {
        case "poll":
            if let question = poll?.question, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return question
            }
            return "Vote time"
        case "dialog":
            return "Announcement"
        case "customscreen":
            return "Update"
        default:
            return "Announcement"
        }
    }

    var resolvedMessage: String {
        if let customBody = customScreen?.body, !customBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customBody
        }

        if let body = message, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return body
        }

        return "Something new just dropped."
    }

    var resolvedPrimaryButtonText: String {
        if let buttonText, !buttonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return buttonText
        }

        if poll?.options.isEmpty == false {
            return "Vote"
        }

        if actionUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "Open"
        }

        return "OK"
    }

    var resolvedSecondaryButtonText: String {
        if let secondaryButtonText, !secondaryButtonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return secondaryButtonText
        }

        return "Later"
    }
}

struct RemotePollPayload: Decodable, Equatable {
    let question: String?
    let options: [String]
}

struct RemoteCustomScreenPayload: Decodable, Equatable {
    let layout: String?
    let accentEmoji: String?
    let body: String?
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
