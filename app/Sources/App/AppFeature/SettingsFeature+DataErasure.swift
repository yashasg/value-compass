import ComposableArchitecture
import Foundation

/// In-flight status of the Settings → "Erase All My Data" orchestration
/// (issue #329). Held on `SettingsFeature.State.dataErasureStatus` and
/// surfaced verbatim by `SettingsView` so the user gets explicit feedback
/// at every step of the GDPR Art. 17 / CCPA §1798.105 flow.
///
/// State transitions:
///
///   .idle
///     ── eraseAllDataTapped ──▶ .awaitingConfirmation
///       ── confirmation .cancel / .dismiss ──▶ .idle
///       ── confirmation .confirm ──▶ .deleting
///         ── network error / non-success ──▶ .failed(reason)
///         ── 204/404 + local steps succeed ──▶ .succeeded
///
/// `.failed` is recoverable — the user can retry. `.succeeded` is
/// terminal for this view: the parent reducer pulls the user back to
/// onboarding via `.delegate(.dataErasureCompleted)` in the same effect.
enum SettingsDataErasureStatus: Equatable, Sendable {
  case idle
  case awaitingConfirmation
  case deleting
  case succeeded
  case failed(reason: String)

  /// The "Erase All My Data" button is disabled while the orchestration
  /// owns the irreversible chain so a double-tap can't fire two DELETE
  /// /portfolio requests against the backend. `awaitingConfirmation`
  /// keeps the button enabled — the dialog is the gate, not the button.
  var isInFlight: Bool {
    if case .deleting = self { return true }
    return false
  }
}

/// Result envelope dispatched back to `SettingsFeature` once the
/// asynchronous erasure effect finishes. Keeping the success / failure
/// data on a single case keeps the reducer's switch exhaustive without
/// modelling intermediate steps as separate inbound actions.
enum SettingsDataErasureOutcome: Equatable, Sendable {
  case succeeded
  case failed(reason: String)
}

extension SettingsFeature {
  /// Confirmation dialog shown when the user taps "Erase All My Data".
  /// Mirrors the destructive-action convention used elsewhere in the
  /// project (e.g. PortfolioListFeature delete confirmation): a
  /// destructive primary action plus a clear cancel button, with body
  /// copy that names the irreversible side effects so consent is
  /// informed (App Store §5.1.1(v), GDPR Art. 7).
  static func dataErasureConfirmationDialog() -> ConfirmationDialogState<Action.DataErasure> {
    ConfirmationDialogState<Action.DataErasure>(
      titleVisibility: .visible,
      title: { TextState("Erase All My Data?") },
      actions: {
        ButtonState(role: .destructive, action: .confirm) {
          TextState("Erase All My Data")
        }
        ButtonState(role: .cancel, action: .cancel) {
          TextState("Cancel")
        }
      },
      message: {
        TextState(
          """
          This permanently deletes your portfolios, holdings, and \
          calculation history from this device and from Value Compass's \
          servers. Your saved Massive API key will be removed and your \
          anonymous device identity rotated. You'll be returned to the \
          welcome screen and asked to re-acknowledge the disclaimer.
          """
        )
      }
    )
  }

  /// Handles `.eraseAllDataTapped` by raising the destructive
  /// confirmation dialog. The actual server + local wipe only kicks off
  /// once the user picks `.confirm`. Re-tapping while a request is
  /// already in flight is a no-op so a double-tap can't fire two DELETE
  /// /portfolio requests.
  func reduceEraseAllDataTapped(state: inout State) -> Effect<Action> {
    switch state.dataErasureStatus {
    case .deleting, .succeeded:
      return .none
    case .idle, .awaitingConfirmation, .failed:
      state.dataErasureStatus = .awaitingConfirmation
      state.dataErasureConfirmation = Self.dataErasureConfirmationDialog()
      return .none
    }
  }

  /// Handles the `.confirm` button on the destructive dialog. Issues
  /// `DELETE /portfolio?device_uuid={uuid}` via `@Dependency(\.apiClient)`
  /// (which attaches `X-Device-UUID` + `X-App-Attest`) and, on 204/404,
  /// chains the local wipe in strict order:
  ///
  /// 1. SwiftData wipe (every entity in every configuration).
  /// 2. Massive API key delete (Keychain).
  /// 3. Device UUID rotation (Keychain) — must follow the backend call
  ///    so the DELETE traffic still identifies the right rows.
  /// 4. UserDefaults removal of disclaimer / theme / language so the
  ///    onboarding gate re-fires.
  /// 5. Delegate `.dataErasureCompleted` so `AppFeature` can transition
  ///    the destination back to onboarding.
  ///
  /// Any failure short-circuits the chain so a partial wipe never
  /// happens — if the backend rejects the call (offline, 5xx, etc.) the
  /// local data stays intact and the user can retry.
  func reduceDataErasureConfirmed(state: inout State) -> Effect<Action> {
    state.dataErasureConfirmation = nil
    state.dataErasureStatus = .deleting

    let deviceUUID = deviceID.deviceID()
    let baseURL = APIClient.configuredBaseURL()

    return .run { send in
      do {
        try await performErasure(baseURL: baseURL, deviceUUID: deviceUUID)
        await send(.dataErasureCompleted(.succeeded))
      } catch let error as DataErasureError {
        await send(.dataErasureCompleted(.failed(reason: error.userFacingReason)))
      } catch {
        await send(
          .dataErasureCompleted(.failed(reason: String(describing: error))))
      }
    }
  }

  /// Handles the asynchronous outcome of the orchestration. On success,
  /// flip status to `.succeeded` and notify the parent so the
  /// destination switches back to onboarding; on failure, surface the
  /// reason and stay on Settings so the user can retry.
  func reduceDataErasureCompleted(
    outcome: SettingsDataErasureOutcome,
    state: inout State
  ) -> Effect<Action> {
    switch outcome {
    case .succeeded:
      state.dataErasureStatus = .succeeded
      state.apiKeyStatus = .noStoredKey
      state.apiKeyMaskedDisplay = nil
      state.apiKeyMaskedAccessibilityLabel = nil
      state.apiKeyDraft = ""
      state.apiKeyRequestStatus = .idle
      state.apiKeyLoadError = nil
      return .send(.delegate(.dataErasureCompleted))
    case .failed(let reason):
      state.dataErasureStatus = .failed(reason: reason)
      return .none
    }
  }

  /// Backend + local erasure chain. Pulled out of the `.run` closure so
  /// it can be unit-tested independently of the reducer's `TestStore`
  /// scaffolding. Each step throws ``DataErasureError`` with a
  /// step-specific reason on failure so the surfaced message tells the
  /// user where the flow stopped (and whether the local data is still
  /// intact).
  private func performErasure(baseURL: URL, deviceUUID: String) async throws {
    // 1. Backend cascade delete — MUST complete before any local wipe so
    //    an offline / 5xx user keeps their data.
    guard
      let request = DataErasureRequest.makeURLRequest(
        baseURL: baseURL, deviceID: deviceUUID)
    else {
      throw DataErasureError.requestConstructionFailed
    }
    let response: HTTPURLResponse
    do {
      let (_, http) = try await apiClient.send(request)
      response = http
    } catch {
      throw DataErasureError.network(underlying: error)
    }
    guard DataErasureRequest.isSuccessfulErasure(statusCode: response.statusCode) else {
      throw DataErasureError.unexpectedStatus(response.statusCode)
    }

    // 2. SwiftData wipe.
    do {
      try await modelContainer.wipe()
    } catch {
      throw DataErasureError.localWipeFailed(underlying: error)
    }

    // 3. Keychain — Massive API key.
    do {
      try massiveAPIKey.delete()
    } catch {
      throw DataErasureError.keychainWipeFailed(underlying: error)
    }

    // 4. Keychain — Device UUID rotation.
    do {
      try deviceID.rotate()
    } catch {
      throw DataErasureError.keychainWipeFailed(underlying: error)
    }

    // 5. UserDefaults — re-arm the onboarding gate and clear any
    //    preference that survived the user's old identity.
    userDefaults.remove(forKey: AppPreferenceKeys.disclaimer)
    userDefaults.remove(forKey: AppPreferenceKeys.legacyOnboarding)
    userDefaults.remove(forKey: AppPreferenceKeys.theme)
    userDefaults.remove(forKey: AppPreferenceKeys.language)
  }
}

/// Step-specific failure type for the erasure orchestration. The
/// `userFacingReason` accessor renders a short, action-oriented message
/// safe to display in the Settings status row (never contains the device
/// UUID or any other PII).
enum DataErasureError: Error, Sendable {
  case requestConstructionFailed
  case network(underlying: Error)
  case unexpectedStatus(Int)
  case localWipeFailed(underlying: Error)
  case keychainWipeFailed(underlying: Error)

  var userFacingReason: String {
    switch self {
    case .requestConstructionFailed:
      return "Could not build the erasure request. Please contact support."
    case .network(let underlying):
      return "Network error contacting the server: \(underlying.localizedDescription)"
    case .unexpectedStatus(let status):
      return "Server refused the erasure request (HTTP \(status)). Local data was not changed."
    case .localWipeFailed(let underlying):
      return "Server data was erased but local cleanup failed: "
        + "\(underlying.localizedDescription). Reinstall the app to finish removing local data."
    case .keychainWipeFailed(let underlying):
      return "Server and local data were erased but key cleanup failed: "
        + "\(underlying.localizedDescription). Reinstall the app to finish."
    }
  }
}
