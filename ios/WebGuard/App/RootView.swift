import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.session == nil {
                ConnectView()
            } else if appState.session?.pushSetupCompleted == false {
                PushSetupView()
            } else {
                MainTabsView()
            }
        }
        .alert("WebGuard", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                appState.errorMessage = nil
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .onOpenURL { url in
            appState.handleDeepLink(url)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appState.errorMessage != nil },
            set: { value in
                if !value {
                    appState.errorMessage = nil
                }
            }
        )
    }
}

struct MainTabsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MainTab = .monitorings

    var body: some View {
        TabView(selection: $selectedTab) {
            MonitoringListView()
                .tabItem {
                    Label("Monitorings", systemImage: "checklist")
                }
                .tag(MainTab.monitorings)

            NotificationsView()
                .tabItem {
                    Label("Benachrichtigungen", systemImage: "bell")
                }
                .tag(MainTab.notifications)

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(MainTab.settings)
        }
        .onChange(of: appState.pendingMonitoringID) { _, monitoringID in
            if monitoringID != nil {
                selectedTab = .monitorings
            }
        }
    }
}

private enum MainTab {
    case monitorings
    case notifications
    case settings
}
