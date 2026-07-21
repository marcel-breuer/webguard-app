import SwiftUI

struct MonitoringDetailView: View {
    @EnvironmentObject private var appState: AppState
    let monitor: KnownMonitor
    @State private var statusPayload: MonitoringStatusPayload?
    @State private var isLoading = false

    private var tone: MonitorTone {
        MonitorTone(rawValue: statusPayload?.status ?? monitor.status ?? "unknown") ?? monitor.tone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("MONITORING")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.3)
                                .foregroundStyle(Brand.mutedText)
                            Text(monitor.name)
                                .font(.system(size: 29, weight: .black, design: .rounded))
                                .foregroundStyle(Brand.text)
                        }
                        Spacer()
                        WebGuardStatusBadge(tone: tone, label: nil)
                    }
                    Text(monitor.target.isEmpty ? monitor.id : monitor.target)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Brand.mutedText)
                        .textSelection(.enabled)
                }
                .webGuardCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Statuskontext")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.text)
                    DetailValueRow(label: "Aktueller Zustand", value: tone.displayName, color: tone.color)
                    DetailValueRow(label: "Letzte lokale Aktualisierung", value: monitor.lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                    if let checkedAt = statusPayload?.checkedAt, !checkedAt.isEmpty {
                        DetailValueRow(label: "Letzter Check", value: checkedAt)
                    }
                }
                .webGuardCard()

                if isLoading {
                    ProgressView("Status wird aktualisiert …")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .webGuardCard()
                }

                Text("Die Detailansicht nutzt die serverseitige Statuslogik des WebGuard Core. Bei fehlender Verbindung bleibt der zuletzt bekannte Zustand sichtbar.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                    .padding(.horizontal, 4)
            }
            .padding(20)
            .webGuardContentWidth(860)
        }
        .background(Brand.background)
        .navigationTitle(monitor.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadStatus()
        }
        .task {
            await loadStatus()
        }
    }

    private func loadStatus() async {
        guard let client = appState.apiClient else { return }
        isLoading = true
        defer { isLoading = false }

        statusPayload = try? await client.monitoringStatus(monitorID: monitor.id)
    }
}

private struct DetailValueRow: View {
    let label: String
    let value: String
    var color: Color = Brand.text

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Brand.mutedText)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
        }
    }
}
