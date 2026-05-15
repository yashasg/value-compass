import ComposableArchitecture
import XCTest

@testable import VCA

/// `TestStore` coverage for `SettingsFeature` (issue #188, part of #185).
///
/// Pins the preferences/about surface: `.task` hydrates `theme`, `language`,
/// `appVersion`, and `deviceIDPrefix` from the injected dependencies (with
/// `.system` fallbacks for missing/unknown stored values), and the `theme`
/// and `language` bindings persist through to `UserDefaults` while other
/// bindings (e.g., `isDisclaimerExpanded`) do not.
@MainActor
final class SettingsFeatureTests: XCTestCase {
  private static let themeKey = "com.valuecompass.appTheme"
  private static let languageKey = "com.valuecompass.appLanguage"

  func testTaskHydratesFromUserDefaultsAndDeviceMetadata() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.userDefaults.string = { key in
        switch key {
        case Self.themeKey: return AppTheme.dark.rawValue
        case Self.languageKey: return AppLanguage.english.rawValue
        default: return nil
        }
      }
      $0.bundleInfo.info = {
        BundleInfo(
          shortVersionString: "1.2.3",
          bundleVersion: "45",
          appStoreID: nil,
          apiBaseURLString: nil
        )
      }
      $0.deviceID.deviceID = { "ABCDEFGH-XYZ" }
    }

    await store.send(.task) {
      $0.theme = .dark
      $0.language = .english
      $0.appVersion = "1.2.3 (45)"
      $0.deviceIDPrefix = "ABCDEFGH\u{2026}"
    }
  }

  func testTaskFallsBackToSystemWhenStoredValuesAreMissing() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.userDefaults.string = { _ in nil }
      $0.bundleInfo.info = {
        BundleInfo(
          shortVersionString: "2.0.0",
          bundleVersion: "100",
          appStoreID: nil,
          apiBaseURLString: nil
        )
      }
      $0.deviceID.deviceID = { "" }
    }

    await store.send(.task) {
      $0.theme = .system
      $0.language = .system
      $0.appVersion = "2.0.0 (100)"
      $0.deviceIDPrefix = "\u{2026}"
    }
  }

  func testTaskFallsBackToSystemWhenStoredValuesAreUnrecognised() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.userDefaults.string = { key in
        switch key {
        case Self.themeKey: return "midnight-mode"
        case Self.languageKey: return "klingon"
        default: return nil
        }
      }
      $0.bundleInfo.info = {
        BundleInfo(
          shortVersionString: "0.9.0",
          bundleVersion: "9",
          appStoreID: nil,
          apiBaseURLString: nil
        )
      }
      $0.deviceID.deviceID = { "1234567890" }
    }

    await store.send(.task) {
      $0.theme = .system
      $0.language = .system
      $0.appVersion = "0.9.0 (9)"
      $0.deviceIDPrefix = "12345678\u{2026}"
    }
  }

  func testBindingThemePersistsToUserDefaults() async {
    let writes = LockIsolated<[(value: String, key: String)]>([])
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.userDefaults.setString = { value, key in
        writes.withValue { $0.append((value, key)) }
      }
    }

    await store.send(.binding(.set(\.theme, .dark))) {
      $0.theme = .dark
    }

    XCTAssertEqual(writes.value.map { $0.key }, [Self.themeKey])
    XCTAssertEqual(writes.value.map { $0.value }, [AppTheme.dark.rawValue])
  }

  func testBindingLanguagePersistsToUserDefaults() async {
    let writes = LockIsolated<[(value: String, key: String)]>([])
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.userDefaults.setString = { value, key in
        writes.withValue { $0.append((value, key)) }
      }
    }

    await store.send(.binding(.set(\.language, .english))) {
      $0.language = .english
    }

    XCTAssertEqual(writes.value.map { $0.key }, [Self.languageKey])
    XCTAssertEqual(writes.value.map { $0.value }, [AppLanguage.english.rawValue])
  }

  func testBindingDisclaimerExpansionDoesNotTouchUserDefaults() async {
    let writes = LockIsolated<[(value: String, key: String)]>([])
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.userDefaults.setString = { value, key in
        writes.withValue { $0.append((value, key)) }
      }
    }

    await store.send(.binding(.set(\.isDisclaimerExpanded, true))) {
      $0.isDisclaimerExpanded = true
    }

    XCTAssertTrue(writes.value.isEmpty)
  }
}
