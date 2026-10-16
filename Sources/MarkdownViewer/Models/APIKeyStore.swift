import Foundation

/// Metadata about the key the user saved. The secret itself only ever lives in
/// the keychain; this record exists so the UI can show what is configured
/// without unlocking anything.
struct APIKeyRecord: Codable, Equatable {
    var addedAt: Date
    /// The last few characters of the key, shown as a reminder of which one it is.
    var suffix: String

    /// `••••1234` — enough to recognise a key, not enough to leak it.
    var maskedValue: String {
        suffix.isEmpty ? "••••" : "••••\(suffix)"
    }
}

/// Errors raised while saving a key.
enum APIKeyError: LocalizedError {
    case emptyKey

    var errorDescription: String? {
        switch self {
        case .emptyKey: return "Enter an API key first."
        }
    }
}

/// Keeps the app's single API key in the macOS Keychain. The store only
/// publishes non-secret metadata; reading the key is an explicit call and the
/// secret is never held on to.
@MainActor
final class APIKeyStore: ObservableObject {

    static let shared = APIKeyStore()

    /// The keychain account the key is stored under.
    static let account = "api-key"

    @Published private(set) var record: APIKeyRecord?

    private let defaults: UserDefaults
    private let keychain: Keychain

    private enum Keys {
        static let record = "apiKeyRecord"
    }

    init(defaults: UserDefaults = .standard, keychain: Keychain = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
        if let data = defaults.data(forKey: Keys.record),
           let stored = try? JSONDecoder().decode(APIKeyRecord.self, from: data),
           keychain.contains(account: Self.account) {
            // The key can disappear from the keychain (removed in Keychain
            // Access, an unresolvable item after re-signing). Reconcile on
            // launch so the UI never claims a key the app cannot read.
            record = stored
        }
    }

    // MARK: - Queries

    var hasKey: Bool { record != nil }

    /// Reads the secret out of the keychain. Returns `nil` when no key is
    /// stored or the keychain cannot be read (a locked keychain, for example) —
    /// callers treat both as "no key available".
    func secret() -> String? {
        do {
            return try keychain.secret(account: Self.account)
        } catch {
            return nil
        }
    }

    // MARK: - Mutations

    /// Stores `secret` in the keychain, replacing any key already saved.
    func save(secret value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIKeyError.emptyKey }

        try keychain.setSecret(trimmed, account: Self.account)

        let updated = APIKeyRecord(addedAt: Date(), suffix: String(trimmed.suffix(4)))
        record = updated
        persist()
    }

    /// Deletes the keychain item and its metadata.
    func remove() {
        keychain.deleteSecret(account: Self.account)
        record = nil
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        if let record, let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: Keys.record)
        } else {
            defaults.removeObject(forKey: Keys.record)
        }
    }
}
