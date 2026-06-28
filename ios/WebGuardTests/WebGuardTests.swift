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
