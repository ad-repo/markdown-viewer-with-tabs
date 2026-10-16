import MarkdownViewerKit
import SwiftUI

/// Toolbar menu for the reading-column width and body text size.
struct ViewOptionsMenu: View {
    @EnvironmentObject private var options: ViewOptions

    var body: some View {
        Menu {
            Picker("Content Width", selection: $options.contentWidth) {
                ForEach(MarkdownContentWidth.allCases) { width in
                    Text(width.title).tag(width)
                }
            }
            Divider()
            Button("Increase Text Size") { options.increaseFontSize() }
                .disabled(!options.canIncreaseFontSize)
            Button("Decrease Text Size") { options.decreaseFontSize() }
                .disabled(!options.canDecreaseFontSize)
            Button("Actual Text Size (\(Int(options.fontSize)) pt)") { options.resetFontSize() }
        } label: {
            Image(systemName: "textformat.size")
        }
        .help("View options")
    }
}
