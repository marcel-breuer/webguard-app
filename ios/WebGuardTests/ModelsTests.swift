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

    func testOverviewTrendPreservesNoDataAndDeliveryFailureSignals() throws {
        var overview = MobileOverviewPayload.fallback(monitors: [], events: [])
        overview.trend = [
            OverviewTrendPoint(date: "2026-08-20", label: "Mi", uptimePercentage: 100, hasData: true),
            OverviewTrendPoint(date: "2026-08-21", label: "Do", uptimePercentage: nil, hasData: false),
            OverviewTrendPoint(date: "2026-08-22", label: "Fr", uptimePercentage: 0, hasData: true)
        ]
        overview.failedDeliveryCount = 2
        overview.recommendedAction = "notifications"

        let decoded = try JSONDecoder().decode(
            MobileOverviewPayload.self,
            from: JSONEncoder().encode(overview)
        )

        XCTAssertEqual(decoded.trend, overview.trend)
        XCTAssertEqual(decoded.trend[1].uptimePercentage, nil)
        XCTAssertTrue(decoded.trend[2].hasData)
        XCTAssertEqual(decoded.failedDeliveryCount, 2)
        XCTAssertEqual(decoded.recommendedAction, "notifications")
    }

    func testMonitoringFixtureDecodesConsolidatedCoreMonitoringPayload() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let listJSON = """
        {
          "data": [
            {
              "id": "monitor-1",
              "name": "API",
              "target": "https://example.test",
              "type": "http",
              "lifecycle_status": "active",
              "groups": [{"id": "group-1", "name": "Production"}],
              "latest_check": {
                "status": "up",
                "checked_at": "2026-07-21T10:30:00Z",
                "response_time_ms": 128.5
              },
              "ownership": {"type": "private", "can_manage": true},
              "open_incident": false,
              "can_manage": true,
              "maintenance": {
                "starts_at": "2026-07-21T10:00:00Z",
                "ends_at": "2026-07-21T11:00:00Z",
                "has_recurring_window": true
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let list = try decoder.decode(MonitoringListResponse.self, from: listJSON)
        let monitor = list.data[0]

        XCTAssertEqual(monitor.lifecycleStatus, "active")
        XCTAssertEqual(monitor.latestCheck?.status, "up")
        XCTAssertEqual(monitor.latestCheck?.checkedAt, Date(timeIntervalSince1970: 1_784_629_800))
        XCTAssertEqual(monitor.groups.first?.name, "Production")
        XCTAssertEqual(monitor.ownership?.type, "private")
        XCTAssertEqual(monitor.maintenance.startsAt, Date(timeIntervalSince1970: 1_784_628_000))
        XCTAssertEqual(monitor.maintenance.endsAt, Date(timeIntervalSince1970: 1_784_631_600))
        XCTAssertTrue(monitor.maintenance.hasRecurringWindow)

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
        XCTAssertNil(detail.data.serverHealthTelemetry)
    }

    func testServerHealthTelemetryDecodesNullableSamplesAndThresholds() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let telemetry = try decoder.decode(
            MobileServerHealthTelemetry.self,
            from: """
            {
              "data": [
                {
                  "checked_at": "2026-08-15T08:00:00Z",
                  "cpu_usage_percent": 72.5,
                  "ram_usage_percent": null,
                  "storage_usage_percent": 91.0,
                  "normalized_load": 1.2
                },
                {
                  "checked_at": "2026-08-15T09:00:00Z",
                  "cpu_usage_percent": null,
                  "ram_usage_percent": 88.0,
                  "storage_usage_percent": null,
                  "normalized_load": null
                }
              ],
              "thresholds": {
                "cpu_usage_percent": 90,
                "ram_usage_percent": 90,
                "storage_usage_percent": 90,
                "load_per_cpu": null
              }
            }
            """.data(using: .utf8)!
        )

        XCTAssertEqual(telemetry.data.count, 2)
        XCTAssertEqual(telemetry.data.first?.cpuUsagePercent, 72.5)
        XCTAssertNil(telemetry.data.first?.ramUsagePercent)
        XCTAssertEqual(telemetry.data.last?.ramUsagePercent, 88)
        XCTAssertNil(telemetry.thresholds?.loadPerCPU)
    }

    func testMonitoringCalendarPresentationSortsMonthsAndDaysAndOmitsEmptyMonths() {
        let months = [
            "2026-10": MobileMonitoringCalendarMonth(
                days: [
                    MobileMonitoringCalendarDay(date: "2026-10-02", uptimePercentage: 98),
                    MobileMonitoringCalendarDay(date: "2026-10-01", uptimePercentage: nil)
                ],
                monthlyAverageUptime: 98
            ),
            "2026-08": MobileMonitoringCalendarMonth(days: [], monthlyAverageUptime: nil),
            "2026-09": MobileMonitoringCalendarMonth(
                days: [MobileMonitoringCalendarDay(date: "2026-09-30", uptimePercentage: 100)],
                monthlyAverageUptime: 100
            )
        ]

        let sortedMonths = MonitoringCalendarPresentation.sortedMonths(months)

        XCTAssertEqual(sortedMonths.map(\.key), ["2026-09", "2026-10"])
        XCTAssertEqual(
            MonitoringCalendarPresentation.sortedDays(in: sortedMonths[1].month).map(\.date),
            ["2026-10-01", "2026-10-02"]
        )
    }

    func testMonitoringCalendarPresentationUsesStableUTCDateLabelsAndNoDataState() {
        XCTAssertEqual(MonitoringCalendarPresentation.monthTitle(for: "2026-03"), "März 2026")
        XCTAssertEqual(MonitoringCalendarPresentation.dayTitle(for: "2026-03-29"), "Sonntag, 29. März 2026")
        XCTAssertEqual(MonitoringCalendarPresentation.dayNumber(for: "2026-03-29"), "29")
        XCTAssertEqual(MonitoringCalendarPresentation.statusLabel(for: nil), "Keine Daten")
        XCTAssertEqual(MonitoringCalendarPresentation.statusLabel(for: 99.95), "Stabil")
        XCTAssertEqual(MonitoringCalendarPresentation.statusLabel(for: 94), "Ausfallrisiko")
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
