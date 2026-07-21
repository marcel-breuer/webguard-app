import Foundation

final class LocalCache {
    static let shared = LocalCache()

    private let monitorsKey = "webguard.known-monitors"
    private let eventsKey = "webguard.notification-events"
    private let overviewKey = "webguard.operations-overview"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadMonitors() -> [KnownMonitor] {
        guard let data = UserDefaults.standard.data(forKey: monitorsKey),
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
        guard let data = UserDefaults.standard.data(forKey: eventsKey),
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
            lastSeenAt: event.occurredAt
        ))
    }

    func loadOverview() -> MobileOverviewPayload? {
        guard let data = UserDefaults.standard.data(forKey: overviewKey) else {
            return nil
        }

        return try? decoder.decode(MobileOverviewPayload.self, from: data)
    }

    func saveOverview(_ overview: MobileOverviewPayload) {
        save(overview, key: overviewKey)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: monitorsKey)
        UserDefaults.standard.removeObject(forKey: eventsKey)
        UserDefaults.standard.removeObject(forKey: overviewKey)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key)
    }
}
