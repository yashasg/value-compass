import XCTest

@testable import VCA

@MainActor
final class AppStateTests: XCTestCase {
  func testDisclaimerFlagDefaultsToFalseAndPersistsWhenSeen() {
    let suiteName = "com.valuecompass.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let firstLaunchState = AppState(userDefaults: defaults)
    XCTAssertFalse(firstLaunchState.hasSeenDisclaimer)

    firstLaunchState.hasSeenDisclaimer = true

    let relaunchedState = AppState(userDefaults: defaults)
    XCTAssertTrue(relaunchedState.hasSeenDisclaimer)
  }

  func testLegacyOnboardingFlagMigratesToDisclaimerGate() {
    let suiteName = "com.valuecompass.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(true, forKey: AppState.legacyOnboardingKey)

    let relaunchedState = AppState(userDefaults: defaults)

    XCTAssertTrue(relaunchedState.hasSeenDisclaimer)
  }

  func testLocalSettingsDefaultToSystemAndPersist() {
    let suiteName = "com.valuecompass.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let firstLaunchState = AppState(userDefaults: defaults)
    XCTAssertEqual(firstLaunchState.appTheme, .system)
    XCTAssertEqual(firstLaunchState.appLanguage, .system)

    firstLaunchState.appTheme = .dark
    firstLaunchState.appLanguage = .english

    let relaunchedState = AppState(userDefaults: defaults)
    XCTAssertEqual(relaunchedState.appTheme, .dark)
    XCTAssertEqual(relaunchedState.appLanguage, .english)
  }

  func testThemeMapsToPreferredColorScheme() {
    XCTAssertNil(AppTheme.system.preferredColorScheme)
    XCTAssertEqual(AppTheme.light.preferredColorScheme, .light)
    XCTAssertEqual(AppTheme.dark.preferredColorScheme, .dark)
  }
}
