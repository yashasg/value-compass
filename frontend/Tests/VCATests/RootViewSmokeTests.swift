import SwiftData
import SwiftUI
import XCTest

@testable import VCA

final class RootViewSmokeTests: XCTestCase {
  @MainActor
  func testRootViewCanBeHostedWithRequiredDependencies() throws {
    let suiteName = "com.valuecompass.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let appState = AppState(userDefaults: defaults)
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let view = RootView()
      .modelContainer(container)
      .environmentObject(appState)
      .environmentObject(MinAppVersionMonitor(currentVersion: "1.0.0"))
      .environmentObject(PushNotificationManager.shared)
    let host = UIHostingController(rootView: view)

    XCTAssertNotNil(host.view)
  }
}
