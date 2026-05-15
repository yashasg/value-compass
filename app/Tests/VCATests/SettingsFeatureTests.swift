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

    // Default is `true` (#233 remediation point 4 — keep the Settings
    // disclosure expanded so the long-form copy is one tap closer to
    // the dollar-amount surfaces). Toggle to `false` here so the
    // binding actually mutates state and the no-persistence assertion
    // still exercises the reducer path.
    await store.send(.binding(.set(\.isDisclaimerExpanded, false))) {
      $0.isDisclaimerExpanded = false
    }

    XCTAssertTrue(writes.value.isEmpty)
  }

  func testDisclaimerExpansionDefaultsToTrue() {
    // #233: Settings > Legal disclosure ships expanded so the
    // canonical disclaimer copy is visible without an extra tap.
    let state = SettingsFeature.State()
    XCTAssertTrue(state.isDisclaimerExpanded)
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
      $0.apiKeyMaskedAccessibilityLabel = "Saved API key ending in W X Y Z"
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

  // MARK: - Return-key submit (issue #462)

  /// Issue #462: hitting the SecureField Return key with a valid draft
  /// must dispatch the same effect as the paired `Save` Button (HIG →
  /// Onscreen keyboards / Text fields → Submitting input). The reducer
  /// owns the routing so a single canSave predicate gates both surfaces.
  func testSubmitAPIKeyTappedOnValidDraftRoutesToSave() async {
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

    await store.send(.submitAPIKeyTapped)
    await store.receive(\.saveAPIKeyTapped) {
      $0.apiKeyRequestStatus = .validating
    }
    await store.receive(\.apiKeyValidationCompleted) {
      $0.apiKeyStatus = .storedAndValid
      $0.apiKeyMaskedDisplay = "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ"
      $0.apiKeyMaskedAccessibilityLabel = "Saved API key ending in W X Y Z"
      $0.apiKeyDraft = ""
      $0.apiKeyRequestStatus = .savedSuccessfully
      $0.apiKeyLoadError = nil
    }
    XCTAssertEqual(saved.value, ["placeholder-key-WXYZ"])
  }

  /// A Return-key press on an empty / whitespace-only draft must be a
  /// silent no-op — it must NOT fall through to `.saveAPIKeyTapped`'s
  /// "API key cannot be empty" rejection banner the way an explicit
  /// `Save` tap does, because the user pressing Return while typing is
  /// not a deliberate submit attempt. The `Save` Button is disabled in
  /// the same state, so the predicates stay in lockstep.
  func testSubmitAPIKeyTappedOnEmptyDraftIsNoop() async {
    let store = TestStore(initialState: SettingsFeature.State(apiKeyDraft: "  ")) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKeyValidator.validate = { _ in
        XCTFail("Validator must not be invoked for empty draft")
        return .invalid(reason: "")
      }
    }

    await store.send(.submitAPIKeyTapped)
  }

  /// A second Return press while the first validation is still in flight
  /// must not kick off a duplicate validation. Mirrors the `Save` Button
  /// being disabled (`apiKeyRequestStatus.isInFlight`).
  func testSubmitAPIKeyTappedWhileValidatingIsNoop() async {
    var initialState = SettingsFeature.State(apiKeyDraft: "placeholder-key-WXYZ")
    initialState.apiKeyRequestStatus = .validating

    let store = TestStore(initialState: initialState) {
      SettingsFeature()
    } withDependencies: {
      $0.massiveAPIKeyValidator.validate = { _ in
        XCTFail("Validator must not run while a previous validation is in flight")
        return .invalid(reason: "")
      }
    }

    await store.send(.submitAPIKeyTapped)
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
      $0.apiKeyMaskedAccessibilityLabel = "Saved API key ending in W X Y Z"
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

  // MARK: - Legal links (issue #224)

  /// Pins the canonical in-app Privacy Policy URL. The published policy
  /// lives under `docs/legal/privacy-policy.md` until the publisher hosts a
  /// production policy page; rotating this URL requires updating the
  /// matching reference in `docs/legal/privacy-policy.md` §10 and the
  /// re-validation hook in `loop-strategy.md`.
  func testPrivacyPolicyLinkPointsAtCanonicalSourceOfTruth() {
    XCTAssertEqual(
      LegalLinks.privacyPolicy,
      URL(
        string: "https://github.com/yashasg/value-compass/blob/main/docs/legal/privacy-policy.md"
      )
    )
  }

  /// The in-app legal link must resolve to an `https` scheme so iOS
  /// happily hands it to Safari (no App Transport Security warning) and so
  /// no in-process credential exchange can hide behind a custom scheme.
  func testPrivacyPolicyLinkUsesHTTPS() {
    XCTAssertEqual(LegalLinks.privacyPolicy.scheme, "https")
  }

  // MARK: - Massive third-party legal links (issue #294)

  /// Pins the Massive Terms of Service URL surfaced inside the API-key
  /// entry section. The register and re-verification trigger live in
  /// `docs/legal/third-party-services.md`; rotate both together if
  /// Massive renames the page.
  func testMassiveTermsOfServiceLinkPointsAtCanonicalURL() {
    XCTAssertEqual(
      LegalLinks.massiveTermsOfService,
      URL(string: "https://massive.com/legal/terms")
    )
  }

  /// Pins the Massive Privacy Policy URL surfaced inside the API-key
  /// entry section. Same re-verification trigger as the Terms link.
  func testMassivePrivacyPolicyLinkPointsAtCanonicalURL() {
    XCTAssertEqual(
      LegalLinks.massivePrivacyPolicy,
      URL(string: "https://massive.com/legal/privacy")
    )
  }

  /// Both Massive legal links must use `https` so iOS hands them to
  /// Safari without an App Transport Security exception and so no
  /// custom-scheme handler can intercept them.
  func testMassiveLegalLinksUseHTTPS() {
    XCTAssertEqual(LegalLinks.massiveTermsOfService.scheme, "https")
    XCTAssertEqual(LegalLinks.massivePrivacyPolicy.scheme, "https")
  }

  /// The Massive legal links must point at `massive.com` — not at the API
  /// host `api.massive.com`, and not at any unrelated domain — so the
  /// in-app disclosure surfaces the operator's published policy pages
  /// rather than the API endpoint that the saved key authenticates to.
  func testMassiveLegalLinksPointAtMassiveDotCom() {
    XCTAssertEqual(LegalLinks.massiveTermsOfService.host, "massive.com")
    XCTAssertEqual(LegalLinks.massivePrivacyPolicy.host, "massive.com")
  }

  // MARK: - Account erasure (issue #329)

  /// Tapping the destructive button only opens the confirmation dialog —
  /// no network call, no Keychain mutation, no SwiftData wipe yet.
  func testEraseAllDataTappedOpensConfirmationOnly() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.accountErasure.eraseAccount = {
        XCTFail("Erasure must not start until the user confirms")
        return .success
      }
    }

    await store.send(.eraseAllDataTapped) {
      $0.isErasureConfirmationPresented = true
    }
  }

  /// Dismissing the confirmation closes the dialog without firing any
  /// effect.
  func testEraseAllDataConfirmationDismissedClosesDialog() async {
    let store = TestStore(
      initialState: SettingsFeature.State(isErasureConfirmationPresented: true)
    ) {
      SettingsFeature()
    }

    await store.send(.eraseAllDataConfirmationDismissed) {
      $0.isErasureConfirmationPresented = false
    }
  }

  /// Happy path: backend 204 → local wipe → Keychain wipe → UUID rotation →
  /// onboarding reset, in that order. The reducer-state mirrors for the
  /// API key reset alongside `.erased`.
  func testEraseAllDataConfirmedRunsFullPipelineInOrder() async {
    let callOrder = LockIsolated<[String]>([])
    let userDefaultWrites = LockIsolated<[(value: Bool, key: String)]>([])
    let initialState = SettingsFeature.State(
      apiKeyStatus: .storedAndValid,
      apiKeyMaskedDisplay: "\u{2022}\u{2022}\u{2022}\u{2022}WXYZ",
      apiKeyMaskedAccessibilityLabel: "Saved API key ending in W X Y Z",
      apiKeyDraft: "draft-key-text",
      apiKeyRequestStatus: .savedSuccessfully,
      isErasureConfirmationPresented: true
    )

    let store = TestStore(initialState: initialState) {
      SettingsFeature()
    } withDependencies: {
      $0.accountErasure.eraseAccount = {
        callOrder.withValue { $0.append("backend") }
        return .success
      }
      $0.localDataReset.eraseAllPersonalData = {
        callOrder.withValue { $0.append("localData") }
      }
      $0.massiveAPIKey.delete = {
        callOrder.withValue { $0.append("massiveKey") }
      }
      $0.deviceID.rotate = {
        callOrder.withValue { $0.append("rotate") }
      }
      $0.userDefaults.setBool = { value, key in
        userDefaultWrites.withValue { $0.append((value, key)) }
      }
    }

    await store.send(.eraseAllDataConfirmed) {
      $0.isErasureConfirmationPresented = false
      $0.accountErasureStatus = .erasing
    }
    await store.receive(\.accountErasureNetworkCompleted)
    await store.receive(\.accountErasureLocalCleanupCompleted) {
      $0.apiKeyStatus = .noStoredKey
      $0.apiKeyMaskedDisplay = nil
      $0.apiKeyMaskedAccessibilityLabel = nil
      $0.apiKeyDraft = ""
      $0.apiKeyRequestStatus = .idle
      $0.apiKeyLoadError = nil
      $0.accountErasureStatus = .erased
    }

    XCTAssertEqual(callOrder.value, ["backend", "localData", "massiveKey", "rotate"])

    // Both onboarding-gate userDefault keys are reset so AppFeature.task
    // re-fires onboarding on next launch.
    let onboardingWrites = userDefaultWrites.value.filter { write in
      write.key.contains("isclaimer") || write.key.contains("nboarding")
    }
    XCTAssertEqual(
      onboardingWrites.map { $0.key }.sorted(),
      [
        AppPreferenceKeys.disclaimer,
        AppPreferenceKeys.legacyOnboarding,
      ].sorted()
    )
    XCTAssertTrue(onboardingWrites.allSatisfy { $0.value == false })
  }

  /// A 404 from the backend means "no rows existed" and should also
  /// continue the local-cleanup pipeline. The backend rate-limits the
  /// erasure endpoint to "device that has actually synced", so an early
  /// adopter who never synced still needs the local wipe to fire.
  func testEraseAllData404BackendStillRunsLocalCleanup() async {
    let localDataCalls = LockIsolated<Int>(0)
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.accountErasure.eraseAccount = { .success }
      $0.localDataReset.eraseAllPersonalData = {
        localDataCalls.withValue { $0 += 1 }
      }
      $0.massiveAPIKey.delete = {}
      $0.deviceID.rotate = {}
      $0.userDefaults.setBool = { _, _ in }
    }

    await store.send(.eraseAllDataConfirmed) {
      $0.accountErasureStatus = .erasing
    }
    await store.receive(\.accountErasureNetworkCompleted)
    await store.receive(\.accountErasureLocalCleanupCompleted) {
      $0.accountErasureStatus = .erased
    }
    XCTAssertEqual(localDataCalls.value, 1)
  }

  /// Network failure aborts the pipeline BEFORE any local mutation so the
  /// user can retry online instead of being left half-erased.
  func testEraseAllDataNetworkUnavailableLeavesLocalStateIntact() async {
    let localDataCalls = LockIsolated<Int>(0)
    let keyDeletes = LockIsolated<Int>(0)
    let rotations = LockIsolated<Int>(0)

    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.accountErasure.eraseAccount = { .networkUnavailable(reason: "offline") }
      $0.localDataReset.eraseAllPersonalData = {
        localDataCalls.withValue { $0 += 1 }
        XCTFail("Local data MUST NOT be wiped when the backend call failed")
      }
      $0.massiveAPIKey.delete = {
        keyDeletes.withValue { $0 += 1 }
        XCTFail("Keychain MUST NOT be wiped when the backend call failed")
      }
      $0.deviceID.rotate = {
        rotations.withValue { $0 += 1 }
        XCTFail("Device UUID MUST NOT rotate when the backend call failed")
      }
    }

    await store.send(.eraseAllDataConfirmed) {
      $0.accountErasureStatus = .erasing
    }
    await store.receive(\.accountErasureNetworkCompleted) {
      $0.accountErasureStatus = .failed(
        reason:
          "Could not reach the server: offline. Your data was not erased — "
          + "please try again when you're online."
      )
    }
    XCTAssertEqual(localDataCalls.value, 0)
    XCTAssertEqual(keyDeletes.value, 0)
    XCTAssertEqual(rotations.value, 0)
  }

  /// 5xx from backend aborts the pipeline before any local mutation.
  func testEraseAllDataServerErrorLeavesLocalStateIntact() async {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.accountErasure.eraseAccount = { .serverError(status: 503) }
      $0.localDataReset.eraseAllPersonalData = {
        XCTFail("Local data MUST NOT be wiped when the backend call failed")
      }
      $0.massiveAPIKey.delete = {
        XCTFail("Keychain MUST NOT be wiped when the backend call failed")
      }
      $0.deviceID.rotate = {
        XCTFail("Device UUID MUST NOT rotate when the backend call failed")
      }
    }

    await store.send(.eraseAllDataConfirmed) {
      $0.accountErasureStatus = .erasing
    }
    await store.receive(\.accountErasureNetworkCompleted) {
      $0.accountErasureStatus = .failed(
        reason:
          "Server returned HTTP 503. Your data was not erased — please try again."
      )
    }
  }

  /// SwiftData wipe failure must short-circuit the rest of the pipeline so
  /// we never rotate the device UUID or wipe the API key while the local
  /// store is still half-populated.
  func testEraseAllDataLocalWipeFailureStopsBeforeKeychain() async {
    let keyDeletes = LockIsolated<Int>(0)
    let rotations = LockIsolated<Int>(0)
    let userDefaultWrites = LockIsolated<Int>(0)

    struct FakeError: Error, CustomStringConvertible { let description = "diskFull" }
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.accountErasure.eraseAccount = { .success }
      $0.localDataReset.eraseAllPersonalData = { throw FakeError() }
      $0.massiveAPIKey.delete = {
        keyDeletes.withValue { $0 += 1 }
        XCTFail("Keychain MUST NOT be wiped when local data wipe failed")
      }
      $0.deviceID.rotate = {
        rotations.withValue { $0 += 1 }
        XCTFail("Device UUID MUST NOT rotate when local data wipe failed")
      }
      $0.userDefaults.setBool = { _, _ in
        userDefaultWrites.withValue { $0 += 1 }
        XCTFail("Onboarding-gate userDefaults MUST NOT reset when wipe failed")
      }
    }

    await store.send(.eraseAllDataConfirmed) {
      $0.accountErasureStatus = .erasing
    }
    await store.receive(\.accountErasureNetworkCompleted)
    await store.receive(\.accountErasureLocalCleanupCompleted) {
      // `FakeError` conforms to `CustomStringConvertible`, so
      // `String(describing:)` collapses to its `description` ("diskFull").
      $0.accountErasureStatus = .failed(
        reason: "Could not erase local data: diskFull."
      )
    }
    XCTAssertEqual(keyDeletes.value, 0)
    XCTAssertEqual(rotations.value, 0)
    XCTAssertEqual(userDefaultWrites.value, 0)
  }

  /// While the pipeline is in flight, additional `eraseAllDataTapped` /
  /// `eraseAllDataConfirmed` sends are no-ops so the user can't kick off a
  /// duplicate erasure mid-flight.
  func testEraseAllDataTappedIsNoOpWhileErasing() async {
    let store = TestStore(
      initialState: SettingsFeature.State(accountErasureStatus: .erasing)
    ) {
      SettingsFeature()
    } withDependencies: {
      $0.accountErasure.eraseAccount = {
        XCTFail("Tapped is a no-op while erasing")
        return .success
      }
    }

    await store.send(.eraseAllDataTapped)
  }

  /// Confirmed mid-flight is also a no-op (defense in depth — the View
  /// disables the row, but the reducer should not assume the View layer
  /// got there in time). `isErasureConfirmationPresented` is already
  /// `false` in the seeded state, so the reducer's idempotent reset
  /// produces no observable state change.
  func testEraseAllDataConfirmedIsNoOpWhileErasing() async {
    let store = TestStore(
      initialState: SettingsFeature.State(accountErasureStatus: .erasing)
    ) {
      SettingsFeature()
    } withDependencies: {
      $0.accountErasure.eraseAccount = {
        XCTFail("Confirmed is a no-op while erasing")
        return .success
      }
    }

    await store.send(.eraseAllDataConfirmed)
  }

  // MARK: - AccountErasureRequestFactory + outcome mapping

  /// The DELETE request must carry the device UUID as `device_uuid` so the
  /// backend's row selector can resolve the calling device.
  func testAccountErasureRequestAttachesDeviceUUIDQueryItem() throws {
    let baseURL = URL(string: "https://api.valuecompass.app")!
    let request = AccountErasureRequestFactory.makeRequest(
      baseURL: baseURL,
      deviceID: "DEVICE-1234"
    )

    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertEqual(request.url?.path, "/portfolio")

    let components = try XCTUnwrap(
      request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
    )
    let items = components.queryItems ?? []
    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(items.first?.name, "device_uuid")
    XCTAssertEqual(items.first?.value, "DEVICE-1234")
  }

  /// Outcome mapping: 2xx and 404 both fold to `.success` (rows deleted or
  /// no rows existed) so the local-cleanup pipeline still fires.
  func testAccountErasureOutcomeMapsSuccessAnd404ToSuccess() {
    XCTAssertEqual(AccountErasureClient.outcome(for: 204), .success)
    XCTAssertEqual(AccountErasureClient.outcome(for: 200), .success)
    XCTAssertEqual(AccountErasureClient.outcome(for: 404), .success)
  }

  /// Outcome mapping: any other 4xx/5xx surfaces as `.serverError` so the
  /// reducer can abort before the local mutation.
  func testAccountErasureOutcomeMapsOtherStatusesToServerError() {
    XCTAssertEqual(AccountErasureClient.outcome(for: 400), .serverError(status: 400))
    XCTAssertEqual(AccountErasureClient.outcome(for: 401), .serverError(status: 401))
    XCTAssertEqual(AccountErasureClient.outcome(for: 500), .serverError(status: 500))
    XCTAssertEqual(AccountErasureClient.outcome(for: 503), .serverError(status: 503))
  }
}
