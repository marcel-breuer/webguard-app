import Foundation
import XCTest
@testable import WebGuard

final class WebGuardTests: XCTestCase {
    func testProductionConfigurationUsesCanonicalCoreDomain() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let files = [
            "ios/WebGuard/Config/Debug.xcconfig",
            "ios/WebGuard/Config/Release.xcconfig",
            "docs/ios-app-store.md"
        ]

        for file in files {
            let contents = try String(contentsOf: repositoryRoot.appendingPathComponent(file), encoding: .utf8)

            XCTAssertFalse(contents.contains("app.webguard.marcel-breuer.dev"), file)
            XCTAssertTrue(contents.contains("https:/$()/app.webguard.dev"), file)
        }
    }

    func testClientNormalizesBaseURL() {
        let client = WebGuardAPIClient(serverURL: URL(string: "https://webguard.example.com/api?debug=true#section")!)

        XCTAssertEqual(client.serverURL.absoluteString, "https://webguard.example.com/api")
    }

    func testClientUsesConsolidatedCoreRoutes() async throws {
        URLProtocolStub.reset()
        URLProtocolStub.install { request in
            let path = request.url?.path ?? ""
            let body: Data

            switch path {
            case "/api/mobile/login":
                body = #"{"data":{"token":"mobile-token","token_type":"Bearer","user":{"id":"user-1","name":"Marcel","email":"marcel@example.test"}}}"#.data(using: .utf8)!
            case "/api/monitorings":
                body = #"{"data":[]}"#.data(using: .utf8)!
            case "/api/mobile/push-devices":
                body = #"{"data":{"id":"device-1","platform":"ios","push_provider":"apns","enabled":true}}"#.data(using: .utf8)!
            case "/api/mobile/status-pages/status-page-1/incidents/incident-1/updates":
                body = #"{"data":{"id":"incident-1","monitoring":{"id":"monitor-1","name":"Example","target":"https://example.test"},"lifecycle":{"state":"investigating","opened_at":null,"resolved_at":null},"readiness":{"can_publish_update":true,"requires_public_update":false,"update_count":1},"updates":[]}}"#.data(using: .utf8)!
            default:
                body = Data()
            }

            let statusCode = request.httpMethod == "DELETE" ? 204 : 200
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            return (response, body)
        }
        defer { URLProtocolStub.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let unauthenticatedClient = WebGuardAPIClient(
            serverURL: URL(string: "https://webguard.example.test")!,
            urlSession: session
        )
        let authenticatedClient = WebGuardAPIClient(
            serverURL: URL(string: "https://webguard.example.test")!,
            token: "mobile-token",
            urlSession: session
        )
        let deviceContext = DeviceContext(name: "Test iPhone", appVersion: "1.0", locale: "en_US", timezone: "UTC")

        _ = try await unauthenticatedClient.login(email: "marcel@example.test", password: "password", deviceContext: deviceContext)
        _ = try await authenticatedClient.listMonitorings()
        _ = try await authenticatedClient.registerAPNsDevice(token: "apns-token", deviceContext: deviceContext)
        try await authenticatedClient.revokeMobilePushDevice(deviceID: "device-1")
        _ = try await authenticatedClient.publishIncidentUpdate(
            statusPageID: "status-page-1",
            incidentID: "incident-1",
            payload: MobileIncidentUpdatePayload(status: "investigating", message: "Investigating the incident."),
            idempotencyKey: "request-1"
        )

        let requests = URLProtocolStub.recordedRequests()

        XCTAssertEqual(requests.map { $0.url?.path }, [
            "/api/mobile/login",
            "/api/monitorings",
            "/api/mobile/push-devices",
            "/api/mobile/push-devices/device-1",
            "/api/mobile/status-pages/status-page-1/incidents/incident-1/updates"
        ])
        XCTAssertEqual(requests.map { $0.httpMethod }, ["POST", "GET", "POST", "DELETE", "POST"])
        XCTAssertEqual(requests[4].value(forHTTPHeaderField: "Idempotency-Key"), "request-1")
    }

    func testClientUsesIncidentWorkspaceRoutesAndIdempotencyHeaders() async throws {
        URLProtocolStub.reset()
        URLProtocolStub.install { request in
            let responseBody = #"{"data":{"id":"incident-1","monitoring":{"id":"monitor-1","name":"Example","target":"https://example.test"},"lifecycle":{"state":"open","opened_at":null,"resolved_at":null},"readiness":{"can_publish_update":true,"requires_public_update":false,"update_count":1},"updates":[]}}"#
            let statusCode = request.httpMethod == "DELETE" ? 204 : 200
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(responseBody.utf8))
        }
        defer { URLProtocolStub.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = WebGuardAPIClient(
            serverURL: URL(string: "https://webguard.example.test")!,
            token: "mobile-token",
            urlSession: URLSession(configuration: configuration)
        )

        _ = try await client.statusPageIncident(statusPageID: "page-1", incidentID: "incident-1")
        _ = try await client.updateIncidentMetadata(
            statusPageID: "page-1",
            incidentID: "incident-1",
            payload: MobileIncidentMetadataPayload(incidentType: "dependency", severity: "high", affectedService: "Checkout", customerImpact: "degraded", contributingCategory: "dependency")
        )
        _ = try await client.updateIncidentReview(
            statusPageID: "page-1",
            incidentID: "incident-1",
            payload: MobileIncidentReviewPayload(problemDescription: "Upstream unavailable", resolutionDescription: nil)
        )
        _ = try await client.createIncidentFollowUp(
            statusPageID: "page-1",
            incidentID: "incident-1",
            payload: MobileIncidentFollowUpPayload(title: "Add fallback", description: nil, assignedUserID: nil, dueAt: nil, status: nil, externalURL: nil, idempotencyKey: nil),
            idempotencyKey: "follow-up-1"
        )
        _ = try await client.updateIncidentFollowUp(
            statusPageID: "page-1",
            incidentID: "incident-1",
            followUpID: "follow-up-1",
            payload: MobileIncidentFollowUpPayload(title: "Add fallback", description: nil, assignedUserID: nil, dueAt: nil, status: "in_progress", externalURL: nil, idempotencyKey: nil)
        )
        try await client.deleteIncidentFollowUp(statusPageID: "page-1", incidentID: "incident-1", followUpID: "follow-up-1")
        _ = try await client.createIncidentTimelineEvent(
            statusPageID: "page-1",
            incidentID: "incident-1",
            payload: MobileIncidentTimelineEventPayload(title: "Fallback enabled", description: nil, occurredAt: "2026-08-15T09:00:00Z", idempotencyKey: nil),
            idempotencyKey: "timeline-1"
        )
        _ = try await client.updateIncidentTimelineEvent(
            statusPageID: "page-1",
            incidentID: "incident-1",
            eventID: "timeline-1",
            payload: MobileIncidentTimelineEventPayload(title: "Fallback active", description: nil, occurredAt: "2026-08-15T09:00:00Z", idempotencyKey: nil)
        )
        try await client.deleteIncidentTimelineEvent(statusPageID: "page-1", incidentID: "incident-1", eventID: "timeline-1")

        let requests = URLProtocolStub.recordedRequests()
        XCTAssertEqual(requests.map { $0.url?.path }, [
            "/api/mobile/status-pages/page-1/incidents/incident-1",
            "/api/mobile/status-pages/page-1/incidents/incident-1/metadata",
            "/api/mobile/status-pages/page-1/incidents/incident-1/review",
            "/api/mobile/status-pages/page-1/incidents/incident-1/follow-ups",
            "/api/mobile/status-pages/page-1/incidents/incident-1/follow-ups/follow-up-1",
            "/api/mobile/status-pages/page-1/incidents/incident-1/follow-ups/follow-up-1",
            "/api/mobile/status-pages/page-1/incidents/incident-1/timeline",
            "/api/mobile/status-pages/page-1/incidents/incident-1/timeline/timeline-1",
            "/api/mobile/status-pages/page-1/incidents/incident-1/timeline/timeline-1"
        ])
        XCTAssertEqual(requests.map { $0.httpMethod }, ["GET", "PATCH", "PATCH", "POST", "PATCH", "DELETE", "POST", "PATCH", "DELETE"])
        XCTAssertEqual(requests[3].value(forHTTPHeaderField: "Idempotency-Key"), "follow-up-1")
        XCTAssertEqual(requests[6].value(forHTTPHeaderField: "Idempotency-Key"), "timeline-1")
        XCTAssertTrue(String(data: requests[1].httpBody ?? Data(), encoding: .utf8)?.contains("\"severity\":\"high\"") == true)
    }

    func testClientTreatsIncidentWorkspacePermissionErrorsAsUnauthorized() async throws {
        URLProtocolStub.reset()
        URLProtocolStub.install { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { URLProtocolStub.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = WebGuardAPIClient(serverURL: URL(string: "https://webguard.example.test")!, urlSession: URLSession(configuration: configuration))

        do {
            _ = try await client.updateIncidentMetadata(
                statusPageID: "page-1",
                incidentID: "incident-1",
                payload: MobileIncidentMetadataPayload(incidentType: nil, severity: nil, affectedService: nil, customerImpact: nil, contributingCategory: nil)
            )
            XCTFail("Expected unauthorized response")
        } catch WebGuardAPIError.unauthorized {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClientMapsConsolidatedMonitoringContractAndOwnershipRoutes() async throws {
        URLProtocolStub.reset()
        URLProtocolStub.install { request in
            let path = request.url?.path ?? ""
            let responseBody: String

            switch (request.httpMethod, path) {
            case ("GET", "/api/monitorings"):
                responseBody = #"{"data":[{"id":"monitor-1","name":"API","target":"https://example.test","type":"http","lifecycle_status":"active","groups":[{"id":"group-1","name":"Production"}],"latest_check":{"status":"up","checked_at":"2026-08-22T10:30:00Z","response_time_ms":128.5},"ownership":{"type":"private","can_manage":true,"team_id":null,"team_name":null},"open_incident":false,"can_manage":true,"maintenance":{"starts_at":"2026-08-22T10:00:00Z","ends_at":"2026-08-22T11:00:00Z","has_recurring_window":true}}],"links":{"first":"https://example.test/api/monitorings?page=1","last":"https://example.test/api/monitorings?page=1","prev":null,"next":null},"meta":{"current_page":1,"last_page":1,"per_page":25,"from":1,"to":1,"total":1,"as_of":"2026-08-22T10:30:00Z"}}"#
            case ("POST", "/api/monitorings"):
                responseBody = #"{"data":{"id":"monitor-2","name":"Created","type":"http","lifecycle_status":"active","public_label_enabled":false,"ownership":{"type":"private","can_manage":true,"team_id":null},"group_assignments":[]}}"#
            case ("PATCH", "/api/monitorings/monitor-2"):
                responseBody = #"{"data":{"id":"monitor-2","name":"Updated","type":"http","lifecycle_status":"paused","public_label_enabled":false,"ownership":{"type":"private","can_manage":true,"team_id":null},"group_assignments":[{"id":"group-1","name":"Production"}]}}"#
            case ("POST", "/api/monitorings/monitor-1/ownership/team"):
                responseBody = #"{"data":{"id":"monitor-1","ownership":{"type":"team","can_manage":true,"team_id":"team-1","team_name":"Operations"}}}"#
            case ("POST", "/api/monitorings/monitor-1/ownership/private"):
                responseBody = #"{"data":{"id":"monitor-1","ownership":{"type":"private","can_manage":true,"team_id":null,"team_name":null}}}"#
            case ("DELETE", "/api/monitorings/monitor-2"):
                responseBody = ""
            default:
                responseBody = "{}"
            }

            let statusCode = request.httpMethod == "DELETE" ? 204 : 200
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            return (response, Data(responseBody.utf8))
        }
        defer { URLProtocolStub.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = WebGuardAPIClient(
            serverURL: URL(string: "https://webguard.example.test")!,
            token: "mobile-token",
            urlSession: URLSession(configuration: configuration)
        )
        let payload = MonitoringMutationPayload(
            name: "Created",
            target: "https://created.example.test",
            type: "http",
            status: "active",
            timeout: 10,
            httpMethod: "GET",
            expectedHTTPStatuses: "200-299",
            httpHeaders: [:],
            port: nil
        )

        let monitors = try await client.listMonitorings()
        let created = try await client.createMonitoring(payload)
        let updated = try await client.updateMonitoring(id: "monitor-2", payload: payload)
        let movedToTeam = try await client.moveMonitoring(id: "monitor-1", toTeamID: "team-1")
        let movedToPrivate = try await client.moveMonitoring(id: "monitor-1", toTeamID: nil)
        try await client.deleteMonitoring(id: "monitor-2")

        XCTAssertEqual(monitors.first?.status, "up")
        XCTAssertEqual(monitors.first?.lifecycleStatus, "active")
        XCTAssertEqual(monitors.first?.lastSeenAt ?? .distantPast, Date(timeIntervalSince1970: 1_787_394_600))
        XCTAssertEqual(monitors.first?.groups?.first?.name, "Production")
        XCTAssertEqual(monitors.first?.ownership?.type, "private")
        XCTAssertEqual(created.data.lifecycleStatus, "active")
        XCTAssertEqual(updated.data.lifecycleStatus, "paused")
        XCTAssertEqual(updated.data.groupAssignments?.first?.id, "group-1")
        XCTAssertEqual(movedToTeam.data.ownership?.teamID, "team-1")
        XCTAssertEqual(movedToPrivate.data.ownership?.type, "private")

        let requests = URLProtocolStub.recordedRequests()
        XCTAssertEqual(requests.map { $0.url?.path }, [
            "/api/monitorings",
            "/api/monitorings",
            "/api/monitorings/monitor-2",
            "/api/monitorings/monitor-1/ownership/team",
            "/api/monitorings/monitor-1/ownership/private",
            "/api/monitorings/monitor-2"
        ])
        XCTAssertEqual(requests.map { $0.httpMethod }, ["GET", "POST", "PATCH", "POST", "POST", "DELETE"])
    }

    func testClientTreatsUnauthorizedAndUnexpectedMonitoringResponsesAsFailures() async throws {
        URLProtocolStub.reset()
        URLProtocolStub.install { request in
            let statusCode: Int
            switch request.url?.path {
            case "/api/monitorings": statusCode = 401
            case "/api/monitorings/monitor-1": statusCode = 403
            default: statusCode = 200
            }
            let body = statusCode == 401 ? Data() : Data(#"{"data":{"id":"monitor-1"}}"#.utf8)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }
        defer { URLProtocolStub.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = WebGuardAPIClient(
            serverURL: URL(string: "https://webguard.example.test")!,
            urlSession: URLSession(configuration: configuration)
        )

        do {
            _ = try await client.listMonitorings()
            XCTFail("Expected unauthorized response")
        } catch WebGuardAPIError.unauthorized {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            try await client.deleteMonitoring(id: "monitor-1")
            XCTFail("Expected forbidden response")
        } catch WebGuardAPIError.unauthorized {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await client.createMonitoring(MonitoringMutationPayload(name: "API", target: "https://example.test", type: "http", status: "active", timeout: nil, httpMethod: nil, expectedHTTPStatuses: nil, httpHeaders: nil, port: nil))
            XCTFail("Expected decoding failure")
        } catch DecodingError.keyNotFound(_, _) {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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

    func testNotificationBoardAndEffectivePreferenceDecodeCoreContract() throws {
        let board = """
        {"data":[{"id":"notification-1","event_type":"ssl_expiring","severity":"warning","message":"Certificate expires soon","occurred_at":"2026-08-15T10:00:00Z","read":false,"delivery_status":"failed","monitoring":{"id":"monitor-1","name":"Example","target":"https://example.test"},"cursor":"opaque-cursor"}],"meta":{"next_cursor":"next","has_more":true,"unread_count":3}}
        """.data(using: .utf8)!
        let preference = """
        {"data":{"monitoring_id":"monitor-1","effective":{"notification_on_failure":true,"notification_channels":["mail","apns"],"ssl_expiry_warning_days":14},"source":"team_member","permitted_channels":["mail","apns"],"can_update":false,"updated_at":"2026-08-15T10:00:00Z"}}
        """.data(using: .utf8)!
        let decoder = WebGuardJSONCoding.makeDecoder()

        let decodedBoard = try decoder.decode(MobileNotificationBoardResponse.self, from: board)
        let decodedPreference = try decoder.decode(MonitoringNotificationPreferenceResponse.self, from: preference)

        XCTAssertEqual(decodedBoard.data.first?.eventType, "ssl_expiring")
        XCTAssertEqual(decodedBoard.meta.unreadCount, 3)
        XCTAssertEqual(decodedPreference.data.source, "team_member")
        XCTAssertFalse(decodedPreference.data.canUpdate)
        XCTAssertEqual(decodedPreference.data.sslExpiryWarningDays, 14)
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
        XCTAssertEqual(WebGuardAccessibilityID.notificationNavigation, "webguard.navigation.notifications")
        XCTAssertEqual(WebGuardAccessibilityID.overview, "webguard.overview")
        XCTAssertEqual(WebGuardAccessibilityID.overviewDataState, "webguard.overview.data-state")
        XCTAssertEqual(WebGuardAccessibilityID.overviewUptimeTrend, "webguard.overview.uptime-trend")
        XCTAssertEqual(WebGuardAccessibilityID.overviewDeliveryFailures, "webguard.overview.delivery-failures")
        XCTAssertEqual(WebGuardAccessibilityID.overviewServiceLandscape, "webguard.overview.service-landscape")
        XCTAssertEqual(WebGuardAccessibilityID.service("monitor-1"), "webguard.overview.service.monitor-1")
        XCTAssertEqual(WebGuardAccessibilityID.attention("incident-1"), "webguard.overview.attention.incident-1")
        XCTAssertEqual(WebGuardAccessibilityID.monitoringDetail("monitor-1"), "webguard.monitorings.detail.monitor-1")
        XCTAssertEqual(WebGuardAccessibilityID.monitoringPerformance, "webguard.monitorings.performance")
        XCTAssertEqual(WebGuardAccessibilityID.monitoringServerHealth, "webguard.monitorings.server-health")
        XCTAssertEqual(WebGuardAccessibilityID.monitoringUptimeCalendar, "webguard.monitorings.uptime-calendar")
        XCTAssertEqual(
            WebGuardAccessibilityID.monitoringUptimeCalendarDay("2026-08-15"),
            "webguard.monitorings.uptime-calendar-day.2026-08-15"
        )
        XCTAssertEqual(WebGuardAccessibilityID.statusPageIncidentMetadata, "webguard.status-pages.incident.metadata")
        XCTAssertEqual(WebGuardAccessibilityID.statusPageIncidentTimeline, "webguard.status-pages.incident.timeline")
        XCTAssertEqual(WebGuardAccessibilityID.statusPageIncidentFollowUps, "webguard.status-pages.incident.follow-ups")
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

private final class URLProtocolStub: URLProtocol {
    private static let lock = NSLock()
    private static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    private static var requests: [URLRequest] = []

    static func install(_ handler: @escaping (URLRequest) -> (HTTPURLResponse, Data)) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        handler = nil
        requests = []
        lock.unlock()
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            fatalError("URLProtocolStub was used without a response handler.")
        }

        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !data.isEmpty {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
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

    func testNotificationBoardRefreshCachesServerEntriesAndUnreadCount() async {
        let entry = MobileNotificationBoardEntry(
            id: "notification-1",
            eventType: "incident",
            severity: "critical",
            message: "Example is down",
            occurredAt: Date(),
            read: false,
            deliveryStatus: "unknown",
            monitoring: MobileNotificationBoardMonitoring(id: "monitor-1", name: "Example", target: "https://example.test"),
            cursor: "cursor-1"
        )
        let cache = InMemoryCacheStore()
        let api = MockAPIClient()
        api.notificationBoardResult = .success(MobileNotificationBoardResponse(
            data: [entry],
            meta: MobileNotificationBoardMeta(nextCursor: "next", hasMore: true, unreadCount: 1)
        ))
        let state = AppState(
            keychain: InMemorySessionStore(session: Fixtures.session()),
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )

        await state.refreshNotificationBoard()

        XCTAssertEqual(state.notificationBoard, [entry])
        XCTAssertEqual(state.notificationBoardMeta.unreadCount, 1)
        XCTAssertEqual(cache.loadNotificationBoard()?.entries, [entry])
        XCTAssertFalse(state.isNotificationBoardStale)
    }

    func testNotificationBoardUsesCachedUnreadCountWhenRefreshFails() async {
        let entry = MobileNotificationBoardEntry(
            id: "notification-cached",
            eventType: "incident",
            severity: "critical",
            message: "Example is down",
            occurredAt: Date(),
            read: false,
            deliveryStatus: "unknown",
            monitoring: MobileNotificationBoardMonitoring(id: "monitor-1", name: "Example", target: "https://example.test"),
            cursor: "cursor-cached"
        )
        let cache = InMemoryCacheStore(notificationBoard: CachedNotificationBoard(
            entries: [entry],
            meta: MobileNotificationBoardMeta(nextCursor: nil, hasMore: false, unreadCount: 1),
            fetchedAt: Date().addingTimeInterval(-600)
        ))
        let api = MockAPIClient()
        api.notificationBoardResult = .failure(TestError.requestFailed)
        let state = AppState(
            keychain: InMemorySessionStore(session: Fixtures.session()),
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )

        await state.refreshNotificationBoard()

        XCTAssertEqual(state.notificationBoardMeta.unreadCount, 1)
        XCTAssertEqual(state.notificationBoard, [entry])
        XCTAssertTrue(state.isOffline)
        XCTAssertTrue(state.isNotificationBoardStale)
    }

    func testPushEventIncrementsNotificationUnreadCount() async {
        let cache = InMemoryCacheStore(notificationBoard: CachedNotificationBoard(
            entries: [],
            meta: MobileNotificationBoardMeta(nextCursor: nil, hasMore: false, unreadCount: 1),
            fetchedAt: Date()
        ))
        let api = MockAPIClient()
        api.notificationBoardResult = .success(MobileNotificationBoardResponse(
            data: [],
            meta: MobileNotificationBoardMeta(nextCursor: nil, hasMore: false, unreadCount: 2)
        ))
        let state = AppState(
            keychain: InMemorySessionStore(session: Fixtures.session()),
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )
        let event = PushEvent(
            id: "push-1",
            eventType: "incident",
            severity: "critical",
            monitoringID: "monitor-1",
            monitoringName: "Example",
            monitoringTarget: "https://example.test",
            occurredAt: Date(),
            notificationID: "notification-push-1",
            receivedAt: Date()
        )

        NotificationCenter.default.post(name: .didReceivePushEvent, object: event)
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(state.notificationBoardMeta.unreadCount, 2)
        XCTAssertEqual(state.notificationBoard.first?.id, "local-notification-push-1")
    }

    func testMarkingNotificationReadRollsBackUnreadCountWhenRequestFails() async {
        let entry = MobileNotificationBoardEntry(
            id: "notification-rollback",
            eventType: "incident",
            severity: "critical",
            message: "Example is down",
            occurredAt: Date(),
            read: false,
            deliveryStatus: "unknown",
            monitoring: MobileNotificationBoardMonitoring(id: "monitor-1", name: "Example", target: "https://example.test"),
            cursor: "cursor-rollback"
        )
        let cache = InMemoryCacheStore(notificationBoard: CachedNotificationBoard(
            entries: [entry],
            meta: MobileNotificationBoardMeta(nextCursor: nil, hasMore: false, unreadCount: 1),
            fetchedAt: Date()
        ))
        let api = MockAPIClient()
        api.markNotificationReadResult = .failure(TestError.requestFailed)
        let state = AppState(
            keychain: InMemorySessionStore(session: Fixtures.session()),
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )

        await state.markNotificationRead(entry)

        XCTAssertEqual(state.notificationBoard, [entry])
        XCTAssertEqual(state.notificationBoardMeta.unreadCount, 1)
        XCTAssertNotNil(state.errorMessage)
    }

    func testMarkingAllNotificationsReadHidesUnreadCount() async {
        let entry = MobileNotificationBoardEntry(
            id: "notification-all",
            eventType: "incident",
            severity: "critical",
            message: "Example is down",
            occurredAt: Date(),
            read: false,
            deliveryStatus: "unknown",
            monitoring: MobileNotificationBoardMonitoring(id: "monitor-1", name: "Example", target: "https://example.test"),
            cursor: "cursor-all"
        )
        let cache = InMemoryCacheStore(notificationBoard: CachedNotificationBoard(
            entries: [entry],
            meta: MobileNotificationBoardMeta(nextCursor: nil, hasMore: false, unreadCount: 1),
            fetchedAt: Date()
        ))
        let api = MockAPIClient()
        api.markAllNotificationReadResult = .success(0)
        let state = AppState(
            keychain: InMemorySessionStore(session: Fixtures.session()),
            cache: cache,
            apnsService: .shared,
            clientFactory: { _ in api }
        )

        await state.markAllNotificationsRead()

        XCTAssertEqual(state.notificationBoardMeta.unreadCount, 0)
        XCTAssertTrue(state.notificationBoard.allSatisfy(\.read))
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
            user: AuthenticatedUser(id: "user-1", name: "Test User", email: "test@example.test")
        ))
        api.monitoringsResult = .success([monitor])
        api.notificationBoardResult = .success(MobileNotificationBoardResponse(
            data: [],
            meta: MobileNotificationBoardMeta(nextCursor: nil, hasMore: false, unreadCount: 0)
        ))

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
    var notificationBoard: CachedNotificationBoard?
    var lastRefreshAt: Date?

    init(
        monitors: [KnownMonitor] = [],
        events: [PushEvent] = [],
        overview: MobileOverviewPayload? = nil,
        notificationPreferences: [String: MonitoringNotificationPreference] = [:],
        lastRefreshAt: Date? = nil,
        notificationBoard: CachedNotificationBoard? = nil
    ) {
        self.monitors = monitors
        self.events = events
        self.overview = overview
        self.notificationPreferences = notificationPreferences
        self.lastRefreshAt = lastRefreshAt
        self.notificationBoard = notificationBoard
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
    func loadNotificationBoard() -> CachedNotificationBoard? { notificationBoard }
    func saveNotificationBoard(_ board: CachedNotificationBoard) { notificationBoard = board }
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
        notificationBoard = nil
        lastRefreshAt = nil
    }
}

private final class MockAPIClient: WebGuardAPIClientProtocol {
    var loginResult: Result<MobileLoginData, Error> = .failure(TestError.unexpectedCall)
    var monitoringsResult: Result<[KnownMonitor], Error> = .failure(TestError.unexpectedCall)
    var overviewResult: Result<MobileOverviewPayload, Error> = .success(.fallback(monitors: [], events: []))
    var detailResult: Result<MobileMonitoringDetailResponse, Error> = .failure(TestError.unexpectedCall)
    var notificationBoardResult: Result<MobileNotificationBoardResponse, Error> = .failure(TestError.unexpectedCall)
    var markNotificationReadResult: Result<Void, Error> = .success(())
    var markAllNotificationReadResult: Result<Int, Error> = .success(0)
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
    func notificationBoard(cursor: String?, eventType: String?, showRead: Bool) async throws -> MobileNotificationBoardResponse { try notificationBoardResult.get() }
    func markNotificationRead(id: String) async throws { try markNotificationReadResult.get() }
    func markAllNotificationsRead() async throws -> Int { try markAllNotificationReadResult.get() }
    func statusPages() async throws -> [MobileStatusPage] { [] }
    func statusPageIncidents(statusPageID: String) async throws -> [MobileIncidentWorkspace] { [] }
    func statusPageIncident(statusPageID: String, incidentID: String) async throws -> MobileIncidentWorkspace { throw TestError.unexpectedCall }
    func updateStatusPagePublication(id: String, isPublic: Bool) async throws -> MobileStatusPage { throw TestError.unexpectedCall }
    func publishIncidentUpdate(statusPageID: String, incidentID: String, payload: MobileIncidentUpdatePayload, idempotencyKey: String) async throws -> MobileIncidentWorkspace { throw TestError.unexpectedCall }
    func updateIncidentMetadata(statusPageID: String, incidentID: String, payload: MobileIncidentMetadataPayload) async throws -> MobileIncidentWorkspace { throw TestError.unexpectedCall }
    func updateIncidentReview(statusPageID: String, incidentID: String, payload: MobileIncidentReviewPayload) async throws -> MobileIncidentWorkspace { throw TestError.unexpectedCall }
    func createIncidentFollowUp(statusPageID: String, incidentID: String, payload: MobileIncidentFollowUpPayload, idempotencyKey: String) async throws -> MobileIncidentWorkspace { throw TestError.unexpectedCall }
    func updateIncidentFollowUp(statusPageID: String, incidentID: String, followUpID: String, payload: MobileIncidentFollowUpPayload) async throws -> MobileIncidentWorkspace { throw TestError.unexpectedCall }
    func deleteIncidentFollowUp(statusPageID: String, incidentID: String, followUpID: String) async throws {}
    func createIncidentTimelineEvent(statusPageID: String, incidentID: String, payload: MobileIncidentTimelineEventPayload, idempotencyKey: String) async throws -> MobileIncidentWorkspace { throw TestError.unexpectedCall }
    func updateIncidentTimelineEvent(statusPageID: String, incidentID: String, eventID: String, payload: MobileIncidentTimelineEventPayload) async throws -> MobileIncidentWorkspace { throw TestError.unexpectedCall }
    func deleteIncidentTimelineEvent(statusPageID: String, incidentID: String, eventID: String) async throws {}

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
