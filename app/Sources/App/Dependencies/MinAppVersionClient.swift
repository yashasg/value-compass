import Combine
import ComposableArchitecture
import Foundation

/// A snapshot of the min-version state derived from the latest backend
/// response observed by `APIClient`.
struct MinAppVersionEvent: Equatable, Sendable {
  var requiresUpdate: Bool
  var minimumVersion: String?
}

/// `@DependencyClient` that publishes `MinAppVersionEvent`s derived from the
/// `X-Min-App-Version` HTTP response header.
///
/// Phase 2 (#158): the `MinAppVersionMonitor.shared` view-model
/// singleton is deleted. `APIClient` now calls `MinAppVersionClient.observe`
/// (a pure, side-effecting static helper) for every response; consumers
/// observe the result via `events()`, which yields the latest event to each
/// subscriber and then continues to forward distinct updates.
@DependencyClient
struct MinAppVersionClient: Sendable {
  var events: @Sendable () -> AsyncStream<MinAppVersionEvent> = { AsyncStream { _ in } }
}

extension MinAppVersionClient {
  /// Long-lived broadcast subject. `APIClient` writes here from any actor
  /// after every `URLSession` response; reducer effects subscribe via
  /// `events()`.
  fileprivate static let eventSubject = CurrentValueSubject<MinAppVersionEvent, Never>(
    MinAppVersionEvent(requiresUpdate: false, minimumVersion: nil)
  )

  /// Inspect a response, fold it into the broadcast subject, and remember
  /// "requires update" stickily — once the backend declares the running app
  /// unsupported, every subsequent event keeps `requiresUpdate = true`
  /// until the process exits, matching the legacy `MinAppVersionMonitor`
  /// behavior.
  ///
  /// `currentVersion` defaults to the running bundle's
  /// `CFBundleShortVersionString` so production callers don't have to thread
  /// it through; tests can pass an explicit value.
  static func observe(
    response: HTTPURLResponse,
    currentVersion: String = Self.bundleShortVersion()
  ) {
    guard let header = response.value(forHTTPHeaderField: "X-Min-App-Version"),
      !header.isEmpty
    else { return }

    let below = AppVersion.isBelowMinimum(
      current: currentVersion,
      minimum: header
    )
    let previous = eventSubject.value
    let next = MinAppVersionEvent(
      requiresUpdate: previous.requiresUpdate || below,
      minimumVersion: header
    )
    if next != previous {
      eventSubject.send(next)
    }
  }

  /// Test helper: resets the broadcast subject so a fresh observation can
  /// be made without the previous test's "requires update" stickiness
  /// leaking forward.
  static func resetForTesting() {
    eventSubject.send(MinAppVersionEvent(requiresUpdate: false, minimumVersion: nil))
  }

  /// Reads the running app's marketing version. Falls back to `"0.0.0"` so
  /// `isBelowMinimum` evaluates to `true` for any non-empty min-version
  /// header — i.e. fail-closed when the bundle is misconfigured.
  static func bundleShortVersion() -> String {
    (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
  }
}

extension MinAppVersionClient: DependencyKey {
  static let liveValue = MinAppVersionClient(
    events: {
      AsyncStream { continuation in
        let cancellable =
          eventSubject
          .removeDuplicates()
          .sink { event in continuation.yield(event) }
        continuation.onTermination = { _ in cancellable.cancel() }
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
