import Foundation
import Testing
@testable import MarkdownViewerKit

@Suite("View options")
struct ViewOptionsTests {

    @Test("content width maps to a max-width value")
    func widthValues() {
        #expect(MarkdownContentWidth.comfortable.maxWidthCSS == "860px")
        #expect(MarkdownContentWidth.wide.maxWidthCSS == "1200px")
        #expect(MarkdownContentWidth.full.maxWidthCSS == "none")
    }

    @Test("the page applies the chosen content width")
    func pageAppliesWidth() {
        #expect(MarkdownCSS.page(for: "<p>x</p>", contentWidth: .comfortable).contains("max-width: 860px"))
        #expect(MarkdownCSS.page(for: "<p>x</p>", contentWidth: .full).contains("max-width: none"))
    }

    @Test("the page applies the chosen font size")
    func pageAppliesFontSize() {
        #expect(MarkdownCSS.page(for: "<p>x</p>", fontSize: 18).contains("font-size: 18px"))
        #expect(MarkdownCSS.page(for: "<p>x</p>", fontSize: 13.5).contains("font-size: 13.5px"))
    }

    @Test("MarkdownPage forwards view options through")
    func markdownPageForwards() {
        let page = MarkdownPage.html(markdown: "# Hi", baseURL: nil, contentWidth: .wide, fontSize: 20)
        #expect(page.contains("max-width: 1200px"))
        #expect(page.contains("font-size: 20px"))
        #expect(page.contains("<h1>Hi</h1>"))
    }

    @Test("defaults keep the comfortable column and base text size")
    func defaults() {
        let page = MarkdownPage.html(markdown: "# Hi", baseURL: nil)
        #expect(page.contains("max-width: 860px"))
        #expect(page.contains("font-size: 15px"))
    }
}
