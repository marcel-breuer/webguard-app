import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var session: StoredSession?
    @Published var monitors: [KnownMonitor] = []
    @Published var overview = MobileOverviewPayload.fallback(monitors: [], events: [])
    @Published var events: [PushEvent] = []
    @Published var notificationPreferences: [String: MonitoringNotificationPreference] = [:]
    @Published var pendingMonitoringID: String?
    @Published var isOffline = false
    @Published var lastMonitoringRefreshAt: Date?
    @Published private(set) var authenticationState: AuthenticationState = .signedOut
    @Published private(set) var monitoringLoadState: MonitoringLoadState = .idle
    @Published private(set) var operationState: AppOperationState = .idle
    @Published private(set) var alert: AppAlert?

    private let keychain: SessionStore
    private let cache: CacheStore
    private let apnsService: any PushAuthorizing
    private let deviceContextProvider: any DeviceContextProviding
    private let apiClientFactory: WebGuardAPIClientFactory
    private let serverURLProvider: () throws -> URL
    private var notificationObservers: [NSObjectProtocol] = []
    private static let monitoringFreshnessWindow: TimeInterval = 5 * 60

    convenience init() {
        self.init(
            keychain: KeychainStore.shared,
            cache: LocalCache.shared,
            apnsService: APNsService.shared,
            deviceContextProvider: SystemDeviceContextProvider(),
            apiClientFactory: .live,
            serverURLProvider: { try WebGuardConfiguration.serverURL() }
        )
    }

    init(
        keychain: SessionStore,
        cache: CacheStore,
        apnsService: any PushAuthorizing,
        deviceContextProvider: any DeviceContextProviding,
        apiClientFactory: WebGuardAPIClientFactory,
        serverURLProvider: @escaping () throws -> URL
    ) {
        self.keychain = keychain
        self.cache = cache
        self.apnsService = apnsService
        self.deviceContextProvider = deviceContextProvider
        self.apiClientFactory = apiClientFactory
        self.serverURLProvider = serverURLProvider
        session = try? keychain.loadSession()
        cache.activate(for: session?.user.id)
        monitors = cache.loadMonitors()
        events = cache.loadEvents()
        overview = cache.loadOverview() ?? .fallback(monitors: monitors, events: events)
        notificationPreferences = cache.loadNotificationPreferences()
        lastMonitoringRefreshAt = cache.loadLastMonitoringRefreshAt()
        authenticationState = session == nil ? .signedOut : .authenticated
        monitoringLoadState = monitors.isEmpty ? .empty : (isMonitoringDataStale ? .stale : .loaded)
        if session == nil {
            WidgetSnapshotStore.clear()
        } else {
            saveWidgetSnapshot()
        }

        registerNotificationObservers()
    }

    convenience init(
        keychain: SessionStore,
        cache: CacheStore,
        apnsService: APNsService,
        clientFactory: @escaping (StoredSession) -> WebGuardAPIClientProtocol = { session in
            WebGuardAPIClient(serverURL: session.serverURL, token: session.accessToken)
        }
    ) {
        self.init(
            keychain: keychain,
            cache: cache,
            apnsService: apnsService,
            deviceContextProvider: SystemDeviceContextProvider(),
            apiClientFactory: WebGuardAPIClientFactory(
                unauthenticatedClient: { WebGuardAPIClient(serverURL: $0) },
                authenticatedClient: clientFactory
            ),
            serverURLProvider: { try WebGuardConfiguration.serverURL() }
        )
    }

    private func registerNotificationObservers() {
        let receiveObserver = NotificationCenter.default.addObserver(
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

        notificationObservers.append(receiveObserver)

        let openObserver = NotificationCenter.default.addObserver(
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

        notificationObservers.append(openObserver)
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
    }

    var isBusy: Bool {
        operationState != .idle
    }

    var errorMessage: String? {
        alert?.message
    }

    var apiClient: (any WebGuardAPIClientProtocol)? {
        session.map(apiClientFactory.authenticatedClient)
    }

    func signIn(email: String, password: String) async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            alert = AppAlert(message: "E-Mail und Passwort sind erforderlich.")
            return
        }

        let serverURL: URL
        do {
            serverURL = try serverURLProvider()
        } catch {
            show(error)
            return
        }

        authenticationState = .signingIn
        monitoringLoadState = .loading
        operationState = .signingIn
        defer { operationState = .idle }

        do {
            let loginClient = apiClientFactory.unauthenticatedClient(serverURL)
            let loginData = try await loginClient.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                deviceContext: deviceContextProvider.currentDeviceContext()
            )
            let authenticatedClient = apiClientFactory.authenticatedClient(
                StoredSession(
                    serverURL: serverURL,
                    accessToken: loginData.token,
                    user: loginData.user,
                    deviceID: nil,
                    pushSetupCompleted: false,
                    pushNotificationsEnabled: false,
                    lastAPICallAt: nil,
                    lastTokenRefreshAt: nil
                )
            )
            let monitorings = try await authenticatedClient.listMonitorings()
            let remoteOverview = try? await authenticatedClient.operationsOverview(servicePage: 1)

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
            cache.activate(for: next.user.id)
            session = next
            events = cache.loadEvents()
            notificationPreferences = cache.loadNotificationPreferences()
            cache.saveMonitors(monitorings)
            let refreshedAt = Date()
            cache.saveLastMonitoringRefreshAt(refreshedAt)
            lastMonitoringRefreshAt = refreshedAt
            isOffline = false
            monitors = monitorings
            overview = remoteOverview ?? .fallback(monitors: monitorings, events: events)
            if let remoteOverview {
                cache.saveOverview(remoteOverview)
            }
            saveWidgetSnapshot()
            authenticationState = .authenticated
            monitoringLoadState = monitorings.isEmpty ? .empty : .loaded
        } catch {
            authenticationState = .signedOut
            monitoringLoadState = .failed
            show(error)
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

        operationState = .registeringPush
        defer { operationState = .idle }

        do {
            let token = try await apnsService.requestAuthorizationAndRegister()
            let device = try await client.registerAPNsDevice(
                token: token,
                existingDeviceID: next.deviceID,
                deviceContext: deviceContextProvider.currentDeviceContext()
            )

            next.deviceID = device.id
            next.pushSetupCompleted = true
            next.pushNotificationsEnabled = device.enabled
            next.lastAPICallAt = Date()
            next.lastTokenRefreshAt = Date()
            persist(next)
        } catch {
            show(error)
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

        operationState = .updatingPushPreference
        defer { operationState = .idle }

        do {
            let device = try await client.updateMobilePushDevice(deviceID: deviceID, enabled: enabled)
            next.pushNotificationsEnabled = device.enabled
            next.lastAPICallAt = Date()
            persist(next)
        } catch {
            show(error)
        }
    }

    func refreshMonitorings() async {
        guard let client = apiClient else {
            return
        }

        monitoringLoadState = monitors.isEmpty ? .loading : .refreshing
        do {
            let monitorings = try await client.listMonitorings()
            cache.saveMonitors(monitorings)
            monitors = monitorings
            let refreshedAt = Date()
            cache.saveLastMonitoringRefreshAt(refreshedAt)
            lastMonitoringRefreshAt = refreshedAt
            isOffline = false
            overview = .fallback(monitors: monitorings, events: events)
            saveWidgetSnapshot()
            updateLastAPICallAt()
            monitoringLoadState = monitorings.isEmpty ? .empty : .loaded
        } catch WebGuardAPIError.unauthorized {
            await signOut()
            show(WebGuardAPIError.unauthorized)
        } catch {
            isOffline = true
            monitoringLoadState = monitors.isEmpty ? .failed : .stale
            show(error)
        }
    }

    var isMonitoringDataStale: Bool {
        guard let lastMonitoringRefreshAt else {
            return !monitors.isEmpty
        }

        return Date().timeIntervalSince(lastMonitoringRefreshAt) > Self.monitoringFreshnessWindow
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
               let date = WebGuardJSONCoding.date(from: checkedAt) {
                monitor.lastSeenAt = date
            } else {
                monitor.lastSeenAt = Date()
            }

            monitors[index] = monitor
            cache.upsertMonitor(monitor)
            saveWidgetSnapshot()
            updateLastAPICallAt()
            return monitor
        } catch WebGuardAPIError.unauthorized {
            await signOut()
            show(WebGuardAPIError.unauthorized)
        } catch {
            show(error)
        }

        return nil
    }

    func refreshOverview() async {
        guard let client = apiClient else {
            return
        }

        monitoringLoadState = monitors.isEmpty ? .loading : .refreshing
        do {
            let nextOverview = try await client.operationsOverview(servicePage: 1)
            overview = nextOverview
            cache.saveOverview(nextOverview)
            let nextMonitors = nextOverview.services.map { service in
                KnownMonitor(
                    id: service.id,
                    name: service.name,
                    target: service.target,
                    status: service.status,
                    lastSeenAt: service.lastCheckedAt ?? Date()
                )
            }
            if !nextMonitors.isEmpty {
                cache.saveMonitors(nextMonitors)
                monitors = nextMonitors
            }
            isOffline = false
            updateLastAPICallAt()
            monitoringLoadState = monitors.isEmpty ? .empty : .loaded
        } catch WebGuardAPIError.unauthorized {
            await signOut()
            show(WebGuardAPIError.unauthorized)
        } catch {
            isOffline = true
            if overview.services.isEmpty {
                overview = .fallback(monitors: monitors, events: events)
            }
            monitoringLoadState = monitors.isEmpty ? .failed : .stale
            show(error)
        }
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
                show(WebGuardAPIError.unauthorized)
                return
            } catch {
                show(error)
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

        operationState = .updatingMonitoringPreference
        defer { operationState = .idle }

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
            show(WebGuardAPIError.unauthorized)
        } catch {
            notificationPreferences[monitoringID] = previous
            cache.saveNotificationPreferences(notificationPreferences)
            show(error)
        }
    }

    func signOut() async {
        authenticationState = .signingOut
        if let client = apiClient {
            if let deviceID = session?.deviceID {
                try? await client.revokeMobilePushDevice(deviceID: deviceID)
            }

            try? await client.logout()
        }

        try? keychain.clearSession()
        cache.clear()
        cache.activate(for: nil)
        session = nil
        monitors = []
        events = []
        overview = .fallback(monitors: [], events: [])
        notificationPreferences = [:]
        pendingMonitoringID = nil
        isOffline = false
        lastMonitoringRefreshAt = nil
        monitoringLoadState = .empty
        authenticationState = .signedOut
        operationState = .idle
        WidgetSnapshotStore.clear()
    }

    func dismissAlert() {
        alert = nil
    }

    func present(message: String) {
        alert = AppAlert(message: message)
    }

    func handleDeepLink(_ url: URL) {
        if let monitoringID = WidgetDeepLink.monitoringID(from: url) {
            pendingMonitoringID = monitoringID
        }
    }

    private func handlePushEvent(_ event: PushEvent) {
        cache.addEvent(event)
        events = cache.loadEvents()
        monitors = cache.loadMonitors()
        overview = .fallback(monitors: monitors, events: events)
        monitoringLoadState = monitors.isEmpty ? .empty : .loaded
        saveWidgetSnapshot()
    }

    private func persist(_ next: StoredSession) {
        do {
            try keychain.saveSession(next)
            session = next
        } catch {
            show(error)
        }
    }

    private func updateLastAPICallAt() {
        guard var next = session else {
            return
        }

        next.lastAPICallAt = Date()
        persist(next)
    }

    private func saveWidgetSnapshot() {
        WidgetSnapshotStore.save(
            monitors: monitors.map { monitor in
                WidgetMonitorSnapshot(
                    id: monitor.id,
                    name: monitor.name,
                    target: monitor.target,
                    status: monitor.status ?? "",
                    isDown: monitor.tone == .down,
                    isMaintenance: monitor.tone == .maintenance
                )
            }
        )
    }

    private func show(_ error: Error) {
        alert = AppAlert(message: error.localizedDescription)
    }
}
