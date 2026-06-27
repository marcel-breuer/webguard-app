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
                VStack(alignment: .leading, spacing: 18) {
                    Text("Benachrichtigungen")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.text)
                    Text("Letzte Push Events")
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(Brand.mutedText)

                    Picker("Filter", selection: $filter) {
                        Text("Statusänderungen").tag(NotificationFilter.statusChanges)
                        Text("Alle").tag(NotificationFilter.all)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 0) {
                        if visibleEvents.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "bell")
                                Text("Noch keine Push Events empfangen.")
                            }
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Brand.mutedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        } else {
                            ForEach(visibleEvents) { event in
                                NotificationRow(event: event)
                                Divider().background(Brand.border)
                            }
                        }
                    }
                    .webGuardCard()
                }
                .padding(20)
                .webGuardContentWidth(900)
            }
            .background(Brand.background)
        }
    }
}

private enum NotificationFilter {
    case statusChanges
    case all
}

struct NotificationRow: View {
    var event: PushEvent

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(tone == .up ? Brand.success : Brand.danger)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.monitoringName)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Brand.text)
                    .lineLimit(2)

                Text(event.eventType == "recovery" ? "Wiederhergestellt" : "Kritische Vorfälle")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Brand.mutedText)

                Text(event.monitoringTarget)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Text(event.occurredAt.formatted(date: .numeric, time: .shortened))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
                StatusPill(tone: tone, label: event.eventType == "recovery" ? "up" : "down")
            }
        }
        .frame(minHeight: 92)
        .padding(.vertical, 12)
    }

    private var tone: MonitorTone {
        event.eventType == "recovery" ? .up : .down
    }
}
