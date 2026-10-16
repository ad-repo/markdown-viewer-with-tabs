import MarkdownViewerKit
import SwiftUI

/// A round, floating button that advances the color theme. Its swatch previews
/// the theme that the next press will apply — the theme's background fill, an
/// accent ring and an accent icon — so the button always matches the look it is
/// about to switch to.
struct ThemeCycleButton: View {
    @EnvironmentObject private var options: ViewOptions

    private let diameter: CGFloat = 46

    var body: some View {
        let next = options.nextTheme
        let background = HexColor.color(next.background)
        let accent = HexColor.color(next.accent)

        Button {
            options.cycleTheme()
        } label: {
            ZStack {
                Circle()
                    .fill(background)
                Circle()
                    .strokeBorder(accent, lineWidth: 3)
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: diameter * 0.34, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: diameter, height: diameter)
            .overlay(
                Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
            )
            .shadow(color: accent.opacity(0.55), radius: 6, y: 2)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Next color theme: \(next.name)")
        .accessibilityLabel("Cycle color theme")
        .accessibilityValue("Next: \(next.name)")
        .animation(.easeInOut(duration: 0.15), value: next.id)
    }
}
