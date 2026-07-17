import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetMonitorSnapshot: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var target: String
    var status: String
    var isDown: Bool
    var isMaintenance: Bool

    var statusLabel: String {
        if isMaintenance {
            return "MAINTENANCE"
        }

        if isDown {
            return "DOWN"
        }

        let value = status.lowercased()
        if value.contains("up") || value == "active" {
            return "UP"
        }

        return "UNKNOWN"
    }
}

struct WidgetSnapshot: Codable, Equatable {
    var generatedAt: Date
    var monitors: [WidgetMonitorSnapshot]
}

enum WidgetDeepLink {
    static let scheme = "webguard"

    static var overview: URL {
        URL(string: "\(scheme)://monitorings")!
    }

    static func monitoring(_ id: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "monitoring"
        components.path = "/\(id)"
        return components.url
    }

    static func monitoringID(from url: URL) -> String? {
        guard url.scheme == scheme,
              url.host == "monitoring" else {
            return nil
        }

        let id = url.pathComponents.dropFirst().first
        return id?.isEmpty == false ? id : nil
    }
}

enum WidgetSnapshotStore {
    static let appGroup = "group.com.example.webguard"
    private static let snapshotKey = "webguard.widget.snapshot"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func save(monitors: [WidgetMonitorSnapshot]) {
        let snapshot = WidgetSnapshot(generatedAt: Date(), monitors: Array(monitors.prefix(100)))

        guard let data = try? encoder.encode(snapshot),
              let defaults = UserDefaults(suiteName: appGroup) else {
            return
        }

        defaults.set(data, forKey: snapshotKey)
        WidgetCenterBridge.reloadAllTimelines()
    }

    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: snapshotKey) else {
            return nil
        }

        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static func clear() {
        UserDefaults(suiteName: appGroup)?.removeObject(forKey: snapshotKey)
        WidgetCenterBridge.reloadAllTimelines()
    }
}

enum WidgetCenterBridge {
    static func reloadAllTimelines() {
        #if canImport(WidgetKit)
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
