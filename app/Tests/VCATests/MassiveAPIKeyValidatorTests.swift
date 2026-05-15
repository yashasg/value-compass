import XCTest

@testable import VCA

/// Tests for `URLSessionMassiveAPIKeyValidator` (issue #127).
///
/// These exercise the validator end-to-end by stubbing the transport with a
/// custom `URLProtocol`, so no real Massive endpoint is reached and no real
/// Massive key is required.
final class MassiveAPIKeyValidatorTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func makeValidator() -> URLSessionMassiveAPIKeyValidator {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: configuration)
    return URLSessionMassiveAPIKeyValidator(
      session: session,
      baseURL: URL(string: "https://stub.example/")!,
      probePath: "/v1/account",
      timeoutSeconds: 1)
  }

  private func http(_ request: URLRequest, status: Int) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: status,
      httpVersion: "HTTP/1.1",
      headerFields: nil)!
    return (response, Data())
  }

  // MARK: - Tests

  func testEmptyKeyIsRejectedWithoutNetwork() async {
    StubURLProtocol.handler = { _ in
      XCTFail("Network must not be touched for empty key")
      return (HTTPURLResponse(), Data())
    }
    let validator = makeValidator()
    let outcome = await validator.validate(key: "  ")
    XCTAssertEqual(outcome, .invalid(reason: "API key cannot be empty."))
  }

  func test200IsValid() async {
    StubURLProtocol.handler = { request in
      XCTAssertEqual(
        request.value(forHTTPHeaderField: "Authorization"),
        "Bearer placeholder-key")
      XCTAssertEqual(request.url?.absoluteString, "https://stub.example/v1/account")
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil)!
      return (response, Data())
    }
    let validator = makeValidator()
    let outcome = await validator.validate(key: "placeholder-key")
    XCTAssertEqual(outcome, .valid)
  }

  func test401IsInvalid() async {
    StubURLProtocol.handler = { [self] request in http(request, status: 401) }
    let validator = makeValidator()
    let outcome = await validator.validate(key: "placeholder-key")
    XCTAssertEqual(outcome, .invalid(reason: "Massive rejected the API key."))
  }

  func test403IsInvalid() async {
    StubURLProtocol.handler = { [self] request in http(request, status: 403) }
    let validator = makeValidator()
    let outcome = await validator.validate(key: "placeholder-key")
    XCTAssertEqual(outcome, .invalid(reason: "Massive rejected the API key."))
  }

  func test500IsServerError() async {
    StubURLProtocol.handler = { [self] request in http(request, status: 500) }
    let validator = makeValidator()
    let outcome = await validator.validate(key: "placeholder-key")
    XCTAssertEqual(outcome, .serverError(status: 500))
  }

  func testTransportFailureIsNetworkUnavailable() async {
    StubURLProtocol.handler = { _ in
      throw URLError(.notConnectedToInternet)
    }
    let validator = makeValidator()
    let outcome = await validator.validate(key: "placeholder-key")
    if case .networkUnavailable = outcome {
      // Reason text is `URLError.localizedDescription`; we don't pin its
      // exact wording because it varies across iOS versions.
    } else {
      XCTFail("Expected .networkUnavailable, got \(outcome)")
    }
  }
}

/// Custom `URLProtocol` that lets each test inject a per-request handler.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  /// Per-test handler. Set in test methods, cleared in `tearDown`.
  nonisolated(unsafe) static var handler:
    (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = StubURLProtocol.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.unknown))
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
}
