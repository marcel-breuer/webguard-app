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
        cache.activate(for: "user-1")
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

    func testLocalCacheMigratesLegacyDataAndIsolatesAccounts() {
        let suiteName = "webguard.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data([0x01]), forKey: "webguard.known-monitors")

        let cache = LocalCache(defaults: defaults)
        let firstMonitor = KnownMonitor(
            id: "monitor-a",
            name: "First account",
            target: "https://first.example.test",
            status: "up",
            lastSeenAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let secondMonitor = KnownMonitor(
            id: "monitor-b",
            name: "Second account",
            target: "https://second.example.test",
            status: "down",
            lastSeenAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        cache.activate(for: "user-a")
        cache.saveMonitors([firstMonitor])
        cache.activate(for: "user-b")

        XCTAssertNil(defaults.data(forKey: "webguard.known-monitors"))
        XCTAssertTrue(cache.loadMonitors().isEmpty)

        cache.saveMonitors([secondMonitor])
        cache.activate(for: "user-a")
        XCTAssertEqual(cache.loadMonitors(), [firstMonitor])

        cache.activate(for: "user-b")
        XCTAssertEqual(cache.loadMonitors(), [secondMonitor])
    }

    func testMobileMonitoringDetailFixtureDecodesSectionFreshnessAndDiagnostics() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = """
        {
          "data": {
            "summary": {"id":"monitor-1","name":"API","target":"https://example.test","type":"http","lifecycle_status":"active","ownership":{"type":"private","can_manage":true},"performance":null,"open_incident":false},
            "current_check": {"status":"up","status_label":"Up","checked_at":"2026-08-15T08:00:00Z","response_time":120},
            "availability": {"has_data":true,"tracking_started_at":"2026-08-01T08:00:00Z","uptime":{"minutes":100,"percentage":99.5,"total":100},"downtime":{"minutes":1,"percentage":0.5,"total":1,"incidents_count":1},"unknown":{"minutes":0,"percentage":0,"total":0}},
            "response_times": {"data":[{"date":"2026-08-15T08:00:00Z","avg":120,"min":110,"max":140}],"aggregated":{"avg":120,"min":110,"max":140}},
            "incidents": [{"down_at":"2026-08-14T08:00:00Z","up_at":null}],
            "heatmap": [{"date":"2026-08-15T08:00:00Z","uptime":99.5,"downtime":0.5,"unknown":0}],
            "maintenance": {"active":false,"starts_at":null,"ends_at":null,"has_recurring_window":false},
            "ssl": {"valid":true,"expiration":"2026-12-01T08:00:00Z","issuer":"Example CA","issue_date":"2026-01-01T08:00:00Z"},
            "domain": null,
            "uptime_calendar": {"2026-08":{"days":[{"date":"2026-08-15","uptime_percentage":99.5}],"monthly_average_uptime":99.5}},
            "capabilities": {"can_manage":true}
          },
          "meta": {
            "generated_at":"2026-08-15T08:00:00Z",
            "range":{"days":30,"from":"2026-07-16T00:00:00Z","to":"2026-08-15T08:00:00Z"},
            "incidents":{"limit":20,"offset":0,"has_more":false,"next_offset":null},
            "sections":{"current_check":{"state":"current","generated_at":"2026-08-15T08:00:00Z"},"ssl":{"state":"current","generated_at":"2026-08-15T08:00:00Z"},"domain":{"state":"unavailable","generated_at":"2026-08-15T08:00:00Z"}}
          }
        }
        """.data(using: .utf8)!

        let detail = try decoder.decode(MobileMonitoringDetailResponse.self, from: json)

        XCTAssertEqual(detail.data.summary.name, "API")
        XCTAssertEqual(detail.data.availability.uptime.percentage, 99.5)
        XCTAssertEqual(detail.data.responseTimes.data.first?.avg, 120)
        XCTAssertNil(detail.data.incidents.first?.upAt)
        XCTAssertEqual(detail.meta.sections["domain"]?.state, .unavailable)
    }

    func testLocalCachePersistsBoundedMonitoringDetails() throws {
        let suiteName = "webguard.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let cache = LocalCache(defaults: defaults)
        cache.activate(for: "user-1")

        let detail = try monitoringDetailFixture()
        cache.saveMonitoringDetails(["monitor-1": CachedMonitoringDetail(payload: detail, fetchedAt: Date())])

        XCTAssertEqual(cache.loadMonitoringDetails()["monitor-1"]?.payload, detail)
        cache.clear()
        XCTAssertTrue(cache.loadMonitoringDetails().isEmpty)
    }

    private func monitoringDetailFixture() throws -> MobileMonitoringDetailResponse {
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
