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

    var body: some View {
        NavigationStack {
            List {
                Section("Veröffentlichung") {
                    Toggle(
                        "Öffentlich",
                        isOn: Binding(
                            get: { page.publication.isPublic },
                            set: { value in Task { await appState.setStatusPagePublication(page, isPublic: value) } }
                        )
                    )
                    .disabled(!page.publication.canChange)
                }

                Section("Offene Vorfälle") {
                    let incidents = appState.statusPageIncidents[page.id] ?? []
                    if incidents.isEmpty {
                        Text("Keine offenen Vorfälle.")
                            .foregroundStyle(Brand.mutedText)
                    } else {
                        ForEach(incidents) { incident in
                            StatusPageIncidentWorkspaceCard(statusPageID: page.id, incident: incident)
                        }
                    }
                }
            }
            .navigationTitle(page.name)
            .toolbar { Button("Fertig") { dismiss() } }
        }
    }
}

private struct StatusPageIncidentWorkspaceCard: View {
    @EnvironmentObject private var appState: AppState
    let statusPageID: String
    let incident: MobileIncidentWorkspace
    @State private var showingMetadataEditor = false
    @State private var showingFollowUpEditor = false
    @State private var editingFollowUp: MobileIncidentFollowUp?
    @State private var showingTimelineEditor = false
    @State private var editingTimelineEvent: MobileIncidentCustomTimelineEvent?
    @State private var publicMessage = ""
    @State private var confirmingFollowUpDeletion = false
    @State private var confirmingTimelineDeletion = false
    @State private var pendingDeletionID: String?
    @State private var confirmingPublication = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(incident.monitoring.name)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(Brand.text)
                Text(incident.lifecycle.state == "resolved" ? "Wiederhergestellt" : "Offener Incident")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(incident.lifecycle.state == "resolved" ? Brand.success : Brand.danger)
            }

            incidentMetadataSummary

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Öffentliche Updates")
                        .font(.headline)
                    Spacer()
                    Text("\(incident.readiness.updateCount)")
                        .foregroundStyle(Brand.mutedText)
                }
                ForEach(incident.updates) { update in
                    WorkspaceTimelineRow(
                        title: update.status.capitalized,
                        description: update.message,
                        date: update.publishedAt,
                        icon: "megaphone"
                    )
                }
                if incident.readiness.canPublishUpdate {
                    TextField("Öffentliche Nachricht", text: $publicMessage, axis: .vertical)
                        .lineLimit(2...5)
                    Button("Update veröffentlichen") {
                        confirmingPublication = true
                    }
                    .disabled(publicMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .confirmationDialog("Update veröffentlichen?", isPresented: $confirmingPublication) {
                        Button("Veröffentlichen") {
                            let message = publicMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task {
                                await appState.publishIncidentUpdate(
                                    statusPageID: statusPageID,
                                    incidentID: incident.id,
                                    status: "investigating",
                                    message: message,
                                    idempotencyKey: UUID().uuidString
                                )
                                publicMessage = ""
                            }
                        }
                    }
                }
            }

            Divider()
            incidentTimeline
            Divider()
            incidentFollowUps
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("webguard.status-pages.incident.\(incident.id)")
        .sheet(isPresented: $showingMetadataEditor) {
            IncidentMetadataEditor(incident: incident) { metadata, review in
                Task {
                    await appState.updateStatusPageIncidentMetadata(statusPageID: statusPageID, incidentID: incident.id, payload: metadata)
                    await appState.updateStatusPageIncidentReview(statusPageID: statusPageID, incidentID: incident.id, payload: review)
                }
            }
        }
        .sheet(isPresented: $showingFollowUpEditor) {
            IncidentFollowUpEditor(followUp: editingFollowUp) { payload in
                Task {
                    if let editingFollowUp {
                        await appState.updateStatusPageIncidentFollowUp(statusPageID: statusPageID, incidentID: incident.id, followUpID: editingFollowUp.id, payload: payload)
                    } else {
                        await appState.createStatusPageIncidentFollowUp(statusPageID: statusPageID, incidentID: incident.id, payload: payload)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTimelineEditor) {
            IncidentTimelineEditor(event: editingTimelineEvent) { payload in
                Task {
                    if let editingTimelineEvent {
                        await appState.updateStatusPageIncidentTimelineEvent(statusPageID: statusPageID, incidentID: incident.id, eventID: editingTimelineEvent.id, payload: payload)
                    } else {
                        await appState.createStatusPageIncidentTimelineEvent(statusPageID: statusPageID, incidentID: incident.id, payload: payload)
                    }
                }
            }
        }
        .confirmationDialog("Follow-up löschen?", isPresented: $confirmingFollowUpDeletion) {
            Button("Löschen", role: .destructive) {
                if let pendingDeletionID {
                    Task { await appState.deleteStatusPageIncidentFollowUp(statusPageID: statusPageID, incidentID: incident.id, followUpID: pendingDeletionID) }
                }
            }
        }
        .confirmationDialog("Timeline-Ereignis löschen?", isPresented: $confirmingTimelineDeletion) {
            Button("Löschen", role: .destructive) {
                if let pendingDeletionID {
                    Task { await appState.deleteStatusPageIncidentTimelineEvent(statusPageID: statusPageID, incidentID: incident.id, eventID: pendingDeletionID) }
                }
            }
        }
    }

    private var incidentMetadataSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Metadaten und Review")
                    .font(.headline)
                Spacer()
                Button("Bearbeiten") { showingMetadataEditor = true }
            }
            WorkspaceValueRow(label: "Typ", value: incident.metadata?.incidentType)
            WorkspaceValueRow(label: "Schweregrad", value: incident.metadata?.severity)
            WorkspaceValueRow(label: "Betroffener Service", value: incident.metadata?.affectedService)
            WorkspaceValueRow(label: "Kundenauswirkung", value: incident.metadata?.customerImpact)
            WorkspaceValueRow(label: "Beitragende Kategorie", value: incident.metadata?.contributingCategory)
            WorkspaceValueRow(label: "Problem", value: incident.metadata?.problemDescription)
            WorkspaceValueRow(label: "Lösung", value: incident.metadata?.resolutionDescription)
        }
        .accessibilityIdentifier(WebGuardAccessibilityID.statusPageIncidentMetadata)
    }

    private var incidentTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Timeline")
                    .font(.headline)
                Spacer()
                Button {
                    editingTimelineEvent = nil
                    showingTimelineEditor = true
                } label: {
                    Label("Ereignis", systemImage: "plus")
                }
            }
            ForEach((incident.timeline ?? []).sorted { $0.occurredAt < $1.occurredAt }, id: \.identity) { event in
                WorkspaceTimelineRow(title: event.title, description: event.description, date: event.occurredAt, icon: event.sourceType == "custom" ? "pencil.and.outline" : "clock")
            }
            ForEach(incident.customTimelineEvents ?? []) { event in
                HStack {
                    Spacer()
                    Button("Bearbeiten") {
                        editingTimelineEvent = event
                        showingTimelineEditor = true
                    }
                    Button("Löschen", role: .destructive) {
                        pendingDeletionID = event.id
                        confirmingTimelineDeletion = true
                    }
                }
            }
            if (incident.timeline ?? []).isEmpty {
                Text("Noch keine Timeline-Ereignisse.")
                    .foregroundStyle(Brand.mutedText)
            }
        }
        .accessibilityIdentifier(WebGuardAccessibilityID.statusPageIncidentTimeline)
    }

    private var incidentFollowUps: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Follow-ups")
                    .font(.headline)
                Spacer()
                Button {
                    editingFollowUp = nil
                    showingFollowUpEditor = true
                } label: {
                    Label("Follow-up", systemImage: "plus")
                }
            }
            ForEach(incident.followUps ?? []) { followUp in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(followUp.title).font(.system(size: 15, weight: .bold, design: .rounded))
                        Spacer()
                        Text(followUp.status)
                            .font(.caption.bold())
                            .foregroundStyle(followUp.status == "completed" ? Brand.success : Brand.warning)
                    }
                    WorkspaceValueRow(label: "Zuständig", value: followUp.assignedUser?.name ?? followUp.assignedUser?.id)
                    WorkspaceValueRow(label: "Fällig", value: followUp.dueAt)
                    WorkspaceValueRow(label: "Abgeschlossen", value: followUp.completedAt?.formatted(date: .abbreviated, time: .shortened))
                    if let description = followUp.description, !description.isEmpty {
                        Text(description).font(.system(size: 13, design: .rounded)).foregroundStyle(Brand.mutedText)
                    }
                    HStack {
                        Button("Bearbeiten") { editingFollowUp = followUp; showingFollowUpEditor = true }
                        Button("Löschen", role: .destructive) { pendingDeletionID = followUp.id; confirmingFollowUpDeletion = true }
                    }
                }
                .padding(.vertical, 4)
            }
            if (incident.followUps ?? []).isEmpty {
                Text("Keine Follow-ups angelegt.")
                    .foregroundStyle(Brand.mutedText)
            }
        }
        .accessibilityIdentifier(WebGuardAccessibilityID.statusPageIncidentFollowUps)
    }
}

private struct WorkspaceValueRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(Brand.mutedText)
            Spacer()
            if let value, !value.isEmpty {
                Text(value)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Brand.text)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("Nicht gesetzt")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct WorkspaceTimelineRow: View {
    let title: String
    let description: String?
    let date: Date?
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(Brand.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded))
                if let description, !description.isEmpty {
                    Text(description).font(.system(size: 13, design: .rounded)).foregroundStyle(Brand.mutedText)
                }
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Brand.mutedText)
                }
            }
        }
    }
}

private struct IncidentMetadataEditor: View {
    @Environment(\.dismiss) private var dismiss
    let incident: MobileIncidentWorkspace
    let onSave: (MobileIncidentMetadataPayload, MobileIncidentReviewPayload) -> Void
    @State private var incidentType: String
    @State private var severity: String
    @State private var affectedService: String
    @State private var customerImpact: String
    @State private var contributingCategory: String
    @State private var problemDescription: String
    @State private var resolutionDescription: String

    init(incident: MobileIncidentWorkspace, onSave: @escaping (MobileIncidentMetadataPayload, MobileIncidentReviewPayload) -> Void) {
        self.incident = incident
        self.onSave = onSave
        _incidentType = State(initialValue: incident.metadata?.incidentType ?? "")
        _severity = State(initialValue: incident.metadata?.severity ?? "")
        _affectedService = State(initialValue: incident.metadata?.affectedService ?? "")
        _customerImpact = State(initialValue: incident.metadata?.customerImpact ?? "")
        _contributingCategory = State(initialValue: incident.metadata?.contributingCategory ?? "")
        _problemDescription = State(initialValue: incident.metadata?.problemDescription ?? "")
        _resolutionDescription = State(initialValue: incident.metadata?.resolutionDescription ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Klassifizierung") {
                    workspacePicker("Typ", selection: $incidentType, values: ["availability", "performance", "security", "dependency", "configuration", "other"])
                    workspacePicker("Schweregrad", selection: $severity, values: ["low", "medium", "high", "critical"])
                    TextField("Betroffener Service", text: $affectedService)
                    workspacePicker("Kundenauswirkung", selection: $customerImpact, values: ["none", "degraded", "outage", "unknown"])
                    workspacePicker("Beitragende Kategorie", selection: $contributingCategory, values: ["code", "infrastructure", "dependency", "configuration", "process", "unknown"])
                }
                Section("Interner Review") {
                    TextField("Problembeschreibung", text: $problemDescription, axis: .vertical).lineLimit(3...8)
                    TextField("Lösungsbeschreibung", text: $resolutionDescription, axis: .vertical).lineLimit(3...8)
                }
            }
            .navigationTitle("Incident bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(
                            MobileIncidentMetadataPayload(incidentType: incidentType.nilIfEmpty, severity: severity.nilIfEmpty, affectedService: affectedService.nilIfEmpty, customerImpact: customerImpact.nilIfEmpty, contributingCategory: contributingCategory.nilIfEmpty),
                            MobileIncidentReviewPayload(problemDescription: problemDescription.nilIfEmpty, resolutionDescription: resolutionDescription.nilIfEmpty)
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func workspacePicker(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        Picker(title, selection: selection) {
            Text("Nicht gesetzt").tag("")
            ForEach(values, id: \.self) { value in Text(value.capitalized).tag(value) }
        }
    }
}

private struct IncidentFollowUpEditor: View {
    @Environment(\.dismiss) private var dismiss
    let followUp: MobileIncidentFollowUp?
    let onSave: (MobileIncidentFollowUpPayload) -> Void
    @State private var title: String
    @State private var description: String
    @State private var assignedUserID: String
    @State private var dueAt: String
    @State private var status: String
    @State private var externalURL: String

    init(followUp: MobileIncidentFollowUp?, onSave: @escaping (MobileIncidentFollowUpPayload) -> Void) {
        self.followUp = followUp
        self.onSave = onSave
        _title = State(initialValue: followUp?.title ?? "")
        _description = State(initialValue: followUp?.description ?? "")
        _assignedUserID = State(initialValue: followUp?.assignedUser?.id ?? "")
        _dueAt = State(initialValue: followUp?.dueAt ?? "")
        _status = State(initialValue: followUp?.status ?? "open")
        _externalURL = State(initialValue: followUp?.externalURL ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Titel", text: $title)
                TextField("Beschreibung", text: $description, axis: .vertical).lineLimit(3...8)
                TextField("Zuständige Benutzer-ID", text: $assignedUserID)
                TextField("Fälligkeit (JJJJ-MM-TT)", text: $dueAt)
                TextField("Externe URL", text: $externalURL)
                if followUp != nil {
                    Picker("Status", selection: $status) {
                        Text("Offen").tag("open")
                        Text("In Arbeit").tag("in_progress")
                        Text("Abgeschlossen").tag("completed")
                    }
                }
            }
            .navigationTitle(followUp == nil ? "Follow-up anlegen" : "Follow-up bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        onSave(MobileIncidentFollowUpPayload(title: title.trimmingCharacters(in: .whitespacesAndNewlines), description: description.nilIfEmpty, assignedUserID: assignedUserID.nilIfEmpty, dueAt: dueAt.nilIfEmpty, status: followUp == nil ? nil : status, externalURL: externalURL.nilIfEmpty, idempotencyKey: nil))
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct IncidentTimelineEditor: View {
    @Environment(\.dismiss) private var dismiss
    let event: MobileIncidentCustomTimelineEvent?
    let onSave: (MobileIncidentTimelineEventPayload) -> Void
    @State private var title: String
    @State private var description: String
    @State private var occurredAt: String

    init(event: MobileIncidentCustomTimelineEvent?, onSave: @escaping (MobileIncidentTimelineEventPayload) -> Void) {
        self.event = event
        self.onSave = onSave
        _title = State(initialValue: event?.title ?? "")
        _description = State(initialValue: event?.description ?? "")
        _occurredAt = State(initialValue: event.map { WebGuardJSONCoding.string(from: $0.occurredAt) } ?? WebGuardJSONCoding.string(from: Date()))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Titel", text: $title)
                TextField("Beschreibung", text: $description, axis: .vertical).lineLimit(3...8)
                TextField("Zeitpunkt (ISO 8601)", text: $occurredAt)
            }
            .navigationTitle(event == nil ? "Ereignis anlegen" : "Ereignis bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        onSave(MobileIncidentTimelineEventPayload(title: title.trimmingCharacters(in: .whitespacesAndNewlines), description: description.nilIfEmpty, occurredAt: occurredAt, idempotencyKey: nil))
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
