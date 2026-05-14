import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `APIClient.shared.send(_:)`.
///
/// Phase 1 reducers consume this via `@Dependency(\.apiClient)` so they
/// never reach into the `APIClient.shared` singleton directly. `liveValue`
/// forwards to the existing client (which still routes every response
/// through `MinAppVersionMonitor`); the macro-synthesized `testValue`
/// fails any unstubbed call.
@DependencyClient
struct APIClientDependency: Sendable {
  var send: @Sendable (_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension APIClientDependency: DependencyKey {
  static let liveValue = APIClientDependency(
    send: { request in try await APIClient.shared.send(request) }
  )
}

extension DependencyValues {
  var apiClient: APIClientDependency {
    get { self[APIClientDependency.self] }
    set { self[APIClientDependency.self] = newValue }
  }
}
