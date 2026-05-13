import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

/// Encapsulates UserNotifications + APNs registration.
///
/// Call `requestAuthorizationAndRegister()` after onboarding completes (not on
/// first launch — the spec mandates the disclaimer is shown before any system
/// prompts). The APNs device token, once received in the `AppDelegate`, is
/// uploaded by the backend the next time the app calls any authenticated
/// endpoint via `APIClient`.
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var apnsToken: String?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Asks the user for alert/badge/sound permission and, on success,
    /// registers with APNs. Errors and denials are silent — the app is
    /// fully functional without notifications.
    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            let settings = await center.notificationSettings()
            self.authorizationStatus = settings.authorizationStatus
            if granted {
                #if canImport(UIKit)
                UIApplication.shared.registerForRemoteNotifications()
                #endif
            }
        } catch {
            // Notifications are optional; swallow the error.
        }
    }

    /// Called by `AppDelegate` when APNs returns a device token.
    func didRegister(deviceToken: Data) {
        apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Show notifications even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
