import ComposableArchitecture
import Foundation

/// Outcome of issuing `DELETE /portfolio?device_uuid=<X-Device-UUID>` for the
/// "Erase All My Data" flow (issue #329).
///
/// The backend honors GDPR Art. 17 / CCPA §1798.105 by removing the calling
/// device's `Portfolio` row and every cascaded `Holding`. The endpoint
/// returns `204 No Content` on success and `404 portfolioNotFound` when the
/// device never synced a portfolio. Both are surfaced as `.success` here
/// because a 404 means "no server-side rows exist" — the user-visible
/// guarantee ("nothing left on the backend") already holds. Treating 404 as
/// success also means the local-cleanup follow-up still runs for users who
/// hit Erase before the dormant sync transport ever lights up.
enum AccountErasureOutcome: Equatable, Sendable {
  /// Backend confirmed the row was deleted, or never had one (204 / 404).
  case success
  /// The DELETE request failed before reaching a status code (transport,
  /// DNS, timeout). Local cleanup is **not** performed so the user can
  /// retry once connectivity returns.
  case networkUnavailable(reason: String)
  /// Backend returned a non-success / non-404 status (any other 4xx/5xx).
  /// Local cleanup is **not** performed — the server still has rows.
  case serverError(status: Int)

  var isSuccess: Bool {
    if case .success = self { return true }
    return false
  }
}

/// Builds the `URLRequest` that erases the calling device's portfolio.
///
/// Kept separate from `AccountErasureClient.liveValue` so reducer tests can
/// assert on the URL/method/query-string the request would carry without
/// spinning up a real `URLSession`. The `X-Device-UUID` and `X-App-Attest`
/// headers are attached by the shared `APIClient.send` transport at dispatch
/// time — this builder only owns the path, the method, and the
/// `device_uuid` query parameter that the backend uses as its row selector.
enum AccountErasureRequestFactory {
  /// Path component that the backend mounts the `DELETE /portfolio` handler
  /// on. Pinned here so a regression that renames it surfaces as a test
  /// failure (`AccountErasureClientTests`) rather than silent 404s.
  static let path = "/portfolio"

  /// Query-parameter name the backend's `delete_portfolio` handler reads
  /// the `device_uuid` selector from. Mirrors the `device_uuid` parameter
  /// declared in `app/Sources/Backend/Networking/openapi.json` under the
  /// `DELETE /portfolio` operation.
  static let deviceUUIDQueryItem = "device_uuid"

  /// Builds the `URLRequest` that erases the portfolio keyed by `deviceID`.
  ///
  /// `baseURL` is the backend root (`APIClient.baseURL`). The returned
  /// request carries `httpMethod = "DELETE"` and a single
  /// `device_uuid` query item — the standard auth/identity headers are
  /// attached by `APIClient.send` itself.
  static func makeRequest(baseURL: URL, deviceID: String) -> URLRequest {
    var components = URLComponents(
      url: baseURL.appendingPathComponent(path),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = [URLQueryItem(name: deviceUUIDQueryItem, value: deviceID)]

    var request = URLRequest(url: components.url!)
    request.httpMethod = "DELETE"
    return request
  }
}

/// `@DependencyClient` wrapper that invokes the backend account-erasure
/// endpoint (`DELETE /portfolio`) for issue #329.
///
/// The live implementation routes through `@Dependency(\.apiClient)` so the
/// standard `X-Device-UUID` / `X-App-Attest` headers and forced-update
/// observation continue to apply. Reducers consume this via
/// `@Dependency(\.accountErasure)`; the macro-synthesized `testValue` fails
/// any unstubbed call so reducer tests have to inject the outcome they want.
@DependencyClient
struct AccountErasureClient: Sendable {
  /// Issues `DELETE /portfolio?device_uuid=<X-Device-UUID>` and maps the
  /// HTTP outcome to an `AccountErasureOutcome`. Never throws — transport
  /// errors are funneled into `.networkUnavailable`.
  var eraseAccount: @Sendable () async -> AccountErasureOutcome = {
    .networkUnavailable(reason: "")
  }
}

extension AccountErasureClient: DependencyKey {
  static let liveValue: AccountErasureClient = {
    AccountErasureClient(
      eraseAccount: {
        let request = AccountErasureRequestFactory.makeRequest(
          baseURL: APIClient.shared.baseURL,
          deviceID: DeviceIDProvider.deviceID()
        )
        do {
          @Dependency(\.apiClient) var apiClient
          let (_, response) = try await apiClient.send(request)
          return AccountErasureClient.outcome(for: response.statusCode)
        } catch let error as URLError {
          return .networkUnavailable(reason: error.localizedDescription)
        } catch {
          return .networkUnavailable(reason: String(describing: error))
        }
      }
    )
  }()

  /// Deterministic preview value so SwiftUI `#Preview`s that touch the
  /// Settings erasure flow do not bounce through the macro-synthesized
  /// `testValue`'s unimplemented-call reporter or hit the live backend.
  static let previewValue: AccountErasureClient = AccountErasureClient(
    eraseAccount: { .success }
  )

  /// Maps an HTTP status code to an `AccountErasureOutcome`. Pulled out as a
  /// free function so tests can pin the contract without exercising a real
  /// transport. Refer to the backend docs at
  /// `docs/legal/data-subject-rights.md` "Erasure — full account" for the
  /// status-code semantics.
  static func outcome(for statusCode: Int) -> AccountErasureOutcome {
    switch statusCode {
    case 200..<300, 404:
      return .success
    default:
      return .serverError(status: statusCode)
    }
  }
}

extension DependencyValues {
  var accountErasure: AccountErasureClient {
    get { self[AccountErasureClient.self] }
    set { self[AccountErasureClient.self] = newValue }
  }
}
