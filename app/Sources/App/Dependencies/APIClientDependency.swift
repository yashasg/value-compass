import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `APIClient.shared.send(_:)`.
///
/// Phase 1 reducers consume this via `@Dependency(\.apiClient)` so they
/// never reach into the `APIClient.shared` singleton directly. `liveValue`
/// forwards to the existing client (which still routes every response
/// through `MinAppVersionMonitor`); `previewValue` returns a deterministic
/// empty-`Data` + synthesized 200 response so SwiftUI `#Preview`s for
/// reducers that consume `\.apiClient` don't hit the network or trip the
/// macro-synthesized `testValue`'s unimplemented-call reporter; the
/// macro-synthesized `testValue` fails any unstubbed call.
@DependencyClient
struct APIClientDependency: Sendable {
  var send: @Sendable (_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension APIClientDependency: DependencyKey {
  static let liveValue = APIClientDependency(
    send: { request in try await APIClient.shared.send(request) }
  )

  /// Deterministic, non-network preview stub. Returns empty `Data` paired
  /// with a synthesized HTTP/1.1 `200 OK` response whose URL echoes the
  /// caller's `URLRequest.url` (falling back to `about:blank` when nil) so
  /// SwiftUI `#Preview`s exercising a reducer that consumes
  /// `@Dependency(\.apiClient)` get a stable, side-effect-free response
  /// instead of hitting the live `APIClient.shared` transport or tripping
  /// the macro-synthesized `testValue`'s unimplemented-call reporter.
  static let previewValue = APIClientDependency(
    send: { request in
      let url = request.url ?? URL(string: "about:blank")!
      let response = HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )!
      return (Data(), response)
    }
  )
}

extension DependencyValues {
  var apiClient: APIClientDependency {
    get { self[APIClientDependency.self] }
    set { self[APIClientDependency.self] = newValue }
  }
}
