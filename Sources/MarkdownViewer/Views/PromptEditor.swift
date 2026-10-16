import AppKit
import SwiftUI

/// A multi-line prompt field for the chat panel.
///
/// AppKit-backed rather than a SwiftUI `TextField` so Return can send the
/// message — Shift+Return (and Option+Return) insert a newline instead, which
/// is impossible to express with a single-line field and awkward with a plain
/// `TextEditor`.
struct PromptEditor: NSViewRepresentable {

    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding?
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PromptTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.font = .systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.onSubmit = { context.coordinator.parent.onSubmit() }
        textView.onFocusChange = { [weak coordinator = context.coordinator] focused in
            // The text view reports this from AppKit's responder chain, which
            // can land inside a SwiftUI update; hop to the next run loop tick
            // so the binding is not mutated during a view update.
            DispatchQueue.main.async {
                coordinator?.parent.isFocused?.wrappedValue = focused
            }
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.contentView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? PromptTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        if isFocused?.wrappedValue == true, textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PromptEditor

        init(_ parent: PromptEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// The `NSTextView` behind `PromptEditor`; it owns the Return-key behaviour.
private final class PromptTextView: NSTextView {

    var onSubmit: () -> Void = {}
    var onFocusChange: (Bool) -> Void = { _ in }

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 // Return
        let wantsNewline = event.modifierFlags.contains(.shift)
            || event.modifierFlags.contains(.option)
        if isReturn, !wantsNewline {
            onSubmit()
            return
        }
        super.keyDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChange(false) }
        return resigned
    }
}
