import Foundation
import Security

/// A Keychain operation that failed, carrying the `OSStatus` the Security
/// framework returned.
struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "Keychain error \(status)"
    }
}

/// A place to keep small secrets, keyed by an account name. The real
/// implementation is `KeychainStore`; tests substitute an in-memory fake.
protocol Keychain {
    func setSecret(_ secret: String, account: String) throws
    func secret(account: String) throws -> String?
    func contains(account: String) -> Bool
    func deleteSecret(account: String)
}

/// Stores API keys as generic-password items in the user's login keychain,
/// scoped to this app. Secrets are only ever read on demand — nothing keeps a
/// key in memory longer than a request needs it.
struct KeychainStore: Keychain {

    /// Namespaces this app's items so they are easy to find in Keychain Access.
    static let defaultService = "com.mdtabs.markdown-viewer.api-keys"

    private let service: String

    init(service: String = KeychainStore.defaultService) {
        self.service = service
    }

    /// Where the item lives and what identifies it.
    private func query(account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }

    /// Adds a secret, or replaces the one already stored for `account`.
    func setSecret(_ secret: String, account: String) throws {
        let data = Data(secret.utf8)
        let base = query(account: account)

        switch SecItemCopyMatching(base as CFDictionary, nil) {
        case errSecSuccess:
            let updates: [CFString: Any] = [kSecValueData: data]
            let status = SecItemUpdate(base as CFDictionary, updates as CFDictionary)
            guard status == errSecSuccess else { throw KeychainError(status: status) }

        case errSecItemNotFound:
            var attributes = base
            attributes[kSecValueData] = data
            attributes[kSecAttrLabel] = "markdown-viewer API key (\(account))"
            attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let status = SecItemAdd(attributes as CFDictionary, nil)
            guard status == errSecSuccess else { throw KeychainError(status: status) }

        case let status:
            throw KeychainError(status: status)
        }
    }

    /// Reads the secret stored for `account`, or `nil` when there is none.
    func secret(account: String) throws -> String? {
        var query = query(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    /// Whether a secret is stored for `account`.
    func contains(account: String) -> Bool {
        var query = query(account: account)
        query[kSecMatchLimit] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    /// Removes the secret stored for `account`, if any.
    func deleteSecret(account: String) {
        SecItemDelete(query(account: account) as CFDictionary)
    }
}
