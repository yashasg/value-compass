import ComposableArchitecture
import Foundation

/// Reducer that drives `SettingsView` — the preferences / about / legal screen
/// reachable from the portfolio toolbar (compact) and the iPad split-view
/// sidebar.
///
/// Persists `theme` and `language` selections to `UserDefaults` via
/// `@Dependency(\.userDefaults)` so the same keys read by `AppState` keep
/// surviving across launches. App version + device ID are pulled from
/// `@Dependency(\.bundleInfo)` and `@Dependency(\.deviceID)` so the view never
/// reaches into `Bundle.main` or the keychain-backed `DeviceIDProvider`.
///
/// Issue #127 adds the Massive API key management surface: the stored key is
/// kept in the iOS Keychain via `@Dependency(\.massiveAPIKey)` (never in
/// `UserDefaults`, SwiftData, logs, or fixtures) and revalidated against
/// Massive via `@Dependency(\.massiveAPIKeyValidator)` before any save.
///
/// Phase 2 (#158) replaces the legacy `AppState`-backed bridge in
/// `SettingsView.init()` once the real `Store` is wired at app entry.
@Reducer
struct SettingsFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var theme: AppTheme = .system
    var language: AppLanguage = .system
    var isDisclaimerExpanded: Bool = false
    var appVersion: String = ""
    var deviceIDPrefix: String = ""

    // MARK: API key (issue #127)

    /// Source-of-truth view of the persisted Massive API key.
    var apiKeyStatus: SettingsAPIKeyStatus = .noStoredKey
    /// Masked rendering of the stored key (e.g. "••••WXYZ"). `nil` when no
    /// key is stored. Reducer state never holds the raw key — the masked
    /// string is the only thing crossing the View boundary.
    var apiKeyMaskedDisplay: String?
    /// User input from the API key text field. Cleared after a successful
    /// save so we never round-trip the raw key through `@ObservableState`
    /// for longer than the form keeps it.
    var apiKeyDraft: String = ""
    /// Result of the most recent save / revalidation attempt initiated from
    /// the form. Drives inline status messaging.
    var apiKeyRequestStatus: SettingsAPIKeyRequestStatus = .idle
    /// Last error encountered while reading the keychain at `.task`. Kept
    /// separate from `apiKeyRequestStatus` so a load failure doesn't get
    /// clobbered by a later save attempt.
    var apiKeyLoadError: String?
  }

  enum Action: BindableAction, Equatable, Sendable {
    case binding(BindingAction<State>)
    case task

    // MARK: API key actions (issue #127)
    case saveAPIKeyTapped
    case removeAPIKeyTapped
    case revalidateStoredKeyTapped
    case apiKeyValidationCompleted(MassiveAPIKeyValidationOutcome, persistedKey: String)
    case apiKeyRevalidationCompleted(MassiveAPIKeyValidationOutcome)
    case apiKeyRemovalFailed(reason: String)
  }

  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.bundleInfo) var bundleInfo
  @Dependency(\.deviceID) var deviceID
  @Dependency(\.massiveAPIKey) var massiveAPIKey
  @Dependency(\.massiveAPIKeyValidator) var massiveAPIKeyValidator

  /// `UserDefaults` keys mirrored from `AppState` so reducer reads/writes hit
  /// the same persisted values the legacy `AppState` does. #158 deletes
  /// `AppState` once the `Store` is wired at app entry.
  private enum DefaultsKey {
    static let theme = "com.valuecompass.appTheme"
    static let language = "com.valuecompass.appLanguage"
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .task:
        let storedTheme = userDefaults.string(forKey: DefaultsKey.theme) ?? ""
        state.theme = AppTheme(rawValue: storedTheme) ?? .system
        let storedLanguage = userDefaults.string(forKey: DefaultsKey.language) ?? ""
        state.language = AppLanguage(rawValue: storedLanguage) ?? .system
        let info = bundleInfo.info()
        state.appVersion = "\(info.shortVersionString) (\(info.bundleVersion))"
        state.deviceIDPrefix = String(deviceID.deviceID().prefix(8)) + "\u{2026}"

        do {
          if let storedKey = try massiveAPIKey.load() {
            state.apiKeyStatus = .storedAndValid
            state.apiKeyMaskedDisplay = MassiveAPIKeyMask.mask(storedKey)
          } else {
            state.apiKeyStatus = .noStoredKey
            state.apiKeyMaskedDisplay = nil
          }
          state.apiKeyLoadError = nil
        } catch {
          state.apiKeyStatus = .noStoredKey
          state.apiKeyMaskedDisplay = nil
          state.apiKeyLoadError = String(describing: error)
        }
        return .none

      case .binding(\.theme):
        userDefaults.setString(value: state.theme.rawValue, forKey: DefaultsKey.theme)
        return .none

      case .binding(\.language):
        userDefaults.setString(value: state.language.rawValue, forKey: DefaultsKey.language)
        return .none

      case .binding:
        return .none

      case .saveAPIKeyTapped:
        let candidate = state.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
          state.apiKeyRequestStatus = .rejected(reason: "API key cannot be empty.")
          return .none
        }
        state.apiKeyRequestStatus = .validating
        return .run { send in
          let outcome = await massiveAPIKeyValidator.validate(key: candidate)
          await send(.apiKeyValidationCompleted(outcome, persistedKey: candidate))
        }

      case .apiKeyValidationCompleted(let outcome, let persistedKey):
        switch outcome {
        case .valid:
          do {
            try massiveAPIKey.save(persistedKey)
            state.apiKeyStatus = .storedAndValid
            state.apiKeyMaskedDisplay = MassiveAPIKeyMask.mask(persistedKey)
            state.apiKeyDraft = ""
            state.apiKeyRequestStatus = .savedSuccessfully
            state.apiKeyLoadError = nil
          } catch {
            state.apiKeyRequestStatus = .storeError(reason: String(describing: error))
          }
        case .invalid(let reason):
          state.apiKeyRequestStatus = .rejected(reason: reason)
        case .networkUnavailable(let reason):
          state.apiKeyRequestStatus = .networkError(reason: reason)
        case .serverError(let status):
          state.apiKeyRequestStatus = .networkError(
            reason: "Massive responded with HTTP \(status). Please try again.")
        }
        return .none

      case .removeAPIKeyTapped:
        do {
          try massiveAPIKey.delete()
          state.apiKeyStatus = .noStoredKey
          state.apiKeyMaskedDisplay = nil
          state.apiKeyDraft = ""
          state.apiKeyRequestStatus = .idle
          state.apiKeyLoadError = nil
          return .none
        } catch {
          return .send(.apiKeyRemovalFailed(reason: String(describing: error)))
        }

      case .apiKeyRemovalFailed(let reason):
        state.apiKeyRequestStatus = .storeError(reason: reason)
        return .none

      case .revalidateStoredKeyTapped:
        guard case .storedAndValid = state.apiKeyStatus else {
          // No stored key (or already known-failing) — nothing to do.
          return .none
        }
        let storedKey: String?
        do {
          storedKey = try massiveAPIKey.load()
        } catch {
          state.apiKeyStatus = .storedButLastCheckFailed(reason: String(describing: error))
          state.apiKeyRequestStatus = .storeError(reason: String(describing: error))
          return .none
        }
        guard let key = storedKey else {
          state.apiKeyStatus = .noStoredKey
          state.apiKeyMaskedDisplay = nil
          return .none
        }
        state.apiKeyRequestStatus = .validating
        return .run { send in
          let outcome = await massiveAPIKeyValidator.validate(key: key)
          await send(.apiKeyRevalidationCompleted(outcome))
        }

      case .apiKeyRevalidationCompleted(let outcome):
        switch outcome {
        case .valid:
          state.apiKeyStatus = .storedAndValid
          state.apiKeyRequestStatus = .savedSuccessfully
        case .invalid(let reason):
          state.apiKeyStatus = .storedButLastCheckFailed(reason: reason)
          state.apiKeyRequestStatus = .rejected(reason: reason)
        case .networkUnavailable(let reason):
          state.apiKeyStatus = .storedButLastCheckFailed(reason: reason)
          state.apiKeyRequestStatus = .networkError(reason: reason)
        case .serverError(let status):
          let reason = "Massive responded with HTTP \(status). Please try again."
          state.apiKeyStatus = .storedButLastCheckFailed(reason: reason)
          state.apiKeyRequestStatus = .networkError(reason: reason)
        }
        return .none
      }
    }
  }
}
