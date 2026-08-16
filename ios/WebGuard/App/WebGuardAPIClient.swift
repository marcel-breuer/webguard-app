import Foundation

enum WebGuardAPIError: LocalizedError {
    case invalidResponse
    case requestFailed(Int)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Die WebGuard API hat keine gueltige Antwort geliefert."
        case let .requestFailed(status) where (400..<500).contains(status):
            return "Die Anfrage konnte nicht verarbeitet werden. Bitte pruefe deine Eingaben und versuche es erneut."
        case .requestFailed:
            return "Der WebGuard-Dienst ist derzeit nicht erreichbar. Bitte versuche es spaeter erneut."
        case .unauthorized:
            return "Die Anmeldung ist abgelaufen. Bitte melde dich erneut an."
        }
    }
}

protocol WebGuardAPIClientProtocol {
    func login(email: String, password: String, deviceContext: DeviceContext) async throws -> MobileLoginData
    func logout() async throws
    func listMonitorings() async throws -> [KnownMonitor]
    func operationsOverview(servicePage: Int) async throws -> MobileOverviewPayload
    func registerAPNsDevice(
        token apnsToken: String,
        existingDeviceID: String?,
        deviceContext: DeviceContext
    ) async throws -> MobilePushDevice
    func updateMobilePushDevice(deviceID: String, enabled: Bool) async throws -> MobilePushDevice
    func revokeMobilePushDevice(deviceID: String) async throws
    func monitoringStatus(monitorID: String) async throws -> MonitoringStatusPayload
    func monitoringDetail(monitorID: String, days: Int, incidentOffset: Int) async throws -> MobileMonitoringDetailResponse
    func createMonitoring(_ payload: MonitoringMutationPayload) async throws -> MonitoringManagementResponse
    func updateMonitoring(id: String, payload: MonitoringMutationPayload) async throws -> MonitoringManagementResponse
    func deleteMonitoring(id: String) async throws
    func monitoringGroups() async throws -> [MobileMonitoringGroup]
    func saveMonitoringGroup(id: String?, payload: MonitoringGroupMutationPayload) async throws -> MobileMonitoringGroup
    func deleteMonitoringGroup(id: String) async throws
    func teams() async throws -> [TeamSummary]
    func moveMonitoring(id: String, toTeamID: String?) async throws -> MonitoringManagementResponse
    func maintenanceWindows(kind: String, state: String?) async throws -> [MobileMaintenanceWindow]
    func maintenanceCapabilities() async throws -> MobileMaintenanceCapabilities
    func scheduleMaintenance(_ payload: MaintenanceSchedulePayload) async throws -> MobileMaintenanceWindow
    func setRecurringMaintenanceEnabled(id: String, enabled: Bool) async throws -> MobileMaintenanceWindow
    func cancelOneOffMaintenance(monitoringID: String) async throws
    func notificationBoard(cursor: String?, eventType: String?, showRead: Bool) async throws -> MobileNotificationBoardResponse
    func markNotificationRead(id: String) async throws
    func markAllNotificationsRead() async throws -> Int
    func statusPages() async throws -> [MobileStatusPage]
    func statusPageIncidents(statusPageID: String) async throws -> [MobileIncidentWorkspace]
    func updateStatusPagePublication(id: String, isPublic: Bool) async throws -> MobileStatusPage
    func publishIncidentUpdate(statusPageID: String, incidentID: String, payload: MobileIncidentUpdatePayload, idempotencyKey: String) async throws -> MobileIncidentWorkspace
    func monitoringNotificationPreference(monitorID: String) async throws -> MonitoringNotificationPreference
    func updateMonitoringNotificationPreference(
        monitoringID: String,
        notificationOnFailure: Bool,
        notificationChannels: [String],
        sslExpiryWarningDays: Int
    ) async throws -> MonitoringNotificationPreference
}

final class WebGuardAPIClient: WebGuardAPIClientProtocol {
    let serverURL: URL
    private let token: String?
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(serverURL: URL, token: String? = nil, urlSession: URLSession = .shared) {
        self.serverURL = serverURL.normalizedWebGuardBaseURL()
        self.token = token
        self.urlSession = urlSession
        decoder = WebGuardJSONCoding.makeDecoder()
        encoder = WebGuardJSONCoding.makeEncoder()
    }

    func login(email: String, password: String, deviceContext: DeviceContext) async throws -> MobileLoginData {
        let payload = MobileLoginPayload(email: email, password: password, deviceName: deviceContext.name)
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
                type: monitoring.type,
                ownership: monitoring.ownership,
                lastSeenAt: Date(),
                maintenanceActive: monitoring.maintenanceActive,
                maintenanceFrom: monitoring.maintenanceFrom,
                maintenanceUntil: monitoring.maintenanceUntil
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

    func registerAPNsDevice(
        token apnsToken: String,
        existingDeviceID: String?,
        deviceContext: DeviceContext
    ) async throws -> MobilePushDevice {
        let payload = APNsRegistrationPayload(
            pushToken: apnsToken,
            deviceName: deviceContext.name,
            appVersion: deviceContext.appVersion,
            locale: deviceContext.locale,
            timezone: deviceContext.timezone,
            notificationsAuthorizedAt: WebGuardJSONCoding.string(from: Date())
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

    func monitoringDetail(monitorID: String, days: Int = 30, incidentOffset: Int = 0) async throws -> MobileMonitoringDetailResponse {
        let normalizedDays = min(max(days, 1), 90)
        let normalizedOffset = max(incidentOffset, 0)

        return try await request(
            "/mobile/monitorings/\(monitorID)?days=\(normalizedDays)&incident_limit=20&incident_offset=\(normalizedOffset)",
            method: "GET"
        )
    }

    func createMonitoring(_ payload: MonitoringMutationPayload) async throws -> MonitoringManagementResponse {
        try await request("/monitorings", method: "POST", body: payload)
    }

    func updateMonitoring(id: String, payload: MonitoringMutationPayload) async throws -> MonitoringManagementResponse {
        try await request("/monitorings/\(id)", method: "PATCH", body: payload)
    }

    func deleteMonitoring(id: String) async throws {
        try await requestNoResponse("/monitorings/\(id)", method: "DELETE")
    }

    func monitoringGroups() async throws -> [MobileMonitoringGroup] {
        let response: MobileMonitoringGroupListResponse = try await request("/mobile/monitoring-groups?per_page=100", method: "GET")
        return response.data
    }

    func saveMonitoringGroup(id: String?, payload: MonitoringGroupMutationPayload) async throws -> MobileMonitoringGroup {
        let response: MobileMonitoringGroupResponse = if let id {
            try await request("/mobile/monitoring-groups/\(id)", method: "PATCH", body: payload)
        } else {
            try await request("/mobile/monitoring-groups", method: "POST", body: payload)
        }
        return response.data
    }

    func deleteMonitoringGroup(id: String) async throws {
        try await requestNoResponse("/mobile/monitoring-groups/\(id)", method: "DELETE")
    }

    func teams() async throws -> [TeamSummary] {
        let response: TeamListResponse = try await request("/teams", method: "GET")
        return response.data
    }

    func moveMonitoring(id: String, toTeamID: String?) async throws -> MonitoringManagementResponse {
        if let toTeamID {
            return try await request("/monitorings/\(id)/team-ownership", method: "POST", body: ["team_id": toTeamID])
        }
        return try await request("/monitorings/\(id)/team-ownership", method: "DELETE")
    }

    func maintenanceWindows(kind: String, state: String? = nil) async throws -> [MobileMaintenanceWindow] {
        let filter = state.map { "&state=\($0)" } ?? ""
        let response: MobileMaintenanceListResponse = try await request("/mobile/maintenance/\(kind)?per_page=100\(filter)", method: "GET")
        return response.data
    }

    func maintenanceCapabilities() async throws -> MobileMaintenanceCapabilities {
        let response: MobileMaintenanceCapabilitiesResponse = try await request("/mobile/maintenance/capabilities", method: "GET")
        return response.data
    }

    func scheduleMaintenance(_ payload: MaintenanceSchedulePayload) async throws -> MobileMaintenanceWindow {
        let response: MobileMaintenanceResponse = try await request("/mobile/maintenance", method: "POST", body: payload)
        return response.data
    }

    func setRecurringMaintenanceEnabled(id: String, enabled: Bool) async throws -> MobileMaintenanceWindow {
        let response: MobileMaintenanceResponse = try await request("/mobile/maintenance/recurring/\(id)", method: "PATCH", body: ["enabled": enabled])
        return response.data
    }

    func cancelOneOffMaintenance(monitoringID: String) async throws {
        try await requestNoResponse("/mobile/maintenance/one-off/\(monitoringID)", method: "DELETE")
    }

    func notificationBoard(cursor: String? = nil, eventType: String? = nil, showRead: Bool) async throws -> MobileNotificationBoardResponse {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "show_read", value: showRead ? "true" : "false")
        ]
        if let cursor {
            components.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let eventType {
            components.queryItems?.append(URLQueryItem(name: "event_type", value: eventType))
        }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return try await request("/mobile/notification-board\(query)", method: "GET")
    }

    func markNotificationRead(id: String) async throws {
        try await requestNoResponse("/mobile/notification-board/\(id)/read", method: "PATCH")
    }

    func markAllNotificationsRead() async throws -> Int {
        let response: MobileNotificationReadResponse = try await request("/mobile/notification-board/read-all", method: "PATCH")
        return response.meta?.unreadCount ?? 0
    }

    func statusPages() async throws -> [MobileStatusPage] {
        let response: MobileStatusPageListResponse = try await request("/mobile/status-pages?per_page=100", method: "GET")
        return response.data
    }
    func statusPageIncidents(statusPageID: String) async throws -> [MobileIncidentWorkspace] {
        let response: MobileIncidentWorkspaceListResponse = try await request("/mobile/status-pages/\(statusPageID)/incidents?state=open&per_page=100", method: "GET")
        return response.data
    }
    func updateStatusPagePublication(id: String, isPublic: Bool) async throws -> MobileStatusPage {
        let response: MobileStatusPageResponse = try await request("/mobile/status-pages/\(id)/publication", method: "PATCH", body: ["is_public": isPublic])
        return response.data
    }
    func publishIncidentUpdate(statusPageID: String, incidentID: String, payload: MobileIncidentUpdatePayload, idempotencyKey: String) async throws -> MobileIncidentWorkspace {
        let response: MobileIncidentWorkspaceResponse = try await performRequest("/mobile/status-pages/\(statusPageID)/incidents/\(incidentID)/updates", apiPrefix: "/api/v1", method: "POST", bodyData: encoder.encode(payload), headers: ["Idempotency-Key": idempotencyKey])
        return response.data
    }

    func monitoringNotificationPreference(monitorID: String) async throws -> MonitoringNotificationPreference {
        let response: MonitoringNotificationPreferenceResponse = try await request(
            "/mobile/monitorings/\(monitorID)/notification-preferences",
            method: "GET"
        )
        return response.data
    }

    func updateMonitoringNotificationPreference(
        monitoringID: String,
        notificationOnFailure: Bool,
        notificationChannels: [String],
        sslExpiryWarningDays: Int
    ) async throws -> MonitoringNotificationPreference {
        let payload = MonitoringNotificationPreferenceUpdatePayload(
            notificationOnFailure: notificationOnFailure,
            notificationChannels: notificationChannels,
            sslExpiryWarningDays: sslExpiryWarningDays
        )
        let response: MonitoringNotificationPreferenceResponse = try await request(
            "/mobile/monitorings/\(monitoringID)/notification-preferences",
            method: "PATCH",
            body: payload
        )
        return response.data
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
        bodyData: Data?,
        headers: [String: String] = [:]
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
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

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

            throw WebGuardAPIError.requestFailed(httpResponse.statusCode)
        }

        return try decoder.decode(Response.self, from: data)
    }

}

private struct EmptyResponse: Decodable {}

private extension URL {
    func normalizedWebGuardBaseURL() -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        let trimmedPath = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        components?.path = trimmedPath.isEmpty ? "" : "/\(trimmedPath)"
        components?.query = nil
        components?.fragment = nil
        return components?.url ?? self
    }
}
