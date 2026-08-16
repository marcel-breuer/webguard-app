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

struct KnownMonitor: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var target: String
    var status: String?
    var type: String? = nil
    var ownership: MobileMonitoringOwnership? = nil
    var lastSeenAt: Date
    var maintenanceActive: Bool? = nil
    var maintenanceFrom: Date? = nil
    var maintenanceUntil: Date? = nil
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

struct MonitoringMutationPayload: Encodable, Equatable {
    var name: String
    var target: String
    var type: String
    var status: String
    var timeout: Int?
    var httpMethod: String?
    var expectedHTTPStatuses: String?
    var httpHeaders: [String: String]?
    var port: Int?

    enum CodingKeys: String, CodingKey {
        case name, target, type, status, timeout, port
        case httpMethod = "http_method"
        case expectedHTTPStatuses = "expected_http_statuses"
        case httpHeaders = "http_headers"
    }
}

struct MonitoringManagementResponse: Decodable, Equatable {
    var data: MonitoringManagementItem
}

struct MobileMonitoringGroupListResponse: Decodable, Equatable {
    var data: [MobileMonitoringGroup]
}

struct MobileMonitoringGroupResponse: Decodable, Equatable {
    var data: MobileMonitoringGroup
}

struct MobileMonitoringGroup: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var description: String?
    var ownership: MobileMonitoringOwnership
    var assignableMonitoringCount: Int
    var assignments: [MobileMonitoringAssignment]

    enum CodingKeys: String, CodingKey {
        case id, name, description, ownership, assignments
        case assignableMonitoringCount = "assignable_monitoring_count"
    }
}

struct MobileMonitoringAssignment: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var target: String
    var type: String?
    var status: String?
    var ownership: MobileMonitoringOwnership
}

struct MonitoringGroupMutationPayload: Encodable {
    var name: String
    var description: String?
    var monitoringIDs: [String]

    enum CodingKeys: String, CodingKey {
        case name, description
        case monitoringIDs = "monitoring_ids"
    }
}

struct TeamListResponse: Decodable { var data: [TeamSummary] }
struct TeamSummary: Decodable, Identifiable {
    var id: String
    var name: String
    var description: String?
}

struct MobileMaintenanceListResponse: Decodable { var data: [MobileMaintenanceWindow] }
struct MobileMaintenanceResponse: Decodable { var data: MobileMaintenanceWindow; var idempotent: Bool? }

struct MobileMaintenanceWindow: Codable, Identifiable, Equatable {
    var id: String
    var kind: String
    var state: String
    var enabled: Bool
    var target: MobileMaintenanceTarget
    var schedule: MobileMaintenanceSchedule
    var canManage: Bool

    enum CodingKeys: String, CodingKey { case id, kind, state, enabled, target, schedule; case canManage = "can_manage" }
}

struct MobileMaintenanceTarget: Codable, Equatable {
    var type: String
    var id: String
    var name: String?
    var manageableMonitoringIDs: [String]
    enum CodingKeys: String, CodingKey { case type, id, name; case manageableMonitoringIDs = "manageable_monitoring_ids" }
}

struct MobileMaintenanceSchedule: Codable, Equatable {
    var startsAt: Date?
    var endsAt: Date?
    var timezone: String
    var recurrence: String?
    var durationMinutes: Int?
    var repeatUntil: Date?
    var nextOccurrence: Date?
    enum CodingKeys: String, CodingKey {
        case timezone, recurrence
        case startsAt = "starts_at"; case endsAt = "ends_at"; case durationMinutes = "duration_minutes"
        case repeatUntil = "repeat_until"; case nextOccurrence = "next_occurrence"
    }
}

struct MobileMaintenanceCapabilitiesResponse: Decodable { var data: MobileMaintenanceCapabilities }
struct MobileMaintenanceCapabilities: Decodable, Equatable {
    var canSchedule: Bool
    var manageableMonitorings: [MobileMaintenanceMonitoring]
    var monitoringGroups: [MobileMaintenanceGroup]
    enum CodingKeys: String, CodingKey { case canSchedule = "can_schedule"; case manageableMonitorings = "manageable_monitorings"; case monitoringGroups = "monitoring_groups" }
}
struct MobileMaintenanceMonitoring: Decodable, Identifiable, Equatable { var id: String; var name: String; var ownership: String }
struct MobileMaintenanceGroup: Decodable, Identifiable, Equatable { var id: String; var name: String; var monitoringsCount: Int; enum CodingKeys: String, CodingKey { case id, name; case monitoringsCount = "monitorings_count" } }

struct MaintenanceSchedulePayload: Encodable {
    var mode: String; var scope: String; var monitoringID: String?; var monitoringGroupID: String?
    var maintenanceFrom: Date?; var maintenanceUntil: Date?; var recurringStartsAt: Date?; var recurringDurationMinutes: Int?; var recurrence: String?; var recurringTimezone: String?; var idempotencyKey: String
    enum CodingKeys: String, CodingKey {
        case mode, scope, recurrence
        case monitoringID = "monitoring_id"; case monitoringGroupID = "monitoring_group_id"
        case maintenanceFrom = "maintenance_from"; case maintenanceUntil = "maintenance_until"
        case recurringStartsAt = "recurring_starts_at"; case recurringDurationMinutes = "recurring_duration_minutes"; case recurringTimezone = "recurring_timezone"; case idempotencyKey = "idempotency_key"
    }
}

struct MonitoringManagementItem: Decodable, Equatable {
    var id: String
    var name: String
    var target: String
    var type: String
    var status: String
    var ownership: MobileMonitoringOwnership?

    func knownMonitor(fallback: KnownMonitor? = nil) -> KnownMonitor {
        KnownMonitor(
            id: id,
            name: name,
            target: target,
            status: status,
            type: type,
            ownership: ownership,
            lastSeenAt: fallback?.lastSeenAt ?? Date(),
            maintenanceActive: fallback?.maintenanceActive,
            maintenanceFrom: fallback?.maintenanceFrom,
            maintenanceUntil: fallback?.maintenanceUntil
        )
    }
}

struct MobileMonitoringDetailResponse: Codable, Equatable {
    var data: MobileMonitoringDetailPayload
    var meta: MobileMonitoringDetailMeta
}

struct MobileMonitoringDetailPayload: Codable, Equatable {
    var summary: MobileMonitoringDetailSummary
    var currentCheck: MobileMonitoringCurrentCheck
    var availability: MobileMonitoringAvailability
    var responseTimes: MobileMonitoringResponseTimes
    var incidents: [MobileMonitoringIncident]
    var heatmap: [MobileMonitoringHeatmapPoint]
    var maintenance: MobileMonitoringMaintenance
    var ssl: MobileMonitoringSsl?
    var domain: MobileMonitoringDomain?
    var uptimeCalendar: [String: MobileMonitoringCalendarMonth]
    var capabilities: MobileMonitoringCapabilities

    enum CodingKeys: String, CodingKey {
        case summary
        case currentCheck = "current_check"
        case availability
        case responseTimes = "response_times"
        case incidents
        case heatmap
        case maintenance
        case ssl
        case domain
        case uptimeCalendar = "uptime_calendar"
        case capabilities
    }
}

struct MobileMonitoringDetailSummary: Codable, Equatable {
    var id: String
    var name: String
    var target: String
    var type: String?
    var lifecycleStatus: String?
    var ownership: MobileMonitoringOwnership?
    var performance: MobileMonitoringPerformance?
    var openIncident: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case target
        case type
        case lifecycleStatus = "lifecycle_status"
        case ownership
        case performance
        case openIncident = "open_incident"
    }
}

struct MobileMonitoringOwnership: Codable, Equatable, Hashable {
    var type: String?
    var canManage: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case canManage = "can_manage"
    }
}

struct MobileMonitoringPerformance: Codable, Equatable {
    var status: String?
    var consecutiveBreaches: Int?
    var degradedAt: Date?

    enum CodingKeys: String, CodingKey {
        case status
        case consecutiveBreaches = "consecutive_breaches"
        case degradedAt = "degraded_at"
    }
}

struct MobileMonitoringCurrentCheck: Codable, Equatable {
    var status: String?
    var statusLabel: String?
    var checkedAt: Date?
    var responseTime: Double?

    enum CodingKeys: String, CodingKey {
        case status
        case statusLabel = "status_label"
        case checkedAt = "checked_at"
        case responseTime = "response_time"
    }
}

struct MobileMonitoringAvailability: Codable, Equatable {
    var hasData: Bool
    var trackingStartedAt: Date?
    var uptime: MobileMonitoringAvailabilitySegment
    var downtime: MobileMonitoringAvailabilitySegment
    var unknown: MobileMonitoringAvailabilitySegment

    enum CodingKeys: String, CodingKey {
        case hasData = "has_data"
        case trackingStartedAt = "tracking_started_at"
        case uptime
        case downtime
        case unknown
    }
}

struct MobileMonitoringAvailabilitySegment: Codable, Equatable {
    var minutes: Int
    var percentage: Double?
    var total: Int
    var incidentsCount: Int?

    enum CodingKeys: String, CodingKey {
        case minutes
        case percentage
        case total
        case incidentsCount = "incidents_count"
    }
}

struct MobileMonitoringResponseTimes: Codable, Equatable {
    var data: [MobileMonitoringResponseTimePoint]
    var aggregated: MobileMonitoringResponseTimeAggregate
}

struct MobileMonitoringResponseTimePoint: Codable, Identifiable, Equatable {
    var date: Date
    var avg: Double?
    var min: Double?
    var max: Double?

    var id: Date { date }
}

struct MobileMonitoringResponseTimeAggregate: Codable, Equatable {
    var avg: Double?
    var min: Double?
    var max: Double?
}

struct MobileMonitoringIncident: Codable, Identifiable, Equatable {
    var downAt: Date
    var upAt: Date?

    var id: Date { downAt }

    enum CodingKeys: String, CodingKey {
        case downAt = "down_at"
        case upAt = "up_at"
    }
}

struct MobileMonitoringHeatmapPoint: Codable, Identifiable, Equatable {
    var date: Date
    var uptime: Double
    var downtime: Double
    var unknown: Double

    var id: Date { date }
}

struct MobileMonitoringMaintenance: Codable, Equatable {
    var active: Bool
    var startsAt: Date?
    var endsAt: Date?
    var hasRecurringWindow: Bool

    enum CodingKeys: String, CodingKey {
        case active
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case hasRecurringWindow = "has_recurring_window"
    }
}

struct MobileMonitoringSsl: Codable, Equatable {
    var valid: Bool?
    var expiration: Date?
    var issuer: String?
    var issueDate: Date?

    enum CodingKeys: String, CodingKey {
        case valid
        case expiration
        case issuer
        case issueDate = "issue_date"
    }
}

struct MobileMonitoringDomain: Codable, Equatable {
    var valid: Bool?
    var expiresAt: Date?
    var registrar: String?
    var checkedAt: Date?

    enum CodingKeys: String, CodingKey {
        case valid
        case expiresAt = "expires_at"
        case registrar
        case checkedAt = "checked_at"
    }
}

struct MobileMonitoringCalendarMonth: Codable, Equatable {
    var days: [MobileMonitoringCalendarDay]
    var monthlyAverageUptime: Double?

    enum CodingKeys: String, CodingKey {
        case days
        case monthlyAverageUptime = "monthly_average_uptime"
    }
}

struct MobileMonitoringCalendarDay: Codable, Identifiable, Equatable {
    var date: String
    var uptimePercentage: Double?

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case uptimePercentage = "uptime_percentage"
    }
}

struct MobileMonitoringCapabilities: Codable, Equatable {
    var canManage: Bool

    enum CodingKeys: String, CodingKey {
        case canManage = "can_manage"
    }
}

struct MobileMonitoringDetailMeta: Codable, Equatable {
    var generatedAt: Date
    var range: MobileMonitoringDetailRange
    var incidents: MobileMonitoringIncidentPagination
    var sections: [String: MobileMonitoringDetailSection]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case range
        case incidents
        case sections
    }
}

struct MobileMonitoringDetailRange: Codable, Equatable {
    var days: Int
    var from: Date
    var to: Date
}

struct MobileMonitoringIncidentPagination: Codable, Equatable {
    var limit: Int
    var offset: Int
    var hasMore: Bool
    var nextOffset: Int?

    enum CodingKeys: String, CodingKey {
        case limit
        case offset
        case hasMore = "has_more"
        case nextOffset = "next_offset"
    }
}

enum MobileMonitoringDetailSectionState: String, Codable {
    case current
    case stale
    case empty
    case unavailable
}

struct MobileMonitoringDetailSection: Codable, Equatable {
    var state: MobileMonitoringDetailSectionState
    var generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case state
        case generatedAt = "generated_at"
    }
}

struct CachedMonitoringDetail: Codable, Equatable {
    var payload: MobileMonitoringDetailResponse
    var fetchedAt: Date
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
    var type: String?
    var ownership: MobileMonitoringOwnership?
    var maintenanceActive: Bool?
    var maintenanceFrom: Date?
    var maintenanceUntil: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case target
        case status
        case maintenanceActive = "maintenance_active"
        case maintenanceFrom = "maintenance_from"
        case maintenanceUntil = "maintenance_until"
    }
}

struct MonitoringNotificationPreference: Codable, Identifiable, Equatable, Hashable {
    var monitoringID: String
    var notificationOnFailure: Bool
    var notificationChannels: [String]
    var sslExpiryWarningDays: Int
    var source: String
    var permittedChannels: [String]
    var canUpdate: Bool
    var updatedAt: Date?

    var id: String {
        monitoringID
    }

    enum CodingKeys: String, CodingKey {
        case monitoringID = "monitoring_id"
        case effective, source
        case permittedChannels = "permitted_channels"
        case canUpdate = "can_update"
        case updatedAt = "updated_at"
    }

    private enum EffectiveKeys: String, CodingKey {
        case notificationOnFailure = "notification_on_failure"
        case notificationChannels = "notification_channels"
        case sslExpiryWarningDays = "ssl_expiry_warning_days"
    }

    init(
        monitoringID: String,
        notificationOnFailure: Bool,
        notificationChannels: [String],
        sslExpiryWarningDays: Int,
        source: String,
        permittedChannels: [String],
        canUpdate: Bool,
        updatedAt: Date?
    ) {
        self.monitoringID = monitoringID
        self.notificationOnFailure = notificationOnFailure
        self.notificationChannels = notificationChannels
        self.sslExpiryWarningDays = sslExpiryWarningDays
        self.source = source
        self.permittedChannels = permittedChannels
        self.canUpdate = canUpdate
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let effective = try container.nestedContainer(keyedBy: EffectiveKeys.self, forKey: .effective)
        monitoringID = try container.decode(String.self, forKey: .monitoringID)
        notificationOnFailure = try effective.decode(Bool.self, forKey: .notificationOnFailure)
        notificationChannels = try effective.decode([String].self, forKey: .notificationChannels)
        sslExpiryWarningDays = try effective.decode(Int.self, forKey: .sslExpiryWarningDays)
        source = try container.decode(String.self, forKey: .source)
        permittedChannels = try container.decode([String].self, forKey: .permittedChannels)
        canUpdate = try container.decode(Bool.self, forKey: .canUpdate)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monitoringID, forKey: .monitoringID)
        var effective = container.nestedContainer(keyedBy: EffectiveKeys.self, forKey: .effective)
        try effective.encode(notificationOnFailure, forKey: .notificationOnFailure)
        try effective.encode(notificationChannels, forKey: .notificationChannels)
        try effective.encode(sslExpiryWarningDays, forKey: .sslExpiryWarningDays)
        try container.encode(source, forKey: .source)
        try container.encode(permittedChannels, forKey: .permittedChannels)
        try container.encode(canUpdate, forKey: .canUpdate)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct MonitoringNotificationPreferenceResponse: Decodable {
    var data: MonitoringNotificationPreference
}

struct MonitoringNotificationPreferenceUpdatePayload: Encodable {
    var notificationOnFailure: Bool
    var notificationChannels: [String]
    var sslExpiryWarningDays: Int

    enum CodingKeys: String, CodingKey {
        case notificationOnFailure = "notification_on_failure"
        case notificationChannels = "notification_channels"
        case sslExpiryWarningDays = "ssl_expiry_warning_days"
    }
}

struct MobileNotificationBoardResponse: Decodable {
    var data: [MobileNotificationBoardEntry]
    var meta: MobileNotificationBoardMeta
}

struct MobileNotificationBoardMeta: Codable, Equatable {
    var nextCursor: String?
    var hasMore: Bool
    var unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
        case unreadCount = "unread_count"
    }
}

struct MobileNotificationBoardEntry: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var eventType: String
    var severity: String
    var message: String
    var occurredAt: Date
    var read: Bool
    var deliveryStatus: String
    var monitoring: MobileNotificationBoardMonitoring
    var cursor: String

    enum CodingKeys: String, CodingKey {
        case id, message, read, monitoring, cursor, severity
        case eventType = "event_type"
        case occurredAt = "occurred_at"
        case deliveryStatus = "delivery_status"
    }
}

struct MobileNotificationBoardMonitoring: Codable, Equatable, Hashable {
    var id: String
    var name: String
    var target: String
}

struct MobileNotificationReadResponse: Decodable {
    var data: MobileNotificationReadData
    var meta: MobileNotificationReadMeta?
}

struct MobileNotificationReadData: Decodable {
    var id: String?
    var read: Bool
}

struct MobileNotificationReadMeta: Decodable {
    var unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case unreadCount = "unread_count"
    }
}

struct MobileStatusPageListResponse: Decodable { var data: [MobileStatusPage] }
struct MobileStatusPageResponse: Decodable { var data: MobileStatusPage }
struct MobileStatusPage: Codable, Identifiable, Equatable {
    var id: String; var name: String; var description: String?; var publication: MobileStatusPagePublication
    var componentCount: Int; var verifiedSubscriberCount: Int; var openIncidentCount: Int
    enum CodingKeys: String, CodingKey { case id, name, description, publication; case componentCount = "component_count"; case verifiedSubscriberCount = "verified_subscriber_count"; case openIncidentCount = "open_incident_count" }
}
struct MobileStatusPagePublication: Codable, Equatable { var isPublic: Bool; var canChange: Bool; enum CodingKeys: String, CodingKey { case isPublic = "is_public"; case canChange = "can_change" } }
struct MobileIncidentWorkspaceListResponse: Decodable { var data: [MobileIncidentWorkspace] }
struct MobileIncidentWorkspaceResponse: Decodable { var data: MobileIncidentWorkspace }
struct MobileIncidentWorkspace: Codable, Identifiable, Equatable {
    var id: String; var monitoring: MobileNotificationBoardMonitoring; var lifecycle: MobileIncidentLifecycle; var readiness: MobileIncidentReadiness; var updates: [MobileIncidentUpdate]
}
struct MobileIncidentLifecycle: Codable, Equatable { var state: String; var openedAt: Date?; var resolvedAt: Date?; enum CodingKeys: String, CodingKey { case state; case openedAt = "opened_at"; case resolvedAt = "resolved_at" } }
struct MobileIncidentReadiness: Codable, Equatable { var canPublishUpdate: Bool; var requiresPublicUpdate: Bool; var updateCount: Int; enum CodingKeys: String, CodingKey { case canPublishUpdate = "can_publish_update"; case requiresPublicUpdate = "requires_public_update"; case updateCount = "update_count" } }
struct MobileIncidentUpdate: Codable, Identifiable, Equatable { var id: String; var status: String; var message: String; var publishedAt: Date?; enum CodingKeys: String, CodingKey { case id, status, message; case publishedAt = "published_at" } }
struct MobileIncidentUpdatePayload: Encodable { var status: String; var message: String }

struct CachedNotificationBoard: Codable, Equatable {
    var entries: [MobileNotificationBoardEntry]
    var meta: MobileNotificationBoardMeta
    var fetchedAt: Date
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

extension MonitorTone {
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
}

enum MaintenanceWindowState: Equatable {
    case active
    case upcoming

    var title: String {
        switch self {
        case .active:
            return "Aktiv"
        case .upcoming:
            return "Geplant"
        }
    }
}

extension KnownMonitor {
    var tone: MonitorTone {
        let value = (status ?? "").lowercased()

        if maintenanceWindowState == .active {
            return .maintenance
        }

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

    var maintenanceWindowState: MaintenanceWindowState? {
        let now = Date()

        if maintenanceActive == true
            || (maintenanceFrom.map { $0 <= now } == true
                && (maintenanceUntil == nil || maintenanceUntil.map { $0 > now } == true)) {
            return .active
        }

        if maintenanceFrom.map({ $0 > now }) == true {
            return .upcoming
        }

        return nil
    }
}
