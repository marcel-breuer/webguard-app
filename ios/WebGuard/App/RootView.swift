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
        .alert("WebGuard", isPresented: alertBinding) {
            Button("OK", role: .cancel) {
                appState.dismissAlert()
            }
        } message: {
            Text(appState.alert?.message ?? "")
        }
        .onOpenURL { url in
            appState.handleDeepLink(url)
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { appState.alert != nil },
            set: { value in
                if !value {
                    appState.dismissAlert()
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
        Group {
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
                .accessibilityIdentifier(WebGuardAccessibilityID.mainNavigation)
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
                    destinationView(.statusPages)
                        .tabItem { Label(MainDestination.statusPages.title, systemImage: MainDestination.statusPages.systemImage) }
                        .tag(MainDestination.statusPages as MainDestination?)
                    destinationView(.settings)
                        .tabItem { Label(MainDestination.settings.title, systemImage: MainDestination.settings.systemImage) }
                        .tag(MainDestination.settings as MainDestination?)
                }
                .tint(Brand.accent)
                .accessibilityIdentifier(WebGuardAccessibilityID.mainNavigation)
            }
        }
        .onChange(of: appState.pendingMonitoringID) { _, monitoringID in
            if monitoringID != nil {
                selectedDestination = .monitorings
            }
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: MainDestination) -> some View {
        switch destination {
        case .overview: OperationsOverviewView()
        case .monitorings: MonitoringListView()
        case .notifications: NotificationsView()
        case .statusPages: StatusPageWorkspaceView()
        case .settings: SettingsView()
        }
    }
}

private enum MainDestination: String, CaseIterable, Identifiable, Hashable {
    case overview
    case monitorings
    case notifications
    case statusPages
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Übersicht"
        case .monitorings: return "Monitorings"
        case .notifications: return "Benachrichtigungen"
        case .statusPages: return "Statusseiten"
        case .settings: return "Einstellungen"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "rectangle.3.group"
        case .monitorings: return "checklist"
        case .notifications: return "bell"
        case .statusPages: return "megaphone"
        case .settings: return "gearshape"
        }
    }
}

struct StatusPageWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPage: MobileStatusPage?
    var body: some View {
        NavigationStack {
            List {
                if appState.isOffline { Label("Offline: Arbeitsdaten können veraltet sein.", systemImage: "wifi.slash").foregroundStyle(Brand.warning) }
                ForEach(appState.statusPages) { page in
                    Button { selectedPage = page; Task { await appState.refreshStatusPageIncidents(page.id) } } label: {
                        VStack(alignment: .leading) {
                            Text(page.name).font(.headline)
                            Text("\(page.openIncidentCount) offene Vorfälle · \(page.publication.isPublic ? "Öffentlich" : "Entwurf")").foregroundStyle(Brand.mutedText)
                        }
                    }.buttonStyle(.plain)
                }
                if appState.statusPages.isEmpty { ContentUnavailableView("Keine Statusseiten", systemImage: "rectangle.on.rectangle.slash", description: Text("Keine autorisierten Statusseiten verfügbar.")) }
            }.navigationTitle("Statusseiten").task { await appState.refreshStatusPages() }
             .sheet(item: $selectedPage) { page in StatusPageIncidentSheet(page: page) }
        }
    }
}

private struct StatusPageIncidentSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let page: MobileStatusPage
    @State private var message = ""
    @State private var confirmationVisible = false
    var body: some View {
        NavigationStack {
            List {
                Section("Veröffentlichung") {
                    Toggle("Öffentlich", isOn: Binding(get: { page.publication.isPublic }, set: { value in Task { await appState.setStatusPagePublication(page, isPublic: value) } })).disabled(!page.publication.canChange)
                }
                Section("Offene Vorfälle") {
                    ForEach(appState.statusPageIncidents[page.id] ?? []) { incident in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(incident.monitoring.name).font(.headline)
                            Text(incident.readiness.requiresPublicUpdate ? "Öffentliche Aktualisierung erforderlich" : "\(incident.readiness.updateCount) Aktualisierungen").foregroundStyle(incident.readiness.requiresPublicUpdate ? Brand.warning : Brand.mutedText)
                            if incident.readiness.canPublishUpdate {
                                TextField("Öffentliche Nachricht", text: $message, axis: .vertical).lineLimit(2...5)
                                Button("Update veröffentlichen") { confirmationVisible = true }.disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .confirmationDialog("Update veröffentlichen?", isPresented: $confirmationVisible) {
                                        Button("Veröffentlichen") { let key = UUID().uuidString; Task { await appState.publishIncidentUpdate(statusPageID: page.id, incidentID: incident.id, status: "investigating", message: message, idempotencyKey: key); message = "" } }
                                    }
                            }
                        }
                    }
                    if (appState.statusPageIncidents[page.id] ?? []).isEmpty { Text("Keine offenen Vorfälle.").foregroundStyle(Brand.mutedText) }
                }
            }.navigationTitle(page.name).toolbar { Button("Fertig") { dismiss() } }
        }
    }
}
