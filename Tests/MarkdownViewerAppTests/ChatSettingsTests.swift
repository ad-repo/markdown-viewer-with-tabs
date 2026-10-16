import Testing
@testable import MarkdownViewer

@Suite("Chat settings")
@MainActor
struct ChatSettingsTests {

    @Test("a fresh store is empty and resolves to the defaults")
    func defaults() {
        let settings = ChatSettings(defaults: makeScratchDefaults())

        #expect(settings.baseURL == "")
        #expect(settings.model == "")
        #expect(settings.includeDocument)
        #expect(settings.resolvedBaseURL == ChatSettings.defaultBaseURL)
        #expect(settings.resolvedModel == ChatSettings.defaultModel)
    }

    @Test("a custom base URL is used, and whitespace falls back to the default")
    func baseURLFallback() {
        let settings = ChatSettings(defaults: makeScratchDefaults())

        settings.baseURL = "https://example.test/v1"
        #expect(settings.resolvedBaseURL == "https://example.test/v1")

        settings.baseURL = "   "
        #expect(settings.resolvedBaseURL == ChatSettings.defaultBaseURL)
    }

    @Test("a custom model is trimmed, and an empty field falls back to the default")
    func modelFallback() {
        let settings = ChatSettings(defaults: makeScratchDefaults())

        settings.model = "  gpt-4o-mini \n"
        #expect(settings.model == "  gpt-4o-mini \n")
        #expect(settings.resolvedModel == "gpt-4o-mini")

        settings.model = ""
        #expect(settings.resolvedModel == ChatSettings.defaultModel)
    }

    @Test("settings persist across instances sharing the same defaults")
    func persists() {
        let defaults = makeScratchDefaults()
        let first = ChatSettings(defaults: defaults)
        first.baseURL = "https://example.test/v1"
        first.model = "custom-model"
        first.includeDocument = false

        let second = ChatSettings(defaults: defaults)
        #expect(second.baseURL == "https://example.test/v1")
        #expect(second.model == "custom-model")
        #expect(!second.includeDocument)
    }
}
