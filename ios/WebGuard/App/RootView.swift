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
    var body: some View {
        TabView {
            MonitoringListView()
                .tabItem {
                    Label("Monitorings", systemImage: "checklist")
                }

            NotificationsView()
                .tabItem {
                    Label("Benachrichtigungen", systemImage: "bell")
                }

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}
