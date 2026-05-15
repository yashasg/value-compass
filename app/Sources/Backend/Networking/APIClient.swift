import Foundation

/// Thin wrapper around `URLSession` for talking to the value-compass backend.
///
/// Responsibilities:
/// - Uses HTTP/2 by default (URLSession negotiates this automatically over TLS).
/// - Attaches the device UUID on every request so the backend can identify
///   the install without requiring an account.
/// - Attaches the `X-App-Attest` header on every request that targets a
///   protected backend route (everything except `/health`) so the
///   `require_app_attest` dependency in `backend/api/main.py` does not
///   reject calls with `401 appAttestMissing`. The token value comes from
///   `AppAttestProvider.currentToken()` — see that type for the MVP
///   placeholder vs. real `DCAppAttestService` plan.
/// - Forwards every response to `MinAppVersionClient.observe(response:)` so
///   the forced-update screen can be triggered. The backend signals the
///   minimum supported build via the response-only `X-Min-App-Version`
///   header (declared in `openapi.json`); the client does not transmit its
///   own build version because the backend does not negotiate on it.
///   Phase 2 (#158) replaced the former `MinAppVersionMonitor.shared`
///   singleton with this client-static bridge.
///
/// The generated SwiftOpenAPIGenerator client is configured to use this
/// session as its underlying transport — see `Sources/Backend/Networking/openapi-generator-config.yaml`
/// and the generated `Client` type that's produced at build time.
final class APIClient {
  static let shared = APIClient()
  private static let fallbackBaseURL = URL(string: "https://api.valuecompass.app")!

  let session: URLSession
  let baseURL: URL

  init(
    baseURL: URL = APIClient.configuredBaseURL(),
    session: URLSession? = nil
  ) {
    self.baseURL = baseURL
    if let session {
      self.session = session
    } else {
      let config = URLSessionConfiguration.default
      // URLSession negotiates HTTP/2 automatically over TLS; no flag needed.
      config.waitsForConnectivity = true
      config.timeoutIntervalForRequest = 30
      self.session = URLSession(configuration: config)
    }
  }

  static func configuredBaseURL(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:])
    -> URL
  {
    guard let rawValue = infoDictionary["VCAAPIBaseURL"] as? String else {
      return fallbackBaseURL
    }

    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
      return fallbackBaseURL
    }

    guard let url = URL(string: value),
      let scheme = url.scheme,
      !scheme.isEmpty,
      url.host != nil
    else {
      preconditionFailure("Invalid VCAAPIBaseURL value: \(value)")
    }

    return url
  }

  enum APIError: Error {
    case nonHTTPResponse
  }

  /// Path of the only public backend endpoint that does NOT require an
  /// `X-App-Attest` header. Mirrors the explicit opt-out documented in
  /// `backend/api/main.py:require_app_attest`.
  static let unauthenticatedHealthPath = "/health"

  /// Returns `true` when the supplied request targets a backend route that
  /// requires the `X-App-Attest` header. Returns `false` for the
  /// unauthenticated `/health` endpoint and for requests whose URL does not
  /// expose a path (which never reach the backend, but fail-open here so
  /// `URLSession` surfaces the underlying error instead of a header that
  /// would never be read).
  static func appAttestRequired(for request: URLRequest) -> Bool {
    guard let path = request.url?.path, !path.isEmpty else { return false }
    return path != unauthenticatedHealthPath
  }

  /// Returns a copy of `request` with the standard backend headers applied.
  /// Pulled out of `send(_:)` so reducers and tests can verify exactly which
  /// headers the live transport attaches without spinning up a real
  /// `URLSession`.
  ///
  /// Note: the client does not attach `X-App-Version`. Version negotiation
  /// is server-driven via the response-only `X-Min-App-Version` header
  /// (`MinAppVersionClient.observe(response:)`); there is no request-side
  /// app-version channel in the OpenAPI contract. See issue #429.
  static func makeOutgoingRequest(
    from request: URLRequest,
    deviceID: String,
    appAttestToken: String?
  ) -> URLRequest {
    var req = request
    req.setValue(deviceID, forHTTPHeaderField: "X-Device-UUID")
    if let appAttestToken {
      req.setValue(appAttestToken, forHTTPHeaderField: "X-App-Attest")
    }
    return req
  }

  /// Sends a request and returns `(Data, HTTPURLResponse)`. Every response
  /// is funneled through `MinAppVersionClient.observe` before being returned
  /// to the caller, regardless of HTTP status, so a 4xx with a min-version
  /// header still triggers the forced-update flow.
  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let appAttestToken: String? =
      Self.appAttestRequired(for: request) ? AppAttestProvider.currentToken() : nil
    let req = Self.makeOutgoingRequest(
      from: request,
      deviceID: DeviceIDProvider.deviceID(),
      appAttestToken: appAttestToken
    )

    let (data, response) = try await session.data(for: req)
    guard let http = response as? HTTPURLResponse else {
      throw APIError.nonHTTPResponse
    }
    MinAppVersionClient.observe(response: http)
    return (data, http)
  }
}
