import Foundation
import Testing
@testable import MarkdownViewerKit

@Suite("LabelRegistry")
struct LabelRegistryTests {

    @Test("creating a label returns it and trims the name")
    func createLabel() {
        var registry = LabelRegistry()
        let label = registry.createLabel(named: "  Work  ")
        #expect(label.name == "Work")
        #expect(registry.labels.count == 1)
    }

    @Test("creating a label with an existing name returns the same label")
    func createLabelIsIdempotent() {
        var registry = LabelRegistry()
        let first = registry.createLabel(named: "Work")
        let second = registry.createLabel(named: "work")
        #expect(first.id == second.id)
        #expect(registry.labels.count == 1)
    }

    @Test("labels are created with distinct palette colors")
    func distinctColors() {
        var registry = LabelRegistry()
        let a = registry.createLabel(named: "A")
        let b = registry.createLabel(named: "B")
        #expect(a.colorHex != b.colorHex)
    }

    @Test("assigning and removing paths")
    func assignAndRemove() {
        var registry = LabelRegistry()
        let label = registry.createLabel(named: "Work")
        registry.assign(path: "/tmp/a.md", to: label.id)
        registry.assign(path: "/tmp/a.md", to: label.id) // idempotent
        registry.assign(path: "/tmp/b.md", to: label.id)
        #expect(registry.files(inLabelNamed: "Work") == ["/tmp/a.md", "/tmp/b.md"])
        #expect(registry.contains(path: "/tmp/a.md", in: label.id))

        registry.remove(path: "/tmp/a.md", from: label.id)
        #expect(registry.files(inLabelNamed: "Work") == ["/tmp/b.md"])
        #expect(!registry.contains(path: "/tmp/a.md", in: label.id))
    }

    @Test("toggling membership")
    func toggle() {
        var registry = LabelRegistry()
        let label = registry.createLabel(named: "Work")
        registry.toggle(path: "/tmp/a.md", in: label.id)
        #expect(registry.contains(path: "/tmp/a.md", in: label.id))
        registry.toggle(path: "/tmp/a.md", in: label.id)
        #expect(!registry.contains(path: "/tmp/a.md", in: label.id))
    }

    @Test("removeEverywhere drops a path from every label")
    func removeEverywhere() {
        var registry = LabelRegistry()
        registry.assign(path: "/tmp/a.md", toLabelNamed: "Work")
        registry.assign(path: "/tmp/a.md", toLabelNamed: "Home")
        registry.removeEverywhere(path: "/tmp/a.md")
        #expect(registry.labels.allSatisfy { $0.paths.isEmpty })
    }

    @Test("a file can report all of its labels")
    func labelsContaining() {
        var registry = LabelRegistry()
        registry.assign(path: "/tmp/a.md", toLabelNamed: "Work")
        registry.assign(path: "/tmp/a.md", toLabelNamed: "Home")
        let names = registry.labels(containing: "/tmp/a.md").map(\.name).sorted()
        #expect(names == ["Home", "Work"])
    }

    @Test("labeledFiles groups paths with their label names")
    func labeledFiles() {
        var registry = LabelRegistry()
        registry.assign(path: "/tmp/a.md", toLabelNamed: "Work")
        registry.assign(path: "/tmp/a.md", toLabelNamed: "Home")
        registry.assign(path: "/tmp/b.md", toLabelNamed: "Work")
        let files = registry.labeledFiles.sorted { $0.path < $1.path }
        #expect(files[0].path == "/tmp/a.md")
        #expect(files[0].labels == ["Home", "Work"])
        #expect(files[1].labels == ["Work"])
    }

    @Test("search matches file name, path and label name, case-insensitively")
    func searchMatching() {
        var registry = LabelRegistry()
        registry.assign(path: "/Docs/report.md", toLabelNamed: "Work")
        registry.assign(path: "/Docs/notes.md", toLabelNamed: "Personal")

        #expect(registry.search(query: "REPORT", sort: .fileName).map(\.path) == ["/Docs/report.md"])
        #expect(registry.search(query: "personal", sort: .fileName).map(\.path) == ["/Docs/notes.md"])
        #expect(registry.search(query: "docs", sort: .fileName).count == 2)
        #expect(registry.search(query: "", sort: .fileName).count == 2)
    }

    @Test("results sort by label, file name and path")
    func searchSorting() {
        var registry = LabelRegistry()
        registry.assign(path: "/tmp/zeta.md", toLabelNamed: "Alpha")
        registry.assign(path: "/tmp/alpha.md", toLabelNamed: "Zeta")

        #expect(registry.search(query: "", sort: .label).map(\.path) == ["/tmp/zeta.md", "/tmp/alpha.md"])
        #expect(registry.search(query: "", sort: .fileName).map(\.path) == ["/tmp/alpha.md", "/tmp/zeta.md"])
        #expect(registry.search(query: "", sort: .path).map(\.path) == ["/tmp/alpha.md", "/tmp/zeta.md"])
    }

    @Test("unlabeled files sort after labeled ones when sorting by label")
    func unlabeledSortLast() {
        let files = [
            LabeledFile(path: "/tmp/plain.md", labels: []),
            LabeledFile(path: "/tmp/tagged.md", labels: ["Work"])
        ]
        let sorted = LabelRegistry.sorted(files, by: .label)
        #expect(sorted.first?.path == "/tmp/tagged.md")
    }

    @Test("pruning drops paths whose files are missing")
    func pruning() {
        var registry = LabelRegistry()
        registry.assign(path: "/tmp/keep.md", toLabelNamed: "Work")
        registry.assign(path: "/tmp/gone.md", toLabelNamed: "Work")
        registry.pruneMissingFiles { $0 == "/tmp/keep.md" }
        #expect(registry.files(inLabelNamed: "Work") == ["/tmp/keep.md"])
    }

    @Test("renaming and deleting labels")
    func renameAndDelete() {
        var registry = LabelRegistry()
        let label = registry.createLabel(named: "Work")
        registry.renameLabel(id: label.id, to: "Office")
        #expect(registry.label(id: label.id)?.name == "Office")
        registry.renameLabel(id: label.id, to: "  ")
        #expect(registry.label(id: label.id)?.name == "Office")
        registry.deleteLabel(id: label.id)
        #expect(registry.labels.isEmpty)
    }

    @Test("the registry round-trips through Codable")
    func codable() throws {
        var registry = LabelRegistry()
        registry.assign(path: "/tmp/a.md", toLabelNamed: "Work")
        let data = try JSONEncoder().encode(registry)
        let decoded = try JSONDecoder().decode(LabelRegistry.self, from: data)
        #expect(decoded == registry)
    }
}
