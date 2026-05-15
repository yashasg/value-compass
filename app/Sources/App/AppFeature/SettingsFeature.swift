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
/// Issue #329 adds the "Erase All My Data" surface that satisfies GDPR
/// Art. 17 / CCPA §1798.105 / App Store §5.1.1(v). The orchestration
/// (backend `DELETE /portfolio` → SwiftData wipe → Keychain wipe →
/// device-UUID rotation → onboarding-gate reset) lives in
/// `SettingsFeature+DataErasure.swift` so this file stays focused on the
/// preferences/API-key surface; the entry-point action is declared here so
/// the reducer body's single `switch` covers every dispatched action.
///
/// Phase 2 (#158) replaces the legacy `AppState`-backed bridge in
/// `SettingsView.init()` once the real `Store` is wired at app entry.
@Reducer
struct SettingsFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var theme: AppTheme = .system
    var language: AppLanguage = .system
    /// Defaults to `true` so the Settings > Legal disclaimer copy is
    /// visible without an extra tap (#233 remediation point 4). The
    /// onboarding gate + the Settings DisclosureGroup are the two
    /// long-form surfaces that complement the short-form footer
    /// rendered on every calculation-output screen via
    /// `CalculationOutputDisclaimerFooter`; keeping the disclosure
    /// expanded by default preserves the "load-bearing and visible"
    /// posture required by Reuben's charter.
    var isDisclaimerExpanded: Bool = true
    var appVersion: String = ""
    var deviceIDPrefix: String = ""

    // MARK: API key (issue #127)

    /// Source-of-truth view of the persisted Massive API key.
    var apiKeyStatus: SettingsAPIKeyStatus = .noStoredKey
    /// Masked rendering of the stored key (e.g. "••••WXYZ"). `nil` when no
    /// key is stored. Reducer state never holds the raw key — the masked
    /// string is the only thing crossing the View boundary.
    var apiKeyMaskedDisplay: String?
    /// VoiceOver-friendly label for the masked-display row (e.g.
    /// "Saved API key ending in W X Y Z"). Computed alongside
    /// `apiKeyMaskedDisplay` so the View layer can attach a single
    /// `.accessibilityLabel` to the masked-key row instead of letting
    /// VoiceOver read the literal `•` bullets verbatim. `nil` whenever
    /// `apiKeyMaskedDisplay` is `nil`.
    var apiKeyMaskedAccessibilityLabel: String?
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

    // MARK: Data erasure (issue #329)

    /// Source-of-truth status of the in-app data-erasure orchestration.
    /// See `SettingsFeature+DataErasure.swift` for the reducer logic.
    var dataErasureStatus: SettingsDataErasureStatus = .idle
    /// `nil` whenever the destructive confirmation dialog is dismissed.
    /// Populated by `eraseAllDataTapped` and consumed by the view's
    /// `.confirmationDialog(...)` modifier.
    @Presents var dataErasureConfirmation: ConfirmationDialogState<Action.DataErasure>?
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

    // MARK: Data erasure actions (issue #329)
    case eraseAllDataTapped
    case dataErasureConfirmation(PresentationAction<DataErasure>)
    case dataErasureCompleted(SettingsDataErasureOutcome)
    case dataErasureAcknowledged
    case delegate(Delegate)

    /// Confirmation-dialog button payloads. Kept on `Action` (rather than
    /// nested under `dataErasureConfirmation`) so `BindableAction`
    /// conformance and the `Equatable` synthesis stay simple.
    @CasePathable
    enum DataErasure: Equatable, Sendable {
      case confirm
      case cancel
    }

    @CasePathable
    enum Delegate: Equatable, Sendable {
      /// Server + local erasure completed. The parent reducer
      /// (`AppFeature`) clears the disclaimer gate and routes back to
      /// onboarding so the user re-acknowledges the terms before any
      /// fresh traffic is issued.
      case dataErasureCompleted
    }
  }

  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.bundleInfo) var bundleInfo
  @Dependency(\.deviceID) var deviceID
  @Dependency(\.massiveAPIKey) var massiveAPIKey
  @Dependency(\.massiveAPIKeyValidator) var massiveAPIKeyValidator
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.modelContainer) var modelContainer

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
            state.apiKeyMaskedAccessibilityLabel =
              MassiveAPIKeyMask.accessibilityLabel(for: storedKey)
          } else {
            state.apiKeyStatus = .noStoredKey
            state.apiKeyMaskedDisplay = nil
            state.apiKeyMaskedAccessibilityLabel = nil
          }
          state.apiKeyLoadError = nil
        } catch {
          state.apiKeyStatus = .noStoredKey
          state.apiKeyMaskedDisplay = nil
          state.apiKeyMaskedAccessibilityLabel = nil
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
            state.apiKeyMaskedAccessibilityLabel =
              MassiveAPIKeyMask.accessibilityLabel(for: persistedKey)
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
          state.apiKeyMaskedAccessibilityLabel = nil
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
          state.apiKeyMaskedAccessibilityLabel = nil
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

      case .eraseAllDataTapped:
        return reduceEraseAllDataTapped(state: &state)

      case .dataErasureConfirmation(.presented(.confirm)):
        return reduceDataErasureConfirmed(state: &state)

      case .dataErasureConfirmation(.presented(.cancel)),
        .dataErasureConfirmation(.dismiss):
        state.dataErasureConfirmation = nil
        return .none

      case .dataErasureCompleted(let outcome):
        return reduceDataErasureCompleted(outcome: outcome, state: &state)

      case .dataErasureAcknowledged:
        state.dataErasureStatus = .idle
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$dataErasureConfirmation, action: \.dataErasureConfirmation)
  }
}
