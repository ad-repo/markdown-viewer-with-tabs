import MarkdownViewerKit
import SwiftUI

/// Root view: the vertical tab bar on the left, rendered Markdown on the right.
struct MainView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var labels: LabelStore

    var body: some View {
        NavigationSplitView {
            TabSidebarView()
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ViewOptionsMenu()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            store.handleDrop(providers: providers)
        }
        .onOpenURL { url in
            store.open(url: url)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let document = store.selectedDocument {
            VStack(spacing: 0) {
                header(for: document)
                Divider()
                MarkdownWebView(html: document.html, revision: document.revision)
            }
            .frame(minWidth: 380, minHeight: 300)
        } else {
            EmptyStateView()
        }
    }

    private func header(for document: OpenDocument) -> some View {
        let names = labels.labels(containing: document.url.path).map(\.name).sorted()
        return HStack(spacing: 8) {
            Text(document.fileName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            if !names.isEmpty {
                LabelPills(names: names)
            }
            Menu {
                LabelMenuItems(path: document.url.path)
            } label: {
                Image(systemName: "tag")
                    .font(.system(size: 11))
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Labels")
            Spacer()
            Text(document.url.deletingLastPathComponent().path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("No Markdown file open")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Open File…") {
                store.presentOpenPanel()
            }
            .keyboardShortcut("o", modifiers: .command)
            Text("or drag a .md file here")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
