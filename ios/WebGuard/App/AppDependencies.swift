import Foundation

enum WebGuardConfigurationError: LocalizedError {
    case missingServerURL
    case invalidServerURL

    var errorDescription: String? {
        switch self {
        case .missingServerURL:
            return "Die WebGuard-Serveradresse fehlt in der App-Konfiguration."
        case .invalidServerURL:
            return "Die WebGuard-Serveradresse muss eine gueltige HTTPS-URL sein."
        }
    }
}

enum WebGuardConfiguration {
    static func serverURL(in bundle: Bundle = .main) throws -> URL {
        try validatedHTTPSURL(bundle.object(forInfoDictionaryKey: "WEBGUARD_BASE_URL") as? String)
    }

    static func registrationURL(in bundle: Bundle = .main) throws -> URL {
        try validatedHTTPSURL(bundle.object(forInfoDictionaryKey: "WEBGUARD_REGISTRATION_URL") as? String)
    }

    static func validatedHTTPSURL(_ value: String?) throws -> URL {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WebGuardConfigurationError.missingServerURL
        }

        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false,
              url.user == nil,
              url.password == nil else {
            throw WebGuardConfigurationError.invalidServerURL
        }

        return url
    }
}

enum WebGuardJSONCoding {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func date(from value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    static func string(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

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
