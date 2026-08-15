import SwiftUI

struct MonitoringListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var filter: MonitorFilter = .systems
    @State private var selectedMonitor: KnownMonitor?
    @State private var showingCreate = false
    @State private var showingCollaboration = false
    @State private var showingMaintenance = false

    private var filteredMonitors: [KnownMonitor] {
        let base = filter == .systems ? appState.monitors.filter { $0.status != nil } : appState.monitors
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalized.isEmpty else {
            return base
        }

        return base.filter {
            $0.name.lowercased().contains(normalized)
                || $0.target.lowercased().contains(normalized)
                || $0.id.lowercased().contains(normalized)
        }
    }

    private var maintenanceMonitors: [KnownMonitor] {
        appState.monitors
            .filter { $0.maintenanceWindowState != nil }
            .sorted { lhs, rhs in
                if lhs.maintenanceWindowState != rhs.maintenanceWindowState {
                    return lhs.maintenanceWindowState == .active
                }

                return lhs.maintenanceFrom ?? .distantFuture < rhs.maintenanceFrom ?? .distantFuture
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HeaderBar()

                    MonitoringFreshnessBanner()

                    if !maintenanceMonitors.isEmpty {
                        MaintenanceSummaryCard(monitors: maintenanceMonitors)
                    }

                    HStack {
                        Text("Monitorings")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)
                        Spacer()
                        Button { showingCreate = true } label: {
                            Label("Monitoring erstellen", systemImage: "plus")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button { showingCollaboration = true } label: {
                            Image(systemName: "person.3")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Teams und Monitoring-Gruppen")
                        Button { showingMaintenance = true } label: { Image(systemName: "wrench.and.screwdriver") }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Wartung verwalten")
                    }

                    Picker("Filter", selection: $filter) {
                        Text("Alle Systeme").tag(MonitorFilter.systems)
                        Text("Alle Monitorings").tag(MonitorFilter.all)
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                        MetricTile(label: "Up", value: count(.up), color: Brand.success)
                        MetricTile(label: "Maintenance", value: count(.maintenance), color: Brand.warning)
                        MetricTile(label: "Down", value: count(.down), color: Brand.danger)
                        MetricTile(label: "Gesamt", value: appState.monitors.count, color: Brand.text)
                    }

                    FormTextField(title: "Suchen", text: $query)
                        .accessibilityIdentifier(WebGuardAccessibilityID.monitoringSearch)

                    VStack(spacing: 0) {
                        if filteredMonitors.isEmpty {
                            Text(emptyStateMessage)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(Brand.mutedText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredMonitors) { monitor in
                                Button {
                                    selectedMonitor = monitor
                                } label: {
                                    MonitorRow(monitor: monitor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(WebGuardAccessibilityID.monitoringRow(monitor.id))
                                Divider().background(Brand.border)
                            }
                        }
                    }
                    .webGuardCard()
                }
                .padding(20)
                .webGuardContentWidth(1040)
            }
            .accessibilityIdentifier(WebGuardAccessibilityID.monitoringList)
            .refreshable {
                await appState.refreshMonitorings()
            }
            .task {
                if appState.monitors.isEmpty {
                    await appState.refreshMonitorings()
                }

                openPendingMonitoringIfNeeded()
            }
            .onChange(of: appState.pendingMonitoringID) { _, _ in
                openPendingMonitoringIfNeeded()
            }
            .navigationDestination(item: $selectedMonitor) { monitor in
                MonitoringDetailView(monitor: monitor)
            }
            .background(Brand.background)
            .sheet(isPresented: $showingCreate) {
                MonitoringEditorView(monitor: nil) { created in
                    selectedMonitor = created
                }
            }
            .sheet(isPresented: $showingCollaboration) {
                CollaborationWorkspaceView()
            }
            .sheet(isPresented: $showingMaintenance) { MaintenanceWorkspaceView() }
        }
    }

    private func openPendingMonitoringIfNeeded() {
        guard let monitoringID = appState.pendingMonitoringID else {
            return
        }

        if let monitor = appState.monitors.first(where: { $0.id == monitoringID }) {
            selectedMonitor = monitor
            appState.pendingMonitoringID = nil
        } else {
            appState.pendingMonitoringID = nil
            appState.present(message: "Das Monitoring aus der Benachrichtigung ist nicht mehr verfügbar.")
        }
    }

    private func count(_ tone: MonitorTone) -> Int {
        appState.monitors.filter { $0.tone == tone }.count
    }

    private var emptyStateMessage: String {
        if appState.monitors.isEmpty && appState.isOffline {
            return "Keine Verbindung. Cached Monitorings sind noch nicht verfügbar."
        }

        return "Keine Monitorings gefunden."
    }
}

struct MonitoringFreshnessBanner: View {
    @EnvironmentObject private var appState: AppState

    private var title: String {
        if appState.isOffline {
            return "Offline"
        }

        if appState.isMonitoringDataStale {
            return "Daten möglicherweise veraltet"
        }

        return "Monitoring-Daten aktuell"
    }

    private var message: String {
        guard let lastRefresh = appState.lastMonitoringRefreshAt else {
            return "Noch keine erfolgreiche Synchronisierung."
        }

        return "Zuletzt synchronisiert \(lastRefresh.formatted(date: .abbreviated, time: .shortened))"
    }

    private var iconName: String {
        if appState.isOffline {
            return "wifi.slash"
        }

        if appState.isMonitoringDataStale {
            return "clock.badge.exclamationmark"
        }

        return "checkmark.circle"
    }

    private var color: Color {
        if appState.isOffline {
            return Brand.danger
        }

        if appState.isMonitoringDataStale {
            return Brand.warning
        }

        return Brand.success
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Brand.text)
                Text(message)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Brand.mutedText)

                if appState.isOffline {
                    Button("Erneut versuchen") {
                        Task {
                            await appState.refreshMonitorings()
                        }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.accent)
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .webGuardCard()
    }
}

private struct MaintenanceSummaryCard: View {
    let monitors: [KnownMonitor]

    private var activeCount: Int {
        monitors.filter { $0.maintenanceWindowState == .active }.count
    }

    var body: some View {
        NavigationLink {
            MaintenanceWindowsView(monitors: monitors)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Brand.warning)
                    .frame(width: 42, height: 42)
                    .background(Brand.warningMuted)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Wartungsfenster")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.text)
                    Text("\(activeCount) aktiv · \(monitors.count - activeCount) geplant")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Brand.mutedText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Brand.mutedText)
            }
        }
        .buttonStyle(.plain)
        .webGuardCard()
    }
}

private struct MaintenanceWindowsView: View {
    let monitors: [KnownMonitor]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Aktive und geplante Wartungsfenster")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(Brand.text)

                ForEach(monitors) { monitor in
                    MaintenanceWindowRow(monitor: monitor)
                }
            }
            .padding(20)
            .webGuardContentWidth(900)
        }
        .navigationTitle("Wartungsfenster")
        .navigationBarTitleDisplayMode(.inline)
        .background(Brand.background)
    }
}

private struct MaintenanceWindowRow: View {
    let monitor: KnownMonitor

    private var state: MaintenanceWindowState {
        monitor.maintenanceWindowState ?? .upcoming
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: state == .active ? "wrench.and.screwdriver.fill" : "calendar")
                    .foregroundStyle(Brand.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.name)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.text)
                    Text(monitor.target.isEmpty ? monitor.id : monitor.target)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Brand.mutedText)
                        .lineLimit(1)
                }

                Spacer()

                Text(state.title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Brand.warning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Brand.warningMuted)
                    .clipShape(Capsule())
            }

            if let from = monitor.maintenanceFrom {
                DetailField(label: "Zeitraum", value: maintenancePeriod(from: from, until: monitor.maintenanceUntil))
            }
        }
        .webGuardCard()
    }

    private func maintenancePeriod(from: Date, until: Date?) -> String {
        let start = from.formatted(date: .abbreviated, time: .shortened)

        guard let until else {
            return "Ab \(start)"
        }

        return "\(start) – \(until.formatted(date: .abbreviated, time: .shortened))"
    }
}

struct MonitoringDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var monitor: KnownMonitor
    @State private var detail: MobileMonitoringDetailResponse?
    @State private var isRefreshing = false
    @State private var isLoadingMoreIncidents = false
    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false

    init(monitor: KnownMonitor) {
        _monitor = State(initialValue: monitor)
    }

    private var relatedEvents: [PushEvent] {
        appState.events
            .filter { $0.monitoringID == monitor.id }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    private var displayedName: String {
        detail?.data.summary.name ?? monitor.name
    }

    private var displayedTarget: String {
        detail?.data.summary.target ?? monitor.target
    }

    private var currentTone: MonitorTone {
        if let status = detail?.data.currentCheck.status ?? detail?.data.summary.lifecycleStatus {
            return MonitorTone(rawValue: status) ?? monitor.tone
        }

        return monitor.tone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(displayedName)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)

                        Spacer()

                        StatusPill(
                            tone: currentTone,
                            label: detail?.data.currentCheck.statusLabel
                                ?? detail?.data.currentCheck.status
                                ?? monitor.status
                                ?? "Unknown"
                        )
                    }

                    Text(displayedTarget.isEmpty ? monitor.id : displayedTarget)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(Brand.mutedText)
                        .textSelection(.enabled)
                }
                .webGuardCard()

                if let detail {
                    DetailFreshnessBanner(
                        generatedAt: detail.meta.generatedAt,
                        isOffline: appState.isOffline,
                        hasStaleSections: detail.meta.sections.values.contains { $0.state == .stale }
                    )
                } else if appState.isOffline {
                    DetailUnavailableCard(message: "Keine Verbindung und keine zwischengespeicherten Diagnosedaten für dieses Monitoring.")
                }

                if let detail {
                    serverDetailSections(detail)
                } else if let maintenanceState = monitor.maintenanceWindowState {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            "Wartungsfenster \(maintenanceState.title.lowercased())",
                            systemImage: "wrench.and.screwdriver"
                        )
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.warning)

                        if let from = monitor.maintenanceFrom {
                            DetailField(
                                label: "Zeitraum",
                                value: maintenancePeriod(from: from, until: monitor.maintenanceUntil)
                            )
                        }

                        Text("Der Status wird während des Wartungsfensters als Wartung angezeigt.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Brand.mutedText)
                    }
                    .webGuardCard()
                }

                if detail == nil {
                    VStack(alignment: .leading, spacing: 14) {
                    Text("Status")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.text)

                    DetailField(
                        label: "Letzte Prüfung",
                        value: monitor.lastSeenAt.formatted(date: .abbreviated, time: .shortened)
                    )

                    Button {
                        Task {
                            isRefreshing = true
                            if let refreshed = await appState.refreshMonitoring(monitor.id) {
                                monitor = refreshed
                            }
                            isRefreshing = false
                        }
                    } label: {
                        Label(
                            isRefreshing ? "Wird aktualisiert" : "Status aktualisieren",
                            systemImage: "arrow.clockwise"
                        )
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isRefreshing)
                    }
                    .webGuardCard()
                }

                if detail == nil {
                    VStack(alignment: .leading, spacing: 0) {
                    Text("Letzte Ereignisse")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.text)
                        .padding(.bottom, 12)

                    if relatedEvents.isEmpty {
                        Text("Für dieses Monitoring liegen noch keine Push Events vor.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Brand.mutedText)
                    } else {
                        ForEach(relatedEvents) { event in
                            IncidentTimelineRow(event: event)
                            if event.id != relatedEvents.last?.id {
                                Divider().background(Brand.border)
                            }
                        }
                    }
                    }
                    .webGuardCard()
                }
            }
            .padding(20)
            .webGuardContentWidth(900)
        }
        .navigationTitle("Monitoring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Bearbeiten") { showingEditor = true }
                Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Monitoring löschen")
            }
        }
        .accessibilityIdentifier(WebGuardAccessibilityID.monitoringDetail(monitor.id))
        .background(Brand.background)
        .task {
            detail = appState.monitoringDetail(for: monitor.id)?.payload
            await refreshDetail()
        }
        .sheet(isPresented: $showingEditor) {
            MonitoringEditorView(monitor: monitor) { updated in
                monitor = updated
            }
        }
        .confirmationDialog("Monitoring löschen?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Endgültig löschen", role: .destructive) {
                Task { _ = await appState.deleteMonitoring(monitor.id) }
            }
        } message: {
            Text("Das Monitoring wird serverseitig gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }

    private func maintenancePeriod(from: Date, until: Date?) -> String {
        let start = from.formatted(date: .abbreviated, time: .shortened)

        guard let until else {
            return "Ab \(start)"
        }

        return "\(start) – \(until.formatted(date: .abbreviated, time: .shortened))"
    }

    @ViewBuilder
    private func serverDetailSections(_ detail: MobileMonitoringDetailResponse) -> some View {
        DetailSectionCard(title: "Aktueller Check", section: detail.meta.sections["current_check"]) {
            DetailField(
                label: "Letzte Prüfung",
                value: detail.data.currentCheck.checkedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Nicht verfügbar"
            )
            if let responseTime = detail.data.currentCheck.responseTime {
                DetailField(label: "Antwortzeit", value: "\(Int(responseTime)) ms")
            }
            Button {
                Task { await refreshDetail() }
            } label: {
                Label(isRefreshing ? "Wird aktualisiert" : "Diagnose aktualisieren", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isRefreshing)
        }

        DetailSectionCard(title: "Verfügbarkeit (30 Tage)", section: detail.meta.sections["availability"]) {
            if detail.data.availability.hasData {
                HStack(spacing: 10) {
                    AvailabilityMetric(label: "Verfügbar", value: detail.data.availability.uptime.percentage, color: Brand.success)
                    AvailabilityMetric(label: "Ausfall", value: detail.data.availability.downtime.percentage, color: Brand.danger)
                    AvailabilityMetric(label: "Unbekannt", value: detail.data.availability.unknown.percentage, color: Brand.warning)
                }
                DetailField(label: "Vorfälle", value: "\(detail.data.availability.downtime.incidentsCount ?? detail.data.incidents.count)")
            } else {
                DetailUnavailableCard(message: "Für den gewählten Zeitraum liegen noch keine Verfügbarkeitsdaten vor.")
            }
        }

        DetailSectionCard(title: "Antwortzeiten", section: detail.meta.sections["response_times"]) {
            ResponseTimeChart(points: detail.data.responseTimes.data)
            if let average = detail.data.responseTimes.aggregated.avg {
                DetailField(label: "Durchschnitt", value: "\(Int(average)) ms")
            }
        }

        DetailSectionCard(title: "Vorfälle", section: detail.meta.sections["incidents"]) {
            if detail.data.incidents.isEmpty {
                Text("Für den gewählten Zeitraum liegen keine Vorfälle vor.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
            } else {
                ForEach(detail.data.incidents) { incident in
                    ServerIncidentRow(incident: incident)
                    if incident.id != detail.data.incidents.last?.id {
                        Divider().background(Brand.border)
                    }
                }
            }

            if detail.meta.incidents.hasMore {
                Button(isLoadingMoreIncidents ? "Weitere Vorfälle werden geladen" : "Weitere Vorfälle laden") {
                    Task { await loadMoreIncidents() }
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.accent)
                .disabled(isLoadingMoreIncidents)
                .padding(.top, 8)
            }
        }

        DetailSectionCard(title: "Wartung", section: detail.meta.sections["maintenance"]) {
            if detail.data.maintenance.active {
                Label("Dieses Monitoring befindet sich in einem aktiven Wartungsfenster.", systemImage: "wrench.and.screwdriver.fill")
                    .foregroundStyle(Brand.warning)
            } else if detail.data.maintenance.hasRecurringWindow {
                Label("Ein wiederkehrendes Wartungsfenster ist eingerichtet.", systemImage: "calendar.badge.clock")
                    .foregroundStyle(Brand.mutedText)
            } else {
                Text("Kein aktives Wartungsfenster.")
                    .foregroundStyle(Brand.mutedText)
            }
            if let startsAt = detail.data.maintenance.startsAt {
                DetailField(label: "Beginn", value: startsAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let endsAt = detail.data.maintenance.endsAt {
                DetailField(label: "Ende", value: endsAt.formatted(date: .abbreviated, time: .shortened))
            }
        }

        DetailSectionCard(title: "Zertifikat und Domain", section: detail.meta.sections["ssl"]) {
            CertificateAndDomainDetail(ssl: detail.data.ssl, domain: detail.data.domain, domainSection: detail.meta.sections["domain"])
        }

        DetailSectionCard(title: "Uptime-Kalender", section: detail.meta.sections["uptime_calendar"]) {
            UptimeCalendarPreview(months: detail.data.uptimeCalendar)
        }
    }

    private func refreshDetail() async {
        isRefreshing = true
        if let refreshed = await appState.refreshMonitoringDetail(monitor.id) {
            detail = refreshed
            if let status = refreshed.data.currentCheck.status ?? refreshed.data.summary.lifecycleStatus {
                monitor.status = status
            }
        }
        isRefreshing = false
    }

    private func loadMoreIncidents() async {
        guard let offset = detail?.meta.incidents.nextOffset else {
            return
        }

        isLoadingMoreIncidents = true
        defer { isLoadingMoreIncidents = false }
        guard let next = await appState.refreshMonitoringDetail(monitor.id, incidentOffset: offset),
              var existing = detail else {
            return
        }

        existing.data.incidents += next.data.incidents.filter { candidate in
            !existing.data.incidents.contains(where: { $0.id == candidate.id })
        }
        existing.meta = next.meta
        detail = existing
    }
}

private struct DetailFreshnessBanner: View {
    let generatedAt: Date
    let isOffline: Bool
    let hasStaleSections: Bool

    var body: some View {
        let title = isOffline ? "Offline – gespeicherte Diagnosedaten" : hasStaleSections ? "Teilweise veraltete Diagnosedaten" : "Diagnosedaten aktuell"
        let color = isOffline ? Brand.danger : hasStaleSections ? Brand.warning : Brand.success

        Label(title, systemImage: isOffline ? "wifi.slash" : hasStaleSections ? "clock.badge.exclamationmark" : "checkmark.circle.fill")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(title). Stand \(generatedAt.formatted(date: .abbreviated, time: .shortened))")
            .webGuardCard()
    }
}

private struct DetailSectionCard<Content: View>: View {
    let title: String
    let section: MobileMonitoringDetailSection?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Brand.text)
                Spacer()
                SectionStateBadge(section: section)
            }
            content
        }
        .webGuardCard()
    }
}

private struct SectionStateBadge: View {
    let section: MobileMonitoringDetailSection?

    var body: some View {
        let state = section?.state ?? .unavailable
        Text(label(for: state))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(color(for: state))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color(for: state).opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel("Datenstatus: \(label(for: state))")
    }

    private func label(for state: MobileMonitoringDetailSectionState) -> String {
        switch state {
        case .current: return "Aktuell"
        case .stale: return "Veraltet"
        case .empty: return "Keine Daten"
        case .unavailable: return "Nicht verfügbar"
        }
    }

    private func color(for state: MobileMonitoringDetailSectionState) -> Color {
        switch state {
        case .current: return Brand.success
        case .stale: return Brand.warning
        case .empty, .unavailable: return Brand.mutedText
        }
    }
}

private struct DetailUnavailableCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(Brand.mutedText)
    }
}

private struct AvailabilityMetric: View {
    let label: String
    let value: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.mutedText)
            Text(value.map { String(format: "%.2f%%", $0) } ?? "–")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ResponseTimeChart: View {
    let points: [MobileMonitoringResponseTimePoint]

    var body: some View {
        if points.isEmpty {
            DetailUnavailableCard(message: "Für den gewählten Zeitraum liegen keine Antwortzeitmessungen vor.")
        } else {
            let displayed = Array(points.suffix(12))
            let maximum = max(displayed.compactMap(\.avg).max() ?? 1, 1)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(displayed) { point in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Brand.accent)
                                .frame(height: max(8, CGFloat((point.avg ?? 0) / maximum) * 88))
                            Text(point.date.formatted(.dateTime.hour()))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(Brand.mutedText)
                        }
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .accessibilityLabel("\(point.date.formatted(date: .abbreviated, time: .shortened)): \(Int(point.avg ?? 0)) Millisekunden")
                    }
                }
                .frame(height: 118, alignment: .bottom)
                Text("Letzte \(displayed.count) Messpunkte")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
            }
        }
    }
}

private struct ServerIncidentRow: View {
    let incident: MobileMonitoringIncident

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: incident.upAt == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(incident.upAt == nil ? Brand.danger : Brand.success)
            VStack(alignment: .leading, spacing: 3) {
                Text(incident.upAt == nil ? "Aktiver Vorfall" : "Wiederhergestellt")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.text)
                Text("Beginn \(incident.downAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                if let upAt = incident.upAt {
                    Text("Ende \(upAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Brand.mutedText)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CertificateAndDomainDetail: View {
    let ssl: MobileMonitoringSsl?
    let domain: MobileMonitoringDomain?
    let domainSection: MobileMonitoringDetailSection?

    var body: some View {
        if ssl == nil && domain == nil {
            DetailUnavailableCard(message: "Für dieses Monitoring sind keine Zertifikats- oder Domaindaten verfügbar.")
        } else {
            if let ssl {
                DetailField(label: "Zertifikat", value: ssl.valid == true ? "Gültig" : ssl.valid == false ? "Ungültig" : "Unbekannt")
                if let expiration = ssl.expiration {
                    DetailField(label: "Zertifikat läuft ab", value: expiration.formatted(date: .abbreviated, time: .shortened))
                }
            }
            if let domain {
                DetailField(label: "Domain", value: domain.valid == true ? "Gültig" : domain.valid == false ? "Ungültig" : "Unbekannt")
                if let expiresAt = domain.expiresAt {
                    DetailField(label: "Domain läuft ab", value: expiresAt.formatted(date: .abbreviated, time: .shortened))
                }
            } else if domainSection?.state == .unavailable {
                Text("Domaindaten nicht verfügbar.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
            }
        }
    }
}

private struct UptimeCalendarPreview: View {
    let months: [String: MobileMonitoringCalendarMonth]

    private var days: [MobileMonitoringCalendarDay] {
        months.values.flatMap(\.days).suffix(21).reversed()
    }

    var body: some View {
        if days.isEmpty {
            DetailUnavailableCard(message: "Noch keine Kalendereinträge verfügbar.")
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: day.uptimePercentage))
                        .frame(height: 24)
                        .accessibilityLabel("\(day.date): \(day.uptimePercentage.map { String(format: "%.2f Prozent verfügbar", $0) } ?? "keine Daten")")
                }
            }
        }
    }

    private func color(for uptime: Double?) -> Color {
        guard let uptime else { return Brand.border }
        if uptime >= 99.9 { return Brand.success }
        if uptime >= 95 { return Brand.warning }
        return Brand.danger
    }
}

private struct IncidentTimelineRow: View {
    let event: PushEvent

    private var isRecovery: Bool {
        event.eventType == "recovery"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isRecovery ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isRecovery ? Brand.success : Brand.danger)

            VStack(alignment: .leading, spacing: 4) {
                Text(isRecovery ? "Wiederhergestellt" : "Vorfall")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.text)
                Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
            }

            Spacer()

            Text(event.severity.capitalized)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.mutedText)
        }
        .padding(.vertical, 10)
    }
}

private struct MaintenanceWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showingScheduler = false

    var body: some View {
        NavigationStack {
            List {
                Section("Einmalige Wartung") {
                    ForEach(appState.oneOffMaintenance) { window in
                        MaintenanceRow(window: window) { Task { await appState.cancelOneOffMaintenance(window) } }
                    }
                }
                Section("Wiederkehrende Wartung") {
                    ForEach(appState.recurringMaintenance) { window in
                        VStack(alignment: .leading, spacing: 6) {
                            MaintenanceRow(window: window, cancel: nil)
                            if window.canManage {
                                Toggle("Aktiv", isOn: Binding(
                                    get: { window.enabled },
                                    set: { enabled in
                                        Task { await appState.setRecurringMaintenanceEnabled(window, enabled: enabled) }
                                    }
                                ))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Wartung")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button { showingScheduler = true } label: { Image(systemName: "plus") }.disabled(appState.maintenanceCapabilities?.canSchedule != true) } }
            .task { await appState.refreshMaintenance() }
            .refreshable { await appState.refreshMaintenance() }
            .sheet(isPresented: $showingScheduler) { MaintenanceSchedulerView() }
        }
    }
}

private struct MaintenanceRow: View {
    let window: MobileMaintenanceWindow
    let cancel: (() -> Void)?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(window.target.name ?? window.target.id).font(.headline)
            Text("\(window.state.capitalized) · \(window.schedule.nextOccurrence ?? window.schedule.startsAt ?? .distantPast, format: .dateTime.day().month().hour().minute())").font(.footnote).foregroundStyle(Brand.mutedText)
            if let recurrence = window.schedule.recurrence { Text("\(recurrence) · \(window.schedule.timezone)").font(.footnote).foregroundStyle(Brand.mutedText) }
            if let cancel, window.canManage { Button("Wartung abbrechen", role: .destructive, action: cancel).font(.footnote) }
        }
    }
}

private struct MaintenanceSchedulerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var mode = "one_off"; @State private var monitoringID = ""; @State private var startsAt = Date().addingTimeInterval(3600); @State private var endsAt = Date().addingTimeInterval(7200); @State private var recurrence = "weekly"
    var body: some View {
        NavigationStack { Form {
            Picker("Art", selection: $mode) { Text("Einmalig").tag("one_off"); Text("Wiederkehrend").tag("recurring") }
            Picker("Monitoring", selection: $monitoringID) { ForEach(appState.maintenanceCapabilities?.manageableMonitorings ?? []) { Text($0.name).tag($0.id) } }
            DatePicker("Beginn", selection: $startsAt)
            if mode == "one_off" { DatePicker("Ende", selection: $endsAt) } else { Picker("Wiederholung", selection: $recurrence) { Text("Wöchentlich").tag("weekly"); Text("Monatlich").tag("monthly") }; Text("Die nächste Ausführung wird nach dem Speichern serverseitig mit Zeitzone und DST berechnet.").font(.footnote).foregroundStyle(Brand.mutedText) }
        }.navigationTitle("Wartung planen").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Planen") { Task { await save() } }.disabled(monitoringID.isEmpty) } } }.task { if monitoringID.isEmpty { monitoringID = appState.maintenanceCapabilities?.manageableMonitorings.first?.id ?? "" } }
    }
    private func save() async {
        let payload = MaintenanceSchedulePayload(mode: mode, scope: "monitoring", monitoringID: monitoringID, monitoringGroupID: nil, maintenanceFrom: mode == "one_off" ? startsAt : nil, maintenanceUntil: mode == "one_off" ? endsAt : nil, recurringStartsAt: mode == "recurring" ? startsAt : nil, recurringDurationMinutes: mode == "recurring" ? 60 : nil, recurrence: mode == "recurring" ? recurrence : nil, recurringTimezone: mode == "recurring" ? TimeZone.current.identifier : nil, idempotencyKey: UUID().uuidString)
        if await appState.scheduleMaintenance(payload) { dismiss() }
    }
}

private struct CollaborationWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editingGroup: MobileMonitoringGroup?
    @State private var showingNewGroup = false

    var body: some View {
        NavigationStack {
            List {
                Section("Teams") {
                    if appState.teams.isEmpty {
                        Text("Keine Teams sichtbar.").foregroundStyle(Brand.mutedText)
                    } else {
                        ForEach(appState.teams) { team in
                            VStack(alignment: .leading) {
                                Text(team.name).font(.headline)
                                if let description = team.description, !description.isEmpty { Text(description).font(.footnote).foregroundStyle(Brand.mutedText) }
                            }
                        }
                    }
                }
                Section("Private Monitoring-Gruppen") {
                    ForEach(appState.monitoringGroups) { group in
                        Button { editingGroup = group } label: {
                            VStack(alignment: .leading) {
                                Text(group.name).foregroundStyle(Brand.text)
                                Text("\(group.assignableMonitoringCount) zuweisbare Monitorings").font(.footnote).foregroundStyle(Brand.mutedText)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { Task { _ = await appState.deleteMonitoringGroup(appState.monitoringGroups[index].id) } }
                    }
                }
                Section("Ownership") {
                    ForEach(appState.monitors) { monitoring in
                        Menu {
                            ForEach(appState.teams) { team in
                                Button("Team: \(team.name)") { Task { _ = await appState.setMonitoringOwnership(monitoring, teamID: team.id) } }
                            }
                            Button("Privat verwalten") { Task { _ = await appState.setMonitoringOwnership(monitoring, teamID: nil) } }
                        } label: {
                            HStack { Text(monitoring.name); Spacer(); Image(systemName: "person.2") }
                        }
                    }
                    Text("Nur serverseitig autorisierte Team-Administratoren können Ownership ändern; Team-Monitorings werden aus privaten Gruppen entfernt.")
                        .font(.footnote).foregroundStyle(Brand.mutedText)
                }
            }
            .navigationTitle("Zusammenarbeit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button { showingNewGroup = true } label: { Image(systemName: "plus") } }
            }
            .task { await appState.refreshCollaboration() }
            .refreshable { await appState.refreshCollaboration() }
            .sheet(item: $editingGroup) { group in MonitoringGroupEditorView(group: group) }
            .sheet(isPresented: $showingNewGroup) { MonitoringGroupEditorView(group: nil) }
        }
    }
}

private struct MonitoringGroupEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let group: MobileMonitoringGroup?
    @State private var name: String
    @State private var description: String
    @State private var selectedIDs: Set<String>

    init(group: MobileMonitoringGroup?) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
        _description = State(initialValue: group?.description ?? "")
        _selectedIDs = State(initialValue: Set(group?.assignments.map(\.id) ?? []))
    }

    private var assignable: [KnownMonitor] { appState.monitors.filter { $0.ownership?.type != "team" } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gruppe") {
                    TextField("Name", text: $name)
                    TextField("Beschreibung", text: $description, axis: .vertical)
                }
                Section("Private Monitorings") {
                    ForEach(assignable) { monitoring in
                        Toggle(monitoring.name, isOn: selectionBinding(for: monitoring.id))
                    }
                }
            }
            .navigationTitle(group == nil ? "Gruppe erstellen" : "Gruppe bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        let saved = await appState.saveMonitoringGroup(
            id: group?.id,
            payload: MonitoringGroupMutationPayload(name: name, description: description.isEmpty ? nil : description, monitoringIDs: Array(selectedIDs))
        )
        if saved { dismiss() }
    }

    private func selectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(id) },
            set: { selected in
                if selected {
                    selectedIDs.insert(id)
                } else {
                    selectedIDs.remove(id)
                }
            }
        )
    }
}

private struct MonitoringEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let monitor: KnownMonitor?
    let onSaved: (KnownMonitor) -> Void
    @State private var name: String
    @State private var target: String
    @State private var type: String
    @State private var status: String
    @State private var port: String
    @State private var isSaving = false

    init(monitor: KnownMonitor?, onSaved: @escaping (KnownMonitor) -> Void) {
        self.monitor = monitor
        self.onSaved = onSaved
        _name = State(initialValue: monitor?.name ?? "")
        _target = State(initialValue: monitor?.target ?? "")
        _type = State(initialValue: monitor?.type ?? "http")
        _status = State(initialValue: monitor?.status == "paused" ? "paused" : "active")
        _port = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Grunddaten") {
                    TextField("Name", text: $name)
                    TextField("Ziel", text: $target)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Typ", selection: $type) {
                        Text("HTTP").tag("http")
                        Text("Ping").tag("ping")
                        Text("Port").tag("port")
                    }
                    Picker("Status", selection: $status) {
                        Text("Aktiv").tag("active")
                        Text("Pausiert").tag("paused")
                    }
                }
                if type == "port" {
                    Section("Port-Konfiguration") {
                        TextField("Port", text: $port).keyboardType(.numberPad)
                    }
                }
                Section {
                    Text("Ein Erstellen wird bei unbekanntem Ergebnis nicht automatisch wiederholt. Änderungen und Löschen verwenden die serverseitig definierten idempotenten Methoden.")
                        .font(.footnote)
                        .foregroundStyle(Brand.mutedText)
                }
            }
            .navigationTitle(monitor == nil ? "Monitoring erstellen" : "Monitoring bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Speichern…" : "Speichern") { Task { await save() } }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (type == "port" && Int(port) == nil))
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let payload = MonitoringMutationPayload(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            target: target.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            status: status,
            timeout: type == "http" ? 10 : nil,
            httpMethod: type == "http" ? "GET" : nil,
            expectedHTTPStatuses: type == "http" ? "200-299" : nil,
            httpHeaders: type == "http" ? [:] : nil,
            port: type == "port" ? Int(port) : nil
        )
        if let saved = await appState.saveMonitoring(id: monitor?.id, payload: payload) {
            onSaved(saved)
            dismiss()
        }
    }
}

private enum MonitorFilter {
    case systems
    case all
}

struct HeaderBar: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Brand.accent)
                .frame(width: 34, height: 34)
                .background(Brand.accent.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(Brand.accent, lineWidth: 1))

            Text("WebGuard")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Brand.text)

            Spacer()

            Image(systemName: "bell")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Brand.text)
        }
    }
}

struct MetricTile: View {
    var label: String
    var value: Int
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.mutedText)
            Text("\(value)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .webGuardCard()
    }
}

struct MonitorRow: View {
    var monitor: KnownMonitor

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(toneColor)
                .frame(width: 48, height: 48)
                .background(toneMutedColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(monitor.name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Brand.text)
                    .lineLimit(1)
                Text(monitor.target.isEmpty ? monitor.id : monitor.target)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusPill(tone: monitor.tone, label: monitor.status ?? "Unknown")
        }
        .padding(.vertical, 12)
    }

    private var iconName: String {
        let value = "\(monitor.name) \(monitor.target)".lowercased()

        if value.contains("cron") || value.contains("job") {
            return "chevron.left.forwardslash.chevron.right"
        }

        if value.contains("server") {
            return "server.rack"
        }

        if value.contains("db") || value.contains("datenbank") {
            return "cylinder.split.1x2"
        }

        return "globe"
    }

    private var toneColor: Color {
        switch monitor.tone {
        case .up:
            return Brand.success
        case .down:
            return Brand.danger
        case .maintenance:
            return Brand.warning
        case .unknown:
            return Brand.mutedText
        }
    }

    private var toneMutedColor: Color {
        switch monitor.tone {
        case .up:
            return Brand.successMuted
        case .down:
            return Brand.dangerMuted
        case .maintenance:
            return Brand.warningMuted
        case .unknown:
            return Brand.border
        }
    }
}

struct StatusPill: View {
    var tone: MonitorTone
    var label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(displayLabel)
                .font(.system(size: 12, weight: .black, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(background)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayLabel)
    }

    private var displayLabel: String {
        if tone == .maintenance {
            return "MAINTENANCE"
        }

        let value = label.lowercased()

        if value.contains("up") || value == "active" {
            return "UP"
        }

        if value.contains("down") || value.contains("fail") {
            return "DOWN"
        }

        if value.contains("maintenance") {
            return "MAINTENANCE"
        }

        return "UNKNOWN"
    }

    private var color: Color {
        switch tone {
        case .up:
            return Brand.success
        case .down:
            return Brand.danger
        case .maintenance:
            return Brand.warning
        case .unknown:
            return Brand.mutedText
        }
    }

    private var background: Color {
        switch tone {
        case .up:
            return Brand.successMuted
        case .down:
            return Brand.dangerMuted
        case .maintenance:
            return Brand.warningMuted
        case .unknown:
            return Brand.border
        }
    }
}
