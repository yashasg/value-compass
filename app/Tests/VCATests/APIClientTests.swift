import XCTest

@testable import VCA

final class APIClientTests: XCTestCase {
  func testConfiguredBaseURLUsesInfoDictionaryValue() {
    let url = APIClient.configuredBaseURL(infoDictionary: [
      "VCAAPIBaseURL": "https://services.example.com"
    ])

    XCTAssertEqual(url.absoluteString, "https://services.example.com")
  }

  func testConfiguredBaseURLFallsBackWhenInfoDictionaryValueIsEmpty() {
    let url = APIClient.configuredBaseURL(infoDictionary: [
      "VCAAPIBaseURL": "  "
    ])

    XCTAssertEqual(url.absoluteString, "https://api.valuecompass.app")
  }

  // MARK: - X-App-Attest header (#226)

  func testAppAttestRequiredIsTrueForProtectedRoutes() {
    let protectedPaths = [
      "/schema/version",
      "/portfolio/status",
      "/portfolio/data",
      "/portfolio/holdings",
    ]

    for path in protectedPaths {
      let request = URLRequest(url: URL(string: "https://api.valuecompass.app\(path)")!)
      XCTAssertTrue(
        APIClient.appAttestRequired(for: request),
        "Expected attest required for \(path)"
      )
    }
  }

  func testAppAttestRequiredIsFalseForUnauthenticatedHealthEndpoint() {
    let request = URLRequest(url: URL(string: "https://api.valuecompass.app/health")!)
    XCTAssertFalse(APIClient.appAttestRequired(for: request))
  }

  func testMakeOutgoingRequestAttachesXAppAttestWhenTokenProvided() {
    let base = URLRequest(url: URL(string: "https://api.valuecompass.app/schema/version")!)
    let outgoing = APIClient.makeOutgoingRequest(
      from: base,
      deviceID: "device-1",
      appAttestToken: "token-abc"
    )

    XCTAssertEqual(outgoing.value(forHTTPHeaderField: "X-Device-UUID"), "device-1")
    XCTAssertEqual(outgoing.value(forHTTPHeaderField: "X-App-Attest"), "token-abc")
  }

  func testMakeOutgoingRequestOmitsAppAttestWhenNil() {
    let base = URLRequest(url: URL(string: "https://api.valuecompass.app/health")!)
    let outgoing = APIClient.makeOutgoingRequest(
      from: base,
      deviceID: "device-1",
      appAttestToken: nil
    )

    XCTAssertEqual(outgoing.value(forHTTPHeaderField: "X-Device-UUID"), "device-1")
    XCTAssertNil(outgoing.value(forHTTPHeaderField: "X-App-Attest"))
  }

  // Regression for #429: client must not transmit `X-App-Version` because the
  // OpenAPI contract declares only the response-only `X-Min-App-Version`
  // channel and the backend never reads a request app-version header.
  func testMakeOutgoingRequestNeverAttachesXAppVersion() {
    let base = URLRequest(url: URL(string: "https://api.valuecompass.app/schema/version")!)
    let outgoing = APIClient.makeOutgoingRequest(
      from: base,
      deviceID: "device-1",
      appAttestToken: "token-abc"
    )

    XCTAssertNil(outgoing.value(forHTTPHeaderField: "X-App-Version"))
  }

  func testSendDoesNotAttachXAppVersionThroughLiveTransport() async throws {
    HeaderCapturingURLProtocol.reset()
    HeaderCapturingURLProtocol.stubbedStatusCode = 200

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [HeaderCapturingURLProtocol.self]
    let session = URLSession(configuration: config)

    let client = APIClient(
      baseURL: URL(string: "https://api.valuecompass.app")!,
      session: session
    )
    let request = URLRequest(
      url: URL(string: "https://api.valuecompass.app/schema/version")!
    )

    _ = try await client.send(request)

    let captured = try XCTUnwrap(HeaderCapturingURLProtocol.lastRequest)
    XCTAssertNil(captured.value(forHTTPHeaderField: "X-App-Version"))
  }

  func testAppAttestProviderUsesInfoDictionaryValueWhenPresent() {
    let token = AppAttestProvider.currentToken(infoDictionary: [
      AppAttestProvider.infoDictionaryKey: "  staging-token  "
    ])

    XCTAssertEqual(token, "staging-token")
  }

  func testAppAttestProviderFallsBackToPlaceholderWhenInfoDictionaryEmpty() {
    let missing = AppAttestProvider.currentToken(infoDictionary: [:])
    let blank = AppAttestProvider.currentToken(infoDictionary: [
      AppAttestProvider.infoDictionaryKey: "   "
    ])

    XCTAssertEqual(missing, AppAttestProvider.mvpPlaceholderToken)
    XCTAssertEqual(blank, AppAttestProvider.mvpPlaceholderToken)
  }

  func testSendAttachesXAppAttestHeaderForProtectedRouteThroughLiveTransport() async throws {
    HeaderCapturingURLProtocol.reset()
    HeaderCapturingURLProtocol.stubbedStatusCode = 200

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [HeaderCapturingURLProtocol.self]
    let session = URLSession(configuration: config)

    let client = APIClient(
      baseURL: URL(string: "https://api.valuecompass.app")!,
      session: session
    )
    let request = URLRequest(
      url: URL(string: "https://api.valuecompass.app/schema/version")!
    )

    _ = try await client.send(request)

    let captured = try XCTUnwrap(HeaderCapturingURLProtocol.lastRequest)
    XCTAssertEqual(
      captured.value(forHTTPHeaderField: "X-App-Attest"),
      AppAttestProvider.currentToken()
    )
    XCTAssertNotNil(captured.value(forHTTPHeaderField: "X-Device-UUID"))
  }

  func testSendOmitsXAppAttestHeaderForHealthRouteThroughLiveTransport() async throws {
    HeaderCapturingURLProtocol.reset()
    HeaderCapturingURLProtocol.stubbedStatusCode = 200

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [HeaderCapturingURLProtocol.self]
    let session = URLSession(configuration: config)

    let client = APIClient(
      baseURL: URL(string: "https://api.valuecompass.app")!,
      session: session
    )
    let request = URLRequest(
      url: URL(string: "https://api.valuecompass.app/health")!
    )

    _ = try await client.send(request)

    let captured = try XCTUnwrap(HeaderCapturingURLProtocol.lastRequest)
    XCTAssertNil(captured.value(forHTTPHeaderField: "X-App-Attest"))
    XCTAssertNotNil(captured.value(forHTTPHeaderField: "X-Device-UUID"))
  }
}

/// In-process URLProtocol stub. Captures the most recent outbound request so
/// tests can assert on the headers the live `APIClient.send` attaches before
/// the request would have hit the network. Returns an empty 200 response.
private final class HeaderCapturingURLProtocol: URLProtocol {
  nonisolated(unsafe) static var lastRequest: URLRequest?
  nonisolated(unsafe) static var stubbedStatusCode: Int = 200

  static func reset() {
    lastRequest = nil
    stubbedStatusCode = 200
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.lastRequest = request
    let response = HTTPURLResponse(
      url: request.url ?? URL(string: "https://example.com")!,
      statusCode: Self.stubbedStatusCode,
      httpVersion: "HTTP/1.1",
      headerFields: nil
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data())
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
