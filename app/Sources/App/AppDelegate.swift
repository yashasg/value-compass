import Foundation

#if canImport(UIKit)
  import UIKit

  /// Minimal `UIApplicationDelegate` whose only job is to bridge APNs callbacks
  /// (which are still delegate-based on iOS 17/18/26) into the long-lived
  /// `PushNotificationsClient` token bridge.
  ///
  /// Phase 2 (#158): `PushNotificationManager.shared` is gone — the device
  /// token is forwarded to `PushNotificationsClient.deliver(deviceToken:)`,
  /// which feeds an `AsyncStream` consumed by reducer effects observing
  /// `pushNotifications.tokenUpdates()`.
  final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    )
      -> Bool
    {
      // Eagerly materialize the device UUID so the keychain entry is created
      // before the first network call.
      _ = DeviceIDProvider.deviceID()
      return true
    }

    func application(
      _ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
      PushNotificationsClient.deliver(deviceToken: deviceToken)
    }

    func application(
      _ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
      // Notifications are optional; failure here is non-fatal.
    }
  }
#endif
