import Foundation
import SwiftUI
import Testing
@testable import MarkdownViewerKit

@Suite("Chat markdown")
struct ChatMarkdownTests {

    private func rendered(_ markdown: String) -> AttributedString {
        ChatMarkdown.attributedString(from: markdown, fontSize: 13)
    }

    private func hasIntent(_ text: AttributedString, _ intent: InlinePresentationIntent) -> Bool {
        text.runs.contains { run in
            run.inlinePresentationIntent?.contains(intent) == true
        }
    }

    @Test("plain paragraphs keep their text and get a body font")
    func plainParagraph() {
        let text = rendered("Just a sentence.")
        #expect(String(text.characters).trimmingCharacters(in: .whitespacesAndNewlines) == "Just a sentence.")
        #expect(text.runs.allSatisfy { run in
            text[run.range].characters.allSatisfy(\.isWhitespace) || run.font != nil
        })
    }

    @Test("soft-wrapped lines stay inside one paragraph")
    func softWrap() {
        let text = rendered("first line\nsecond line")
        #expect(String(text.characters).contains("first line\nsecond line"))
    }

    @Test("headings drop the hashes and render bold")
    func headings() {
        let text = rendered("# Title\n\n## Subtitle\n\nbody")
        let plain = String(text.characters)
        #expect(plain.contains("Title"))
        #expect(!plain.contains("#"))
        #expect(hasIntent(text, .stronglyEmphasized))
        #expect(text.runs.contains { $0.font != nil })
    }

    @Test("bullet lists become bullet markers")
    func bullets() {
        let text = rendered("- one\n- two")
        let plain = String(text.characters)
        #expect(plain.contains("• one"))
        #expect(plain.contains("• two"))
    }

    @Test("ordered lists keep their numbers")
    func orderedList() {
        let text = rendered("1. first\n2. second")
        let plain = String(text.characters)
        #expect(plain.contains("1. first"))
        #expect(plain.contains("2. second"))
    }

    @Test("fenced code blocks are monospaced and highlighted")
    func codeBlocks() {
        let text = rendered("before\n\n```swift\nlet x = 1\n```\n\nafter")
        let plain = String(text.characters)
        #expect(plain.contains("let x = 1"))
        #expect(!plain.contains("```"))
        #expect(text.runs.contains { $0.backgroundColor != nil })
    }

    @Test("an unterminated code fence still renders its contents")
    func unterminatedCodeFence() {
        let text = rendered("```\nlet y = 2")
        #expect(String(text.characters).contains("let y = 2"))
    }

    @Test("block quotes are de-marked, italic and muted")
    func blockQuote() {
        let text = rendered("> quoted words")
        let plain = String(text.characters)
        #expect(plain.contains("quoted words"))
        #expect(!plain.contains(">"))
        #expect(hasIntent(text, .emphasized))
        #expect(text.runs.contains { $0.foregroundColor != nil })
    }

    @Test("horizontal rules render as a divider line")
    func horizontalRule() {
        let text = rendered("above\n\n---\n\nbelow")
        #expect(String(text.characters).contains("─"))
    }

    @Test("inline emphasis is preserved for the text renderer")
    func inlineEmphasis() {
        let text = rendered("this is **bold** and *italic*")
        #expect(hasIntent(text, .stronglyEmphasized))
        #expect(hasIntent(text, .emphasized))
        #expect(String(text.characters).contains("bold"))
    }

    @Test("malformed inline markdown falls back to literal text")
    func malformedInline() {
        let text = rendered("a stray [bracket and a _lone_ underscore")
        #expect(String(text.characters).contains("stray [bracket"))
    }
}
