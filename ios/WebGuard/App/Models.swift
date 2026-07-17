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

struct MonitoringListResponse: Decodable {
    var data: [MonitoringSummary]
}

struct MonitoringSummary: Decodable, Identifiable {
    var id: String
    var name: String
    var target: String
    var status: String?
}

struct MonitoringNotificationPreference: Codable, Identifiable, Equatable, Hashable {
    var monitoringID: String
    var notificationOnFailure: Bool
    var notificationChannels: [String]
    var sslExpiryWarningDays: Int

    var id: String {
        monitoringID
    }

    enum CodingKeys: String, CodingKey {
        case monitoringID = "monitoring_id"
        case notificationOnFailure = "notification_on_failure"
        case notificationChannels = "notification_channels"
        case sslExpiryWarningDays = "ssl_expiry_warning_days"
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
