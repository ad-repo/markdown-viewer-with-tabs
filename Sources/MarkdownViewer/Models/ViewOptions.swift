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

    /// Index into `ColorThemeCatalog.themes`, or `nil` to follow the system
    /// light/dark appearance (the default, and the state the app launches in
    /// before the theme button is ever pressed).
    @Published var themeIndex: Int? {
        didSet {
            if let themeIndex {
                defaults.set(themeIndex, forKey: Keys.themeIndex)
            } else {
                defaults.removeObject(forKey: Keys.themeIndex)
            }
        }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let contentWidth = "viewContentWidth"
        static let fontSize = "viewFontSize"
        static let themeIndex = "viewThemeIndex"
    }

    private init() {
        let defaults = UserDefaults.standard
        self.defaults = defaults

        self.contentWidth = defaults.string(forKey: Keys.contentWidth)
            .flatMap(MarkdownContentWidth.init(rawValue:)) ?? .comfortable

        let stored = defaults.object(forKey: Keys.fontSize) as? Double ?? Self.defaultFontSize
        self.fontSize = min(max(stored, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)

        self.themeIndex = Self.loadThemeIndex(from: defaults)
    }

    /// Reads the persisted theme index, dropping it if the catalog changed and
    /// it no longer points at a theme.
    private static func loadThemeIndex(from defaults: UserDefaults) -> Int? {
        guard let stored = defaults.object(forKey: Keys.themeIndex) as? Int,
              (0..<ColorThemeCatalog.themes.count).contains(stored) else { return nil }
        return stored
    }

    // MARK: - Color theme

    /// The theme currently applied to the reading pane, or `nil` for the
    /// system light/dark default.
    var currentTheme: ColorTheme? {
        themeIndex.map { ColorThemeCatalog.theme(at: $0) }
    }

    /// The theme the button will switch to on its next press — always the next
    /// entry in the catalog, wrapping at the end.
    var nextTheme: ColorTheme {
        ColorThemeCatalog.theme(at: ColorThemeCatalog.nextIndex(after: themeIndex))
    }

    /// Advances to the next theme in the catalog.
    func cycleTheme() {
        themeIndex = ColorThemeCatalog.nextIndex(after: themeIndex)
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
