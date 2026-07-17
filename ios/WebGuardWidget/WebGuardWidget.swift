import AppIntents
import SwiftUI
import WidgetKit

struct WidgetMonitoringEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Monitoring")
    static var defaultQuery = WidgetMonitoringQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct WidgetMonitoringQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetMonitoringEntity] {
        let monitors = WidgetSnapshotStore.load()?.monitors ?? []
        return monitors
            .filter { identifiers.contains($0.id) }
            .map { WidgetMonitoringEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [WidgetMonitoringEntity] {
        let monitors = WidgetSnapshotStore.load()?.monitors ?? []
        return monitors.map { WidgetMonitoringEntity(id: $0.id, name: $0.name) }
    }
}

struct WebGuardWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Monitoring anzeigen"
    static var description = IntentDescription("Zeigt den aktuellen WebGuard-Status an.")

    @Parameter(title: "Monitoring")
    var monitoring: WidgetMonitoringEntity?
}

struct WebGuardWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let selectedMonitoringID: String?
}

struct WebGuardWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = WebGuardWidgetEntry
    typealias Intent = WebGuardWidgetConfiguration

    func placeholder(in context: Context) -> WebGuardWidgetEntry {
        WebGuardWidgetEntry(
            date: Date(),
            snapshot: WidgetSnapshot(
                generatedAt: Date(),
                monitors: [
                    WidgetMonitorSnapshot(
                        id: "placeholder",
                        name: "WebGuard",
                        target: "example.com",
                        status: "up",
                        isDown: false,
                        isMaintenance: false
                    )
                ]
            ),
            selectedMonitoringID: nil
        )
    }

    func snapshot(for configuration: WebGuardWidgetConfiguration, in context: Context) async -> WebGuardWidgetEntry {
        makeEntry(for: configuration)
    }

    func timeline(for configuration: WebGuardWidgetConfiguration, in context: Context) async -> Timeline<WebGuardWidgetEntry> {
        let entry = makeEntry(for: configuration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
    }

    private func makeEntry(for configuration: WebGuardWidgetConfiguration) -> WebGuardWidgetEntry {
        WebGuardWidgetEntry(
            date: Date(),
            snapshot: WidgetSnapshotStore.load(),
            selectedMonitoringID: configuration.monitoring?.id
        )
    }
}

struct WebGuardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WebGuardWidgetEntry

    private var selectedMonitor: WidgetMonitorSnapshot? {
        guard let selectedMonitoringID = entry.selectedMonitoringID else {
            return nil
        }

        return entry.snapshot?.monitors.first { $0.id == selectedMonitoringID }
    }

    private var monitors: [WidgetMonitorSnapshot] {
        entry.snapshot?.monitors ?? []
    }

    private var downCount: Int {
        monitors.filter(\.isDown).count
    }

    private var maintenanceCount: Int {
        monitors.filter(\.isMaintenance).count
    }

    var body: some View {
        Group {
            if let selectedMonitor {
                selectedMonitoringView(selectedMonitor)
            } else {
                overviewView
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.08, blue: 0.12)
        }
        .widgetURL(widgetURL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var widgetURL: URL {
        if let selectedMonitoringID = entry.selectedMonitoringID,
           let url = WidgetDeepLink.monitoring(selectedMonitoringID) {
            return url
        }

        return WidgetDeepLink.overview
    }

    private var accessibilityLabel: String {
        if let selectedMonitor {
            return "\(selectedMonitor.name), \(selectedMonitor.statusLabel)"
        }

        if entry.snapshot == nil {
            return "WebGuard, nicht verbunden"
        }

        return "WebGuard, \(monitors.count) Monitorings, \(downCount) Down, \(maintenanceCount) in Wartung"
    }

    private var overviewView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("WebGuard", systemImage: "shield.checkered")
                .font(.headline)
                .foregroundStyle(.white)

            if entry.snapshot == nil {
                statusLine(title: "Nicht verbunden", color: .gray)
            } else if downCount > 0 {
                statusLine(title: "\(downCount) Down", color: .red)
            } else if maintenanceCount > 0 {
                statusLine(title: "\(maintenanceCount) Wartung", color: .orange)
            } else {
                statusLine(title: "Alle Systeme stabil", color: .green)
            }

            HStack(spacing: 12) {
                metric(value: monitors.count, label: "Monitorings")
                metric(value: downCount, label: "Down")
            }

            updatedLabel
        }
        .padding()
    }

    private func selectedMonitoringView(_ monitor: WidgetMonitorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("WebGuard", systemImage: "shield.checkered")
                .font(.headline)
                .foregroundStyle(.white)

            Text(monitor.name)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .lineLimit(2)

            statusLine(
                title: monitor.statusLabel,
                color: monitor.isDown ? .red : monitor.isMaintenance ? .orange : .green
            )

            Text(monitor.target.isEmpty ? monitor.id : monitor.target)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            updatedLabel
        }
        .padding()
    }

    private var updatedLabel: some View {
        Group {
            if let generatedAt = entry.snapshot?.generatedAt {
                Text("Sync \(generatedAt, style: .relative)")
            } else {
                Text("Noch keine Daten")
            }
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.55))
    }

    private func statusLine(title: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }

    private func metric(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
    }
}

struct WebGuardWidget: Widget {
    let kind = "WebGuardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: WebGuardWidgetConfiguration.self,
            provider: WebGuardWidgetProvider()
        ) { entry in
            WebGuardWidgetView(entry: entry)
        }
        .configurationDisplayName("WebGuard Status")
        .description("Gesamtstatus oder ein ausgewähltes Monitoring auf dem Home-Bildschirm.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WebGuardWidgetBundle: WidgetBundle {
    var body: some Widget {
        WebGuardWidget()
    }
}

#Preview(as: .systemSmall) {
    WebGuardWidget()
} timeline: {
    WebGuardWidgetEntry(
        date: Date(),
        snapshot: WidgetSnapshot(
            generatedAt: Date(),
            monitors: [
                WidgetMonitorSnapshot(
                    id: "preview",
                    name: "Production",
                    target: "example.com",
                    status: "up",
                    isDown: false,
                    isMaintenance: false
                )
            ]
        ),
        selectedMonitoringID: nil
    )
}
