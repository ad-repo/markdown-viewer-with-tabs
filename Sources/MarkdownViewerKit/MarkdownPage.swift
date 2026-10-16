import Foundation

/// Convenience helpers for producing a full, styled HTML page from Markdown.
public enum MarkdownPage {

    /// Renders `markdown` to a complete HTML document ready for a `WKWebView`.
    public static func html(markdown: String,
                            baseURL: URL?,
                            contentWidth: MarkdownContentWidth = .comfortable,
                            fontSize: Double = 15,
                            theme: ColorTheme? = nil) -> String {
        let renderer = HTMLRenderer(baseURL: baseURL)
        return MarkdownCSS.page(for: renderer.render(markdown),
                                contentWidth: contentWidth,
                                fontSize: fontSize,
                                theme: theme)
    }
}
