import Foundation
import Testing
@testable import Benchd

/// Stubs the network so the client's response handling can be tested exactly,
/// including Sleeper's habit of answering an unknown user with HTTP 200 `null`.
/// `nonisolated` because `URLProtocol`'s overrides are nonisolated, and this
/// target defaults to main-actor isolation.
nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

@Suite(.serialized)
struct SleeperClientTests {

    private func client() -> SleeperClient {
        SleeperClient(session: StubURLProtocol.makeSession())
    }

    private func respond(status: Int, body: String) {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(body.utf8))
        }
    }

    @Test("A known username decodes")
    func knownUser() async throws {
        respond(status: 200, body: """
        {"username":"anshm","user_id":"12345","display_name":"Ansh","avatar":"abc"}
        """)
        let user = try await client().user(username: "anshm")
        #expect(user.userID == "12345")
        #expect(user.bestName == "Ansh")
        #expect(user.avatarURL?.absoluteString == "https://sleepercdn.com/avatars/abc")
    }

    @Test("HTTP 200 with a null body is a missing user, not a decode failure")
    func nullBodyIsNotFound() async {
        respond(status: 200, body: "null")
        await #expect(throws: SleeperError.userNotFound) {
            try await client().user(username: "nobody")
        }
    }

    @Test("HTTP 404 is a missing user")
    func notFoundStatus() async {
        respond(status: 404, body: "")
        await #expect(throws: SleeperError.userNotFound) {
            try await client().user(username: "nobody")
        }
    }

    @Test("A 5xx or 429 reads as a Sleeper outage, not a missing user")
    func outage() async {
        respond(status: 503, body: "")
        await #expect(throws: SleeperError.serviceUnavailable) {
            try await client().user(username: "anshm")
        }
        respond(status: 429, body: "")
        await #expect(throws: SleeperError.serviceUnavailable) {
            try await client().user(username: "anshm")
        }
    }

    @Test("Unparseable JSON does not surface as 'not found'")
    func garbageBody() async {
        respond(status: 200, body: "<html>nope</html>")
        await #expect(throws: SleeperError.unexpectedResponse) {
            try await client().user(username: "anshm")
        }
    }

    @Test("A transport failure reads as a network error")
    func transportFailure() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: SleeperError.network) {
            try await client().user(username: "anshm")
        }
    }

    @Test("A blank username never reaches the network")
    func blankUsername() async {
        StubURLProtocol.handler = { _ in
            Issue.record("Should not have made a request")
            throw URLError(.badURL)
        }
        await #expect(throws: SleeperError.invalidUsername) {
            try await client().user(username: "   ")
        }
    }

    @Test("Usernames are trimmed and a leading @ is dropped")
    func sanitize() {
        #expect(SleeperClient.sanitize("  anshm ") == "anshm")
        #expect(SleeperClient.sanitize("@anshm") == "anshm")
        #expect(SleeperClient.sanitize("@@anshm") == "anshm")
        #expect(SleeperClient.sanitize("") == nil)
        #expect(SleeperClient.sanitize("   ") == nil)
        #expect(SleeperClient.sanitize("@") == nil)
    }
}
