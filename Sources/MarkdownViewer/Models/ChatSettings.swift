import Foundation

/// UserDefaults keys shared by the chat panel's view state.
enum ChatPanel {
    /// Whether the right-hand chat panel is showing.
    static let visibleKey = "chatPanelVisible"
}

/// The chat panel's persisted preferences: the OpenAI-compatible endpoint and
/// model to use, and whether the open document should be sent along with each
/// prompt.
///
/// The endpoint and model are plain user-entered strings — no provider catalogue
/// is baked in — so the panel can point at OpenAI, OpenRouter, a local Ollama
/// server or anything else that speaks the chat completions API.
@MainActor
final class ChatSettings: ObservableObject {

    static let shared = ChatSettings()

    /// The API root requests are appended to. Empty means "use the default".
    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Keys.baseURL) }
    }

    /// The model name sent with each request. Empty means "use the default".
    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    @Published var includeDocument: Bool {
        didSet { defaults.set(includeDocument, forKey: Keys.includeDocument) }
    }

    /// Used when the user has not entered an endpoint.
    static let defaultBaseURL = "https://api.openai.com/v1"
    /// Used when the user has not entered a model.
    static let defaultModel = "gpt-4o-mini"

    private let defaults: UserDefaults

    private enum Keys {
        static let baseURL = "chatBaseURL"
        static let model = "chatModel"
        static let includeDocument = "chatIncludeDocument"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        baseURL = defaults.string(forKey: Keys.baseURL) ?? ""
        model = defaults.string(forKey: Keys.model) ?? ""
        includeDocument = defaults.object(forKey: Keys.includeDocument) as? Bool ?? true
    }

    /// The endpoint the next request will use, falling back to the default when
    /// the field is empty or only whitespace.
    var resolvedBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultBaseURL : trimmed
    }

    /// The model the next request will use, falling back to the default when
    /// the field is empty or only whitespace.
    var resolvedModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultModel : trimmed
    }
}
