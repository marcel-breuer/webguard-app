import Foundation
import Security

enum KeychainStoreError: Error {
    case encodingFailed
    case decodingFailed
    case unexpectedStatus(OSStatus)
}

protocol SessionStore {
    func loadSession() throws -> StoredSession?
    func saveSession(_ session: StoredSession) throws
    func clearSession() throws
}

final class KeychainStore: SessionStore {
    static let shared = KeychainStore()

    private let service: String

    static func sessionAttributes(for data: Data) -> [CFString: Any] {
        [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    init(service: String = "com.example.webguard") {
        self.service = service
    }

    func loadSession() throws -> StoredSession? {
        guard let data = try data(for: "session") else {
            return nil
        }

        let decoder = WebGuardJSONCoding.makeDecoder()

        do {
            return try decoder.decode(StoredSession.self, from: data)
        } catch {
            throw KeychainStoreError.decodingFailed
        }
    }

    func saveSession(_ session: StoredSession) throws {
        let encoder = WebGuardJSONCoding.makeEncoder()

        do {
            try save(encoder.encode(session), for: "session")
        } catch is EncodingError {
            throw KeychainStoreError.encodingFailed
        }
    }

    func clearSession() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "session"
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func data(for account: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }

        return item as? Data
    }

    private func save(_ data: Data, for account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let attributes = Self.sessionAttributes(for: data)

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        attributes.forEach { key, value in
            addQuery[key] = value
        }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
    }
}
