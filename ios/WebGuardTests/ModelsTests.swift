import XCTest
@testable import WebGuard

final class ModelsTests: XCTestCase {
    func testFallbackCreatesDegradedOverviewForDownMonitor() {
        let monitor = KnownMonitor(
            id: "monitor-1",
            name: "API",
            target: "https://example.test",
            status: "down",
            lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let overview = MobileOverviewPayload.fallback(monitors: [monitor], events: [])

        XCTAssertEqual(overview.overallState, .degraded)
        XCTAssertEqual(overview.summary.total, 1)
        XCTAssertEqual(overview.summary.down, 1)
        XCTAssertEqual(overview.attention.first?.monitoringID, "monitor-1")
    }

    func testOverviewRoundTripPreservesServerPayload() throws {
        let overview = MobileOverviewPayload(
            overallState: .healthy,
            summary: OverviewSummary(total: 1, healthy: 1, down: 0, unknown: 0, paused: 0, maintenance: 0),
            services: [
                OverviewService(
                    id: "monitor-1",
                    name: "API",
                    target: "https://example.test",
                    type: "http",
                    group: "Production",
                    status: "up",
                    openIncident: false,
                    lastCheckedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    responseTimeMs: 120
                )
            ],
            attention: [],
            maintenance: [],
            recentIncidents: [],
            trend: [],
            failedDeliveryCount: 0,
            recommendedAction: "monitorings",
            capabilities: OverviewCapabilities(canCreateMonitoring: true, canManageMaintenance: true)
        )

        let data = try JSONEncoder().encode(overview)
        let decoded = try JSONDecoder().decode(MobileOverviewPayload.self, from: data)

        XCTAssertEqual(decoded, overview)
    }

    func testMonitoringFixtureDecodesMaintenanceAndStatusPayloads() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let listJSON = """
        {
          "data": [
            {
              "id": "monitor-1",
              "name": "API",
              "target": "https://example.test",
              "status": "up",
              "maintenance_active": true,
              "maintenance_from": "2026-07-21T10:00:00Z",
              "maintenance_until": "2026-07-21T11:00:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let list = try decoder.decode(MonitoringListResponse.self, from: listJSON)
        let monitor = list.data[0]

        XCTAssertEqual(monitor.maintenanceActive, true)
        XCTAssertEqual(monitor.maintenanceFrom, Date(timeIntervalSince1970: 1_784_628_000))
        XCTAssertEqual(monitor.maintenanceUntil, Date(timeIntervalSince1970: 1_784_631_600))

        let statusJSON = """
        {
          "status": "down",
          "status_label": "Failed",
          "checked_at": "2026-07-21T10:30:00Z"
        }
        """.data(using: .utf8)!
        let status = try decoder.decode(MonitoringStatusPayload.self, from: statusJSON)

        XCTAssertEqual(status.status, "down")
        XCTAssertEqual(status.statusLabel, "Failed")
        XCTAssertEqual(status.checkedAt, "2026-07-21T10:30:00Z")
    }

    func testPushEventFixtureRoundTripsIncidentAndRecoveryState() throws {
        let event = PushEvent(
            id: "event-1",
            eventType: "incident",
            severity: "critical",
            monitoringID: "monitor-1",
            monitoringName: "API",
            monitoringTarget: "https://example.test",
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            notificationID: "notification-1",
            receivedAt: Date(timeIntervalSince1970: 1_700_000_010)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(PushEvent.self, from: encoder.encode(event))

        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.eventType, "incident")
        XCTAssertEqual(decoded.severity, "critical")
    }

    func testStatusMatrixKeepsMaintenanceAndUnknownStatesExplicit() {
        let now = Date()
        let active = KnownMonitor(
            id: "active",
            name: "Active maintenance",
            target: "https://example.test",
            status: "up",
            lastSeenAt: now,
            maintenanceActive: true
        )
        let upcoming = KnownMonitor(
            id: "upcoming",
            name: "Upcoming maintenance",
            target: "https://example.test",
            status: "up",
            lastSeenAt: now,
            maintenanceFrom: now.addingTimeInterval(3600)
        )
        let unknown = KnownMonitor(
            id: "unknown",
            name: "Unknown",
            target: "https://example.test",
            status: nil,
            lastSeenAt: now
        )

        XCTAssertEqual(active.tone, .maintenance)
        XCTAssertEqual(active.maintenanceWindowState, .active)
        XCTAssertEqual(upcoming.maintenanceWindowState, .upcoming)
        XCTAssertEqual(upcoming.tone, .up)
        XCTAssertEqual(unknown.tone, .unknown)
    }

    func testLocalCachePersistsAndClearsAllFixtureData() {
        let suiteName = "webguard.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let cache = LocalCache(defaults: defaults)
        let monitor = KnownMonitor(
            id: "monitor-1",
            name: "API",
            target: "https://example.test",
            status: "up",
            lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let event = PushEvent(
            id: "event-1",
            eventType: "recovery",
            severity: "info",
            monitoringID: monitor.id,
            monitoringName: monitor.name,
            monitoringTarget: monitor.target,
            occurredAt: monitor.lastSeenAt,
            notificationID: "notification-1",
            receivedAt: monitor.lastSeenAt
        )

        cache.saveMonitors([monitor])
        cache.addEvent(event)
        cache.saveOverview(.fallback(monitors: [monitor], events: [event]))
        cache.saveLastMonitoringRefreshAt(monitor.lastSeenAt)

        XCTAssertEqual(cache.loadMonitors(), [monitor])
        XCTAssertEqual(cache.loadEvents(), [event])
        XCTAssertNotNil(cache.loadOverview())
        XCTAssertEqual(cache.loadLastMonitoringRefreshAt(), monitor.lastSeenAt)

        cache.clear()

        XCTAssertTrue(cache.loadMonitors().isEmpty)
        XCTAssertTrue(cache.loadEvents().isEmpty)
        XCTAssertNil(cache.loadOverview())
        XCTAssertNil(cache.loadLastMonitoringRefreshAt())
    }
}
