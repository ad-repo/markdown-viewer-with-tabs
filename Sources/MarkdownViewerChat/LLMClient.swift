import Foundation

/// Streams chat completions from any OpenAI-compatible endpoint.
///
/// The client is deliberately small and provider-agnostic: the caller supplies
/// the base URL, model and key, and the request is shaped like OpenAI's chat
/// completions API (which OpenRouter, Groq, Ollama, LM Studio and others copy).
/// It yields the reply text as it arrives over server-sent events, so the chat
/// panel can render a reply while it is still being written.
public enum LLMClient {

    /// One turn of the conversation, in the shape the chat completions API accepts.
    public struct Turn: Sendable, Equatable {
        /// `user` or `assistant`.
        public let role: String
        public let content: String

        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }

    /// Merges runs of turns that share a role into a single turn, joining their
    /// content with a blank line.
    ///
    /// A chat transcript can develop such a run whenever a reply never arrives —
    /// a failed request or a reply the user stopped before any text streamed in
    /// — leaving two user prompts adjacent. Some servers reject that shape, so
    /// normalizing here keeps the history well-formed.
    public static func coalescing(_ turns: [Turn]) -> [Turn] {
        var result: [Turn] = []
        for turn in turns {
            if let last = result.last, last.role == turn.role {
                result[result.count - 1] = Turn(role: turn.role,
                                                content: last.content + "\n\n" + turn.content)
            } else {
                result.append(turn)
            }
        }
        return result
    }

    /// Everything needed to run one completion.
    public struct Request: Sendable {
        public let model: String
        public let baseURL: String
        public let apiKey: String
        public let system: String?
        public let turns: [Turn]

        public init(model: String, baseURL: String, apiKey: String, system: String?, turns: [Turn]) {
            self.model = model
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.system = system
            self.turns = turns
        }
    }

    public enum ClientError: LocalizedError {
        case invalidURL
        case invalidResponse
        case http(status: Int, message: String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The API base URL is not a valid URL. Check it in Settings."
            case .invalidResponse:
                return "The server sent a response the app could not read."
            case .http(_, let message):
                return message
            }
        }
    }

    /// Sends the request and yields the assistant's reply as it streams in.
    ///
    /// Cancelling the consuming task cancels the underlying request, so the
    /// chat panel's stop button simply cancels its `Task`. `session` is
    /// injectable so tests can stub the transport.
    public static func stream(_ request: Request,
                              session: URLSession = .shared) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(request, session: session) { chunk in
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func run(_ request: Request,
                            session: URLSession,
                            onChunk: @Sendable (String) -> Void) async throws {
        let urlRequest = try makeURLRequest(request)
        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(status: http.statusCode,
                                   message: await serverMessage(from: bytes, status: http.statusCode))
        }

        var parser = SSEParser()
        for try await line in bytes.lines {
            for chunk in parser.feed(line: line) {
                onChunk(chunk)
            }
        }
    }

    // MARK: - Request building

    static func makeURLRequest(_ request: Request) throws -> URLRequest {
        let base = request.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: "\(base)/chat/completions") else { throw ClientError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if !request.apiKey.isEmpty {
            urlRequest.setValue("Bearer \(request.apiKey)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body(for: request))
        return urlRequest
    }

    static func body(for request: Request) -> [String: Any] {
        var messages: [[String: Any]] = []
        if let system = request.system, !system.isEmpty {
            messages.append(["role": "system", "content": system])
        }
        messages.append(contentsOf: request.turns.map { ["role": $0.role, "content": $0.content] })
        return [
            "model": request.model,
            "stream": true,
            "messages": messages
        ]
    }

    // MARK: - Errors

    /// Pulls the human-readable message out of an error body, falling back to
    /// the raw text and then to the status code.
    private static func serverMessage(from bytes: URLSession.AsyncBytes,
                                      status: Int) async -> String {
        var raw = Data()
        do {
            for try await byte in bytes {
                if raw.count >= 4000 { break }
                raw.append(byte)
            }
        } catch {
            // Whatever arrived before the failure is still worth reporting.
        }
        let body = String(data: raw, encoding: .utf8) ?? ""

        if let data = body.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            if let message = object["error"] as? String { return message }
            if let message = object["message"] as? String { return message }
        }

        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Request failed (HTTP \(status))" : String(trimmed.prefix(300))
    }
}

/// Minimal server-sent-events decoder for OpenAI-style chat completions.
///
/// Events are decoded per `data:` line rather than when the blank line that
/// ends an event arrives: `URLSession.AsyncBytes.lines` swallows empty lines,
/// so a blank-line-delimited parser would never emit anything over the wire.
/// A payload genuinely split across several `data:` lines still works — the
/// fragments accumulate until the JSON parses.
public struct SSEParser {
    private var pending = ""

    /// Longest a split payload may grow before it is discarded as garbage.
    private static let pendingLimit = 200_000

    public init() {}

    /// Feeds one line of the stream and returns any reply text it completes.
    public mutating func feed(line: String) -> [String] {
        let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line

        if trimmed.isEmpty {
            pending = ""
            return []
        }
        // `event:`/`id:`/comment lines carry nothing we need.
        guard trimmed.hasPrefix("data:") else { return [] }

        var value = trimmed.dropFirst("data:".count)
        if value.hasPrefix(" ") { value = value.dropFirst() }
        let fragment = String(value)

        if fragment == "[DONE]" {
            pending = ""
            return []
        }

        if pending.isEmpty {
            if let chunks = decode(fragment) { return chunks }
            // Keep a fragment that could be the start of a split event; drop
            // anything that is not even the start of a JSON object.
            guard fragment.hasPrefix("{") else { return [] }
            pending = fragment
            return []
        }

        pending += fragment
        guard pending.count <= Self.pendingLimit else {
            pending = ""
            return []
        }
        if let chunks = decode(pending) {
            pending = ""
            return chunks
        }
        return []
    }

    private func decode(_ event: String) -> [String]? {
        guard !event.isEmpty,
              let data = event.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let choices = object["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty else { return [] }
        return [content]
    }
}
