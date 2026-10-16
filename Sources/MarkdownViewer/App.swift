import AppKit
import SwiftUI

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DocumentStore.shared
    @StateObject private var labels = LabelStore.shared

    var body: some Scene {
        Window("markdown-viewer-with-tabs", id: "main") {
            MainView()
                .environmentObject(store)
                .environmentObject(labels)
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    store.presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) { }

            CommandMenu("Tabs") {
                Button("Next Tab") { store.selectNext() }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Previous Tab") { store.selectPrevious() }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
                Divider()
                Button("Reload Tab") { store.refreshSelected() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(store.selectedID == nil)
                Button("Close Tab") { store.closeSelected() }
                    .keyboardShortcut("w", modifiers: .command)
                    .disabled(store.selectedID == nil)
                Divider()
                ForEach(1...9, id: \.self) { number in
                    Button("Tab \(number)") { store.selectTab(atIndex: number - 1) }
                        .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
                        .disabled(store.documents.count < number)
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

/// Handles files opened from Finder ("Open With") before the UI is ready, and
/// ensures the app behaves as a regular foreground app when run as a bundle.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let fileArguments = CommandLine.arguments
            .dropFirst()
            .filter { !$0.hasPrefix("-") }
            .map { URL(fileURLWithPath: $0) }

        if fileArguments.isEmpty {
            DocumentStore.shared.restoreSession()
        } else {
            DocumentStore.shared.open(urls: fileArguments)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        DocumentStore.shared.open(urls: urls)
    }

    func applicationWillTerminate(_ notification: Notification) {
        DocumentStore.shared.saveSession()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
