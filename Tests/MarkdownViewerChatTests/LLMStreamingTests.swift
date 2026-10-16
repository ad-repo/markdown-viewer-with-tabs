import Foundation
import Testing
@testable import MarkdownViewerChat

/// Delivers a canned HTTP response so `LLMClient.stream` can be exercised
/// without a network.
final class StubURLProtocol: URLProtocol {

    nonisolated(unsafe) static var response: (status: Int, body: String)?
    nonisolated(unsafe) static var recordedRequest: URLRequest?

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.recordedRequest = request
        guard let response = Self.response, let url = request.url,
              let http = HTTPURLResponse(url: url,
                                         statusCode: response.status,
                                         httpVersion: "HTTP/1.1",
                                         headerFields: ["Content-Type": "text/event-stream"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Serialised because the stub's canned response is process-wide state.
@Suite("Chat streaming", .serialized)
struct LLMStreamingTests {

    private func request() -> LLMClient.Request {
        LLMClient.Request(model: "test-model",
                          baseURL: "https://api.openai.com/v1",
                          apiKey: "secret",
                          system: "Be terse.",
                          turns: [.init(role: "user", content: "hi")])
    }

    private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> String {
        var text = ""
        for try await chunk in stream {
            text += chunk
        }
        return text
    }

    @Test("streamed deltas are concatenated in order")
    func streamsDeltas() async throws {
        StubURLProtocol.response = (200, """
        data: {"choices":[{"delta":{"content":"Hel"}}]}

        data: {"choices":[{"delta":{"content":"lo"}}]}

        data: [DONE]

        """)
        defer { StubURLProtocol.response = nil }

        let text = try await collect(LLMClient.stream(request(), session: StubURLProtocol.makeSession()))
        #expect(text == "Hello")
        #expect(StubURLProtocol.recordedRequest?.url?.path == "/v1/chat/completions")
        #expect(StubURLProtocol.recordedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test("the error body's message is raised as the failure")
    func surfacesServerError() async {
        StubURLProtocol.response = (401, #"{"error":{"message":"Invalid API key"}}"#)
        defer { StubURLProtocol.response = nil }

        do {
            _ = try await collect(LLMClient.stream(request(), session: StubURLProtocol.makeSession()))
            Issue.record("expected the stream to fail")
        } catch {
            #expect(error.localizedDescription == "Invalid API key")
        }
    }
}
