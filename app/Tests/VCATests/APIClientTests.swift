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
}

/// Regression coverage for issue #226: the shared API transport must
/// inject `X-App-Attest` on every request so protected backend routes
/// don't fail with `401 appAttestMissing`.
final class APIClientAppAttestTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  func testSendInjectsAppAttestHeaderFromProvider() async throws {
    let captured = LockBox<URLRequest?>(nil)
    StubURLProtocol.handler = { request in
      captured.value = request
      return Self.ok(request)
    }

    let client = Self.makeClient(token: "stub-token")
    let request = URLRequest(url: URL(string: "https://stub.example/protected")!)
    _ = try await client.send(request)

    let observed = captured.value
    XCTAssertEqual(observed?.value(forHTTPHeaderField: "X-App-Attest"), "stub-token")
  }

  func testSendInvokesAttestProviderOnEveryRequest() async throws {
    let observedTokens = LockBox<[String]>([])
    StubURLProtocol.handler = { request in
      if let header = request.value(forHTTPHeaderField: "X-App-Attest") {
        observedTokens.mutate { $0.append(header) }
      }
      return Self.ok(request)
    }

    let nextTokens = LockBox<[String]>(["token-1", "token-2", "token-3"])
    let client = Self.makeClient {
      var current = ""
      nextTokens.mutate { queue in
        current = queue.isEmpty ? "fallback" : queue.removeFirst()
      }
      return current
    }
    let url = URL(string: "https://stub.example/protected")!
    _ = try await client.send(URLRequest(url: url))
    _ = try await client.send(URLRequest(url: url))
    _ = try await client.send(URLRequest(url: url))

    XCTAssertEqual(observedTokens.value, ["token-1", "token-2", "token-3"])
  }

  func testSendOverridesCallerSuppliedAppAttestHeader() async throws {
    let captured = LockBox<URLRequest?>(nil)
    StubURLProtocol.handler = { request in
      captured.value = request
      return Self.ok(request)
    }

    let client = Self.makeClient(token: "transport-supplied")
    var request = URLRequest(url: URL(string: "https://stub.example/protected")!)
    request.setValue("caller-supplied", forHTTPHeaderField: "X-App-Attest")
    _ = try await client.send(request)

    XCTAssertEqual(
      captured.value?.value(forHTTPHeaderField: "X-App-Attest"),
      "transport-supplied",
      "The transport must own X-App-Attest so callers can never accidentally bypass attestation."
    )
  }

  func testSendPropagatesAttestProviderError() async {
    StubURLProtocol.handler = { _ in
      XCTFail("Network must not be reached when the attest provider throws.")
      throw URLError(.unknown)
    }

    struct ProviderFailure: Error, Equatable {}

    let client = Self.makeClient { throw ProviderFailure() }
    let request = URLRequest(url: URL(string: "https://stub.example/protected")!)
    do {
      _ = try await client.send(request)
      XCTFail("Expected provider failure to propagate.")
    } catch is ProviderFailure {
      // Expected
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testDefaultAttestationTokenProviderReturnsNonEmptyToken() async throws {
    let token = try await APIClient.defaultAttestationTokenProvider()
    XCTAssertFalse(token.isEmpty, "Default attestation provider must return a non-empty token.")
  }

  // MARK: - Helpers

  private static func makeStubSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  private static func makeClient(token: String) -> APIClient {
    APIClient(
      baseURL: URL(string: "https://stub.example/")!,
      session: makeStubSession(),
      attestationTokenProvider: { token }
    )
  }

  private static func makeClient(
    _ provider: @escaping @Sendable () async throws -> String
  ) -> APIClient {
    APIClient(
      baseURL: URL(string: "https://stub.example/")!,
      session: makeStubSession(),
      attestationTokenProvider: provider
    )
  }

  private static func ok(_ request: URLRequest) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: "HTTP/1.1",
      headerFields: nil)!
    return (response, Data())
  }
}

/// Minimal mutable lock box for use inside `@Sendable` test handlers.
/// Avoids pulling in TCA's `LockIsolated` so this test file does not
/// depend on the ComposableArchitecture import.
private final class LockBox<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  init(_ value: Value) { self._value = value }

  var value: Value {
    get { lock.lock(); defer { lock.unlock() }; return _value }
    set { lock.lock(); defer { lock.unlock() }; _value = newValue }
  }

  func mutate(_ transform: (inout Value) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    transform(&_value)
  }
}
