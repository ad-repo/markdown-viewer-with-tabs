import Foundation
import SwiftUI

/// Converts a chat reply written in Markdown into a styled `AttributedString`
/// for display in the chat panel.
///
/// The block styles an LLM is likely to emit (headings, lists, block quotes and
/// fenced code) are handled here; inline emphasis, code spans and links are
/// left to `AttributedString`'s own Markdown parser, which SwiftUI `Text`
/// renders.
public enum ChatMarkdown {

    public static let defaultFontSize: Double = 13

    /// Renders `markdown` for display at `fontSize` points.
    public static func attributedString(from markdown: String,
                                        fontSize: Double = defaultFontSize) -> AttributedString {
        Renderer(fontSize: fontSize).render(markdown)
    }

    // MARK: - Blocks

    private static func heading(of line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " else { return nil }
        let text = rest.dropFirst().trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (hashes.count, text)
    }

    private static func headingSizeStep(for level: Int) -> Double {
        switch level {
        case 1: return 4
        case 2: return 2
        case 3: return 1
        default: return 0
        }
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let core = line.filter { $0 != " " }
        guard core.count >= 3, Set(core).count == 1 else { return false }
        return core.allSatisfy { $0 == "-" || $0 == "*" || $0 == "_" }
    }

    /// A list marker (`•` for bullets, the original numbering for ordered
    /// lists), the item text and how far the item is indented.
    private static func listItem(of line: String) -> (marker: String, text: String, indent: Int)? {
        let indent = line.prefix { $0 == " " }.count
        let rest = line.dropFirst(indent)
        guard let first = rest.first else { return nil }

        if ["-", "*", "+"].contains(String(first)), rest.dropFirst().first == " " {
            return ("• ", String(rest.dropFirst(2)), indent)
        }

        let digits = rest.prefix { $0.isNumber }
        if !digits.isEmpty {
            let afterDigits = rest.dropFirst(digits.count)
            if afterDigits.first == ".", afterDigits.dropFirst().first == " " {
                return ("\(digits). ", String(afterDigits.dropFirst(2)), indent)
            }
        }
        return nil
    }

    private static func quoteBody(_ line: String) -> String {
        var body = line
        while body.hasPrefix(">") {
            body.removeFirst()
            if body.hasPrefix(" ") { body.removeFirst() }
        }
        return body
    }

    /// Parses an inline Markdown fragment, falling back to the literal text
    /// when the fragment is malformed (unbalanced emphasis, stray brackets).
    private static func inline(_ text: String, base: Font) -> AttributedString {
        var parsed: AttributedString
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            parsed = attributed
        } else {
            parsed = AttributedString(text)
        }
        parsed.font = base
        return parsed
    }

    // MARK: - Renderer

    private struct Renderer {
        let fontSize: Double

        private var bodyFont: Font { .system(size: fontSize) }
        private var codeFont: Font { .system(size: max(fontSize - 1, 9), design: .monospaced) }

        func render(_ markdown: String) -> AttributedString {
            var result = AttributedString()
            var paragraph: [String] = []
            var codeLines: [String] = []
            var inCode = false

            func appendBlock(_ block: AttributedString, spacing: String = "\n\n") {
                result.append(block)
                result.append(AttributedString(spacing))
            }

            func flushParagraph() {
                guard !paragraph.isEmpty else { return }
                appendBlock(ChatMarkdown.inline(paragraph.joined(separator: "\n"), base: bodyFont))
                paragraph.removeAll(keepingCapacity: true)
            }

            func flushCode() {
                guard !codeLines.isEmpty else { return }
                var block = AttributedString(codeLines.joined(separator: "\n"))
                block.font = codeFont
                block.backgroundColor = Color.gray.opacity(0.16)
                appendBlock(block)
                codeLines.removeAll(keepingCapacity: true)
            }

            for rawLine in markdown.components(separatedBy: "\n") {
                let line = rawLine.replacingOccurrences(of: "\t", with: "    ")
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    if inCode {
                        flushCode()
                        inCode = false
                    } else {
                        flushParagraph()
                        inCode = true
                    }
                    continue
                }

                if inCode {
                    codeLines.append(rawLine)
                    continue
                }

                if trimmed.isEmpty {
                    flushParagraph()
                    continue
                }

                if let heading = ChatMarkdown.heading(of: trimmed) {
                    flushParagraph()
                    var text = ChatMarkdown.inline(heading.text, base: bodyFont)
                    text.font = .system(size: fontSize + ChatMarkdown.headingSizeStep(for: heading.level),
                                        weight: .bold)
                    text.inlinePresentationIntent = .stronglyEmphasized
                    appendBlock(text)
                    continue
                }

                if ChatMarkdown.isHorizontalRule(trimmed) {
                    flushParagraph()
                    var rule = AttributedString(String(repeating: "─", count: 24))
                    rule.font = bodyFont
                    rule.foregroundColor = .secondary
                    appendBlock(rule)
                    continue
                }

                if let item = ChatMarkdown.listItem(of: line) {
                    flushParagraph()
                    var marker = AttributedString(String(repeating: " ", count: item.indent) + item.marker)
                    marker.font = bodyFont
                    marker.foregroundColor = .secondary
                    result.append(marker)
                    result.append(ChatMarkdown.inline(item.text, base: bodyFont))
                    result.append(AttributedString("\n"))
                    continue
                }

                if trimmed.hasPrefix(">") {
                    flushParagraph()
                    var quote = ChatMarkdown.inline(ChatMarkdown.quoteBody(trimmed), base: bodyFont)
                    quote.font = .system(size: fontSize).italic()
                    quote.foregroundColor = .secondary
                    quote.inlinePresentationIntent = .emphasized
                    appendBlock(quote, spacing: "\n")
                    continue
                }

                paragraph.append(trimmed)
            }

            flushParagraph()
            if inCode { flushCode() }
            return result
        }
    }
}
