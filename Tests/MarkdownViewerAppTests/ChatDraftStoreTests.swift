import Testing
@testable import MarkdownViewer

@Suite("Chat draft store")
@MainActor
struct ChatDraftStoreTests {

    @Test("drafts are kept per document")
    func perDocument() {
        let drafts = ChatDraftStore()

        drafts.setDraft("about the first", for: "/a.md")
        drafts.setDraft("about the second", for: "/b.md")

        #expect(drafts.draft(for: "/a.md") == "about the first")
        #expect(drafts.draft(for: "/b.md") == "about the second")
        #expect(drafts.draft(for: "/c.md") == "")
    }

    @Test("an empty draft reads back as empty")
    func emptyDraft() {
        let drafts = ChatDraftStore()
        drafts.setDraft("something", for: "/a.md")

        drafts.setDraft("", for: "/a.md")

        #expect(drafts.draft(for: "/a.md") == "")
    }

    @Test("clearing removes the draft")
    func clear() {
        let drafts = ChatDraftStore()
        drafts.setDraft("something", for: "/a.md")

        drafts.clear(for: "/a.md")

        #expect(drafts.draft(for: "/a.md") == "")
    }
}
