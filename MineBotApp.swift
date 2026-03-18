import SwiftUI

@main
struct MineBotApp: App {
    @AppStorage("tutorialSeen") private var tutorialSeen = false
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(tutorialSeen: $tutorialSeen)
                .environmentObject(appModel)
        }
    }
}

struct RootView: View {
    @Binding var tutorialSeen: Bool
    @EnvironmentObject var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if !tutorialSeen {
                    TutorialView {
                        tutorialSeen = true
                    }
                } else if !appModel.isLoggedIn {
                    LoginView()
                } else {
                    MainTabsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))

            SnackbarHost()
                .environmentObject(appModel)
                .zIndex(2)

            if let announcement = appModel.presentedRemoteAnnouncement,
               appModel.activeRemoteMaintenance == nil {
                RemoteAnnouncementOverlay(
                    item: announcement,
                    primaryAction: {
                        appModel.handleRemotePrimaryAction()
                    },
                    secondaryAction: {
                        appModel.dismissPresentedRemoteAnnouncement(markSeen: true)
                    },
                    pollSelectionAction: { option in
                        appModel.handleRemotePollSelection(option)
                    }
                )
                .zIndex(3)
            }

            if let maintenance = appModel.activeRemoteMaintenance {
                RemoteMaintenanceOverlay(
                    maintenance: maintenance,
                    primaryAction: {
                        appModel.handleRemoteMaintenanceAction()
                    }
                )
                .zIndex(4)
            }
        }
        .task {
            await appModel.appDidBecomeActive()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await appModel.appDidBecomeActive()
            }
        }
    }
}

struct MainTabsView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            NavigationStack {
                BotView()
            }
            .tabItem {
                Label("Bot", systemImage: "cpu")
            }
            .tag(AppTab.bot)

            NavigationStack {
                StatusView()
            }
            .tabItem {
                Label("Status", systemImage: "chart.bar")
            }
            .tag(AppTab.status)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .tint(.blue)
    }
}
