import Foundation

/// Thin wrapper around `URLSession` for talking to the value-compass backend.
///
/// Responsibilities:
/// - Uses HTTP/2 by default (URLSession negotiates this automatically over TLS).
/// - Attaches the device UUID and current app version on every request so the
///   backend can identify the install and decide whether to emit
///   `X-Min-App-Version`.
/// - Attaches the `X-App-Attest` header on every request so protected backend
///   routes do not reject the call with `401 appAttestMissing` (issue #226).
///   The header value is supplied by `attestationTokenProvider`; production
///   callers default to `DeviceIDProvider.deviceID()` because the FastAPI
///   service only checks that the header is present and non-empty
///   (`backend/api/main.py:require_app_attest`) and Cloudflare performs the
///   real cryptographic attestation in front of the service. Wiring
///   `DCAppAttestService` is a future swap behind this single closure.
/// - Forwards every response to `MinAppVersionClient.observe(response:)` so
///   the forced-update screen can be triggered. Phase 2 (#158) replaced the
///   former `MinAppVersionMonitor.shared` singleton with this client-static
///   bridge.
///
/// The generated SwiftOpenAPIGenerator client is configured to use this
/// session as its underlying transport — see `Sources/Backend/Networking/openapi-generator-config.yaml`
/// and the generated `Client` type that's produced at build time.
final class APIClient {
  static let shared = APIClient()
  private static let fallbackBaseURL = URL(string: "https://api.valuecompass.app")!

  let session: URLSession
  let baseURL: URL
  private let attestationTokenProvider: @Sendable () async throws -> String

  init(
    baseURL: URL = APIClient.configuredBaseURL(),
    session: URLSession? = nil,
    attestationTokenProvider: @escaping @Sendable () async throws -> String =
      APIClient.defaultAttestationTokenProvider
  ) {
    self.baseURL = baseURL
    self.attestationTokenProvider = attestationTokenProvider
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

  /// Default placeholder attestation provider. Returns the persisted
  /// device UUID, which the FastAPI backend accepts as a non-empty
  /// header value while Cloudflare handles real attestation in
  /// production. Replace by passing a different
  /// `attestationTokenProvider` closure to a non-shared `APIClient`
  /// (e.g. when the `DCAppAttestService` flow is wired).
  static let defaultAttestationTokenProvider: @Sendable () async throws -> String = {
    DeviceIDProvider.deviceID()
  }

  enum APIError: Error {
    case nonHTTPResponse
  }

  /// Sends a request and returns `(Data, HTTPURLResponse)`. Every response
  /// is funneled through `MinAppVersionClient.observe` before being returned
  /// to the caller, regardless of HTTP status, so a 4xx with a min-version
  /// header still triggers the forced-update flow.
  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    var req = request
    req.setValue(DeviceIDProvider.deviceID(), forHTTPHeaderField: "X-Device-UUID")
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
      req.setValue(version, forHTTPHeaderField: "X-App-Version")
    }
    let attestationToken = try await attestationTokenProvider()
    req.setValue(attestationToken, forHTTPHeaderField: "X-App-Attest")

    let (data, response) = try await session.data(for: req)
    guard let http = response as? HTTPURLResponse else {
      throw APIError.nonHTTPResponse
    }
    MinAppVersionClient.observe(response: http)
    return (data, http)
  }
}
