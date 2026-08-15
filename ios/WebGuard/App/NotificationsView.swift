import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: NotificationFilter = .all

    private var visibleEntries: [MobileNotificationBoardEntry] {
        appState.notificationBoard.filter { entry in
            switch filter {
            case .all: true
            case .unread: !entry.read
            case .incidents: entry.eventType == "incident" || entry.eventType == "performance_degraded"
            case .recoveries: entry.eventType == "recovery" || entry.eventType == "performance_recovered"
            case .maintenance: entry.eventType == "maintenance"
            case .expiry: entry.eventType.hasPrefix("ssl_") || entry.eventType.hasPrefix("domain_")
            case .deliveryFailures: entry.eventType == "delivery_failure" || entry.deliveryStatus == "failed"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heading
                    Picker("Filter", selection: $filter) {
                        ForEach(NotificationFilter.allCases) { option in Text(option.title).tag(option) }
                    }
                    .pickerStyle(.menu)
                    .tint(Brand.accent)
                    .accessibilityLabel("Benachrichtigungen filtern")

                    if appState.isOffline || appState.isNotificationBoardStale { freshnessNotice }
                    notificationList
                }
                .padding(20)
                .webGuardContentWidth(900)
            }
            .accessibilityIdentifier(WebGuardAccessibilityID.notifications)
            .background(Brand.background)
            .navigationTitle("Benachrichtigungen")
            .navigationBarTitleDisplayMode(.inline)
            .task { await appState.refreshNotificationBoard() }
            .refreshable { await appState.refreshNotificationBoard() }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("NOTIFICATION CENTER").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.3).foregroundStyle(Brand.mutedText)
                    Text("Benachrichtigungen").font(.system(size: 31, weight: .black, design: .rounded)).foregroundStyle(Brand.text)
                    Text("Synchronisierte Ereignisse und Zustellinformationen").font(.system(size: 15, design: .rounded)).foregroundStyle(Brand.mutedText)
                }
                Spacer()
                if appState.notificationBoardMeta.unreadCount > 0 {
                    Button("Alle lesen") { Task { await appState.markAllNotificationsRead() } }
                        .font(.system(size: 14, weight: .bold, design: .rounded)).buttonStyle(.bordered).tint(Brand.accent)
                }
            }
            if appState.notificationBoardMeta.unreadCount > 0 {
                Text("\(appState.notificationBoardMeta.unreadCount) ungelesen").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Brand.accent)
            }
        }
    }

    private var freshnessNotice: some View {
        Label(
            appState.isOffline ? "Offline: Es werden zuletzt synchronisierte Benachrichtigungen angezeigt." : "Die angezeigten Benachrichtigungen sind möglicherweise nicht aktuell.",
            systemImage: appState.isOffline ? "wifi.slash" : "clock.arrow.circlepath"
        )
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(Brand.warning).padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.warning.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var notificationList: some View {
        VStack(spacing: 0) {
            if visibleEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "bell.slash").font(.title2).foregroundStyle(Brand.accent)
                    Text("Keine passenden Benachrichtigungen").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(Brand.text)
                    Text("Neue Ereignisse werden automatisch mit dem WebGuard-Server abgeglichen.").font(.system(size: 14, design: .rounded)).foregroundStyle(Brand.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
            } else {
                ForEach(visibleEntries) { entry in
                    NotificationBoardRow(entry: entry, monitor: monitor(for: entry)) { Task { await appState.markNotificationRead(entry) } }
                        .accessibilityIdentifier(WebGuardAccessibilityID.notificationRow(entry.id))
                    if entry.id != visibleEntries.last?.id { Divider().background(Brand.border) }
                }
            }
            if appState.notificationBoardMeta.hasMore {
                Divider().background(Brand.border)
                Button(appState.isNotificationBoardRefreshing ? "Wird geladen …" : "Weitere laden") { Task { await appState.loadMoreNotificationBoard() } }
                    .disabled(appState.isNotificationBoardRefreshing).font(.system(size: 15, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).padding(.top, 16)
            }
        }
        .webGuardCard()
    }

    private func monitor(for entry: MobileNotificationBoardEntry) -> KnownMonitor {
        appState.monitors.first(where: { $0.id == entry.monitoring.id }) ?? KnownMonitor(id: entry.monitoring.id, name: entry.monitoring.name, target: entry.monitoring.target, lastSeenAt: entry.occurredAt)
    }
}

private enum NotificationFilter: String, CaseIterable, Identifiable {
    case all, unread, incidents, recoveries, maintenance, expiry, deliveryFailures
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "Alle Ereignisse"
        case .unread: "Ungelesen"
        case .incidents: "Vorfälle"
        case .recoveries: "Wiederherstellungen"
        case .maintenance: "Wartung"
        case .expiry: "SSL & Domains"
        case .deliveryFailures: "Zustellfehler"
        }
    }
}

private struct NotificationBoardRow: View {
    let entry: MobileNotificationBoardEntry
    let monitor: KnownMonitor
    let markRead: () -> Void

    private var tone: MonitorTone {
        switch entry.severity {
        case "critical": .down
        case "warning": .maintenance
        case "info": .up
        default: .unknown
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(tone.color).frame(width: 4)
            Image(systemName: icon).foregroundStyle(tone.color).frame(width: 32, height: 32).background(tone.background).clipShape(RoundedRectangle(cornerRadius: 9))
            NavigationLink { MonitoringDetailView(monitor: monitor) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.monitoring.name).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Brand.text).lineLimit(2)
                    Text(entry.message).font(.system(size: 13, design: .rounded)).foregroundStyle(Brand.mutedText).lineLimit(2)
                    Text(entry.monitoring.target).font(.system(size: 12, design: .rounded)).foregroundStyle(Brand.mutedText).lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 7) {
                Text(entry.occurredAt.formatted(date: .numeric, time: .shortened)).font(.system(size: 11, design: .rounded)).foregroundStyle(Brand.mutedText)
                Text(entry.read ? "Gelesen" : entry.eventType.replacingOccurrences(of: "_", with: " ").capitalized).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(entry.read ? Brand.mutedText : tone.color)
                if !entry.read && !entry.id.hasPrefix("local-") {
                    Button("Lesen", action: markRead).font(.system(size: 12, weight: .bold, design: .rounded)).buttonStyle(.borderless).tint(Brand.accent)
                }
            }
        }
        .frame(minHeight: 82).padding(.vertical, 8).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(entry.read ? "Gelesene Benachrichtigung" : "Ungelesene Benachrichtigung")
    }

    private var icon: String {
        switch entry.eventType {
        case "recovery", "performance_recovered": "checkmark.circle.fill"
        case "maintenance": "wrench.and.screwdriver.fill"
        case "ssl_expiring", "ssl_expired", "domain_expiring", "domain_expired": "shield.lefthalf.filled"
        case "delivery_failure": "exclamationmark.arrow.triangle.2.circlepath"
        default: "xmark.octagon.fill"
        }
    }
}
