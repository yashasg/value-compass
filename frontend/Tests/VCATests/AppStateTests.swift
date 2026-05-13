import XCTest

@testable import VCA

final class AppStateTests: XCTestCase {
  @MainActor
  func testOnboardingFlagDefaultsToFalseAndPersistsWhenCompleted() {
    let suiteName = "com.valuecompass.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let firstLaunchState = AppState(userDefaults: defaults)
    XCTAssertFalse(firstLaunchState.hasCompletedOnboarding)

    firstLaunchState.hasCompletedOnboarding = true

    let relaunchedState = AppState(userDefaults: defaults)
    XCTAssertTrue(relaunchedState.hasCompletedOnboarding)
  }
}
