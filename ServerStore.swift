import Foundation

enum ServerStore {
    private static let serversKey = "MineBot.Servers"
    private static let selectedServerKey = "MineBot.SelectedServerID"

    static func loadServers() -> [ServerRecord] {
        guard let data = UserDefaults.standard.data(forKey: serversKey) else {
            return []
        }
        return (try? JSONDecoder().decode([ServerRecord].self, from: data)) ?? []
    }

    static func saveServers(_ servers: [ServerRecord]) {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        UserDefaults.standard.set(data, forKey: serversKey)
    }

    static func loadSelectedServerID() -> String {
        UserDefaults.standard.string(forKey: selectedServerKey) ?? ""
    }

    static func saveSelectedServerID(_ id: String) {
        UserDefaults.standard.set(id, forKey: selectedServerKey)
    }
}
