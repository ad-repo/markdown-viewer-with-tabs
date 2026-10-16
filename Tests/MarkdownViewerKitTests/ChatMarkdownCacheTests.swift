import Testing
@testable import MarkdownViewerKit

@Suite("Chat markdown cache")
@MainActor
struct ChatMarkdownCacheTests {

    @Test("the same text is rendered once and reused")
    func cachesRepeatedText() {
        let cache = ChatMarkdownCache()

        let first = cache.attributedString(from: "hello **world**")
        let second = cache.attributedString(from: "hello **world**")

        #expect(first == second)
        #expect(cache.renders == 1)
    }

    @Test("different text is rendered separately")
    func rendersDistinctText() {
        let cache = ChatMarkdownCache()

        _ = cache.attributedString(from: "one")
        _ = cache.attributedString(from: "two")
        _ = cache.attributedString(from: "one")

        #expect(cache.renders == 2)
    }

    @Test("a cached render matches a direct render")
    func matchesDirectRender() {
        let cache = ChatMarkdownCache()
        let markdown = "# Title\n\n- a\n- b"

        #expect(cache.attributedString(from: markdown)
                == ChatMarkdown.attributedString(from: markdown))
    }
}
