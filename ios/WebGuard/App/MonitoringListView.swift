import SwiftUI

struct MonitoringListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var filter: MonitorFilter = .systems
    @State private var selectedMonitor: KnownMonitor?

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

                    Text("Monitorings")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.text)

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
                                Divider().background(Brand.border)
                            }
                        }
                    }
                    .webGuardCard()
                }
                .padding(20)
                .webGuardContentWidth(1040)
            }
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
            appState.errorMessage = "Das Monitoring aus der Benachrichtigung ist nicht mehr verfügbar."
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
    @State private var isRefreshing = false

    init(monitor: KnownMonitor) {
        _monitor = State(initialValue: monitor)
    }

    private var relatedEvents: [PushEvent] {
        appState.events
            .filter { $0.monitoringID == monitor.id }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(monitor.name)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)

                        Spacer()

                        StatusPill(tone: monitor.tone, label: monitor.status ?? "Unknown")
                    }

                    Text(monitor.target.isEmpty ? monitor.id : monitor.target)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(Brand.mutedText)
                        .textSelection(.enabled)
                }
                .webGuardCard()

                if let maintenanceState = monitor.maintenanceWindowState {
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
            .padding(20)
            .webGuardContentWidth(900)
        }
        .navigationTitle("Monitoring")
        .navigationBarTitleDisplayMode(.inline)
        .background(Brand.background)
    }

    private func maintenancePeriod(from: Date, until: Date?) -> String {
        let start = from.formatted(date: .abbreviated, time: .shortened)

        guard let until else {
            return "Ab \(start)"
        }

        return "\(start) – \(until.formatted(date: .abbreviated, time: .shortened))"
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
