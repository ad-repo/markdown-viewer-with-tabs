import Foundation
import Markdown

/// Renders a Markdown source string into an HTML fragment.
///
/// Uses Apple's `swift-markdown` (CommonMark + GitHub Flavored Markdown:
/// tables, task lists, strikethrough, autolinks, fenced/indented code,
/// blockquotes, nested lists, raw inline/block HTML, ...).
public struct HTMLRenderer {

    /// Base directory used to resolve relative image references so that they
    /// can be inlined as data URIs and displayed inside the web view.
    public var baseURL: URL?

    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }

    /// Parse `markdown` and return an HTML fragment (no `<html>` wrapper).
    public func render(_ markdown: String) -> String {
        let document = Document(parsing: markdown)
        var context = RenderContext(baseURL: baseURL)
        return renderChildren(of: document, into: &context)
    }

    // MARK: - Rendering

    private func renderChildren(of node: Markup, into context: inout RenderContext) -> String {
        node.children.map { render($0, into: &context) }.joined()
    }

    private func render(_ node: Markup, into context: inout RenderContext) -> String {
        switch node {
        case let heading as Heading:
            let level = min(max(heading.level, 1), 6)
            return "<h\(level)>\(renderChildren(of: heading, into: &context))</h\(level)>\n"

        case let paragraph as Paragraph:
            return "<p>\(renderChildren(of: paragraph, into: &context))</p>\n"

        case let code as CodeBlock:
            return renderCodeBlock(code)

        case let blockquote as BlockQuote:
            return "<blockquote>\n\(renderChildren(of: blockquote, into: &context))</blockquote>\n"

        case let list as UnorderedList:
            let items = renderChildren(of: list, into: &context)
            return "<ul>\n\(items)</ul>\n"

        case let list as OrderedList:
            let start = list.startIndex
            let startAttr = start != 1 ? " start=\"\(start)\"" : ""
            let items = renderChildren(of: list, into: &context)
            return "<ol\(startAttr)>\n\(items)</ol>\n"

        case let item as ListItem:
            return renderListItem(item, into: &context)

        case let table as Table:
            return renderTable(table, into: &context)

        case let html as HTMLBlock:
            return html.rawHTML + "\n"

        case is ThematicBreak:
            return "<hr>\n"

        // Inline nodes.
        case let text as Text:
            return renderText(text.string, into: &context)

        case let code as InlineCode:
            return "<code>\(escapeText(code.code))</code>"

        case let emphasis as Emphasis:
            return "<em>\(renderChildren(of: emphasis, into: &context))</em>"

        case let strong as Strong:
            return "<strong>\(renderChildren(of: strong, into: &context))</strong>"

        case let strikethrough as Strikethrough:
            return "<del>\(renderChildren(of: strikethrough, into: &context))</del>"

        case let link as Link:
            return renderLink(link, into: &context)

        case let image as Image:
            return renderImage(image, into: &context)

        case let inlineHTML as InlineHTML:
            return inlineHTML.rawHTML

        case is SoftBreak:
            return "\n"

        case is LineBreak:
            return "<br>\n"

        default:
            // Unknown/unsupported node: render its children transparently.
            return renderChildren(of: node, into: &context)
        }
    }

    // MARK: - Blocks

    private func renderCodeBlock(_ code: CodeBlock) -> String {
        let languageClass: String
        if let language = code.language, !language.isEmpty {
            languageClass = " class=\"language-\(escapeAttribute(language))\""
        } else {
            languageClass = ""
        }
        return "<pre><code\(languageClass)>\(escapeText(code.code))</code></pre>\n"
    }

    private func renderListItem(_ item: ListItem, into context: inout RenderContext) -> String {
        let checkbox: String
        switch item.checkbox {
        case .checked:
            checkbox = "<input type=\"checkbox\" disabled checked> "
        case .unchecked:
            checkbox = "<input type=\"checkbox\" disabled> "
        case .none:
            checkbox = ""
        }

        var body = renderChildren(of: item, into: &context)
        // Single-paragraph list items read better without the extra <p> wrapper.
        if item.childCount == 1 {
            body = unwrapSingleParagraph(body)
        }
        return "<li>\(checkbox)\(body)</li>\n"
    }

    private func renderTable(_ table: Table, into context: inout RenderContext) -> String {
        let alignments = table.columnAlignments
        var html = "<table>\n"

        for child in table.children {
            if let head = child as? Table.Head {
                html += "<thead>\n"
                html += renderTableRow(cells: Array(head.children), alignments: alignments, into: &context, cellTag: "th")
                html += "</thead>\n"
            } else if let body = child as? Table.Body {
                html += "<tbody>\n"
                for row in body.children {
                    html += renderTableRow(cells: Array(row.children), alignments: alignments, into: &context, cellTag: "td")
                }
                html += "</tbody>\n"
            }
        }

        html += "</table>\n"
        return html
    }

    private func renderTableRow(cells: [Markup], alignments: [Table.ColumnAlignment?], into context: inout RenderContext, cellTag: String) -> String {
        var html = "<tr>"
        for (index, cell) in cells.enumerated() {
            let style = alignmentStyle(for: index, in: alignments)
            html += "<\(cellTag)\(style)>\(renderChildren(of: cell, into: &context))</\(cellTag)>"
        }
        html += "</tr>\n"
        return html
    }

    private func alignmentStyle(for index: Int, in alignments: [Table.ColumnAlignment?]) -> String {
        guard index < alignments.count, let alignment = alignments[index] else { return "" }
        switch alignment {
        case .left: return " style=\"text-align:left\""
        case .center: return " style=\"text-align:center\""
        case .right: return " style=\"text-align:right\""
        }
    }

    // MARK: - Inlines

    private func renderLink(_ link: Link, into context: inout RenderContext) -> String {
        let wasInsideLink = context.insideLink
        context.insideLink = true
        let label = renderChildren(of: link, into: &context)
        context.insideLink = wasInsideLink
        guard let destination = link.destination, !destination.isEmpty else {
            return label
        }
        let title = link.title.map { " title=\"\(escapeAttribute($0))\"" } ?? ""
        return "<a href=\"\(escapeAttribute(destination))\"\(title)>\(label)</a>"
    }

    private func renderImage(_ image: Image, into context: inout RenderContext) -> String {
        let alt = escapeAttribute(plainText(of: image))
        let title = image.title.map { " title=\"\(escapeAttribute($0))\"" } ?? ""
        guard let source = image.source, !source.isEmpty else {
            return "<img src=\"\" alt=\"\(alt)\"\(title)>"
        }

        if let inlined = inlineLocalImage(source) {
            return "<img src=\"\(inlined)\" alt=\"\(alt)\"\(title)>"
        }
        return "<img src=\"\(escapeAttribute(source))\" alt=\"\(alt)\"\(title)>"
    }

    // MARK: - Text & autolinks

    private static let autolinkRegex = try! NSRegularExpression(
        pattern: "(?:https?://|www\\.)[^\\s<>\"]+",
        options: [.caseInsensitive]
    )

    private static let trailingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", "'", "\"", "…"]

    /// Escapes text and, when not already inside a link, turns bare URLs into
    /// anchors. `swift-markdown` does not enable cmark-gfm's autolink
    /// extension, so we do this pass ourselves.
    private func renderText(_ string: String, into context: inout RenderContext) -> String {
        guard !context.insideLink else { return escapeText(string) }

        let ns = string as NSString
        let matches = Self.autolinkRegex.matches(in: string, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return escapeText(string) }

        var result = ""
        var cursor = 0

        for match in matches {
            let range = match.range
            if range.location > cursor {
                result += escapeText(ns.substring(with: NSRange(location: cursor, length: range.location - cursor)))
            }

            var url = ns.substring(with: range)
            var trailing = ""
            while let last = url.last, Self.trailingPunctuation.contains(last) {
                trailing.insert(last, at: trailing.startIndex)
                url.removeLast()
            }

            let href = url.lowercased().hasPrefix("http") ? url : "http://\(url)"
            result += "<a href=\"\(escapeAttribute(href))\">\(escapeText(url))</a>"
            result += escapeText(trailing)

            cursor = range.location + range.length
        }

        if cursor < ns.length {
            result += escapeText(ns.substring(from: cursor))
        }
        return result
    }

    // MARK: - Helpers

    /// Returns a `data:` URI if `source` points to a readable local image
    /// relative to (or absolute within) the document's directory.
    private func inlineLocalImage(_ source: String) -> String? {
        guard let baseURL else { return nil }

        // Leave remote / absolute-scheme references untouched.
        if let url = URL(string: source), url.scheme != nil, url.scheme != "file" {
            return nil
        }

        let decoded = source.removingPercentEncoding ?? source
        let fileURL: URL
        if decoded.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: decoded)
        } else if let relative = URL(string: source), relative.scheme == "file" {
            fileURL = relative
        } else {
            fileURL = baseURL.appendingPathComponent(decoded)
        }

        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return "data:\(mimeType(for: fileURL));base64,\(data.base64EncodedString())"
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "tiff", "tif": return "image/tiff"
        case "heic": return "image/heic"
        case "ico": return "image/x-icon"
        case "avif": return "image/avif"
        default: return "application/octet-stream"
        }
    }

    private func plainText(of node: Markup) -> String {
        if let text = node as? Text {
            return text.string
        }
        if let code = node as? InlineCode {
            return code.code
        }
        return node.children.map { plainText(of: $0) }.joined()
    }

    /// Strips the single `<p>...</p>` wrapper produced for a paragraph child.
    /// Only unwraps when the whole body is exactly one paragraph (nothing
    /// follows the closing tag), so multi-block list items keep their spacing.
    private func unwrapSingleParagraph(_ html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<p>"), trimmed.hasSuffix("</p>"), trimmed.count >= 7 else {
            return html
        }
        let inner = trimmed.dropFirst(3).dropLast(4)
        guard !inner.contains("</p>") else { return html }
        return String(inner)
    }

    private func escapeText(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for character in string {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            default: result.append(character)
            }
        }
        return result
    }

    private func escapeAttribute(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for character in string {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }
}

private struct RenderContext {
    var baseURL: URL?
    var insideLink: Bool = false
}
