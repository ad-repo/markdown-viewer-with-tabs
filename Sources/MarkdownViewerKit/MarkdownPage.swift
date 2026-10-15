import Foundation

/// Convenience helpers for producing a full, styled HTML page from Markdown.
public enum MarkdownPage {

    /// Renders `markdown` to a complete HTML document ready for a `WKWebView`.
    public static func html(markdown: String, baseURL: URL?) -> String {
        let renderer = HTMLRenderer(baseURL: baseURL)
        return MarkdownCSS.page(for: renderer.render(markdown))
    }
}
