import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingAddServer = false

    var body: some View {
        List {
            Section("Servers") {
                if appModel.servers.isEmpty {
                    Text("No saved servers yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.servers) { server in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(server.ip)
                                .font(.body.weight(.semibold))
                            Text("Port \(server.port)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: appModel.removeServers)
                }

                Button("Add Server") {
                    showingAddServer = true
                    Haptics.light()
                }
                .foregroundStyle(.blue)
            }

            Section("Community") {
                Button("Join our Discord") {
                    appModel.openDiscord()
                }
                .foregroundStyle(.blue)
            }

            Section("About") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Made with love ❤️")
                    Text("Developer")
                        .foregroundStyle(.secondary)
                    Text("@ilovecatssm2")
                }
                .padding(.vertical, 4)
            }

            Section("Session") {
                Button("Sign Out") {
                    appModel.logout()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingAddServer) {
            AddServerView()
                .environmentObject(appModel)
        }
    }
}
