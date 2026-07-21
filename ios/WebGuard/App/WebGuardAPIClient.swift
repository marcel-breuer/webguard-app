import Foundation
import UIKit

enum WebGuardAPIError: LocalizedError {
    case invalidResponse
    case requestFailed(Int, String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Die WebGuard API hat keine gueltige Antwort geliefert."
        case let .requestFailed(status, message):
            return "WebGuard API Fehler \(status): \(message)"
        case .unauthorized:
            return "Die Anmeldung ist abgelaufen. Bitte melde dich erneut an."
        }
    }
}

final class WebGuardAPIClient {
    let serverURL: URL
    private let token: String?
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(serverURL: URL, token: String? = nil, urlSession: URLSession = .shared) {
        self.serverURL = serverURL.normalizedWebGuardBaseURL()
        self.token = token
        self.urlSession = urlSession
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func login(email: String, password: String) async throws -> MobileLoginData {
        let deviceContext = await Self.currentDeviceContext()
        let payload = MobileLoginPayload(email: email, password: password, deviceName: deviceContext.deviceName)
        let response: MobileLoginResponse = try await request("/login", apiPrefix: "/api/mobile", method: "POST", body: payload)

        return response.data
    }

    func authenticatedUser() async throws -> AuthenticatedUser {
        let response: MobileUserResponse = try await request("/me", apiPrefix: "/api/mobile", method: "GET")

        return response.data
    }

    func logout() async throws {
        try await requestNoResponse("/logout", apiPrefix: "/api/mobile", method: "POST")
    }

    func listMonitorings() async throws -> [KnownMonitor] {
        let response: MonitoringListResponse = try await request("/monitorings", method: "GET")

        return response.data.map { monitoring in
            KnownMonitor(
                id: monitoring.id,
                name: monitoring.name,
                target: monitoring.target,
                status: monitoring.status,
                lastSeenAt: Date()
            )
        }
    }

    func operationsOverview(servicePage: Int = 1) async throws -> MobileOverviewPayload {
        let response: MobileOverviewResponse = try await request(
            "/mobile/overview?service_page=\(max(1, servicePage))",
            method: "GET"
        )

        return response.data
    }

    func listMobilePushDevices() async throws -> [MobilePushDevice] {
        let response: MobilePushDeviceListResponse = try await request("/mobile-push-devices", method: "GET")
        return response.data
    }

    func registerAPNsDevice(token apnsToken: String, existingDeviceID: String?) async throws -> MobilePushDevice {
        let deviceContext = await Self.currentDeviceContext()
        let payload = APNsRegistrationPayload(
            pushToken: apnsToken,
            deviceName: deviceContext.deviceName,
            appVersion: deviceContext.appVersion,
            locale: deviceContext.locale,
            timezone: deviceContext.timezone,
            notificationsAuthorizedAt: ISO8601DateFormatter().string(from: Date())
        )

        let response: MobilePushDeviceResponse = try await request("/mobile-push-devices", method: "POST", body: payload)
        return response.data
    }

    func updateMobilePushDevice(deviceID: String, enabled: Bool) async throws -> MobilePushDevice {
        let response: MobilePushDeviceResponse = try await request(
            "/mobile-push-devices/\(deviceID)",
            method: "PATCH",
            body: ["enabled": enabled]
        )

        return response.data
    }

    func revokeMobilePushDevice(deviceID: String) async throws {
        try await requestNoResponse("/mobile-push-devices/\(deviceID)", method: "DELETE")
    }

    func monitoringStatus(monitorID: String) async throws -> MonitoringStatusPayload {
        try await request("/monitorings/\(monitorID)/status", method: "GET")
    }

    private func request<Response: Decodable>(
        _ path: String,
        method: String
    ) async throws -> Response {
        try await performRequest(path, apiPrefix: "/api/v1", method: method, bodyData: nil)
    }

    private func request<Response: Decodable>(
        _ path: String,
        apiPrefix: String,
        method: String
    ) async throws -> Response {
        try await performRequest(path, apiPrefix: apiPrefix, method: method, bodyData: nil)
    }

    private func requestNoResponse(
        _ path: String,
        method: String
    ) async throws {
        let _: EmptyResponse = try await performRequest(path, apiPrefix: "/api/v1", method: method, bodyData: nil)
    }

    private func requestNoResponse(
        _ path: String,
        apiPrefix: String,
        method: String
    ) async throws {
        let _: EmptyResponse = try await performRequest(path, apiPrefix: apiPrefix, method: method, bodyData: nil)
    }

    private func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body
    ) async throws -> Response {
        try await performRequest(path, apiPrefix: "/api/v1", method: method, bodyData: encoder.encode(body))
    }

    private func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        apiPrefix: String,
        method: String,
        body: Body
    ) async throws -> Response {
        try await performRequest(path, apiPrefix: apiPrefix, method: method, bodyData: encoder.encode(body))
    }

    private func performRequest<Response: Decodable>(
        _ path: String,
        apiPrefix: String,
        method: String,
        bodyData: Data?
    ) async throws -> Response {
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let normalizedPrefix = apiPrefix.hasPrefix("/") ? apiPrefix : "/\(apiPrefix)"
        let urlString = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + normalizedPrefix + normalizedPath

        guard let url = URL(string: urlString) else {
            throw WebGuardAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15

        request.httpBody = bodyData

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebGuardAPIError.invalidResponse
        }

        if httpResponse.statusCode == 204 {
            guard let emptyResponse = EmptyResponse() as? Response else {
                throw WebGuardAPIError.invalidResponse
            }

            return emptyResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw WebGuardAPIError.unauthorized
            }

            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw WebGuardAPIError.requestFailed(httpResponse.statusCode, message)
        }

        return try decoder.decode(Response.self, from: data)
    }

    @MainActor
    private static func currentDeviceContext() -> (deviceName: String, appVersion: String?, locale: String, timezone: String) {
        (
            deviceName: UIDevice.current.name,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
    }
}

private struct EmptyResponse: Decodable {}

private extension URL {
    func normalizedWebGuardBaseURL() -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        let normalizedPath = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        components?.path = normalizedPath
        components?.query = nil
        components?.fragment = nil
        return components?.url ?? self
    }
}
