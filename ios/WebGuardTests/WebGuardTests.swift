import XCTest
@testable import WebGuard

final class WebGuardTests: XCTestCase {
    func testClientNormalizesBaseURL() {
        let client = WebGuardAPIClient(serverURL: URL(string: "https://webguard.example.com/api?debug=true#section")!)

        XCTAssertEqual(client.serverURL.absoluteString, "https://webguard.example.com/api")
    }

    func testServerErrorDoesNotExposeResponseBody() {
        let message = WebGuardAPIError.requestFailed(503).localizedDescription

        XCTAssertEqual(message, "Der WebGuard-Dienst ist derzeit nicht erreichbar. Bitte versuche es spaeter erneut.")
        XCTAssertFalse(message.contains("<"))
    }

    func testConfigurationRequiresValidHTTPSURLs() throws {
        XCTAssertThrowsError(try WebGuardConfiguration.validatedHTTPSURL(nil))
        XCTAssertThrowsError(try WebGuardConfiguration.validatedHTTPSURL("http://webguard.example.test"))

        let url = try WebGuardConfiguration.validatedHTTPSURL("https://webguard.example.test/register")

        XCTAssertEqual(url.host, "webguard.example.test")
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
        XCTAssertEqual(WebGuardAccessibilityID.overviewDataState, "webguard.overview.data-state")
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

    func testOverviewRefreshUpdatesFreshnessTimestamp() async {
        let monitor = Fixtures.monitor(status: "up")
        let staleRefresh = Date().addingTimeInterval(-600)
        let cache = InMemoryCacheStore(monitors: [monitor], lastRefreshAt: staleRefresh)
        let sessionStore = InMemorySessionStore(session: Fixtures.session())
        let api = MockAPIClient()
        api.overviewResult = .success(Fixtures.overview(for: monitor, recommendedAction: "notifications"))
        let state = AppState(
            keychain: sessionStore,
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )

        await state.refreshOverview()

        XCTAssertFalse(state.isMonitoringDataStale)
        XCTAssertNotNil(cache.loadLastMonitoringRefreshAt())
        XCTAssertGreaterThan(state.lastMonitoringRefreshAt ?? .distantPast, staleRefresh)
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

    func testSignInUsesInjectedClientsAndPublishesExplicitStates() async {
        let monitor = Fixtures.monitor(status: "up")
        let sessionStore = InMemorySessionStore()
        let cache = InMemoryCacheStore()
        let api = MockAPIClient()
        api.loginResult = .success(MobileLoginData(
            token: "mobile-token",
            tokenType: "Bearer",
            user: AuthenticatedUser(id: "user-1", name: "Test User", email: "test@example.test")
        ))
        api.monitoringsResult = .success([monitor])

        let state = AppState(
            keychain: sessionStore,
            cache: cache,
            apnsService: FakePushService(),
            deviceContextProvider: FakeDeviceContextProvider(),
            apiClientFactory: WebGuardAPIClientFactory(
                unauthenticatedClient: { _ in api },
                authenticatedClient: { _ in api }
            ),
            serverURLProvider: { URL(string: "https://example.test")! }
        )

        await state.signIn(email: "test@example.test", password: "secret")

        XCTAssertEqual(state.authenticationState, .authenticated)
        XCTAssertEqual(state.monitoringLoadState, .loaded)
        XCTAssertEqual(state.operationState, .idle)
        XCTAssertEqual(state.session?.accessToken, "mobile-token")
        XCTAssertEqual(cache.loadMonitors(), [monitor])
        XCTAssertNil(state.alert)
    }

    func testDetailRefreshKeepsCachedPayloadWhenOffline() async throws {
        let cachedDetail = try Fixtures.monitoringDetail()
        let monitor = Fixtures.monitor(status: "up")
        let cache = InMemoryCacheStore(monitors: [monitor])
        cache.monitoringDetails = [monitor.id: CachedMonitoringDetail(payload: cachedDetail, fetchedAt: Date())]
        let api = MockAPIClient()
        api.detailResult = .failure(TestError.requestFailed)
        let state = AppState(
            keychain: InMemorySessionStore(session: Fixtures.session()),
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )

        let result = await state.refreshMonitoringDetail(monitor.id)

        XCTAssertEqual(result, cachedDetail)
        XCTAssertTrue(state.isOffline)
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

    static func monitoringDetail() throws -> MobileMonitoringDetailResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            MobileMonitoringDetailResponse.self,
            from: """
            {"data":{"summary":{"id":"monitor-1","name":"API","target":"https://example.test"},"current_check":{},"availability":{"has_data":false,"uptime":{"minutes":0,"total":0},"downtime":{"minutes":0,"total":0},"unknown":{"minutes":0,"total":0}},"response_times":{"data":[],"aggregated":{}},"incidents":[],"heatmap":[],"maintenance":{"active":false,"has_recurring_window":false},"ssl":null,"domain":null,"uptime_calendar":{},"capabilities":{"can_manage":false}},"meta":{"generated_at":"2026-08-15T08:00:00Z","range":{"days":30,"from":"2026-07-16T00:00:00Z","to":"2026-08-15T08:00:00Z"},"incidents":{"limit":20,"offset":0,"has_more":false,"next_offset":null},"sections":{}}}
            """.data(using: .utf8)!
        )
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
    var monitoringDetails: [String: CachedMonitoringDetail] = [:]
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

    func activate(for userID: String?) {}
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
    func loadMonitoringDetails() -> [String: CachedMonitoringDetail] { monitoringDetails }
    func saveMonitoringDetails(_ details: [String: CachedMonitoringDetail]) { monitoringDetails = details }
    func clear() {
        monitors = []
        events = []
        overview = nil
        monitoringDetails = [:]
        notificationPreferences = [:]
        lastRefreshAt = nil
    }
}

private final class MockAPIClient: WebGuardAPIClientProtocol {
    var loginResult: Result<MobileLoginData, Error> = .failure(TestError.unexpectedCall)
    var monitoringsResult: Result<[KnownMonitor], Error> = .failure(TestError.unexpectedCall)
    var overviewResult: Result<MobileOverviewPayload, Error> = .success(.fallback(monitors: [], events: []))
    var detailResult: Result<MobileMonitoringDetailResponse, Error> = .failure(TestError.unexpectedCall)
    var logoutCount = 0

    func login(email: String, password: String, deviceContext: DeviceContext) async throws -> MobileLoginData {
        try loginResult.get()
    }

    func logout() async throws {
        logoutCount += 1
    }

    func listMonitorings() async throws -> [KnownMonitor] {
        try monitoringsResult.get()
    }

    func operationsOverview(servicePage: Int) async throws -> MobileOverviewPayload {
        try overviewResult.get()
    }

    func registerAPNsDevice(
        token apnsToken: String,
        existingDeviceID: String?,
        deviceContext: DeviceContext
    ) async throws -> MobilePushDevice {
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

    func monitoringDetail(monitorID: String, days: Int, incidentOffset: Int) async throws -> MobileMonitoringDetailResponse {
        try detailResult.get()
    }

    func createMonitoring(_ payload: MonitoringMutationPayload) async throws -> MonitoringManagementResponse {
        throw TestError.unexpectedCall
    }

    func updateMonitoring(id: String, payload: MonitoringMutationPayload) async throws -> MonitoringManagementResponse {
        throw TestError.unexpectedCall
    }

    func deleteMonitoring(id: String) async throws {
        throw TestError.unexpectedCall
    }

    func monitoringGroups() async throws -> [MobileMonitoringGroup] { throw TestError.unexpectedCall }
    func saveMonitoringGroup(id: String?, payload: MonitoringGroupMutationPayload) async throws -> MobileMonitoringGroup { throw TestError.unexpectedCall }
    func deleteMonitoringGroup(id: String) async throws { throw TestError.unexpectedCall }
    func teams() async throws -> [TeamSummary] { throw TestError.unexpectedCall }
    func moveMonitoring(id: String, toTeamID: String?) async throws -> MonitoringManagementResponse { throw TestError.unexpectedCall }
    func maintenanceWindows(kind: String, state: String?) async throws -> [MobileMaintenanceWindow] { throw TestError.unexpectedCall }
    func maintenanceCapabilities() async throws -> MobileMaintenanceCapabilities { throw TestError.unexpectedCall }
    func scheduleMaintenance(_ payload: MaintenanceSchedulePayload) async throws -> MobileMaintenanceWindow { throw TestError.unexpectedCall }
    func setRecurringMaintenanceEnabled(id: String, enabled: Bool) async throws -> MobileMaintenanceWindow { throw TestError.unexpectedCall }
    func cancelOneOffMaintenance(monitoringID: String) async throws { throw TestError.unexpectedCall }

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

@MainActor
private final class FakePushService: PushAuthorizing {
    func requestAuthorizationAndRegister() async throws -> String {
        "apns-token"
    }
}

@MainActor
private final class FakeDeviceContextProvider: DeviceContextProviding {
    func currentDeviceContext() -> DeviceContext {
        DeviceContext(name: "Test iPhone", appVersion: "1.0", locale: "en_US", timezone: "UTC")
    }
}
