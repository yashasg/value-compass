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

  // MARK: - X-App-Attest header (#226) and X-Device-UUID removal (#348)

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
      appAttestToken: "token-abc"
    )

    XCTAssertEqual(outgoing.value(forHTTPHeaderField: "X-App-Attest"), "token-abc")
  }

  func testMakeOutgoingRequestOmitsAppAttestWhenNil() {
    let base = URLRequest(url: URL(string: "https://api.valuecompass.app/health")!)
    let outgoing = APIClient.makeOutgoingRequest(
      from: base,
      appAttestToken: nil
    )

    XCTAssertNil(outgoing.value(forHTTPHeaderField: "X-App-Attest"))
  }

  // Regression for #348: device identity is the `device_uuid` body field
  // (POST /portfolio/holdings) or query parameter (every other protected
  // op); the OpenAPI contract never declares an `X-Device-UUID` header and
  // the FastAPI backend never reads one. `makeOutgoingRequest` must not
  // attach the header — it would be dead bytes that a future server-side
  // change could start reading and silently double-bind the identity.
  func testMakeOutgoingRequestNeverAttachesXDeviceUUIDForProtectedRoute() {
    let base = URLRequest(url: URL(string: "https://api.valuecompass.app/schema/version")!)
    let outgoing = APIClient.makeOutgoingRequest(
      from: base,
      appAttestToken: "token-abc"
    )

    XCTAssertNil(outgoing.value(forHTTPHeaderField: "X-Device-UUID"))
  }

  func testMakeOutgoingRequestNeverAttachesXDeviceUUIDForHealthRoute() {
    let base = URLRequest(url: URL(string: "https://api.valuecompass.app/health")!)
    let outgoing = APIClient.makeOutgoingRequest(
      from: base,
      appAttestToken: nil
    )

    XCTAssertNil(outgoing.value(forHTTPHeaderField: "X-Device-UUID"))
  }

  // Regression for #429: client must not transmit `X-App-Version` because the
  // OpenAPI contract declares only the response-only `X-Min-App-Version`
  // channel and the backend never reads a request app-version header.
  func testMakeOutgoingRequestNeverAttachesXAppVersion() {
    let base = URLRequest(url: URL(string: "https://api.valuecompass.app/schema/version")!)
    let outgoing = APIClient.makeOutgoingRequest(
      from: base,
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
    // Regression for #348: the live transport must not attach an
    // `X-Device-UUID` header — the OpenAPI contract pins device identity to
    // body/query, not a header.
    XCTAssertNil(captured.value(forHTTPHeaderField: "X-Device-UUID"))
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
    // Regression for #348: `/health` carries no device-identity binding on
    // any surface; the historical `X-Device-UUID` attachment was removed.
    XCTAssertNil(captured.value(forHTTPHeaderField: "X-Device-UUID"))
  }

  // MARK: - OpenAPI contract pin (#348)

  // Contract pin: the OpenAPI spec bundled with the app must not declare an
  // `X-Device-UUID` header parameter on any operation. Device identity is
  // pinned to the `device_uuid` body field (POST `/portfolio/holdings`) or
  // query parameter (every other protected op). A regression that re-adds
  // the header on either surface would create a dual undeclared/declared
  // binding (the original drift this test exists to prevent).
  func testOpenAPISpecHasNoXDeviceUUIDHeaderParameter() throws {
    let spec = try Self.loadBundledOpenAPISpec()
    let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

    for (path, methods) in paths {
      guard let methods = methods as? [String: Any] else { continue }
      for (method, operation) in methods {
        guard let operation = operation as? [String: Any],
          let parameters = operation["parameters"] as? [[String: Any]]
        else { continue }
        for parameter in parameters {
          let location = parameter["in"] as? String
          let name = parameter["name"] as? String
          XCTAssertFalse(
            location == "header" && name?.caseInsensitiveCompare("X-Device-UUID") == .orderedSame,
            "Spec declares X-Device-UUID header on \(method.uppercased()) \(path); #348 forbids this — device identity rides in body/query only."
          )
        }
      }
    }
  }

  // Contract pin: every protected operation that needs device identity must
  // declare it via a single canonical surface — either the `device_uuid`
  // query parameter or the `device_uuid` body field. `/health` and
  // `/schema/version` are intentionally device-agnostic (covered elsewhere
  // in the contract; flagged only for awareness in #348).
  func testOpenAPISpecDeclaresDeviceUuidOnProtectedOperations() throws {
    let spec = try Self.loadBundledOpenAPISpec()
    let paths = try XCTUnwrap(spec["paths"] as? [String: Any])

    let expectedDeviceBindings: [String: [String: String]] = [
      "/portfolio/data": ["get": "query"],
      "/portfolio/export": ["get": "query"],
      "/portfolio/holdings": ["post": "body"],
      "/portfolio": ["patch": "query", "delete": "query"],
      "/portfolio/holdings/{ticker}": ["patch": "query", "delete": "query"],
    ]

    for (path, methodBindings) in expectedDeviceBindings {
      let methods = try XCTUnwrap(
        paths[path] as? [String: Any],
        "Spec missing path \(path)"
      )
      for (method, surface) in methodBindings {
        let operation = try XCTUnwrap(
          methods[method] as? [String: Any],
          "Spec missing \(method.uppercased()) \(path)"
        )
        switch surface {
        case "query":
          let parameters = (operation["parameters"] as? [[String: Any]]) ?? []
          let hasDeviceUuidQuery = parameters.contains {
            ($0["in"] as? String) == "query" && ($0["name"] as? String) == "device_uuid"
          }
          XCTAssertTrue(
            hasDeviceUuidQuery,
            "Spec is missing device_uuid query parameter on \(method.uppercased()) \(path)"
          )
        case "body":
          let schemaRef =
            ((operation["requestBody"] as? [String: Any])?["content"] as? [String: Any])?[
              "application/json"
            ]
            .flatMap { $0 as? [String: Any] }?["schema"] as? [String: Any]
          let ref = schemaRef?["$ref"] as? String ?? ""
          XCTAssertTrue(
            ref.hasSuffix("AddHoldingRequest"),
            "Spec body schema for \(method.uppercased()) \(path) is not AddHoldingRequest"
          )
          let components = try XCTUnwrap(spec["components"] as? [String: Any])
          let schemas = try XCTUnwrap(components["schemas"] as? [String: Any])
          let bodySchema = try XCTUnwrap(
            schemas["AddHoldingRequest"] as? [String: Any]
          )
          let properties = try XCTUnwrap(bodySchema["properties"] as? [String: Any])
          XCTAssertNotNil(
            properties["device_uuid"],
            "AddHoldingRequest missing required device_uuid body field"
          )
        default:
          XCTFail("Unknown surface kind \(surface)")
        }
      }
    }
  }

  /// Loads the OpenAPI spec bundled with the host app. The spec ships as a
  /// resource of the main app target (`openapi.json` in
  /// `app/Sources/Backend/Networking/`) so the SwiftOpenAPIGenerator build
  /// plugin can consume it; tests reach it through `Bundle.main` for the
  /// same reason `NavigationShellTests` reaches `icon.svg`.
  private static func loadBundledOpenAPISpec() throws -> [String: Any] {
    let url = try XCTUnwrap(
      Bundle.main.url(forResource: "openapi", withExtension: "json"),
      "openapi.json is missing from the app bundle"
    )
    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    return try XCTUnwrap(json as? [String: Any], "openapi.json is not a JSON object")
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
