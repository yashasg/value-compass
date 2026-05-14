import Combine
import ComposableArchitecture
import Foundation
import UserNotifications

#if canImport(UIKit)
  import UIKit
#endif

/// `@DependencyClient` that owns push-notification authorization, APNs
/// registration, and APNs device-token delivery.
///
/// Phase 2 (#158): the `PushNotificationManager.shared` singleton is gone.
/// `AppDelegate` forwards APNs callbacks to `PushNotificationsClient.deliver`
/// (a static bridge); `tokenUpdates()` consumes from a long-lived broadcast
/// subject so reducer effects can observe registration without touching
/// `UIApplication` directly.
@DependencyClient
struct PushNotificationsClient: Sendable {
  var requestAuthorizationAndRegister: @Sendable () async -> Void
  var tokenUpdates: @Sendable () -> AsyncStream<String?> = { AsyncStream { _ in } }
}

extension PushNotificationsClient {
  /// Long-lived broadcast of the most recent APNs device token (or `nil`
  /// while none has arrived yet). `AppDelegate` writes here from the main
  /// actor; `tokenUpdates()` consumers receive every distinct value.
  fileprivate static let tokenSubject = CurrentValueSubject<String?, Never>(nil)

  /// Forwards an APNs device token from `AppDelegate` into the client's
  /// shared subject. Hex-encodes the bytes the same way the legacy
  /// `PushNotificationManager.didRegister(deviceToken:)` did so the wire
  /// format observed by the backend is unchanged.
  static func deliver(deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    tokenSubject.send(token)
  }

  /// Owns `UNUserNotificationCenter`'s delegate slot for the live client so
  /// foreground notifications still surface as banner/sound/badge — the
  /// behavior previously inherited from `PushNotificationManager`.
  @MainActor
  fileprivate final class ForegroundPresenter: NSObject,
    UNUserNotificationCenterDelegate
  {
    static let shared = ForegroundPresenter()

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
      [.banner, .sound, .badge]
    }
  }
}

extension PushNotificationsClient: DependencyKey {
  static let liveValue = PushNotificationsClient(
    requestAuthorizationAndRegister: {
      let center = UNUserNotificationCenter.current()
      await MainActor.run { center.delegate = ForegroundPresenter.shared }
      do {
        let granted = try await center.requestAuthorization(
          options: [.alert, .badge, .sound]
        )
        if granted {
          #if canImport(UIKit)
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
          #endif
        }
      } catch {
        // Notifications are optional; swallow the error.
      }
    },
    tokenUpdates: {
      AsyncStream { continuation in
        let cancellable = tokenSubject
          .removeDuplicates()
          .sink { value in continuation.yield(value) }
        continuation.onTermination = { _ in cancellable.cancel() }
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
