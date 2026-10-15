import Foundation

/// Watches a file for changes.
///
/// Watches both the file's own vnode and its parent directory. Watching the
/// directory catches atomic saves (which replace the file via rename), while
/// watching the file's vnode catches in-place writes. Events are debounced
/// and delivered on the main queue.
final class FileWatcher {

    private let url: URL
    private let onChange: () -> Void
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        addSource(path: url.path, mask: [.write, .extend, .delete, .rename, .attrib])
        addSource(path: url.deletingLastPathComponent().path, mask: [.write, .delete, .rename, .extend])
    }

    private func addSource(path: String, mask: DispatchSource.FileSystemEvent) {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: mask,
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            self?.schedule()
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        sources.append(source)
    }

    private func schedule() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pending?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.onChange() }
            self.pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
        }
    }

    func stop() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        pending?.cancel()
        pending = nil
    }

    deinit {
        sources.forEach { $0.cancel() }
    }
}
