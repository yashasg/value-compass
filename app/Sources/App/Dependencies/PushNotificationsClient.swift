import Combine
import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `PushNotificationManager`.
///
/// `requestAuthorizationAndRegister()` runs the existing UNUserNotificationCenter
/// flow on the main actor. `tokenUpdates()` returns an `AsyncStream` of APNs
/// device tokens (or `nil` while none has arrived yet) so reducers can
/// observe registration without depending on the `ObservableObject`.
@DependencyClient
struct PushNotificationsClient: Sendable {
  var requestAuthorizationAndRegister: @Sendable () async -> Void
  var tokenUpdates: @Sendable () -> AsyncStream<String?> = { AsyncStream { _ in } }
}

extension PushNotificationsClient: DependencyKey {
  static let liveValue = PushNotificationsClient(
    requestAuthorizationAndRegister: {
      await PushNotificationManager.shared.requestAuthorizationAndRegister()
    },
    tokenUpdates: {
      AsyncStream { continuation in
        let task = Task { @MainActor in
          let stream = PushNotificationManager.shared.$apnsToken
            .removeDuplicates()
            .values
          for await token in stream {
            continuation.yield(token)
          }
          continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }
  )

  static let previewValue = PushNotificationsClient(
    requestAuthorizationAndRegister: {},
    tokenUpdates: { AsyncStream { _ in } }
  )
}

extension DependencyValues {
  var pushNotifications: PushNotificationsClient {
    get { self[PushNotificationsClient.self] }
    set { self[PushNotificationsClient.self] = newValue }
  }
}
