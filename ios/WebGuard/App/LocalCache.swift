import Foundation

protocol CacheStore {
    func loadMonitors() -> [KnownMonitor]
    func saveMonitors(_ monitors: [KnownMonitor])
    func upsertMonitor(_ monitor: KnownMonitor)
    func loadEvents() -> [PushEvent]
    func addEvent(_ event: PushEvent)
    func loadNotificationPreferences() -> [String: MonitoringNotificationPreference]
    func saveNotificationPreferences(_ preferences: [String: MonitoringNotificationPreference])
    func loadLastMonitoringRefreshAt() -> Date?
    func saveLastMonitoringRefreshAt(_ date: Date)
    func loadOverview() -> MobileOverviewPayload?
    func saveOverview(_ overview: MobileOverviewPayload)
    func clear()
}

final class LocalCache: CacheStore {
    static let shared = LocalCache()

    private let monitorsKey = "webguard.known-monitors"
    private let eventsKey = "webguard.notification-events"
    private let overviewKey = "webguard.operations-overview"
    private let notificationPreferencesKey = "webguard.notification-preferences"
    private let lastMonitoringRefreshAtKey = "webguard.last-monitoring-refresh-at"
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadMonitors() -> [KnownMonitor] {
        guard let data = defaults.data(forKey: monitorsKey),
              let value = try? decoder.decode([KnownMonitor].self, from: data) else {
            return []
        }

        return value
    }

    func saveMonitors(_ monitors: [KnownMonitor]) {
        save(Array(monitors.prefix(100)), key: monitorsKey)
    }

    func upsertMonitor(_ monitor: KnownMonitor) {
        let current = loadMonitors()
        saveMonitors([monitor] + current.filter { $0.id != monitor.id })
    }

    func loadEvents() -> [PushEvent] {
        guard let data = defaults.data(forKey: eventsKey),
              let value = try? decoder.decode([PushEvent].self, from: data) else {
            return []
        }

        return value
    }

    func addEvent(_ event: PushEvent) {
        let current = loadEvents()
        save(Array(([event] + current.filter { $0.id != event.id }).prefix(50)), key: eventsKey)

        upsertMonitor(KnownMonitor(
            id: event.monitoringID,
            name: event.monitoringName,
            target: event.monitoringTarget,
            status: event.eventType == "recovery" ? "up" : event.eventType == "incident" ? "down" : nil,
            lastSeenAt: event.occurredAt,
            maintenanceActive: nil,
            maintenanceFrom: nil,
            maintenanceUntil: nil
        ))
    }

    func loadNotificationPreferences() -> [String: MonitoringNotificationPreference] {
        guard let data = defaults.data(forKey: notificationPreferencesKey),
              let value = try? decoder.decode([String: MonitoringNotificationPreference].self, from: data) else {
            return [:]
        }

        return value
    }

    func saveNotificationPreferences(_ preferences: [String: MonitoringNotificationPreference]) {
        save(preferences, key: notificationPreferencesKey)
    }

    func loadLastMonitoringRefreshAt() -> Date? {
        defaults.object(forKey: lastMonitoringRefreshAtKey) as? Date
    }

    func saveLastMonitoringRefreshAt(_ date: Date) {
        defaults.set(date, forKey: lastMonitoringRefreshAtKey)
    }

    func loadOverview() -> MobileOverviewPayload? {
        guard let data = defaults.data(forKey: overviewKey) else {
            return nil
        }

        return try? decoder.decode(MobileOverviewPayload.self, from: data)
    }

    func saveOverview(_ overview: MobileOverviewPayload) {
        save(overview, key: overviewKey)
    }

    func clear() {
        defaults.removeObject(forKey: monitorsKey)
        defaults.removeObject(forKey: eventsKey)
        defaults.removeObject(forKey: overviewKey)
        defaults.removeObject(forKey: notificationPreferencesKey)
        defaults.removeObject(forKey: lastMonitoringRefreshAtKey)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
