import Foundation

struct StoredSession: Codable, Equatable {
    var serverURL: URL
    var accessToken: String
    var user: AuthenticatedUser
    var deviceID: String?
    var pushSetupCompleted: Bool
    var pushNotificationsEnabled: Bool
    var lastAPICallAt: Date?
    var lastTokenRefreshAt: Date?
}

struct AuthenticatedUser: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var email: String
}

struct MobilePushDevice: Codable, Identifiable, Equatable {
    var id: String
    var platform: String
    var pushProvider: String
    var enabled: Bool
    var lastRegisteredAt: String?
    var lastSeenAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case platform
        case pushProvider = "push_provider"
        case enabled
        case lastRegisteredAt = "last_registered_at"
        case lastSeenAt = "last_seen_at"
    }
}

struct KnownMonitor: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var target: String
    var status: String?
    var lastSeenAt: Date
}

struct PushEvent: Codable, Identifiable, Equatable {
    var id: String
    var eventType: String
    var severity: String
    var monitoringID: String
    var monitoringName: String
    var monitoringTarget: String
    var occurredAt: Date
    var notificationID: String
    var receivedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case severity
        case monitoringID = "monitoring_id"
        case monitoringName = "monitoring_name"
        case monitoringTarget = "monitoring_target"
        case occurredAt = "occurred_at"
        case notificationID = "notification_id"
        case receivedAt = "received_at"
    }
}

struct MonitoringStatusPayload: Decodable {
    var status: String?
    var statusLabel: String?
    var checkedAt: String?

    enum CodingKeys: String, CodingKey {
        case status
        case statusLabel = "status_label"
        case checkedAt = "checked_at"
    }
}

enum OverviewState: String, Codable {
    case healthy
    case degraded
    case attention
    case new
}

struct MobileOverviewResponse: Decodable {
    var data: MobileOverviewPayload
    var meta: MobileOverviewMeta
}

struct MobileOverviewMeta: Decodable {
    var generatedAt: Date?
    var servicePagination: ServicePagination

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case servicePagination = "service_pagination"
    }
}

struct MobileOverviewPayload: Codable, Equatable {
    var overallState: OverviewState
    var summary: OverviewSummary
    var services: [OverviewService]
    var attention: [OverviewAttention]
    var maintenance: [OverviewMaintenance]
    var recentIncidents: [OverviewIncident]
    var trend: [OverviewTrendPoint]
    var failedDeliveryCount: Int
    var recommendedAction: String
    var capabilities: OverviewCapabilities

    enum CodingKeys: String, CodingKey {
        case overallState = "overall_state"
        case summary
        case services
        case attention
        case maintenance
        case recentIncidents = "recent_incidents"
        case trend
        case failedDeliveryCount = "failed_delivery_count"
        case recommendedAction = "recommended_action"
        case capabilities
    }

    static func fallback(monitors: [KnownMonitor], events: [PushEvent]) -> MobileOverviewPayload {
        let services = monitors.map { monitor in
            OverviewService(
                id: monitor.id,
                name: monitor.name,
                target: monitor.target,
                type: nil,
                group: "Ungrouped",
                status: monitor.tone.rawValue,
                openIncident: monitor.tone == .down,
                lastCheckedAt: monitor.lastSeenAt,
                responseTimeMs: nil
            )
        }
        let downCount = services.filter { $0.status == MonitorTone.down.rawValue }.count
        let unknownCount = services.filter { $0.status == MonitorTone.unknown.rawValue }.count
        let maintenanceCount = services.filter { $0.status == MonitorTone.maintenance.rawValue }.count
        let healthyCount = services.filter { $0.status == MonitorTone.up.rawValue }.count
        let state: OverviewState = services.isEmpty
            ? .new
            : downCount > 0
                ? .degraded
                : unknownCount > 0
                    ? .attention
                    : .healthy
        let attention = services
            .filter { $0.status == MonitorTone.down.rawValue || $0.status == MonitorTone.unknown.rawValue }
            .prefix(5)
            .map { service in
                OverviewAttention(
                    type: service.status == MonitorTone.down.rawValue ? "down" : "unknown",
                    count: nil,
                    monitoringID: service.id,
                    monitoringName: service.name,
                    monitoringTarget: service.target,
                    statusPageID: nil,
                    statusPageName: nil
                )
            }
        let incidents = events
            .filter { $0.eventType == "incident" || $0.eventType == "recovery" }
            .prefix(5)
            .map { event in
                OverviewIncident(
                    id: event.id,
                    monitoringID: event.monitoringID,
                    monitoringName: event.monitoringName,
                    monitoringTarget: event.monitoringTarget,
                    downAt: event.eventType == "incident" ? event.occurredAt : nil,
                    upAt: event.eventType == "recovery" ? event.occurredAt : nil,
                    resolved: event.eventType == "recovery"
                )
            }

        return MobileOverviewPayload(
            overallState: state,
            summary: OverviewSummary(
                total: services.count,
                healthy: healthyCount,
                down: downCount,
                unknown: unknownCount,
                paused: 0,
                maintenance: maintenanceCount
            ),
            services: services,
            attention: Array(attention),
            maintenance: [],
            recentIncidents: Array(incidents),
            trend: [],
            failedDeliveryCount: 0,
            recommendedAction: downCount > 0 ? "incidents" : unknownCount > 0 ? "unknown" : "monitorings",
            capabilities: OverviewCapabilities(canCreateMonitoring: false, canManageMaintenance: false)
        )
    }
}

struct OverviewSummary: Codable, Equatable {
    var total: Int
    var healthy: Int
    var down: Int
    var unknown: Int
    var paused: Int
    var maintenance: Int
}

struct OverviewService: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var target: String
    var type: String?
    var group: String
    var status: String
    var openIncident: Bool
    var lastCheckedAt: Date?
    var responseTimeMs: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case target
        case type
        case group
        case status
        case openIncident = "open_incident"
        case lastCheckedAt = "last_checked_at"
        case responseTimeMs = "response_time_ms"
    }

    var tone: MonitorTone {
        MonitorTone(rawValue: status) ?? .unknown
    }
}

struct OverviewAttention: Codable, Identifiable, Equatable {
    var type: String
    var count: Int?
    var monitoringID: String?
    var monitoringName: String?
    var monitoringTarget: String?
    var statusPageID: String?
    var statusPageName: String?

    var id: String {
        "\(type)-\(monitoringID ?? count.map(String.init) ?? "delivery")"
    }

    enum CodingKeys: String, CodingKey {
        case type
        case count
        case monitoringID = "monitoring_id"
        case monitoringName = "monitoring_name"
        case monitoringTarget = "monitoring_target"
        case statusPageID = "status_page_id"
        case statusPageName = "status_page_name"
    }
}

struct OverviewMaintenance: Codable, Identifiable, Equatable {
    var monitoringID: String
    var monitoringName: String
    var monitoringTarget: String
    var status: String
    var startsAt: Date?
    var endsAt: Date?

    var id: String { monitoringID }

    enum CodingKeys: String, CodingKey {
        case monitoringID = "monitoring_id"
        case monitoringName = "monitoring_name"
        case monitoringTarget = "monitoring_target"
        case status
        case startsAt = "starts_at"
        case endsAt = "ends_at"
    }
}

struct OverviewIncident: Codable, Identifiable, Equatable {
    var id: String
    var monitoringID: String?
    var monitoringName: String?
    var monitoringTarget: String?
    var downAt: Date?
    var upAt: Date?
    var resolved: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case monitoringID = "monitoring_id"
        case monitoringName = "monitoring_name"
        case monitoringTarget = "monitoring_target"
        case downAt = "down_at"
        case upAt = "up_at"
        case resolved
    }
}

struct OverviewTrendPoint: Codable, Identifiable, Equatable {
    var date: String
    var label: String
    var uptimePercentage: Double?
    var hasData: Bool

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case label
        case uptimePercentage = "uptime_percentage"
        case hasData = "has_data"
    }
}

struct OverviewCapabilities: Codable, Equatable {
    var canCreateMonitoring: Bool
    var canManageMaintenance: Bool

    enum CodingKeys: String, CodingKey {
        case canCreateMonitoring = "can_create_monitoring"
        case canManageMaintenance = "can_manage_maintenance"
    }
}

struct ServicePagination: Codable, Equatable {
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var from: Int?
    var to: Int?

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case from
        case to
    }
}

struct MonitoringListResponse: Decodable {
    var data: [MonitoringSummary]
}

struct MonitoringSummary: Decodable, Identifiable {
    var id: String
    var name: String
    var target: String
    var status: String?
}

struct MobileLoginPayload: Encodable {
    var email: String
    var password: String
    var deviceName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case deviceName = "device_name"
    }
}

struct MobileLoginResponse: Decodable {
    var data: MobileLoginData
}

struct MobileLoginData: Decodable {
    var token: String
    var tokenType: String
    var user: AuthenticatedUser

    enum CodingKeys: String, CodingKey {
        case token
        case tokenType = "token_type"
        case user
    }
}

struct MobileUserResponse: Decodable {
    var data: AuthenticatedUser
}

struct APNsRegistrationPayload: Encodable {
    var platform = "ios"
    var pushProvider = "apns"
    var pushToken: String
    var deviceName: String?
    var appVersion: String?
    var locale: String?
    var timezone: String?
    var enabled = true
    var notificationsAuthorizedAt: String?

    enum CodingKeys: String, CodingKey {
        case platform
        case pushProvider = "push_provider"
        case pushToken = "push_token"
        case deviceName = "device_name"
        case appVersion = "app_version"
        case locale
        case timezone
        case enabled
        case notificationsAuthorizedAt = "notifications_authorized_at"
    }
}

struct MobilePushDeviceResponse: Decodable {
    var data: MobilePushDevice
}

struct MobilePushDeviceListResponse: Decodable {
    var data: [MobilePushDevice]
}

enum MonitorTone {
    case up
    case down
    case maintenance
    case unknown
}

extension MonitorTone: Codable {
    var rawValue: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .maintenance: return "maintenance"
        case .unknown: return "unknown"
        }
    }

    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "up", "active", "healthy": self = .up
        case "down", "fail", "failed": self = .down
        case "maintenance": self = .maintenance
        default: self = .unknown
        }
    }

    public init(from decoder: Decoder) throws {
        self = MonitorTone(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension KnownMonitor {
    var tone: MonitorTone {
        let value = (status ?? "").lowercased()

        if value.contains("down") || value.contains("fail") {
            return .down
        }

        if value.contains("maintenance") {
            return .maintenance
        }

        if value.contains("up") || value == "active" {
            return .up
        }

        return .unknown
    }
}
