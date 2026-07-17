import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var session: StoredSession?
    @Published var monitors: [KnownMonitor] = []
    @Published var events: [PushEvent] = []
    @Published var notificationPreferences: [String: MonitoringNotificationPreference] = [:]
    @Published var pendingMonitoringID: String?
    @Published var errorMessage: String?
    @Published var isBusy = false

    private let keychain: KeychainStore
    private let cache: LocalCache
    private let apnsService: APNsService
    private static let defaultServerURL = URL(string: "https://app.webguard.marcel-breuer.dev")!

    convenience init() {
        self.init(keychain: .shared, cache: .shared, apnsService: .shared)
    }

    init(keychain: KeychainStore, cache: LocalCache, apnsService: APNsService) {
        self.keychain = keychain
        self.cache = cache
        self.apnsService = apnsService
        session = try? keychain.loadSession()
        monitors = cache.loadMonitors()
        events = cache.loadEvents()
        notificationPreferences = cache.loadNotificationPreferences()

        NotificationCenter.default.addObserver(
            forName: .didReceivePushEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.object as? PushEvent else {
                return
            }

            Task { @MainActor in
                self?.handlePushEvent(event)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .didOpenPushEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.object as? PushEvent else {
                return
            }

            Task { @MainActor in
                self?.pendingMonitoringID = event.monitoringID
            }
        }
    }

    var apiClient: WebGuardAPIClient? {
        guard let session else {
            return nil
        }

        return WebGuardAPIClient(serverURL: session.serverURL, token: session.accessToken)
    }

    private var configuredServerURL: URL {
        guard let configuredValue = Bundle.main.object(forInfoDictionaryKey: "WEBGUARD_BASE_URL") as? String,
              let configuredURL = URL(string: configuredValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              configuredURL.scheme != nil,
              configuredURL.host != nil else {
            return Self.defaultServerURL
        }

        return configuredURL
    }

    func signIn(email: String, password: String) async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            errorMessage = "E-Mail und Passwort sind erforderlich."
            return
        }

        let serverURL = configuredServerURL
        isBusy = true
        defer { isBusy = false }

        do {
            let loginClient = WebGuardAPIClient(serverURL: serverURL)
            let loginData = try await loginClient.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            let authenticatedClient = WebGuardAPIClient(serverURL: serverURL, token: loginData.token)
            let monitorings = try await authenticatedClient.listMonitorings()

            let next = StoredSession(
                serverURL: serverURL,
                accessToken: loginData.token,
                user: loginData.user,
                deviceID: nil,
                pushSetupCompleted: false,
                pushNotificationsEnabled: false,
                lastAPICallAt: Date(),
                lastTokenRefreshAt: nil
            )

            try keychain.saveSession(next)
            session = next
            cache.saveMonitors(monitorings)
            monitors = monitorings
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completePushSetupLater() {
        guard var next = session else {
            return
        }

        next.pushSetupCompleted = true
        persist(next)
    }

    func registerForPush() async {
        guard var next = session,
              let client = apiClient else {
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let token = try await apnsService.requestAuthorizationAndRegister()
            let device = try await client.registerAPNsDevice(token: token, existingDeviceID: next.deviceID)

            next.deviceID = device.id
            next.pushSetupCompleted = true
            next.pushNotificationsEnabled = device.enabled
            next.lastAPICallAt = Date()
            next.lastTokenRefreshAt = Date()
            persist(next)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setPushNotificationsEnabled(_ enabled: Bool) async {
        guard var next = session else {
            return
        }

        if next.deviceID == nil && enabled {
            await registerForPush()
            return
        }

        guard let deviceID = next.deviceID,
              let client = apiClient else {
            next.pushNotificationsEnabled = false
            persist(next)
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let device = try await client.updateMobilePushDevice(deviceID: deviceID, enabled: enabled)
            next.pushNotificationsEnabled = device.enabled
            next.lastAPICallAt = Date()
            persist(next)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshMonitorings() async {
        guard let client = apiClient else {
            return
        }

        do {
            let monitorings = try await client.listMonitorings()
            cache.saveMonitors(monitorings)
            monitors = monitorings
            updateLastAPICallAt()
        } catch WebGuardAPIError.unauthorized {
            await signOut()
            errorMessage = WebGuardAPIError.unauthorized.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshMonitoring(_ monitoringID: String) async -> KnownMonitor? {
        guard let client = apiClient else {
            return nil
        }

        do {
            let payload = try await client.monitoringStatus(monitorID: monitoringID)
            guard let index = monitors.firstIndex(where: { $0.id == monitoringID }) else {
                return nil
            }

            var monitor = monitors[index]
            monitor.status = payload.status ?? payload.statusLabel ?? monitor.status
            if let checkedAt = payload.checkedAt,
               let date = ISO8601DateFormatter().date(from: checkedAt) {
                monitor.lastSeenAt = date
            } else {
                monitor.lastSeenAt = Date()
            }

            monitors[index] = monitor
            cache.upsertMonitor(monitor)
            updateLastAPICallAt()
            return monitor
        } catch WebGuardAPIError.unauthorized {
            await signOut()
            errorMessage = WebGuardAPIError.unauthorized.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    func loadNotificationPreferences() async {
        guard let client = apiClient else {
            return
        }

        for monitor in monitors {
            do {
                let preference = try await client.monitoringNotificationPreference(monitorID: monitor.id)
                notificationPreferences[monitor.id] = preference
                cache.saveNotificationPreferences(notificationPreferences)
            } catch WebGuardAPIError.unauthorized {
                await signOut()
                errorMessage = WebGuardAPIError.unauthorized.localizedDescription
                return
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
    }

    func setMonitoringNotificationEnabled(_ enabled: Bool, monitoringID: String) async {
        guard let client = apiClient,
              let previous = notificationPreferences[monitoringID] else {
            return
        }

        var optimistic = previous
        optimistic.notificationOnFailure = enabled
        notificationPreferences[monitoringID] = optimistic
        cache.saveNotificationPreferences(notificationPreferences)

        isBusy = true
        defer { isBusy = false }

        do {
            let updated = try await client.updateMonitoringNotificationPreference(
                monitoringID: monitoringID,
                notificationOnFailure: enabled,
                notificationChannels: previous.notificationChannels,
                sslExpiryWarningDays: previous.sslExpiryWarningDays
            )
            notificationPreferences[monitoringID] = updated
            cache.saveNotificationPreferences(notificationPreferences)
            updateLastAPICallAt()
        } catch WebGuardAPIError.unauthorized {
            notificationPreferences[monitoringID] = previous
            cache.saveNotificationPreferences(notificationPreferences)
            await signOut()
            errorMessage = WebGuardAPIError.unauthorized.localizedDescription
        } catch {
            notificationPreferences[monitoringID] = previous
            cache.saveNotificationPreferences(notificationPreferences)
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        if let client = apiClient {
            if let deviceID = session?.deviceID {
                try? await client.revokeMobilePushDevice(deviceID: deviceID)
            }

            try? await client.logout()
        }

        try? keychain.clearSession()
        cache.clear()
        session = nil
        monitors = []
        events = []
        notificationPreferences = [:]
        pendingMonitoringID = nil
    }

    private func handlePushEvent(_ event: PushEvent) {
        cache.addEvent(event)
        events = cache.loadEvents()
        monitors = cache.loadMonitors()
    }

    private func persist(_ next: StoredSession) {
        do {
            try keychain.saveSession(next)
            session = next
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateLastAPICallAt() {
        guard var next = session else {
            return
        }

        next.lastAPICallAt = Date()
        persist(next)
    }
}
