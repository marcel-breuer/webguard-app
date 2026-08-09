import Foundation

protocol CacheStore {
    func activate(for userID: String?)
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

    private enum Keys {
        static let schemaVersion = "webguard.cache.schema-version"
        static let schemaVersionValue = 2
        static let namespace = "webguard.cache.v2"
        static let monitors = "monitors"
        static let events = "events"
        static let overview = "overview"
        static let notificationPreferences = "notification-preferences"
        static let lastMonitoringRefreshAt = "last-monitoring-refresh-at"
        static let legacy = [
            "webguard.known-monitors",
            "webguard.notification-events",
            "webguard.operations-overview",
            "webguard.notification-preferences",
            "webguard.last-monitoring-refresh-at"
        ]
    }

    private enum Limits {
        static let monitors = 100
        static let events = 50
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var activeScope: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder = WebGuardJSONCoding.makeEncoder()
        decoder = WebGuardJSONCoding.makeDecoder()
        migrateLegacyCacheIfNeeded()
    }

    func activate(for userID: String?) {
        activeScope = userID.map { "\(Keys.namespace).\(scopedIdentifier(for: $0))" }
    }

    func loadMonitors() -> [KnownMonitor] {
        guard let data = data(for: Keys.monitors),
              let value = try? decoder.decode([KnownMonitor].self, from: data) else {
            return []
        }

        return value
    }

    func saveMonitors(_ monitors: [KnownMonitor]) {
        save(Array(monitors.prefix(Limits.monitors)), for: Keys.monitors)
    }

    func upsertMonitor(_ monitor: KnownMonitor) {
        let current = loadMonitors()
        saveMonitors([monitor] + current.filter { $0.id != monitor.id })
    }

    func loadEvents() -> [PushEvent] {
        guard let data = data(for: Keys.events),
              let value = try? decoder.decode([PushEvent].self, from: data) else {
            return []
        }

        return value
    }

    func addEvent(_ event: PushEvent) {
        let current = loadEvents()
        save(Array(([event] + current.filter { $0.id != event.id }).prefix(Limits.events)), for: Keys.events)

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
        guard let data = data(for: Keys.notificationPreferences),
              let value = try? decoder.decode([String: MonitoringNotificationPreference].self, from: data) else {
            return [:]
        }

        return value
    }

    func saveNotificationPreferences(_ preferences: [String: MonitoringNotificationPreference]) {
        save(preferences, for: Keys.notificationPreferences)
    }

    func loadLastMonitoringRefreshAt() -> Date? {
        guard let key = scopedKey(for: Keys.lastMonitoringRefreshAt) else {
            return nil
        }

        return defaults.object(forKey: key) as? Date
    }

    func saveLastMonitoringRefreshAt(_ date: Date) {
        guard let key = scopedKey(for: Keys.lastMonitoringRefreshAt) else {
            return
        }

        defaults.set(date, forKey: key)
    }

    func loadOverview() -> MobileOverviewPayload? {
        guard let data = data(for: Keys.overview) else {
            return nil
        }

        return try? decoder.decode(MobileOverviewPayload.self, from: data)
    }

    func saveOverview(_ overview: MobileOverviewPayload) {
        save(overview, for: Keys.overview)
    }

    func clear() {
        [
            Keys.monitors,
            Keys.events,
            Keys.overview,
            Keys.notificationPreferences,
            Keys.lastMonitoringRefreshAt
        ].compactMap(scopedKey).forEach(defaults.removeObject(forKey:))
    }

    private func data(for name: String) -> Data? {
        guard let key = scopedKey(for: name) else {
            return nil
        }

        return defaults.data(forKey: key)
    }

    private func save<T: Encodable>(_ value: T, for name: String) {
        guard let key = scopedKey(for: name),
              let data = try? encoder.encode(value) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private func scopedKey(for name: String) -> String? {
        activeScope.map { "\($0).\(name)" }
    }

    private func scopedIdentifier(for userID: String) -> String {
        Data(userID.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func migrateLegacyCacheIfNeeded() {
        guard defaults.integer(forKey: Keys.schemaVersion) < Keys.schemaVersionValue else {
            return
        }

        Keys.legacy.forEach(defaults.removeObject(forKey:))
        defaults.set(Keys.schemaVersionValue, forKey: Keys.schemaVersion)
    }
}
