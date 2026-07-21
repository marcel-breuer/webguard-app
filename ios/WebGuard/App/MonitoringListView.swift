import SwiftUI

struct MonitoringListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var filter: MonitorFilter = .systems

    private var filteredMonitors: [KnownMonitor] {
        let base = filter == .systems ? appState.monitors.filter { $0.status != nil } : appState.monitors
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalized.isEmpty else { return base }

        return base.filter {
            $0.name.lowercased().contains(normalized)
                || $0.target.lowercased().contains(normalized)
                || $0.id.lowercased().contains(normalized)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MONITORINGS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.3)
                            .foregroundStyle(Brand.mutedText)
                        Text("Service-Landkarte")
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)
                    }

                    Picker("Filter", selection: $filter) {
                        Text("Aktive Systeme").tag(MonitorFilter.systems)
                        Text("Alle").tag(MonitorFilter.all)
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                        MetricTile(label: "Up", value: count(.up), tone: .up)
                        MetricTile(label: "Down", value: count(.down), tone: .down)
                        MetricTile(label: "Wartung", value: count(.maintenance), tone: .maintenance)
                        MetricTile(label: "Gesamt", value: appState.monitors.count, tone: .unknown)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Brand.mutedText)
                        TextField("Monitoring suchen", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(13)
                    .background(Brand.surface)
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Brand.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                    VStack(spacing: 0) {
                        if filteredMonitors.isEmpty {
                            Text("Keine Monitorings gefunden.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(Brand.mutedText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                        } else {
                            ForEach(filteredMonitors) { monitor in
                                NavigationLink {
                                    MonitoringDetailView(monitor: monitor)
                                } label: {
                                    MonitorRow(monitor: monitor)
                                }
                                .buttonStyle(.plain)
                                if monitor.id != filteredMonitors.last?.id {
                                    Divider().background(Brand.border)
                                }
                            }
                        }
                    }
                    .webGuardCard()
                }
                .padding(20)
                .webGuardContentWidth(1040)
            }
            .refreshable {
                await appState.refreshOverview()
            }
            .task {
                if appState.monitors.isEmpty {
                    await appState.refreshOverview()
                }
            }
            .background(Brand.background)
            .navigationTitle("Monitorings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func count(_ tone: MonitorTone) -> Int {
        appState.monitors.filter { $0.tone == tone }.count
    }
}

private enum MonitorFilter {
    case systems
    case all
}

private struct MetricTile: View {
    let label: String
    let value: Int
    let tone: MonitorTone

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(value)")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(tone.color)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Brand.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .webGuardCard()
    }
}

private struct MonitorRow: View {
    let monitor: KnownMonitor

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(monitor.tone.color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(monitor.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.text)
                    .lineLimit(1)
                Text(monitor.target.isEmpty ? monitor.id : monitor.target)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            WebGuardStatusBadge(tone: monitor.tone, label: nil)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Brand.mutedText)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
