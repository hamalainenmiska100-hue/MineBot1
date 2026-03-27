import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingAddServer = false
    @State private var easterEggTapCount = 0

    private let botFacts = [
        "AFK lore: jumping occasionally reduces idle kicks on some servers.",
        "Quick trick: lower render distance to keep sessions stable.",
        "Server tip: always whitelist your bot account when possible.",
        "Fun fact: reconnecting can clear ghost lag in long sessions."
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                accountCard
                serverCard
                communityCard
                appInfoCard
                sessionCard
            }
            .frame(maxWidth: 540)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Settings")
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingAddServer) {
            AddServerView()
                .environmentObject(appModel)
        }
    }

    private var accountCard: some View {
        CardView {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.cyan)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("MineBot account")
                        .font(.headline)
                    Text(appModel.isLoggedIn ? "Signed in and synced" : "Signed out")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var serverCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Servers")
                        .font(.headline)
                    Spacer()
                    Text("\(appModel.servers.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }

                if appModel.servers.isEmpty {
                    Text("No saved servers yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(appModel.servers.enumerated()), id: \.offset) { index, server in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(server.ip)
                                    .font(.subheadline.weight(.semibold))
                                Text("Port \(server.port)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                appModel.removeServers(at: IndexSet(integer: index))
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Button("Add Server") {
                    showingAddServer = true
                    Haptics.light()
                }
                .buttonStyle(SecondaryButtonStyle(color: .cyan))
            }
        }
    }

    private var communityCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Community")
                    .font(.headline)

                Button("Join our Discord") {
                    appModel.openDiscord()
                }
                .buttonStyle(SecondaryButtonStyle(color: .blue))

                Button("Surprise me (easy egg)") {
                    appModel.showSnackbar(botFacts.randomElement() ?? "Bots love snacks.", style: .info)
                }
                .buttonStyle(SecondaryButtonStyle(color: .purple))
            }
        }
    }

    private var appInfoCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("About")
                        .font(.headline)
                    Spacer()
                    Text("v\(appVersion)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                MetricRow(title: "Build", value: buildNumber)
                MetricRow(title: "Language", value: "English")
                MetricRow(title: "Developer", value: "@ilovecatssm2")

                Button("Tap for hidden mode") {
                    easterEggTapCount += 1
                    if easterEggTapCount >= 5 {
                        easterEggTapCount = 0
                        appModel.showSnackbar("🐣 Secret unlocked: You found the easy easter egg!", style: .success)
                    } else {
                        appModel.showSnackbar("Keep tapping... \(5 - easterEggTapCount) left", style: .info)
                    }
                }
                .buttonStyle(SecondaryButtonStyle(color: .orange))
            }
        }
    }

    private var sessionCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Session")
                    .font(.headline)

                Button("Sign Out") {
                    Task {
                        await appModel.logout()
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: .red))
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }
}
