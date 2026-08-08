import Foundation

@MainActor
protocol PushAuthorizing {
    func requestAuthorizationAndRegister() async throws -> String
}

struct DeviceContext: Equatable {
    let name: String
    let appVersion: String?
    let locale: String
    let timezone: String
}

@MainActor
protocol DeviceContextProviding {
    func currentDeviceContext() -> DeviceContext
}

struct WebGuardAPIClientFactory {
    let unauthenticatedClient: (URL) -> any WebGuardAPIClientProtocol
    let authenticatedClient: (StoredSession) -> any WebGuardAPIClientProtocol

    static let live = WebGuardAPIClientFactory(
        unauthenticatedClient: { WebGuardAPIClient(serverURL: $0) },
        authenticatedClient: { WebGuardAPIClient(serverURL: $0.serverURL, token: $0.accessToken) }
    )
}

enum AuthenticationState: Equatable {
    case signedOut
    case signingIn
    case authenticated
    case signingOut
}

enum MonitoringLoadState: Equatable {
    case idle
    case loading
    case refreshing
    case loaded
    case stale
    case empty
    case failed
}

enum AppOperationState: Equatable {
    case idle
    case signingIn
    case registeringPush
    case updatingPushPreference
    case updatingMonitoringPreference
}

struct AppAlert: Identifiable, Equatable {
    let message: String

    var id: String { message }
}
