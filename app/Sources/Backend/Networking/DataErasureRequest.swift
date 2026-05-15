import Foundation

/// Builders + outcome handling for the backend leg of the in-app data
/// erasure flow (issue #329). Kept here next to ``APIClient`` so the
/// `URLRequest` template (path, query, method, headers) lives in a single
/// file the contract review can scan against ``openapi.json``.
enum DataErasureRequest {
  /// Path of the cascading account-erasure endpoint. Mirrors the
  /// `DELETE /portfolio` operation declared in ``openapi.json``
  /// (`operationId: delete_portfolio_portfolio_delete`).
  static let path = "/portfolio"

  /// Query-parameter name carrying the calling device's UUID. Matches the
  /// `device_uuid` parameter declared on the OpenAPI operation. The same
  /// UUID is also attached as `X-Device-UUID` by
  /// ``APIClient/makeOutgoingRequest(from:deviceID:appAttestToken:)``;
  /// the spec requires the query parameter as the row selector and the
  /// header as the authenticated identity, so both are populated.
  static let deviceUUIDQueryItem = "device_uuid"

  /// Builds the `DELETE /portfolio?device_uuid={uuid}` request the
  /// Settings → "Erase All My Data" flow issues against the backend
  /// configured by ``APIClient/configuredBaseURL()``. Returns `nil` only
  /// if `baseURL` cannot be combined with the configured path/query —
  /// the live `URL` always supports this, but the optional surface keeps
  /// preview / test stubs from force-unwrapping.
  static func makeURLRequest(baseURL: URL, deviceID: String) -> URLRequest? {
    var components = URLComponents(
      url: baseURL.appendingPathComponent(path),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [URLQueryItem(name: deviceUUIDQueryItem, value: deviceID)]
    guard let url = components?.url else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    return request
  }

  /// HTTP statuses the backend can return on `DELETE /portfolio` that
  /// the client must treat as "erasure completed, proceed to local
  /// wipe". `204` is the documented success status; `404` means the
  /// device has no rows on the backend (no-op success — Apple guideline
  /// §5.1.1(v) does not require the local wipe to be gated on existing
  /// remote state). Every other status is surfaced as an error so the
  /// user can retry without losing local data.
  static func isSuccessfulErasure(statusCode: Int) -> Bool {
    statusCode == 204 || statusCode == 404
  }
}
