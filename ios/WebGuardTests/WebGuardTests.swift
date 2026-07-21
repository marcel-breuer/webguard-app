import XCTest
@testable import WebGuard

final class WebGuardTests: XCTestCase {
    func testClientNormalizesBaseURL() {
        let client = WebGuardAPIClient(serverURL: URL(string: "https://webguard.example.com/api?debug=true#section")!)

        XCTAssertEqual(client.serverURL.absoluteString, "https://webguard.example.com/api")
    }

    func testKnownMonitorToneClassifiesCommonStatuses() {
        XCTAssertEqual(monitor(status: "down").tone, .down)
        XCTAssertEqual(monitor(status: "failed").tone, .down)
        XCTAssertEqual(monitor(status: "maintenance").tone, .maintenance)
        XCTAssertEqual(monitor(status: "active").tone, .up)
        XCTAssertEqual(monitor(status: nil).tone, .unknown)
    }

    func testMobilePushDeviceDecodesSnakeCaseFields() throws {
        let json = """
        {
          "id": "device-1",
          "platform": "ios",
          "push_provider": "apns",
          "enabled": true,
          "last_registered_at": "2026-06-27T08:00:00Z",
          "last_seen_at": "2026-06-27T08:30:00Z"
        }
        """.data(using: .utf8)!

        let device = try JSONDecoder().decode(MobilePushDevice.self, from: json)

        XCTAssertEqual(device.id, "device-1")
        XCTAssertEqual(device.pushProvider, "apns")
        XCTAssertEqual(device.lastRegisteredAt, "2026-06-27T08:00:00Z")
        XCTAssertEqual(device.lastSeenAt, "2026-06-27T08:30:00Z")
    }

    func testWidgetSnapshotRoundTripsStatusData() throws {
        let snapshot = WidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 0),
            monitors: [
                WidgetMonitorSnapshot(
                    id: "monitor-1",
                    name: "Example",
                    target: "https://example.com",
                    status: "down",
                    isDown: true,
                    isMaintenance: false
                )
            ]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let roundTripped = try decoder.decode(
            WidgetSnapshot.self,
            from: encoder.encode(snapshot)
        )

        XCTAssertEqual(roundTripped, snapshot)
        XCTAssertEqual(roundTripped.monitors[0].statusLabel, "DOWN")
    }

    func testWidgetDeepLinksResolveOverviewAndMonitoring() {
        XCTAssertEqual(WidgetDeepLink.overview.absoluteString, "webguard://monitorings")
        let monitoringURL = WidgetDeepLink.monitoring("monitor-1")!

        XCTAssertEqual(monitoringURL.absoluteString, "webguard://monitoring/monitor-1")
        XCTAssertEqual(WidgetDeepLink.monitoringID(from: monitoringURL), "monitor-1")
    }

    func testWidgetSnapshotStoreClearsAccountData() {
        WidgetSnapshotStore.clear()
        WidgetSnapshotStore.save(monitors: [])
        XCTAssertNotNil(WidgetSnapshotStore.load())

        WidgetSnapshotStore.clear()

        XCTAssertNil(WidgetSnapshotStore.load())
    }

    func testDeepLinksRejectUnknownDestinations() {
        XCTAssertNil(WidgetDeepLink.monitoringID(from: URL(string: "https://example.test/monitoring/monitor-1")!))
        XCTAssertNil(WidgetDeepLink.monitoringID(from: URL(string: "webguard://overview")!))
        XCTAssertNil(WidgetDeepLink.monitoringID(from: URL(string: "webguard://monitoring/")!))
    }

    func testAccessibilityIdentifiersExposeStableStateMatrixTargets() {
        XCTAssertEqual(WebGuardAccessibilityID.overview, "webguard.overview")
        XCTAssertEqual(WebGuardAccessibilityID.overviewServiceLandscape, "webguard.overview.service-landscape")
        XCTAssertEqual(WebGuardAccessibilityID.service("monitor-1"), "webguard.overview.service.monitor-1")
        XCTAssertEqual(WebGuardAccessibilityID.attention("incident-1"), "webguard.overview.attention.incident-1")
        XCTAssertEqual(WebGuardAccessibilityID.monitoringDetail("monitor-1"), "webguard.monitorings.detail.monitor-1")
        XCTAssertEqual(WebGuardAccessibilityID.notificationRow("event-1"), "webguard.notifications.row.event-1")
        XCTAssertEqual(WebGuardAccessibilityID.pushToggle, "webguard.settings.push-toggle")
        XCTAssertEqual(WebGuardAccessibilityID.signOut, "webguard.settings.sign-out")
    }

    private func monitor(status: String?) -> KnownMonitor {
        KnownMonitor(
            id: "monitor-1",
            name: "Example",
            target: "https://example.com",
            status: status,
            lastSeenAt: Date(timeIntervalSince1970: 0)
        )
    }
}

@MainActor
final class AppStateTests: XCTestCase {
    func testAppStateLoadsCachedOverviewAndFreshnessState() {
        let monitor = Fixtures.monitor(status: "up")
        let overview = Fixtures.overview(for: monitor, recommendedAction: "notifications")
        let cache = InMemoryCacheStore(
            monitors: [monitor],
            overview: overview,
            lastRefreshAt: Date().addingTimeInterval(-600)
        )
        let sessionStore = InMemorySessionStore(session: Fixtures.session())
        let api = MockAPIClient()

        let state = AppState(
            keychain: sessionStore,
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )

        XCTAssertEqual(state.overview.recommendedAction, "notifications")
        XCTAssertEqual(state.monitors, [monitor])
        XCTAssertTrue(state.isMonitoringDataStale)
    }

    func testOverviewFailureKeepsCachedDataAndMarksOffline() async {
        let monitor = Fixtures.monitor(status: "down")
        let overview = Fixtures.overview(for: monitor, recommendedAction: "incidents")
        let cache = InMemoryCacheStore(monitors: [monitor], overview: overview)
        let sessionStore = InMemorySessionStore(session: Fixtures.session())
        let api = MockAPIClient()
        api.overviewResult = .failure(TestError.requestFailed)

        let state = AppState(
            keychain: sessionStore,
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )

        await state.refreshOverview()

        XCTAssertTrue(state.isOffline)
        XCTAssertEqual(state.overview, overview)
        XCTAssertEqual(state.session, sessionStore.session)
        XCTAssertNotNil(state.errorMessage)
    }

    func testUnauthorizedOverviewClearsSessionCachesAndWidgetData() async {
        let monitor = Fixtures.monitor(status: "down")
        let cache = InMemoryCacheStore(
            monitors: [monitor],
            overview: Fixtures.overview(for: monitor, recommendedAction: "incidents")
        )
        let sessionStore = InMemorySessionStore(session: Fixtures.session(deviceID: "device-1"))
        let api = MockAPIClient()
        api.overviewResult = .failure(WebGuardAPIError.unauthorized)

        let state = AppState(
            keychain: sessionStore,
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )
        WidgetSnapshotStore.save(monitors: [Fixtures.widgetMonitor])

        await state.refreshOverview()

        XCTAssertNil(state.session)
        XCTAssertNil(sessionStore.session)
        XCTAssertTrue(cache.loadMonitors().isEmpty)
        XCTAssertNil(cache.loadOverview())
        XCTAssertNil(WidgetSnapshotStore.load())
        XCTAssertEqual(api.logoutCount, 1)
        XCTAssertEqual(state.errorMessage, WebGuardAPIError.unauthorized.localizedDescription)
    }
}

private enum TestError: Error {
    case requestFailed
    case unexpectedCall
}

private enum Fixtures {
    static let widgetMonitor = WidgetMonitorSnapshot(
        id: "monitor-1",
        name: "API",
        target: "https://example.test",
        status: "up",
        isDown: false,
        isMaintenance: false
    )

    static func session(deviceID: String? = nil) -> StoredSession {
        StoredSession(
            serverURL: URL(string: "https://example.test")!,
            accessToken: "test-token",
            user: AuthenticatedUser(id: "user-1", name: "Test User", email: "test@example.test"),
            deviceID: deviceID,
            pushSetupCompleted: true,
            pushNotificationsEnabled: true,
            lastAPICallAt: Date(),
            lastTokenRefreshAt: Date()
        )
    }

    static func monitor(status: String?) -> KnownMonitor {
        KnownMonitor(
            id: "monitor-1",
            name: "API",
            target: "https://example.test",
            status: status,
            lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func overview(for monitor: KnownMonitor, recommendedAction: String) -> MobileOverviewPayload {
        var overview = MobileOverviewPayload.fallback(monitors: [monitor], events: [])
        overview.recommendedAction = recommendedAction
        return overview
    }
}

private final class InMemorySessionStore: SessionStore {
    var session: StoredSession?

    init(session: StoredSession? = nil) {
        self.session = session
    }

    func loadSession() throws -> StoredSession? { session }

    func saveSession(_ session: StoredSession) throws {
        self.session = session
    }

    func clearSession() throws {
        session = nil
    }
}

private final class InMemoryCacheStore: CacheStore {
    var monitors: [KnownMonitor]
    var events: [PushEvent]
    var overview: MobileOverviewPayload?
    var notificationPreferences: [String: MonitoringNotificationPreference]
    var lastRefreshAt: Date?

    init(
        monitors: [KnownMonitor] = [],
        events: [PushEvent] = [],
        overview: MobileOverviewPayload? = nil,
        notificationPreferences: [String: MonitoringNotificationPreference] = [:],
        lastRefreshAt: Date? = nil
    ) {
        self.monitors = monitors
        self.events = events
        self.overview = overview
        self.notificationPreferences = notificationPreferences
        self.lastRefreshAt = lastRefreshAt
    }

    func loadMonitors() -> [KnownMonitor] { monitors }
    func saveMonitors(_ monitors: [KnownMonitor]) { self.monitors = Array(monitors.prefix(100)) }
    func upsertMonitor(_ monitor: KnownMonitor) {
        saveMonitors([monitor] + monitors.filter { $0.id != monitor.id })
    }
    func loadEvents() -> [PushEvent] { events }
    func addEvent(_ event: PushEvent) {
        events = Array(([event] + events.filter { $0.id != event.id }).prefix(50))
    }
    func loadNotificationPreferences() -> [String: MonitoringNotificationPreference] { notificationPreferences }
    func saveNotificationPreferences(_ preferences: [String: MonitoringNotificationPreference]) {
        notificationPreferences = preferences
    }
    func loadLastMonitoringRefreshAt() -> Date? { lastRefreshAt }
    func saveLastMonitoringRefreshAt(_ date: Date) { lastRefreshAt = date }
    func loadOverview() -> MobileOverviewPayload? { overview }
    func saveOverview(_ overview: MobileOverviewPayload) { self.overview = overview }
    func clear() {
        monitors = []
        events = []
        overview = nil
        notificationPreferences = [:]
        lastRefreshAt = nil
    }
}

private final class MockAPIClient: WebGuardAPIClientProtocol {
    var overviewResult: Result<MobileOverviewPayload, Error> = .success(.fallback(monitors: [], events: []))
    var logoutCount = 0

    func logout() async throws {
        logoutCount += 1
    }

    func listMonitorings() async throws -> [KnownMonitor] {
        throw TestError.unexpectedCall
    }

    func operationsOverview(servicePage: Int) async throws -> MobileOverviewPayload {
        try overviewResult.get()
    }

    func registerAPNsDevice(token apnsToken: String, existingDeviceID: String?) async throws -> MobilePushDevice {
        throw TestError.unexpectedCall
    }

    func updateMobilePushDevice(deviceID: String, enabled: Bool) async throws -> MobilePushDevice {
        throw TestError.unexpectedCall
    }

    func revokeMobilePushDevice(deviceID: String) async throws {
    }

    func monitoringStatus(monitorID: String) async throws -> MonitoringStatusPayload {
        throw TestError.unexpectedCall
    }

    func monitoringNotificationPreference(monitorID: String) async throws -> MonitoringNotificationPreference {
        throw TestError.unexpectedCall
    }

    func updateMonitoringNotificationPreference(
        monitoringID: String,
        notificationOnFailure: Bool,
        notificationChannels: [String],
        sslExpiryWarningDays: Int
    ) async throws -> MonitoringNotificationPreference {
        throw TestError.unexpectedCall
    }
}
