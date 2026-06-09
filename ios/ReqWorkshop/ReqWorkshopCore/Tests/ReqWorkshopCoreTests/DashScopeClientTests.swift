import Foundation
import XCTest
@testable import ReqWorkshopCore

final class DashScopeClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.handler = nil
    }

    func testDashScopeClientParsesJSONObjectResponse() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"output":{"text":"{\\"ok\\":true,\\"ideas\\":[\\"电池盖扣合\\"]}"}}
            """.data(using: .utf8)!
            return (response, body)
        }
        let client = DashScopeClient(
            apiKeyProvider: { "test-key" },
            model: "qwen-plus",
            endpoint: URL(string: "https://example.test/qwen")!,
            session: URLSession.mocked
        )

        let json = try await client.generateJSON(system: "system", user: "user", timeoutSeconds: 3)

        XCTAssertEqual(json["ok"] as? Bool, true)
        XCTAssertEqual(json["ideas"] as? [String], ["电池盖扣合"])
    }

    func testDashScopeClientReportsHTTPErrorBody() async throws {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"message":"Invalid API-key provided."}"#.utf8))
        }
        let client = DashScopeClient(
            apiKeyProvider: { "bad-key" },
            model: "qwen-plus",
            endpoint: URL(string: "https://example.test/qwen")!,
            session: URLSession.mocked
        )

        do {
            _ = try await client.generateJSON(system: "system", user: "user", timeoutSeconds: 3)
            XCTFail("Expected HTTP error")
        } catch {
            XCTAssertTrue(String(describing: error).contains("Invalid API-key provided."))
        }
    }
}

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLSession {
    static var mocked: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
