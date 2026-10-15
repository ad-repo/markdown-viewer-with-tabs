import Foundation
import Testing
@testable import MarkdownViewerKit

@Suite("HTMLRenderer")
struct HTMLRendererTests {

    private func render(_ markdown: String) -> String {
        HTMLRenderer().render(markdown)
    }

    @Test("headings render at the correct level")
    func headings() {
        #expect(render("# Title").contains("<h1>Title</h1>"))
        #expect(render("## Sub").contains("<h2>Sub</h2>"))
        #expect(render("###### Deep").contains("<h6>Deep</h6>"))
    }

    @Test("inline emphasis, strong and strikethrough")
    func inlineFormatting() {
        #expect(render("*em*").contains("<em>em</em>"))
        #expect(render("**strong**").contains("<strong>strong</strong>"))
        #expect(render("~~gone~~").contains("<del>gone</del>"))
    }

    @Test("inline code is escaped")
    func inlineCode() {
        let html = render("Use `a < b && c` here")
        #expect(html.contains("<code>a &lt; b &amp;&amp; c</code>"))
    }

    @Test("fenced code blocks carry a language class and escape content")
    func fencedCode() {
        let html = render("```swift\nlet x = a < b\n```")
        #expect(html.contains("<pre><code class=\"language-swift\">"))
        #expect(html.contains("let x = a &lt; b"))
    }

    @Test("paragraphs and text are HTML escaped")
    func escaping() {
        let html = render("5 < 6 & 7 > 6")
        #expect(html.contains("5 &lt; 6 &amp; 7 &gt; 6"))
    }

    @Test("unstyled links render with href")
    func links() {
        let html = render("[click](https://example.com \"Title\")")
        #expect(html.contains("<a href=\"https://example.com\" title=\"Title\">click</a>"))
    }

    @Test("links with no destination fall back to their label")
    func linkWithoutDestination() {
        let html = render("[^note]")
        #expect(!html.contains("<a href=\"\">"))
    }

    @Test("images render with alt text")
    func images() {
        let html = render("![alt text](https://example.com/a.png)")
        #expect(html.contains("<img src=\"https://example.com/a.png\" alt=\"alt text\">"))
    }

    @Test("unordered lists render")
    func unorderedList() {
        let html = render("- one\n- two\n- three")
        #expect(html.contains("<ul>"))
        #expect(html.contains("<li>one</li>"))
        #expect(html.contains("<li>three</li>"))
    }

    @Test("ordered lists respect the start index")
    func orderedListStart() {
        let html = render("3. three\n4. four")
        #expect(html.contains("<ol start=\"3\">"))
    }

    @Test("task lists render disabled checkboxes")
    func taskList() {
        let html = render("- [x] done\n- [ ] todo")
        #expect(html.contains("type=\"checkbox\" disabled checked"))
        #expect(html.contains("type=\"checkbox\" disabled>"))
    }

    @Test("nested lists render inside a list item")
    func nestedList() {
        let html = render("- parent\n  - child")
        #expect(html.contains("<ul>"))
        #expect(html.contains("<li><p>parent</p>"))
        #expect(html.contains("<li>child"))
    }

    @Test("blockquotes render")
    func blockquote() {
        let html = render("> quoted text")
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("quoted text"))
    }

    @Test("thematic breaks render as hr")
    func thematicBreak() {
        #expect(render("---\n").contains("<hr>"))
    }

    @Test("GFM tables render with head, body and alignment")
    func tables() {
        let markdown = """
        | Left | Center | Right |
        | :--- | :----: | ----: |
        | a    | b      | c     |
        """
        let html = render(markdown)
        #expect(html.contains("<table>"))
        #expect(html.contains("<thead>"))
        #expect(html.contains("<th style=\"text-align:left\">Left</th>"))
        #expect(html.contains("<th style=\"text-align:center\">Center</th>"))
        #expect(html.contains("<th style=\"text-align:right\">Right</th>"))
        #expect(html.contains("<tbody>"))
        #expect(html.contains("<td style=\"text-align:left\">a</td>"))
    }

    @Test("raw inline and block HTML passes through")
    func rawHTML() {
        #expect(render("a <span>b</span>").contains("<span>b</span>"))
        #expect(render("<div class=\"x\">raw</div>").contains("<div class=\"x\">raw</div>"))
    }

    @Test("soft and hard line breaks")
    func lineBreaks() {
        #expect(render("a\nb").contains("a\nb"))
        #expect(render("a  \nb").contains("<br>"))
    }

    @Test("autolinks from GFM are turned into anchors")
    func autolinks() {
        let html = render("Visit https://example.com now")
        #expect(html.contains("href=\"https://example.com\""))
    }

    @Test("attribute values are escaped")
    func attributeEscaping() {
        let html = render("[x](https://example.com/?a=1&b=2)")
        #expect(html.contains("a=1&amp;b=2"))
    }

    @Test("full page includes the CSS and wrapper")
    func fullPage() {
        let page = MarkdownPage.html(markdown: "# Hi", baseURL: nil)
        #expect(page.contains("<!doctype html>"))
        #expect(page.contains("<article class=\"markdown-body\">"))
        #expect(page.contains("<h1>Hi</h1>"))
        #expect(page.contains("prefers-color-scheme"))
    }

    @Test("the shipped sample file renders every GFM feature it documents")
    func sampleFileRenders() throws {
        // Resolve the shipped sample relative to this test source file so the
        // test works regardless of the working directory.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MarkdownViewerKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
        let markdown = try String(contentsOf: root.appendingPathComponent("samples/sample.md"), encoding: .utf8)
        let html = HTMLRenderer().render(markdown)

        #expect(html.contains("<h1>"))
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<del>strikethrough</del>"))
        #expect(html.contains("<code>inline code</code>"))
        #expect(html.contains("<a href=\"https://example.com\" title=\"Example\">"))
        #expect(html.contains("<ul>"))
        #expect(html.contains("<ol>"))
        #expect(html.contains("type=\"checkbox\" disabled checked"))
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("language-swift"))
        #expect(html.contains("language-python"))
        #expect(html.contains("<table>"))
        #expect(html.contains("<th style=\"text-align:left\">Feature</th>"))
        #expect(html.contains("<th style=\"text-align:center\">Supported</th>"))
        #expect(html.contains("raw HTML"))
        #expect(html.contains("<img src=\"https://www.swift.org/assets/images/swift.svg\""))
        #expect(html.contains("<hr>"))
        #expect(html.contains("href=\"https://example.com\""))
    }
}
