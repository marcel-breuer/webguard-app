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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedDestination: MainDestination? = .overview

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(selection: $selectedDestination) {
                    ForEach(MainDestination.allCases) { destination in
                        Label(destination.title, systemImage: destination.systemImage)
                            .tag(destination as MainDestination?)
                    }
                }
                .navigationTitle("WebGuard")
                .listStyle(.sidebar)
            } detail: {
                destinationView(selectedDestination ?? .overview)
            }
        } else {
            TabView(selection: $selectedDestination) {
                destinationView(.overview)
                    .tabItem { Label(MainDestination.overview.title, systemImage: MainDestination.overview.systemImage) }
                    .tag(MainDestination.overview as MainDestination?)
                destinationView(.monitorings)
                    .tabItem { Label(MainDestination.monitorings.title, systemImage: MainDestination.monitorings.systemImage) }
                    .tag(MainDestination.monitorings as MainDestination?)
                destinationView(.notifications)
                    .tabItem { Label(MainDestination.notifications.title, systemImage: MainDestination.notifications.systemImage) }
                    .tag(MainDestination.notifications as MainDestination?)
                destinationView(.settings)
                    .tabItem { Label(MainDestination.settings.title, systemImage: MainDestination.settings.systemImage) }
                    .tag(MainDestination.settings as MainDestination?)
            }
            .tint(Brand.accent)
            .onChange(of: appState.pendingMonitoringID) { _, monitoringID in
                if monitoringID != nil {
                    selectedDestination = .monitorings
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: MainDestination) -> some View {
        switch destination {
        case .overview: OperationsOverviewView()
        case .monitorings: MonitoringListView()
        case .notifications: NotificationsView()
        case .settings: SettingsView()
        }
    }
}

private enum MainDestination: String, CaseIterable, Identifiable, Hashable {
    case overview
    case monitorings
    case notifications
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Übersicht"
        case .monitorings: return "Monitorings"
        case .notifications: return "Benachrichtigungen"
        case .settings: return "Einstellungen"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "rectangle.3.group"
        case .monitorings: return "checklist"
        case .notifications: return "bell"
        case .settings: return "gearshape"
        }
    }
}
