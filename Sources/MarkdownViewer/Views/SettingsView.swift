import SwiftUI

/// The app's Settings window (⌘,).
struct SettingsView: View {
    @AppStorage("saveFilesOnExit") private var saveFilesOnExit = true

    var body: some View {
        Form {
            Section {
                Toggle("Save files on exit", isOn: $saveFilesOnExit)
                Text("When enabled, the files that are open when you quit will be reopened the next time you launch the app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
