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

    // MARK: Account erasure (issue #329)

    /// Source-of-truth view of the in-app "Erase All My Data" flow. Idle
    /// until the user taps the destructive button; then runs the
    /// backend → SwiftData → Keychain → UUID-rotation → onboarding-gate
    /// pipeline serially and reports the outcome inline. See
    /// ``SettingsAccountErasureStatus``.
    var accountErasureStatus: SettingsAccountErasureStatus = .idle
    /// Whether the destructive confirmation dialog is currently showing.
    /// Toggled by `eraseAllDataTapped` and reset by either
    /// `eraseAllDataConfirmationDismissed` (cancel) or
    /// `eraseAllDataConfirmed` (proceed). The View layer binds this to a
    /// SwiftUI `.confirmationDialog` so the destructive choice is
    /// explicitly confirmed before any network/Keychain side effect.
    var isErasureConfirmationPresented: Bool = false
  }

  enum Action: BindableAction, Equatable, Sendable {
    case binding(BindingAction<State>)
    case task

    // MARK: API key actions (issue #127)
    case saveAPIKeyTapped
    /// User pressed the Return key (`.submitLabel(.done)`) on the API key
    /// `SecureField`. Issue #462 — HIG / Onscreen keyboards / Text fields
    /// → Submitting input requires the Return-key path to mirror the
    /// `Save` Button's enable predicate exactly: empty/whitespace drafts
    /// and in-flight validations are dropped so a stray Return press never
    /// surfaces a spurious "API key cannot be empty" banner or kicks off a
    /// duplicate validation.
    case submitAPIKeyTapped
    case removeAPIKeyTapped
    case revalidateStoredKeyTapped
    case apiKeyValidationCompleted(MassiveAPIKeyValidationOutcome, persistedKey: String)
    case apiKeyRevalidationCompleted(MassiveAPIKeyValidationOutcome)
    case apiKeyRemovalFailed(reason: String)

    // MARK: Account erasure actions (issue #329)

    /// User tapped the "Erase All My Data" row in Settings. Opens the
    /// destructive confirmation dialog without firing any side effects.
    case eraseAllDataTapped
    /// User dismissed the confirmation dialog (Cancel, tap-out, etc.).
    case eraseAllDataConfirmationDismissed
    /// User confirmed inside the destructive dialog. Kicks off the
    /// backend `DELETE /portfolio` → local cleanup pipeline.
    case eraseAllDataConfirmed
    /// Backend erasure call returned. Success continues the pipeline;
    /// failure aborts before any local mutation so the user can retry
    /// when connectivity returns.
    case accountErasureNetworkCompleted(AccountErasureOutcome)
    /// Local cleanup (SwiftData wipe → Massive key wipe → UUID rotation →
    /// onboarding reset) finished. `localCleanupError` carries the first
    /// failure reason or `nil` when every step succeeded.
    case accountErasureLocalCleanupCompleted(localCleanupError: String?)
  }

  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.bundleInfo) var bundleInfo
  @Dependency(\.deviceID) var deviceID
  @Dependency(\.massiveAPIKey) var massiveAPIKey
  @Dependency(\.massiveAPIKeyValidator) var massiveAPIKeyValidator
  @Dependency(\.accountErasure) var accountErasure
  @Dependency(\.localDataReset) var localDataReset

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

      case .submitAPIKeyTapped:
        // Issue #462: routes the SecureField Return key through the same
        // enable predicate `apiKeyEntryRow`'s `Save` Button uses, so empty
        // / whitespace drafts and in-flight validations no-op silently
        // instead of falling through to `.saveAPIKeyTapped`'s "API key
        // cannot be empty" rejection banner or starting a duplicate
        // validation. Valid drafts dispatch `.saveAPIKeyTapped` so the
        // two surfaces share a single persistence path.
        let trimmed = state.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !state.apiKeyRequestStatus.isInFlight else {
          return .none
        }
        return .send(.saveAPIKeyTapped)

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

      // MARK: Account erasure (issue #329)

      case .eraseAllDataTapped:
        guard !state.accountErasureStatus.isInFlight else { return .none }
        state.isErasureConfirmationPresented = true
        return .none

      case .eraseAllDataConfirmationDismissed:
        state.isErasureConfirmationPresented = false
        return .none

      case .eraseAllDataConfirmed:
        state.isErasureConfirmationPresented = false
        guard !state.accountErasureStatus.isInFlight else { return .none }
        state.accountErasureStatus = .erasing
        return .run { [accountErasure] send in
          let outcome = await accountErasure.eraseAccount()
          await send(.accountErasureNetworkCompleted(outcome))
        }

      case .accountErasureNetworkCompleted(let outcome):
        switch outcome {
        case .success:
          // Run the rest of the pipeline as a single serial effect so a
          // failure in any step short-circuits the remaining steps and
          // the user sees one inline message instead of a half-finished
          // erase. Captured dependencies are `Sendable` so the closure
          // is safe to run off the main actor.
          return .run {
            [localDataReset, massiveAPIKey, deviceID, userDefaults] send in
            do {
              try await localDataReset.eraseAllPersonalData()
            } catch {
              await send(
                .accountErasureLocalCleanupCompleted(
                  localCleanupError:
                    "Could not erase local data: \(String(describing: error))."
                ))
              return
            }
            do {
              try massiveAPIKey.delete()
            } catch {
              await send(
                .accountErasureLocalCleanupCompleted(
                  localCleanupError:
                    "Local data was cleared but the Massive API key could not be removed: "
                    + "\(String(describing: error))."
                ))
              return
            }
            do {
              try deviceID.rotate()
            } catch {
              await send(
                .accountErasureLocalCleanupCompleted(
                  localCleanupError:
                    "Local data and the API key were cleared but the device identifier "
                    + "could not be rotated: \(String(describing: error))."
                ))
              return
            }
            userDefaults.setBool(value: false, forKey: AppPreferenceKeys.disclaimer)
            userDefaults.setBool(value: false, forKey: AppPreferenceKeys.legacyOnboarding)
            await send(.accountErasureLocalCleanupCompleted(localCleanupError: nil))
          }
        case .networkUnavailable(let reason):
          state.accountErasureStatus = .failed(
            reason:
              "Could not reach the server: \(reason). Your data was not erased — "
              + "please try again when you're online."
          )
          return .none
        case .serverError(let status):
          state.accountErasureStatus = .failed(
            reason:
              "Server returned HTTP \(status). Your data was not erased — please try again."
          )
          return .none
        }

      case .accountErasureLocalCleanupCompleted(let error):
        if let error {
          state.accountErasureStatus = .failed(reason: error)
          return .none
        }
        // Clear reducer-state mirrors of state we just wiped on disk so
        // the Settings screen reflects the erased posture without
        // needing a re-`.task` round trip. The View layer disables
        // every other interactive row while `accountErasureStatus`
        // is `.erased` and surfaces a relaunch prompt.
        state.apiKeyStatus = .noStoredKey
        state.apiKeyMaskedDisplay = nil
        state.apiKeyMaskedAccessibilityLabel = nil
        state.apiKeyDraft = ""
        state.apiKeyRequestStatus = .idle
        state.apiKeyLoadError = nil
        state.accountErasureStatus = .erased
        return .none
      }
    }
  }
}
