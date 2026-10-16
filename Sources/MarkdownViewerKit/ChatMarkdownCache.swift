import Foundation

/// Caches rendered chat replies so a long transcript is not re-parsed every
/// time a streamed chunk arrives.
///
/// Completed messages never change, so their rendering is computed once and
/// reused. Only `MainActor` (view) code touches this, which is where rendering
/// happens.
@MainActor
public final class ChatMarkdownCache {

    private let cache = NSCache<NSString, Box>()
    private let fontSize: Double

    /// Number of times the underlying renderer actually ran (cache misses).
    /// Exposed for tests.
    private(set) var renders = 0

    public init(countLimit: Int = 400, fontSize: Double = ChatMarkdown.defaultFontSize) {
        cache.countLimit = countLimit
        self.fontSize = fontSize
    }

    public func attributedString(from markdown: String) -> AttributedString {
        let key = markdown as NSString
        if let hit = cache.object(forKey: key) {
            return hit.value
        }
        renders += 1
        let rendered = ChatMarkdown.attributedString(from: markdown, fontSize: fontSize)
        cache.setObject(Box(rendered), forKey: key)
        return rendered
    }

    /// `NSCache` needs a class value; `AttributedString` is a struct.
    private final class Box {
        let value: AttributedString
        init(_ value: AttributedString) { self.value = value }
    }
}
