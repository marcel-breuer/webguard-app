import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: NotificationFilter = .statusChanges

    private var visibleEvents: [PushEvent] {
        switch filter {
        case .statusChanges:
            return appState.events.filter { $0.eventType == "incident" || $0.eventType == "recovery" }
        case .all:
            return appState.events
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("STATUS BOARD")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.3)
                            .foregroundStyle(Brand.mutedText)
                        Text("Benachrichtigungen")
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)
                        Text("Letzte Push Events und Statusänderungen")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Brand.mutedText)
                    }

                    Picker("Filter", selection: $filter) {
                        Text("Statusänderungen").tag(NotificationFilter.statusChanges)
                        Text("Alle").tag(NotificationFilter.all)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 0) {
                        if visibleEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "bell.slash")
                                    .font(.title2)
                                    .foregroundStyle(Brand.accent)
                                Text("Noch keine Push Events")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(Brand.text)
                                Text("Statusänderungen erscheinen hier, sobald WebGuard dieses Gerät benachrichtigt.")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(Brand.mutedText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                        } else {
                            ForEach(visibleEvents) { event in
                                if let monitor = appState.monitors.first(where: { $0.id == event.monitoringID }) {
                                    NavigationLink {
                                        MonitoringDetailView(monitor: monitor)
                                    } label: {
                                        NotificationRow(event: event)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier(WebGuardAccessibilityID.notificationRow(event.id))
                                } else {
                                    NotificationRow(event: event)
                                        .accessibilityIdentifier(WebGuardAccessibilityID.notificationRow(event.id))
                                }
                                if event.id != visibleEvents.last?.id {
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
            .accessibilityIdentifier(WebGuardAccessibilityID.notifications)
            .background(Brand.background)
            .navigationTitle("Benachrichtigungen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private enum NotificationFilter: Hashable {
    case statusChanges
    case all
}

private struct NotificationRow: View {
    let event: PushEvent

    private var tone: MonitorTone {
        event.eventType == "recovery" ? .up : .down
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(tone.color)
                .frame(width: 4)

            Image(systemName: event.eventType == "recovery" ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(tone.color)
                .frame(width: 32, height: 32)
                .background(tone.background)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.monitoringName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.text)
                    .lineLimit(2)
                Text(event.eventType == "recovery" ? "Wiederhergestellt" : "Kritischer Vorfall")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                Text(event.monitoringTarget)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 7) {
                Text(event.occurredAt.formatted(date: .numeric, time: .shortened))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                WebGuardStatusBadge(tone: tone, label: nil)
            }
        }
        .frame(minHeight: 82)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
