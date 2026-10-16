import Foundation
import Testing
@testable import MarkdownViewerKit

@Suite("Color themes")
struct ColorThemeTests {

    @Test("the catalog ships 25 themes with unique ids")
    func catalogSize() {
        #expect(ColorThemeCatalog.themes.count == 25)
        let ids = Set(ColorThemeCatalog.themes.map(\.id))
        #expect(ids.count == ColorThemeCatalog.themes.count)
    }

    @Test("every theme defines a full 6-digit hex palette")
    func paletteIsComplete() {
        for theme in ColorThemeCatalog.themes {
            for hex in [theme.background, theme.foreground, theme.mutedForeground,
                        theme.surface, theme.border, theme.accent] {
                #expect(hex.count == 7)
                #expect(hex.hasPrefix("#"))
            }
        }
    }

    @Test("theme lookup wraps around the catalog")
    func lookupWraps() {
        #expect(ColorThemeCatalog.theme(at: 0).id == ColorThemeCatalog.themes[0].id)
        #expect(ColorThemeCatalog.theme(at: 25).id == ColorThemeCatalog.themes[0].id)
        #expect(ColorThemeCatalog.theme(at: -1).id == ColorThemeCatalog.themes[24].id)
    }

    @Test("cycling walks every theme in order and wraps")
    func cyclingWalksTheCatalog() {
        var index: Int? = nil
        #expect(ColorThemeCatalog.nextIndex(after: index) == 0)
        for expected in 0..<ColorThemeCatalog.themes.count {
            index = ColorThemeCatalog.nextIndex(after: index)
            #expect(index == expected)
        }
        #expect(ColorThemeCatalog.nextIndex(after: index) == 0)
    }

    @Test("dark backgrounds are detected")
    func darkDetection() {
        #expect(ColorThemeCatalog.theme(id: "miami-vice")?.isDark == true)
        #expect(ColorThemeCatalog.theme(id: "pastel-mint")?.isDark == false)
    }

    @Test("the page emits the theme's palette")
    func pageAppliesTheme() {
        let theme = ColorThemeCatalog.theme(id: "miami-vice")!
        let page = MarkdownCSS.page(for: "<p>x</p>", theme: theme)
        #expect(page.contains("--bg: #240b4a"))
        #expect(page.contains("--link: #ff2d95"))
        #expect(page.contains("color-scheme: dark"))
    }

    @Test("omitting a theme leaves the default light/dark page")
    func pageWithoutTheme() {
        let page = MarkdownCSS.page(for: "<p>x</p>")
        #expect(!page.contains("--bg: #240b4a"))
        #expect(page.contains("--bg: #ffffff"))
    }

    @Test("MarkdownPage forwards the theme through")
    func markdownPageForwardsTheme() {
        let theme = ColorThemeCatalog.theme(id: "sky-blue")!
        let page = MarkdownPage.html(markdown: "# Hi", baseURL: nil, theme: theme)
        #expect(page.contains("--bg: #e8f6ff"))
    }
}
