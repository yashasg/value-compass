import SwiftUI
import SwiftData

@main
struct VCAApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @StateObject private var appState = AppState()
    @StateObject private var minVersionMonitor = MinAppVersionMonitor.shared
    @StateObject private var pushManager = PushNotificationManager.shared
    private let modelContainer: ModelContainer

    init() {
        do {
            self.modelContainer = try LocalPersistence.makeModelContainer()
        } catch {
            fatalError("Unable to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environmentObject(appState)
                .environmentObject(minVersionMonitor)
                .environmentObject(pushManager)
        }
    }
}
