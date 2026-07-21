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
}
