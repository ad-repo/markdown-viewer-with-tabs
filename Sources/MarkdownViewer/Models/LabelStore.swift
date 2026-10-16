import Foundation
import MarkdownViewerKit

/// Owns the app's label registry and tracks every file the app has opened.
///
/// A label is a list of file pointers; the registry is the source of truth for
/// search and sort. State is persisted as JSON in Application Support so labels
/// survive launches. Missing files are pruned both at launch and whenever an
/// attempt is made to open them.
@MainActor
final class LabelStore: ObservableObject {

    static let shared = LabelStore()

    @Published private(set) var registry: LabelRegistry
    /// Paths of files the app has opened, most recent first. Files that carry
    /// no label still appear in search results because of this registry.
    @Published private(set) var registeredPaths: [String]

    private struct State: Codable {
        var registry: LabelRegistry
        var registeredPaths: [String]
    }

    private let storageURL: URL
    private let fileManager = FileManager.default

    init(storageURL: URL = LabelStore.defaultStorageURL) {
        self.storageURL = storageURL
        let state = LabelStore.load(from: storageURL)
        self.registry = state.registry
        self.registeredPaths = state.registeredPaths
        pruneMissingFiles()
    }

    nonisolated static var defaultStorageURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("MarkdownViewer", isDirectory: true)
            .appendingPathComponent("labels.json")
    }

    // MARK: - Labels

    var allLabels: [FileLabel] {
        registry.labels.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func label(named name: String) -> FileLabel? { registry.label(named: name) }
    func label(id: FileLabel.ID) -> FileLabel? { registry.label(id: id) }

    func colorHex(named name: String) -> String {
        registry.label(named: name)?.colorHex ?? LabelPalette.hex(forIndex: 0)
    }

    func labels(containing path: String) -> [FileLabel] {
        registry.labels(containing: path)
    }

    func contains(path: String, in id: FileLabel.ID) -> Bool {
        registry.contains(path: path, in: id)
    }

    func files(inLabelNamed name: String) -> [String] {
        registry.files(inLabelNamed: name)
    }

    /// Creates a label at runtime, returning the existing one if the name is
    /// already taken. Returns nil when the name is blank.
    @discardableResult
    func createLabel(named name: String) -> FileLabel? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let label = registry.createLabel(named: trimmed)
        persist()
        return label
    }

    func assign(path: String, to id: FileLabel.ID) {
        registry.assign(path: path, to: id)
        register(path: path)
        persist()
    }

    func remove(path: String, from id: FileLabel.ID) {
        registry.remove(path: path, from: id)
        persist()
    }

    func toggle(path: String, in id: FileLabel.ID) {
        registry.toggle(path: path, in: id)
        if registry.contains(path: path, in: id) {
            register(path: path)
        }
        persist()
    }

    func deleteLabel(id: FileLabel.ID) {
        registry.deleteLabel(id: id)
        persist()
    }

    func renameLabel(id: FileLabel.ID, to name: String) {
        registry.renameLabel(id: id, to: name)
        persist()
    }

    // MARK: - Opened-file registry

    /// Records that a file has been opened by the app.
    func register(path: String) {
        guard !registeredPaths.contains(path) else { return }
        registeredPaths.insert(path, at: 0)
        persist()
    }

    func unregister(path: String) {
        guard registeredPaths.contains(path) else { return }
        registeredPaths.removeAll { $0 == path }
        persist()
    }

    /// Drops a path from every label and from the registry. Called when a file
    /// no longer exists on disk.
    func removeEverywhere(path: String) {
        registry.removeEverywhere(path: path)
        registeredPaths.removeAll { $0 == path }
        persist()
    }

    /// Removes every labeled or registered path whose file is gone.
    func pruneMissingFiles() {
        let exists: (String) -> Bool = { [fileManager] in fileManager.fileExists(atPath: $0) }
        registry.pruneMissingFiles(exists)
        registeredPaths.removeAll { !exists($0) }
        persist()
    }

    // MARK: - Search

    /// Files matching `query` by name, path or label name, sorted by `sort`.
    /// Labeled files and previously opened files are both included.
    func search(query: String, sort: LabelSortOrder) -> [LabeledFile] {
        var files = registry.labeledFiles
        let labeled = Set(files.map(\.path))
        for path in registeredPaths where !labeled.contains(path) {
            files.append(LabeledFile(path: path, labels: []))
        }
        return LabelRegistry.sorted(LabelRegistry.matching(files, query: query), by: sort)
    }

    // MARK: - Persistence

    private func persist() {
        let state = State(registry: registry, registeredPaths: registeredPaths)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try fileManager.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoder.encode(state).write(to: storageURL, options: .atomic)
        } catch {
            // Persistence is best-effort; in-memory state remains authoritative.
        }
    }

    private static func load(from url: URL) -> State {
        let empty = State(registry: LabelRegistry(), registeredPaths: [])
        guard let data = try? Data(contentsOf: url) else { return empty }
        return (try? JSONDecoder().decode(State.self, from: data)) ?? empty
    }
}
