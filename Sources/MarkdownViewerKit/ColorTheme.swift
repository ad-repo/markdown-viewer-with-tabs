import Foundation

/// A named color theme for the rendered Markdown document. Each theme carries a
/// fixed palette so the reading pane has a distinct, self-contained look that is
/// independent of the system appearance.
public struct ColorTheme: Identifiable, Hashable, Sendable {
    /// Stable identifier, also used for persistence.
    public let id: String
    public let name: String
    public let background: String
    public let foreground: String
    public let mutedForeground: String
    /// Code blocks, table headers and striped rows.
    public let surface: String
    public let border: String
    /// Links and the theme's accent swatch (used by the theme button).
    public let accent: String

    public init(id: String,
                name: String,
                background: String,
                foreground: String,
                mutedForeground: String,
                surface: String,
                border: String,
                accent: String) {
        self.id = id
        self.name = name
        self.background = background
        self.foreground = foreground
        self.mutedForeground = mutedForeground
        self.surface = surface
        self.border = border
        self.accent = accent
    }

    /// Whether the background reads as dark. Drives the `color-scheme` hint so
    /// native controls (checkboxes, scrollbars) match the theme.
    public var isDark: Bool {
        guard let rgb = Self.components(background) else { return false }
        let luminance = 0.299 * rgb.red + 0.587 * rgb.green + 0.114 * rgb.blue
        return luminance < 0.5
    }

    /// The `:root` custom-property declarations for this theme.
    public var cssDeclarations: String {
        """
        color-scheme: \(isDark ? "dark" : "light");
        --fg: \(foreground);
        --fg-muted: \(mutedForeground);
        --bg: \(background);
        --border: \(border);
        --code-bg: \(surface);
        --quote-bar: \(border);
        --link: \(accent);
        --table-stripe: \(surface);
        """
    }

    private static func components(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        return (
            Double((rgb >> 16) & 0xFF) / 255,
            Double((rgb >> 8) & 0xFF) / 255,
            Double(rgb & 0xFF) / 255
        )
    }
}

/// The built-in catalog of color themes the app cycles through.
public enum ColorThemeCatalog {

    /// Every theme, in cycle order. A bright, saturated mix: Miami-neon, pastel
    /// cream and vivid candy palettes.
    public static let themes: [ColorTheme] = [
        // MARK: Miami / neon
        ColorTheme(id: "miami-vice", name: "Miami Vice",
                   background: "#240b4a", foreground: "#f7ebff", mutedForeground: "#c09bff",
                   surface: "#331370", border: "#5a2fb8", accent: "#ff2d95"),
        ColorTheme(id: "miami-sunset", name: "Miami Sunset",
                   background: "#3a1030", foreground: "#ffe9f6", mutedForeground: "#e08ec0",
                   surface: "#4d1a44", border: "#8a2f70", accent: "#ff8b5e"),
        ColorTheme(id: "neon-nights", name: "Neon Nights",
                   background: "#0f0e17", foreground: "#fffffe", mutedForeground: "#b8bcd6",
                   surface: "#1c1a2a", border: "#3a3756", accent: "#ff8906"),
        ColorTheme(id: "synthwave", name: "Synthwave",
                   background: "#241b2f", foreground: "#fff2ff", mutedForeground: "#c79bff",
                   surface: "#33244e", border: "#5a3f88", accent: "#ff7edb"),
        ColorTheme(id: "vaporwave", name: "Vaporwave",
                   background: "#1a1750", foreground: "#e8fbff", mutedForeground: "#9fb0ff",
                   surface: "#28257a", border: "#463fc0", accent: "#01cdfe"),
        ColorTheme(id: "cyberpunk", name: "Cyberpunk",
                   background: "#12002e", foreground: "#f9f9ff", mutedForeground: "#b487ff",
                   surface: "#20055c", border: "#43129c", accent: "#fcee0a"),
        ColorTheme(id: "outrun", name: "Outrun",
                   background: "#1b0b2e", foreground: "#ffe6fb", mutedForeground: "#cf86e6",
                   surface: "#2c1450", border: "#552a99", accent: "#ff3864"),
        ColorTheme(id: "ultraviolet", name: "Ultraviolet",
                   background: "#1c0033", foreground: "#f2e8ff", mutedForeground: "#bd8cff",
                   surface: "#2d0557", border: "#521e9c", accent: "#b967ff"),

        // MARK: Pastel
        ColorTheme(id: "bubblegum", name: "Bubblegum",
                   background: "#fff0f8", foreground: "#4a1136", mutedForeground: "#c07aa6",
                   surface: "#ffe0f0", border: "#ffc2e2", accent: "#ff3fa4"),
        ColorTheme(id: "cotton-candy", name: "Cotton Candy",
                   background: "#f7f0ff", foreground: "#3c1a56", mutedForeground: "#9b7ac2",
                   surface: "#ede0ff", border: "#dcc2ff", accent: "#ff6ec7"),
        ColorTheme(id: "pastel-mint", name: "Pastel Mint",
                   background: "#e8fff6", foreground: "#0d4a37", mutedForeground: "#5fa88e",
                   surface: "#d0fbec", border: "#a6efce", accent: "#00c9a7"),
        ColorTheme(id: "lavender", name: "Lavender",
                   background: "#f3eeff", foreground: "#3d2a63", mutedForeground: "#8f83bb",
                   surface: "#e6daff", border: "#d1bfff", accent: "#9b5de5"),
        ColorTheme(id: "peach-cream", name: "Peach Cream",
                   background: "#fff2e6", foreground: "#5c3010", mutedForeground: "#bd8a5e",
                   surface: "#ffe4cc", border: "#ffcda3", accent: "#ff7a45"),
        ColorTheme(id: "sky-blue", name: "Sky Blue",
                   background: "#e8f6ff", foreground: "#0f3b5c", mutedForeground: "#6a9cbe",
                   surface: "#d4efff", border: "#aee0ff", accent: "#1e90ff"),
        ColorTheme(id: "lemon-drop", name: "Lemon Drop",
                   background: "#fffbe0", foreground: "#574a00", mutedForeground: "#b0a02e",
                   surface: "#fff7bf", border: "#ffee8f", accent: "#f2b705"),
        ColorTheme(id: "seafoam", name: "Seafoam",
                   background: "#e4fbf6", foreground: "#0b4745", mutedForeground: "#559c98",
                   surface: "#ccf7ef", border: "#a3efe3", accent: "#14c2b8"),
        ColorTheme(id: "orchid", name: "Orchid",
                   background: "#fdeaff", foreground: "#4a1258", mutedForeground: "#a666b6",
                   surface: "#f8d4ff", border: "#f0aaff", accent: "#d13fff"),

        // MARK: Bright & vivid
        ColorTheme(id: "tangerine", name: "Tangerine",
                   background: "#fff7f0", foreground: "#5c2a00", mutedForeground: "#bd7c44",
                   surface: "#ffe8d2", border: "#ffcf9e", accent: "#ff6b00"),
        ColorTheme(id: "coral-reef", name: "Coral Reef",
                   background: "#ffeeef", foreground: "#5c1a20", mutedForeground: "#bd6e75",
                   surface: "#ffdcde", border: "#ffb8bd", accent: "#ff4757"),
        ColorTheme(id: "aqua-pop", name: "Aqua Pop",
                   background: "#e0fbff", foreground: "#00414d", mutedForeground: "#4596a6",
                   surface: "#c2f6ff", border: "#96ecff", accent: "#00b4d8"),
        ColorTheme(id: "lime-zest", name: "Lime Zest",
                   background: "#f4ffe0", foreground: "#375000", mutedForeground: "#7ba637",
                   surface: "#e6ffc2", border: "#ccff8f", accent: "#7cb518"),
        ColorTheme(id: "grape-soda", name: "Grape Soda",
                   background: "#1a0e2e", foreground: "#f0e0ff", mutedForeground: "#b28ed6",
                   surface: "#281442", border: "#472b73", accent: "#c56bff"),

        // MARK: Rich dark
        ColorTheme(id: "midnight", name: "Midnight",
                   background: "#0b1021", foreground: "#e2e9ff", mutedForeground: "#8593c4",
                   surface: "#141c38", border: "#29366a", accent: "#5b8cff"),
        ColorTheme(id: "deep-sea", name: "Deep Sea",
                   background: "#04202b", foreground: "#d6f5ff", mutedForeground: "#6ba6b8",
                   surface: "#0a3140", border: "#164b60", accent: "#00d4ff"),
        ColorTheme(id: "tropical", name: "Tropical",
                   background: "#07301f", foreground: "#d6ffe9", mutedForeground: "#5fae86",
                   surface: "#0d4530", border: "#14664a", accent: "#00e08a")
    ]

    /// The theme at `index`, wrapping around the catalog.
    public static func theme(at index: Int) -> ColorTheme {
        themes[((index % themes.count) + themes.count) % themes.count]
    }

    /// The index that follows `index` in the cycle. `nil` (no theme selected
    /// yet) advances to the very first theme.
    public static func nextIndex(after index: Int?) -> Int {
        ((index ?? -1) + 1) % themes.count
    }

    /// Looks up a theme by its stable identifier.
    public static func theme(id: String) -> ColorTheme? {
        themes.first { $0.id == id }
    }
}
