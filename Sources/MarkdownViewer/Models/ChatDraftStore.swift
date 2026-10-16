import Foundation

/// The in-progress prompt for each document's chat, kept out of `ChatStore` so
/// typing does not mutate the conversation (and so the command menu, undo, and
/// anything observing the transcript are not disturbed by every keystroke).
@MainActor
final class ChatDraftStore: ObservableObject {

    static let shared = ChatDraftStore()

    @Published private var drafts: [String: String] = [:]

    func draft(for path: String) -> String {
        drafts[path] ?? ""
    }

    func setDraft(_ text: String, for path: String) {
        if text.isEmpty {
            drafts[path] = nil
        } else {
            drafts[path] = text
        }
    }

    func clear(for path: String) {
        drafts[path] = nil
    }
}
