import Foundation

/// A named collection of file pointers. A label is the app's unit of
/// organization: every path it holds points at a Markdown file that may be
/// opened from the label's search results.
public struct FileLabel: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    /// Hex color (e.g. `#3E63DD`) used to render the label as a colored button.
    public var colorHex: String
    /// Absolute paths of the files carrying this label.
    public var paths: [String]

    public init(id: UUID = UUID(), name: String, colorHex: String = LabelPalette.hex(forIndex: 0), paths: [String] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.paths = paths
    }
}

/// A file together with the names of the labels that point at it. Used as a
/// row in label search results.
public struct LabeledFile: Identifiable, Hashable, Sendable {
    public let path: String
    public let labels: [String]

    public init(path: String, labels: [String]) {
        self.path = path
        self.labels = labels
    }

    public var id: String { path }
    public var fileName: String { (path as NSString).lastPathComponent }
    public var displayName: String { (fileName as NSString).deletingPathExtension }
}

/// How label search results (or the open files list) should be ordered.
public enum LabelSortOrder: String, CaseIterable, Identifiable, Sendable {
    case label
    case fileName
    case path

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .label: return "Label"
        case .fileName: return "File Name"
        case .path: return "Path"
        }
    }
}

/// The palette labels draw their colors from. Colors cycle as labels are
/// created so that distinct labels are visually distinguishable.
public enum LabelPalette {
    public static let hexes = [
        "#E5484D", "#F76808", "#FFB224", "#46A758", "#12A594",
        "#0091FF", "#3E63DD", "#8E4EC6", "#D6409F", "#E93D82"
    ]

    public static func hex(forIndex index: Int) -> String {
        guard !hexes.isEmpty else { return "#3E63DD" }
        let normalized = ((index % hexes.count) + hexes.count) % hexes.count
        return hexes[normalized]
    }
}

/// The pure, UI-free label model. Holds the labels and every operation on
/// them; the app's `LabelStore` wraps it with persistence and observation.
public struct LabelRegistry: Codable, Equatable, Sendable {

    public private(set) var labels: [FileLabel]

    public init(labels: [FileLabel] = []) {
        self.labels = labels
    }

    // MARK: - Lookup

    public func label(named name: String) -> FileLabel? {
        labels.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    public func label(id: UUID) -> FileLabel? {
        labels.first { $0.id == id }
    }

    public func contains(path: String, in id: UUID) -> Bool {
        label(id: id)?.paths.contains(path) ?? false
    }

    public func labels(containing path: String) -> [FileLabel] {
        labels.filter { $0.paths.contains(path) }
    }

    public func files(inLabelNamed name: String) -> [String] {
        label(named: name)?.paths ?? []
    }

    // MARK: - Mutation

    /// Creates a label if one with this name does not already exist, returning
    /// the existing or newly created label. Names are trimmed and compared
    /// case-insensitively.
    @discardableResult
    public mutating func createLabel(named name: String) -> FileLabel {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = label(named: trimmed) {
            return existing
        }
        let label = FileLabel(name: trimmed, colorHex: LabelPalette.hex(forIndex: labels.count))
        labels.append(label)
        return label
    }

    @discardableResult
    public mutating func assign(path: String, toLabelNamed name: String) -> FileLabel {
        let label = createLabel(named: name)
        assign(path: path, to: label.id)
        return label
    }

    public mutating func assign(path: String, to id: UUID) {
        guard let index = labels.firstIndex(where: { $0.id == id }) else { return }
        guard !labels[index].paths.contains(path) else { return }
        labels[index].paths.append(path)
    }

    public mutating func remove(path: String, from id: UUID) {
        guard let index = labels.firstIndex(where: { $0.id == id }) else { return }
        labels[index].paths.removeAll { $0 == path }
    }

    /// Adds the path to the label if absent, removes it if present.
    public mutating func toggle(path: String, in id: UUID) {
        guard let index = labels.firstIndex(where: { $0.id == id }) else { return }
        if let pathIndex = labels[index].paths.firstIndex(of: path) {
            labels[index].paths.remove(at: pathIndex)
        } else {
            labels[index].paths.append(path)
        }
    }

    /// Removes a path from every label. Used when a file no longer exists.
    public mutating func removeEverywhere(path: String) {
        for index in labels.indices {
            labels[index].paths.removeAll { $0 == path }
        }
    }

    public mutating func deleteLabel(id: UUID) {
        labels.removeAll { $0.id == id }
    }

    public mutating func renameLabel(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = labels.firstIndex(where: { $0.id == id }) else { return }
        labels[index].name = trimmed
    }

    /// Drops any path for which `exists` returns false.
    public mutating func pruneMissingFiles(_ exists: (String) -> Bool) {
        for index in labels.indices {
            labels[index].paths.removeAll { !exists($0) }
        }
    }

    // MARK: - Search

    /// Every file reachable through a label, paired with the labels holding it.
    public var labeledFiles: [LabeledFile] {
        var labelsByPath: [String: [String]] = [:]
        for label in labels {
            for path in label.paths {
                labelsByPath[path, default: []].append(label.name)
            }
        }
        return labelsByPath.map { LabeledFile(path: $0.key, labels: $0.value.sorted()) }
    }

    public func search(query: String, sort: LabelSortOrder) -> [LabeledFile] {
        LabelRegistry.sorted(LabelRegistry.matching(labeledFiles, query: query), by: sort)
    }

    public static func matching(_ files: [LabeledFile], query: String) -> [LabeledFile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return files }
        return files.filter { file in
            file.path.lowercased().contains(trimmed)
                || file.fileName.lowercased().contains(trimmed)
                || file.labels.contains { $0.lowercased().contains(trimmed) }
        }
    }

    public static func sorted(_ files: [LabeledFile], by sort: LabelSortOrder) -> [LabeledFile] {
        switch sort {
        case .label:
            return files.sorted { lhs, rhs in
                let a = lhs.labels.first?.lowercased() ?? Self.unlabeledKey
                let b = rhs.labels.first?.lowercased() ?? Self.unlabeledKey
                if a != b { return a < b }
                return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
            }
        case .fileName:
            return files.sorted {
                $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending
            }
        case .path:
            return files.sorted {
                $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
            }
        }
    }

    /// Sorts unlabeled files after labeled ones.
    private static let unlabeledKey = "\u{10FFFF}"
}
