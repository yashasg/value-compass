import SwiftUI

@main
struct VCAApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @StateObject private var appState = AppState()
    @StateObject private var minVersionMonitor = MinAppVersionMonitor.shared
    @StateObject private var pushManager = PushNotificationManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(minVersionMonitor)
                .environmentObject(pushManager)
        }
    }
}
