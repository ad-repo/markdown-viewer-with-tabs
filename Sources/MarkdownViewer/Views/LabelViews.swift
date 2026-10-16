import AppKit
import MarkdownViewerKit
import SwiftUI

/// Parses the hex colors stored on labels.
enum HexColor {
    static func components(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        return (
            Double((rgb >> 16) & 0xFF) / 255,
            Double((rgb >> 8) & 0xFF) / 255,
            Double(rgb & 0xFF) / 255
        )
    }

    static func color(_ hex: String) -> Color {
        guard let rgb = components(hex) else { return .accentColor }
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// Black or white, whichever reads better on top of the given color.
    static func contrastText(_ hex: String) -> Color {
        guard let rgb = components(hex) else { return .white }
        let luminance = 0.299 * rgb.red + 0.587 * rgb.green + 0.114 * rgb.blue
        return luminance > 0.6 ? .black : .white
    }
}

/// A label rendered as a small, filled colored button. When `onTap` is
/// provided, clicking it filters the sidebar by that label.
struct LabelPill: View {
    let name: String
    let colorHex: String
    var onTap: (() -> Void)?

    var body: some View {
        let fill = HexColor.color(colorHex)
        let label = Text(name)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(HexColor.contrastText(colorHex))
            .background(Capsule().fill(fill))

        if let onTap {
            Button(action: onTap) { label }
                .buttonStyle(.plain)
                .help("Filter by \(name)")
        } else {
            label
        }
    }
}

/// A row of label pills, capped so a heavily labeled file does not overflow
/// the sidebar.
struct LabelPills: View {
    @EnvironmentObject private var labels: LabelStore
    let names: [String]
    var onTap: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(names.prefix(3), id: \.self) { name in
                LabelPill(name: name, colorHex: labels.colorHex(named: name), onTap: onTap.map { handler in { handler(name) } })
            }
            if names.count > 3 {
                Text("+\(names.count - 3)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The toggles and creation action shown inside a "Labels" menu.
struct LabelMenuItems: View {
    @EnvironmentObject private var labels: LabelStore
    let path: String

    var body: some View {
        ForEach(labels.allLabels) { label in
            Toggle(label.name, isOn: Binding(
                get: { labels.contains(path: path, in: label.id) },
                set: { _ in labels.toggle(path: path, in: label.id) }
            ))
        }
        if !labels.allLabels.isEmpty { Divider() }
        Button("New Label…") {
            promptForNewLabel(assigningTo: path)
        }
    }
}

/// Asks for a label name and creates it, optionally tagging a file with it.
/// Uses a modal alert so it can be triggered directly from a context menu.
@MainActor
func promptForNewLabel(assigningTo path: String?) {
    let alert = NSAlert()
    alert.messageText = "New Label"
    alert.informativeText = path == nil
        ? "Enter a name for the new label."
        : "Enter a name; the file will be tagged with it."
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")

    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
    field.placeholderString = "Label name"
    alert.accessoryView = field
    alert.window.initialFirstResponder = field

    guard alert.runModal() == .alertFirstButtonReturn,
          let label = LabelStore.shared.createLabel(named: field.stringValue) else { return }
    if let path {
        LabelStore.shared.assign(path: path, to: label.id)
    }
}
