import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let didReceiveAPNsToken = Notification.Name("WebGuard.didReceiveAPNsToken")
    static let didReceivePushEvent = Notification.Name("WebGuard.didReceivePushEvent")
    static let didOpenPushEvent = Notification.Name("WebGuard.didOpenPushEvent")
}

enum APNsServiceError: LocalizedError {
    case permissionDenied
    case missingToken

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Push-Berechtigung wurde nicht erteilt."
        case .missingToken:
            return "APNs hat noch keinen Device Token geliefert."
        }
    }
}

@MainActor
final class APNsService: ObservableObject {
    static let shared = APNsService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?

    private init() {
        NotificationCenter.default.addObserver(
            forName: .didReceiveAPNsToken,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.deviceToken = notification.object as? String
            }
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorizationAndRegister() async throws -> String {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

        guard granted else {
            authorizationStatus = .denied
            throw APNsServiceError.permissionDenied
        }

        authorizationStatus = .authorized
        UIApplication.shared.registerForRemoteNotifications()

        if let deviceToken {
            return deviceToken
        }

        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 100_000_000)

            if let deviceToken {
                return deviceToken
            }
        }

        throw APNsServiceError.missingToken
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationCenter.default.post(name: .didReceiveAPNsToken, object: token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        postPushEventIfPresent(notification.request.content.userInfo, opened: false)
        return [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        postPushEventIfPresent(response.notification.request.content.userInfo, opened: true)
    }

    private func postPushEventIfPresent(_ userInfo: [AnyHashable: Any], opened: Bool) {
        guard let event = PushEvent(userInfo: userInfo) else {
            return
        }

        NotificationCenter.default.post(name: .didReceivePushEvent, object: event)

        if opened {
            NotificationCenter.default.post(name: .didOpenPushEvent, object: event)
        }
    }
}

private extension PushEvent {
    init?(userInfo: [AnyHashable: Any]) {
        guard let monitoringID = userInfo["monitoring_id"] as? String,
              let monitoringName = userInfo["monitoring_name"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        let occurredAtString = userInfo["occurred_at"] as? String
        let occurredAt = occurredAtString.flatMap { formatter.date(from: $0) } ?? Date()
        let notificationID = userInfo["notification_id"] as? String ?? UUID().uuidString

        self.init(
            id: notificationID,
            eventType: userInfo["event_type"] as? String ?? "incident",
            severity: userInfo["severity"] as? String ?? "critical",
            monitoringID: monitoringID,
            monitoringName: monitoringName,
            monitoringTarget: userInfo["monitoring_target"] as? String ?? "",
            occurredAt: occurredAt,
            notificationID: notificationID,
            receivedAt: Date()
        )
    }
}
