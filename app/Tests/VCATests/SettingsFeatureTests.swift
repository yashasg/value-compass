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
      $0.massiveAPIKey.load = { nil }
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
      $0.massiveAPIKey.load = { nil }
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
      $0.massiveAPIKey.load = { nil }
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

  // MARK: - API key (issue #127)

  /// `.task` with an existing key in the keychain renders a masked display
  /// and reports the stored-and-valid status without bouncing through the
  /// validator.
  func testTaskHydratesAPIKeyFromKeychain() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.userDefaults.string = { _ in nil }
      $0.bundleInfo.info = {
        BundleInfo(
          shortVersionString: "1.0.0",
          bundleVersion: "1",
          appStoreID: nil,
          apiBaseURLString: nil)
      }
      $0.deviceID.deviceID = { "1234567890" }
      $0.massiveAPIKey.load = { "placeholder-key-WXYZ" }
    }

    await store.send(.task) {
      $0.theme = .system
      $0.language = .system
      $0.appVersion = "1.0.0 (1)"
      $0.deviceIDPrefix = "12345678\u{2026}"
      $0.apiKeyStatus = .storedAndValid
      $0.apiKeyMaskedDisplay = "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ"
      $0.apiKeyLoadError = nil
    }
  }

  /// `.task` records a load error on the dedicated `apiKeyLoadError` slot
  /// without polluting `apiKeyRequestStatus`.
  func testTaskCapturesAPIKeyLoadFailure() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.userDefaults.string = { _ in nil }
      $0.bundleInfo.info = {
        BundleInfo(
          shortVersionString: "1.0.0",
          bundleVersion: "1",
          appStoreID: nil,
          apiBaseURLString: nil)
      }
      $0.deviceID.deviceID = { "" }
      $0.massiveAPIKey.load = { throw MassiveAPIKeyStoreError.underlying("simulated") }
    }

    await store.send(.task) {
      $0.theme = .system
      $0.language = .system
      $0.appVersion = "1.0.0 (1)"
      $0.deviceIDPrefix = "\u{2026}"
      $0.apiKeyStatus = .noStoredKey
      $0.apiKeyMaskedDisplay = nil
      $0.apiKeyLoadError = "underlying(\"simulated\")"
    }
  }

  /// Empty draft never reaches the validator and is rejected synchronously.
  func testSaveAPIKeyTappedRejectsEmptyDraft() async {
    let store = TestStore(initialState: SettingsFeature.State(apiKeyDraft: "  ")) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKeyValidator.validate = { _ in
        XCTFail("Validator must not be invoked for empty draft")
        return .invalid(reason: "")
      }
    }

    await store.send(.saveAPIKeyTapped) {
      $0.apiKeyRequestStatus = .rejected(reason: "API key cannot be empty.")
    }
  }

  /// Happy path: validator accepts → reducer persists key → state flips to
  /// stored-and-valid, draft is cleared, and the masked display reveals the
  /// trailing four characters only.
  func testSaveAPIKeyValidThenPersists() async {
    let saved = LockIsolated<[String]>([])
    let store = TestStore(
      initialState: SettingsFeature.State(apiKeyDraft: "placeholder-key-WXYZ")
    ) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKeyValidator.validate = { key in
        XCTAssertEqual(key, "placeholder-key-WXYZ")
        return .valid
      }
      $0.massiveAPIKey.save = { key in
        saved.withValue { $0.append(key) }
      }
    }

    await store.send(.saveAPIKeyTapped) {
      $0.apiKeyRequestStatus = .validating
    }
    await store.receive(\.apiKeyValidationCompleted) {
      $0.apiKeyStatus = .storedAndValid
      $0.apiKeyMaskedDisplay = "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ"
      $0.apiKeyDraft = ""
      $0.apiKeyRequestStatus = .savedSuccessfully
      $0.apiKeyLoadError = nil
    }
    XCTAssertEqual(saved.value, ["placeholder-key-WXYZ"])
  }

  /// Failed validation must not persist the key.
  func testSaveAPIKeyInvalidDoesNotPersist() async {
    let saved = LockIsolated<[String]>([])
    let store = TestStore(
      initialState: SettingsFeature.State(apiKeyDraft: "placeholder-bad-key")
    ) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKeyValidator.validate = { _ in .invalid(reason: "rejected") }
      $0.massiveAPIKey.save = { key in
        saved.withValue { $0.append(key) }
      }
    }

    await store.send(.saveAPIKeyTapped) {
      $0.apiKeyRequestStatus = .validating
    }
    await store.receive(\.apiKeyValidationCompleted) {
      $0.apiKeyRequestStatus = .rejected(reason: "rejected")
    }
    XCTAssertTrue(saved.value.isEmpty)
  }

  /// Network failure on save must not persist the key.
  func testSaveAPIKeyNetworkErrorDoesNotPersist() async {
    let saved = LockIsolated<[String]>([])
    let store = TestStore(
      initialState: SettingsFeature.State(apiKeyDraft: "placeholder-key-NET")
    ) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKeyValidator.validate = { _ in .networkUnavailable(reason: "offline") }
      $0.massiveAPIKey.save = { key in
        saved.withValue { $0.append(key) }
      }
    }

    await store.send(.saveAPIKeyTapped) {
      $0.apiKeyRequestStatus = .validating
    }
    await store.receive(\.apiKeyValidationCompleted) {
      $0.apiKeyRequestStatus = .networkError(reason: "offline")
    }
    XCTAssertTrue(saved.value.isEmpty)
  }

  /// Server error path captures the status code in the surfaced message.
  func testSaveAPIKeyServerErrorIsReportedAsNetworkError() async {
    let store = TestStore(
      initialState: SettingsFeature.State(apiKeyDraft: "placeholder-key-503")
    ) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKeyValidator.validate = { _ in .serverError(status: 503) }
      $0.massiveAPIKey.save = { _ in
        XCTFail("Server error must not persist the key")
      }
    }

    await store.send(.saveAPIKeyTapped) {
      $0.apiKeyRequestStatus = .validating
    }
    await store.receive(\.apiKeyValidationCompleted) {
      $0.apiKeyRequestStatus = .networkError(
        reason: "Massive responded with HTTP 503. Please try again.")
    }
  }

  /// Storage failure on save surfaces a `.storeError` and leaves the
  /// existing on-disk state untouched.
  func testSaveAPIKeyStoreFailureSurfacesStoreError() async {
    let store = TestStore(
      initialState: SettingsFeature.State(apiKeyDraft: "placeholder-key-OK")
    ) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKeyValidator.validate = { _ in .valid }
      $0.massiveAPIKey.save = { _ in throw MassiveAPIKeyStoreError.underlying("disk full") }
    }

    await store.send(.saveAPIKeyTapped) {
      $0.apiKeyRequestStatus = .validating
    }
    await store.receive(\.apiKeyValidationCompleted) {
      $0.apiKeyRequestStatus = .storeError(reason: "underlying(\"disk full\")")
    }
  }

  /// Removal clears the persisted key, the masked display, and any inline
  /// status messaging.
  func testRemoveAPIKeyClearsState() async {
    let deletes = LockIsolated<Int>(0)
    let initialState = SettingsFeature.State(
      apiKeyStatus: .storedAndValid,
      apiKeyMaskedDisplay: "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ",
      apiKeyRequestStatus: .savedSuccessfully)
    let store = TestStore(initialState: initialState) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKey.delete = { deletes.withValue { $0 += 1 } }
    }

    await store.send(.removeAPIKeyTapped) {
      $0.apiKeyStatus = .noStoredKey
      $0.apiKeyMaskedDisplay = nil
      $0.apiKeyRequestStatus = .idle
    }
    XCTAssertEqual(deletes.value, 1)
  }

  /// A failed delete keeps the existing state and surfaces a `.storeError`.
  func testRemoveAPIKeyFailureSurfacesStoreError() async {
    let initialState = SettingsFeature.State(
      apiKeyStatus: .storedAndValid,
      apiKeyMaskedDisplay: "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ")
    let store = TestStore(initialState: initialState) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKey.delete = { throw MassiveAPIKeyStoreError.underlying("denied") }
    }

    await store.send(.removeAPIKeyTapped)
    await store.receive(\.apiKeyRemovalFailed) {
      $0.apiKeyRequestStatus = .storeError(reason: "underlying(\"denied\")")
    }
  }

  /// Re-validating a stored key that is rejected later keeps the key on disk
  /// and flips the status to `.storedButLastCheckFailed` so the UI can
  /// prompt for an update.
  func testRevalidateStoredKeyMarksFailedWithoutDeleting() async {
    let deletes = LockIsolated<Int>(0)
    let initialState = SettingsFeature.State(
      apiKeyStatus: .storedAndValid,
      apiKeyMaskedDisplay: "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ")
    let store = TestStore(initialState: initialState) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKey.load = { "placeholder-key-WXYZ" }
      $0.massiveAPIKey.delete = { deletes.withValue { $0 += 1 } }
      $0.massiveAPIKeyValidator.validate = { _ in .invalid(reason: "expired") }
    }

    await store.send(.revalidateStoredKeyTapped) {
      $0.apiKeyRequestStatus = .validating
    }
    await store.receive(\.apiKeyRevalidationCompleted) {
      $0.apiKeyStatus = .storedButLastCheckFailed(reason: "expired")
      $0.apiKeyRequestStatus = .rejected(reason: "expired")
    }
    XCTAssertEqual(deletes.value, 0)
  }

  /// Successful re-validation marks the key valid again.
  func testRevalidateStoredKeyValidRestoresValidStatus() async {
    let initialState = SettingsFeature.State(
      apiKeyStatus: .storedAndValid,
      apiKeyMaskedDisplay: "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ")
    let store = TestStore(initialState: initialState) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKey.load = { "placeholder-key-WXYZ" }
      $0.massiveAPIKeyValidator.validate = { _ in .valid }
    }

    await store.send(.revalidateStoredKeyTapped) {
      $0.apiKeyRequestStatus = .validating
    }
    await store.receive(\.apiKeyRevalidationCompleted) {
      $0.apiKeyRequestStatus = .savedSuccessfully
    }
  }

  /// Re-validating a network-failed call keeps the key on disk and surfaces
  /// the failure in `apiKeyStatus` so subsequent loads still see the key.
  func testRevalidateStoredKeyNetworkErrorKeepsKey() async {
    let deletes = LockIsolated<Int>(0)
    let initialState = SettingsFeature.State(
      apiKeyStatus: .storedAndValid,
      apiKeyMaskedDisplay: "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ")
    let store = TestStore(initialState: initialState) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKey.load = { "placeholder-key-WXYZ" }
      $0.massiveAPIKey.delete = { deletes.withValue { $0 += 1 } }
      $0.massiveAPIKeyValidator.validate = { _ in .networkUnavailable(reason: "offline") }
    }

    await store.send(.revalidateStoredKeyTapped) {
      $0.apiKeyRequestStatus = .validating
    }
    await store.receive(\.apiKeyRevalidationCompleted) {
      $0.apiKeyStatus = .storedButLastCheckFailed(reason: "offline")
      $0.apiKeyRequestStatus = .networkError(reason: "offline")
    }
    XCTAssertEqual(deletes.value, 0)
  }

  /// Re-validating when no key is stored is a safe no-op.
  func testRevalidateNoStoredKeyIsNoOp() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKey.load = {
        XCTFail("Load must not be invoked when no key is stored")
        return nil
      }
      $0.massiveAPIKeyValidator.validate = { _ in
        XCTFail("Validator must not be invoked when no key is stored")
        return .invalid(reason: "")
      }
    }

    await store.send(.revalidateStoredKeyTapped)
  }
}
