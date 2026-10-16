import Testing
@testable import MarkdownViewer

@Suite("API key store")
@MainActor
struct APIKeyStoreTests {

    @Test("saving a key stores the secret and non-secret metadata")
    func saves() throws {
        let keychain = InMemoryKeychain()
        let store = APIKeyStore(defaults: makeScratchDefaults(), keychain: keychain)

        try store.save(secret: "sk-abcdef1234")

        #expect(store.hasKey)
        #expect(store.secret() == "sk-abcdef1234")
        #expect(store.record?.suffix == "1234")
        #expect(store.record?.maskedValue == "••••1234")
    }

    @Test("an empty key is rejected")
    func rejectsEmpty() {
        let store = APIKeyStore(defaults: makeScratchDefaults(), keychain: InMemoryKeychain())

        #expect(throws: APIKeyError.self) {
            try store.save(secret: "   ")
        }
    }

    @Test("saving again replaces the previous key")
    func replaces() throws {
        let keychain = InMemoryKeychain()
        let store = APIKeyStore(defaults: makeScratchDefaults(), keychain: keychain)
        try store.save(secret: "sk-first")
        try store.save(secret: "sk-second")

        let stored = try keychain.secret(account: APIKeyStore.account)
        #expect(store.secret() == "sk-second")
        #expect(store.record?.suffix == "cond")
        #expect(stored == "sk-second")
    }

    @Test("removing a key deletes the secret and its metadata")
    func removes() throws {
        let keychain = InMemoryKeychain()
        let store = APIKeyStore(defaults: makeScratchDefaults(), keychain: keychain)
        try store.save(secret: "sk-test")

        store.remove()

        #expect(!store.hasKey)
        #expect(store.secret() == nil)
        #expect(keychain.contains(account: APIKeyStore.account) == false)
    }

    @Test("metadata whose keychain item vanished is reconciled away on launch")
    func reconcilesAgainstKeychain() throws {
        let defaults = makeScratchDefaults()
        let keychain = InMemoryKeychain()
        let store = APIKeyStore(defaults: defaults, keychain: keychain)
        try store.save(secret: "sk-gone")

        // Simulate the item disappearing behind the app's back.
        keychain.deleteSecret(account: APIKeyStore.account)

        let reloaded = APIKeyStore(defaults: defaults, keychain: keychain)
        #expect(!reloaded.hasKey)
    }

    @Test("the secret is never written to UserDefaults")
    func secretIsNotPersistedInDefaults() throws {
        let defaults = makeScratchDefaults()
        let store = APIKeyStore(defaults: defaults, keychain: InMemoryKeychain())
        try store.save(secret: "sk-supersecret")

        let dumped = defaults.dictionaryRepresentation().description
        #expect(!dumped.contains("sk-supersecret"))
    }
}
