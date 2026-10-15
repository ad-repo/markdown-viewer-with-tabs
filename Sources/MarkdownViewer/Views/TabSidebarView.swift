import AppKit
import SwiftUI

/// The left vertical tab bar listing every open file.
struct TabSidebarView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        List(selection: $store.selectedID) {
            Section {
                ForEach(store.documents) { document in
                    TabRow(document: document)
                        .tag(document.id)
                        .contextMenu {
                            Button("Reload from Disk") {
                                store.refresh(document.id)
                            }
                            Divider()
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([document.url])
                            }
                            Button("Copy Path") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(document.url.path, forType: .string)
                            }
                            Divider()
                            Button("Close Tab") { store.close(document.id) }
                        }
                }
            } header: {
                Text(store.documents.isEmpty ? "No Files" : "Open Files")
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 340)
        .safeAreaInset(edge: .bottom) {
            Button {
                store.presentOpenPanel()
            } label: {
                Label("Open File…", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(10)
            .background(.bar)
        }
    }
}

private struct TabRow: View {
    @EnvironmentObject private var store: DocumentStore
    let document: OpenDocument

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(document.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(document.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Button {
                store.refresh(document.id)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reload from disk")
            Button {
                store.close(document.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close tab")
        }
        .padding(.vertical, 2)
    }
}
