import Foundation
import MarkdownViewerKit

/// User-adjustable rendering options: how wide the reading column is and how
/// large the body text is. Persisted in `UserDefaults` and shared app-wide.
@MainActor
final class ViewOptions: ObservableObject {

    static let shared = ViewOptions()

    static let fontSizeRange: ClosedRange<Double> = 11...24
    static let defaultFontSize: Double = 15

    @Published var contentWidth: MarkdownContentWidth {
        didSet { defaults.set(contentWidth.rawValue, forKey: Keys.contentWidth) }
    }

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let contentWidth = "viewContentWidth"
        static let fontSize = "viewFontSize"
    }

    private init() {
        let defaults = UserDefaults.standard
        self.defaults = defaults

        self.contentWidth = defaults.string(forKey: Keys.contentWidth)
            .flatMap(MarkdownContentWidth.init(rawValue:)) ?? .comfortable

        let stored = defaults.object(forKey: Keys.fontSize) as? Double ?? Self.defaultFontSize
        self.fontSize = min(max(stored, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
    }

    var canIncreaseFontSize: Bool { fontSize < Self.fontSizeRange.upperBound }
    var canDecreaseFontSize: Bool { fontSize > Self.fontSizeRange.lowerBound }

    func increaseFontSize() {
        fontSize = min(fontSize + 1, Self.fontSizeRange.upperBound)
    }

    func decreaseFontSize() {
        fontSize = max(fontSize - 1, Self.fontSizeRange.lowerBound)
    }

    func resetFontSize() {
        fontSize = Self.defaultFontSize
    }
}
