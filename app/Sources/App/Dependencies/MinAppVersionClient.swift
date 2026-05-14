import Combine
import ComposableArchitecture
import Foundation

/// A snapshot of the values published by `MinAppVersionMonitor.shared`.
struct MinAppVersionEvent: Equatable, Sendable {
  var requiresUpdate: Bool
  var minimumVersion: String?
}

/// `@DependencyClient` wrapper around `MinAppVersionMonitor`.
///
/// `events()` returns an `AsyncStream` so reducers can `.run { send in
/// for await event in client.events() { await send(.minVersionEvent(event)) } }`
/// without observing `@Published` properties from inside the reducer. The
/// live value bridges the existing `@Published requiresUpdate` /
/// `@Published minimumVersion` via Combine's `.values` property.
@DependencyClient
struct MinAppVersionClient: Sendable {
  var events: @Sendable () -> AsyncStream<MinAppVersionEvent> = { AsyncStream { _ in } }
}

extension MinAppVersionClient: DependencyKey {
  static let liveValue = MinAppVersionClient(
    events: {
      AsyncStream { continuation in
        let task = Task { @MainActor in
          let monitor = MinAppVersionMonitor.shared
          let stream =
            Publishers
            .CombineLatest(monitor.$requiresUpdate, monitor.$minimumVersion)
            .map { MinAppVersionEvent(requiresUpdate: $0, minimumVersion: $1) }
            .removeDuplicates()
            .values
          for await event in stream {
            continuation.yield(event)
          }
          continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }
  )

  static let previewValue = MinAppVersionClient(
    events: { AsyncStream { _ in } }
  )
}

extension DependencyValues {
  var minAppVersion: MinAppVersionClient {
    get { self[MinAppVersionClient.self] }
    set { self[MinAppVersionClient.self] = newValue }
  }
}
