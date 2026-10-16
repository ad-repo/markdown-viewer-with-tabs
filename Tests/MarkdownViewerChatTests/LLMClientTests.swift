import Foundation
import Testing
@testable import MarkdownViewerChat

@Suite("SSE parsing")
struct SSEParserTests {

    private func collect(_ lines: [String]) -> [String] {
        var parser = SSEParser()
        return lines.flatMap { parser.feed(line: $0) }
    }

    @Test("deltas are decoded per event")
    func deltas() {
        let chunks = collect([
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}",
            "",
            "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}",
            "",
            "data: [DONE]",
            ""
        ])

        #expect(chunks == ["Hello", " world"])
    }

    @Test("events decode even when the blank separator lines are missing")
    func eventsWithoutBlankLines() {
        // `URLSession.AsyncBytes.lines` drops empty lines, so this is what the
        // parser actually sees on the wire.
        let chunks = collect([
            "data: {\"choices\":[{\"delta\":{\"content\":\"a\"}}]}",
            "data: {\"choices\":[{\"delta\":{\"content\":\"b\"}}]}",
            "data: [DONE]"
        ])

        #expect(chunks == ["a", "b"])
    }

    @Test("carriage returns are tolerated")
    func carriageReturns() {
        let chunks = collect([
            "data: {\"choices\":[{\"delta\":{\"content\":\"crlf\"}}]}\r",
            "\r"
        ])

        #expect(chunks == ["crlf"])
    }

    @Test("role-only and finish events yield nothing")
    func ignoresNonTextEvents() {
        let chunks = collect([
            "data: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}",
            "",
            "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}",
            "",
            "data: {\"choices\":[],\"usage\":{\"total_tokens\":12}}",
            ""
        ])

        #expect(chunks.isEmpty)
    }

    @Test("an event split over several data lines is joined before decoding")
    func multiLineEvent() {
        let chunks = collect([
            "data: {\"choices\":[{\"delta\":",
            "data: {\"content\":\"split\"}}]}",
            ""
        ])

        #expect(chunks == ["split"])
    }

    @Test("comments and malformed payloads are skipped")
    func malformedPayloads() {
        let chunks = collect([
            ": keep-alive comment",
            "data: not json",
            "",
            "garbage"
        ])

        #expect(chunks.isEmpty)
    }
}

@Suite("Turn coalescing")
struct LLMCoalescingTests {

    private func turn(_ role: String, _ content: String) -> LLMClient.Turn {
        LLMClient.Turn(role: role, content: content)
    }

    @Test("alternating turns are left untouched")
    func alreadyAlternating() {
        let turns = [turn("user", "hi"), turn("assistant", "hello"), turn("user", "again")]
        #expect(LLMClient.coalescing(turns) == turns)
    }

    @Test("consecutive user turns are merged so the history stays well-formed")
    func consecutiveUserTurns() {
        // This is the state left behind when a send fails before any reply
        // streams in and the user immediately retries.
        let merged = LLMClient.coalescing([turn("user", "hi"), turn("user", "again")])

        #expect(merged == [turn("user", "hi\n\nagain")])
    }

    @Test("consecutive assistant turns are merged too")
    func consecutiveAssistantTurns() {
        let merged = LLMClient.coalescing([
            turn("user", "hi"),
            turn("assistant", "one"),
            turn("assistant", "two")
        ])

        #expect(merged == [turn("user", "hi"), turn("assistant", "one\n\ntwo")])
    }

    @Test("an empty history stays empty")
    func emptyHistory() {
        #expect(LLMClient.coalescing([]).isEmpty)
    }
}

@Suite("Chat requests")
struct LLMRequestTests {

    private func request() -> LLMClient.Request {
        LLMClient.Request(
            model: "test-model",
            baseURL: "https://api.openai.com/v1",
            apiKey: "secret-key",
            system: "Be terse.",
            turns: [
                .init(role: "user", content: "hi"),
                .init(role: "assistant", content: "hello"),
                .init(role: "user", content: "again")
            ]
        )
    }

    private func jsonBody(_ request: LLMClient.Request) throws -> [String: Any] {
        let urlRequest = try LLMClient.makeURLRequest(request)
        let body = try #require(urlRequest.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test("requests hit chat/completions with a bearer token")
    func hitsChatCompletions() throws {
        let built = try LLMClient.makeURLRequest(request())

        #expect(built.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(built.value(forHTTPHeaderField: "Authorization") == "Bearer secret-key")
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("requests lead with the system message and stream")
    func leadsWithSystemMessage() throws {
        let body = try jsonBody(request())
        let messages = try #require(body["messages"] as? [[String: Any]])

        #expect(body["model"] as? String == "test-model")
        #expect(body["stream"] as? Bool == true)
        #expect(messages.count == 4)
        #expect(messages.first?["role"] as? String == "system")
        #expect(messages.first?["content"] as? String == "Be terse.")
        #expect(messages.last?["content"] as? String == "again")
    }

    @Test("an empty key omits the Authorization header")
    func noKeyNoAuthHeader() throws {
        let local = LLMClient.Request(
            model: "llama3.1",
            baseURL: "http://localhost:11434/v1",
            apiKey: "",
            system: nil,
            turns: [.init(role: "user", content: "hi")]
        )
        let built = try LLMClient.makeURLRequest(local)

        #expect(built.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("a trailing slash on the base URL does not double up")
    func baseURLTrailingSlash() throws {
        let local = LLMClient.Request(
            model: "llama3.1",
            baseURL: "http://localhost:11434/v1/",
            apiKey: "",
            system: nil,
            turns: [.init(role: "user", content: "hi")]
        )
        let built = try LLMClient.makeURLRequest(local)

        #expect(built.url?.absoluteString == "http://localhost:11434/v1/chat/completions")
    }

    @Test("an unparseable base URL is reported, not crashed on")
    func invalidBaseURL() {
        let broken = LLMClient.Request(model: "m",
                                       baseURL: "http://exa mple.com",
                                       apiKey: "",
                                       system: nil,
                                       turns: [])
        #expect(throws: LLMClient.ClientError.self) {
            try LLMClient.makeURLRequest(broken)
        }
    }
}
