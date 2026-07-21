import SwiftUI

struct OperationsOverviewView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OverviewIntro(overview: appState.overview)

                    if appState.overview.summary.total == 0 {
                        OverviewEmptyState()
                    } else {
                        HealthSummaryCard(summary: appState.overview.summary, state: appState.overview.overallState)

                        if !appState.overview.attention.isEmpty {
                            AttentionCard(items: appState.overview.attention, monitors: appState.monitors)
                        }

                        ServiceLandscapeCard(services: appState.overview.services)

                        if !appState.overview.maintenance.isEmpty {
                            MaintenanceContextCard(items: appState.overview.maintenance, monitors: appState.monitors)
                        }

                        if !appState.overview.recentIncidents.isEmpty {
                            RecentIncidentsCard(items: appState.overview.recentIncidents, monitors: appState.monitors)
                        }

                        NextActionCard(overview: appState.overview)
                    }
                }
                .padding(20)
                .webGuardContentWidth(1080)
            }
            .accessibilityIdentifier(WebGuardAccessibilityID.overview)
            .background(Brand.background)
            .refreshable {
                await appState.refreshOverview()
            }
            .task {
                if appState.overview.services.isEmpty && !appState.monitors.isEmpty {
                    await appState.refreshOverview()
                }
            }
            .navigationTitle("Übersicht")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(Brand.accent)
                        .accessibilityLabel("Benachrichtigungen")
                }
            }
        }
    }
}

private struct OverviewIntro: View {
    let overview: MobileOverviewPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 9, height: 9)
                Text("SYSTEMSIGNAL")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(stateColor)
            }

            Text("Signal Room")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Brand.text)

            Text(overview.summary.down + overview.summary.unknown > 0
                ? "Einige Dienste benötigen deine Aufmerksamkeit."
                : "Alle wichtigen Dienste sind unter Kontrolle.")
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(Brand.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Brand.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Brand.accent.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var stateColor: Color {
        switch overview.overallState {
        case .healthy: return Brand.success
        case .degraded: return Brand.danger
        case .attention: return Brand.warning
        case .new: return Brand.accent
        }
    }
}

private struct OverviewEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Brand.accent)
                .frame(width: 56, height: 56)
                .background(Brand.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Noch keine Monitorings")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.text)
            Text("Sobald dein Account Monitorings enthält, erscheint hier die operative Übersicht.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Brand.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .webGuardCard()
    }
}

private struct HealthSummaryCard: View {
    let summary: OverviewSummary
    let state: OverviewState

    private var percentage: Double {
        guard summary.total > 0 else { return 0 }
        return Double(summary.healthy) / Double(summary.total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Brand.border, lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: percentage)
                        .stroke(stateColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(percentage * 100))%")
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)
                        Text("gesund")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Brand.mutedText)
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 6) {
                    Text("GESAMT · \(summary.total)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Brand.mutedText)
                    Text(stateTitle)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.text)
                    Text(stateDescription)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Brand.mutedText)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SummaryMetric(label: "Up", value: summary.healthy, tone: .up)
                SummaryMetric(label: "Down", value: summary.down, tone: .down)
                SummaryMetric(label: "Unknown", value: summary.unknown, tone: .unknown)
                SummaryMetric(label: "Wartung", value: summary.maintenance, tone: .maintenance)
                SummaryMetric(label: "Pausiert", value: summary.paused, tone: .unknown)
            }
        }
        .webGuardCard()
        .accessibilityIdentifier(WebGuardAccessibilityID.overviewHealthSummary)
    }

    private var stateColor: Color {
        switch state {
        case .healthy: return Brand.success
        case .degraded: return Brand.danger
        case .attention: return Brand.warning
        case .new: return Brand.accent
        }
    }

    private var stateTitle: String {
        switch state {
        case .healthy: return "Alles im grünen Bereich"
        case .degraded: return "Systemsignal beeinträchtigt"
        case .attention: return "Prüfung empfohlen"
        case .new: return "Übersicht wird vorbereitet"
        }
    }

    private var stateDescription: String {
        switch state {
        case .healthy: return "Keine offenen Statusprobleme erkannt."
        case .degraded: return "Mindestens ein Monitoring ist derzeit ausgefallen."
        case .attention: return "Mindestens ein Monitoring liefert kein aktuelles Signal."
        case .new: return "Lege ein Monitoring an, um den Systemzustand zu sehen."
        }
    }
}

private struct SummaryMetric: View {
    let label: String
    let value: Int
    let tone: MonitorTone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(tone.color)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Brand.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AttentionCard: View {
    let items: [OverviewAttention]
    let monitors: [KnownMonitor]

    var body: some View {
        DashboardSection(title: "Aufmerksamkeit", subtitle: "Nächste sinnvolle Aktion") {
            ForEach(items) { item in
                if let monitor = monitor(for: item) {
                    NavigationLink {
                        MonitoringDetailView(monitor: monitor)
                    } label: {
                        AttentionRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(WebGuardAccessibilityID.attention(item.id))
                } else {
                    AttentionRow(item: item)
                        .accessibilityIdentifier(WebGuardAccessibilityID.attention(item.id))
                }
            }
        }
        .accessibilityIdentifier(WebGuardAccessibilityID.overviewAttention)
    }

    private func monitor(for item: OverviewAttention) -> KnownMonitor? {
        guard let id = item.monitoringID else { return nil }
        return monitors.first { $0.id == id }
    }
}

private struct AttentionRow: View {
    let item: OverviewAttention

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type == "incident" || item.type == "down" ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                .foregroundStyle(item.type == "incident" || item.type == "down" ? Brand.danger : Brand.warning)
                .frame(width: 34, height: 34)
                .background((item.type == "incident" || item.type == "down" ? Brand.danger : Brand.warning).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.monitoringName ?? "Benachrichtigungszustellung")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.text)
                Text(item.monitoringTarget ?? (item.count.map { "\($0) fehlgeschlagene Zustellungen" } ?? "Status prüfen"))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Brand.mutedText)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

private struct ServiceLandscapeCard: View {
    let services: [OverviewService]

    var body: some View {
        DashboardSection(title: "Service-Landkarte", subtitle: "\(services.count) sichtbare Monitorings") {
            ForEach(groupedServices, id: \.key) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.key)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Brand.mutedText)
                    ForEach(group.value) { service in
                        NavigationLink {
                            MonitoringDetailView(monitor: KnownMonitor(
                                id: service.id,
                                name: service.name,
                                target: service.target,
                                status: service.status,
                                lastSeenAt: service.lastCheckedAt ?? Date()
                            ))
                        } label: {
                            ServiceLandscapeRow(service: service)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(WebGuardAccessibilityID.service(service.id))
                    }
                }
                .padding(.bottom, 5)
            }
        }
        .accessibilityIdentifier(WebGuardAccessibilityID.overviewServiceLandscape)
    }

    private var groupedServices: [(key: String, value: [OverviewService])] {
        Dictionary(grouping: services, by: \.group)
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }
}

private struct ServiceLandscapeRow: View {
    let service: OverviewService

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .fill(service.tone.color)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(service.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.text)
                    .lineLimit(1)
                Text(service.target)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                WebGuardStatusBadge(tone: service.tone, label: nil)
                if let responseTimeMs = service.responseTimeMs {
                    Text("\(Int(responseTimeMs)) ms")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Brand.mutedText)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Brand.mutedText)
        }
        .padding(12)
        .background(service.tone.background.opacity(0.45))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(service.tone.color.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MaintenanceContextCard: View {
    let items: [OverviewMaintenance]
    let monitors: [KnownMonitor]

    var body: some View {
        DashboardSection(title: "Maintenance", subtitle: "Aktiv und bevorstehend") {
            ForEach(items) { item in
                NavigationLink {
                    MonitoringDetailView(monitor: monitor(for: item))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Brand.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.monitoringName)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Brand.text)
                            Text(item.startsAt?.formatted(date: .abbreviated, time: .shortened) ?? "Zeitplan nicht verfügbar")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Brand.mutedText)
                        }
                        Spacer()
                        Text(item.status == "active" ? "Aktiv" : "Bevorstehend")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(item.status == "active" ? Brand.warning : Brand.accent)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func monitor(for item: OverviewMaintenance) -> KnownMonitor {
        monitors.first { $0.id == item.monitoringID }
            ?? KnownMonitor(id: item.monitoringID, name: item.monitoringName, target: item.monitoringTarget, status: "maintenance", lastSeenAt: item.startsAt ?? Date())
    }
}

private struct RecentIncidentsCard: View {
    let items: [OverviewIncident]
    let monitors: [KnownMonitor]

    var body: some View {
        DashboardSection(title: "Letzte Incidents", subtitle: "Aktuelle Vorfälle und Recoveries") {
            ForEach(items) { item in
                if let monitor = monitors.first(where: { $0.id == item.monitoringID }) {
                    NavigationLink {
                        MonitoringDetailView(monitor: monitor)
                    } label: {
                        incidentRow(item)
                    }
                    .buttonStyle(.plain)
                } else {
                    incidentRow(item)
                }
            }
        }
    }

    private func incidentRow(_ item: OverviewIncident) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.resolved ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(item.resolved ? Brand.success : Brand.danger)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.monitoringName ?? "Unbekanntes Monitoring")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.text)
                Text(item.resolved ? "Wiederhergestellt" : "Offener Incident")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
            }
            Spacer()
            Text((item.upAt ?? item.downAt)?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Brand.mutedText)
        }
        .padding(.vertical, 8)
    }
}

private struct NextActionCard: View {
    let overview: MobileOverviewPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NÄCHSTE AKTION")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Brand.accent)
                    Text(actionTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.text)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(Brand.accent)
                    .frame(width: 38, height: 38)
                    .background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text("Nutze die Übersicht, um den operativen Zustand deines Accounts schnell zu beurteilen.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Brand.mutedText)
        }
        .padding(20)
        .background(Brand.accentSoft)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Brand.accent.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier(WebGuardAccessibilityID.overviewNextAction)
    }

    private var actionTitle: String {
        switch overview.recommendedAction {
        case "incidents": return "Offene Incidents prüfen"
        case "unknown": return "Unklare Monitorings prüfen"
        case "notifications": return "Benachrichtigungszustellung prüfen"
        case "maintenance": return "Maintenance-Zeitplan prüfen"
        case "create": return "Erstes Monitoring anlegen"
        default: return "Monitorings beobachten"
        }
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.text)
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
            }
            .padding(.bottom, 10)

            content
        }
        .webGuardCard()
    }
}
