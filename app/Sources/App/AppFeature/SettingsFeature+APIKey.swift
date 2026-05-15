import Foundation

/// Settings-side view of the persisted Massive API key (issue #127).
enum SettingsAPIKeyStatus: Equatable, Sendable {
  /// No key has been saved yet.
  case noStoredKey
  /// The most recent successful save / revalidation accepted the stored key.
  case storedAndValid
  /// A key is still on disk but the most recent revalidation failed. The UI
  /// surfaces this as "stored key may be invalid — re-enter to refresh".
  /// `reason` is a human-readable explanation (never the key itself).
  case storedButLastCheckFailed(reason: String)
}

/// Outcome of the most recent draft / revalidation request initiated from
/// the API key entry form. Drives inline error banners; the "key on disk"
/// state itself lives on `SettingsAPIKeyStatus`.
enum SettingsAPIKeyRequestStatus: Equatable, Sendable {
  case idle
  case validating
  case rejected(reason: String)
  case networkError(reason: String)
  case storeError(reason: String)
  case savedSuccessfully

  var isInFlight: Bool {
    if case .validating = self { return true }
    return false
  }
}

/// Status of the in-app "Erase All My Data" flow (issue #329) — the GDPR
/// Art. 17 / CCPA §1798.105 / App Store §5.1.1(v) right-to-erasure path.
///
/// The state machine is intentionally serial: a single `erasing` window
/// covers the entire pipeline (backend `DELETE /portfolio` → SwiftData wipe
/// → Massive Keychain wipe → device-UUID rotation → onboarding-gate reset)
/// so the View layer can disable the destructive button for as long as any
/// step is still running. `failed` carries a human-readable reason so the
/// inline status row can tell the user whether to retry online or whether
/// the backend succeeded but local cleanup did not.
enum SettingsAccountErasureStatus: Equatable, Sendable {
  /// Nothing in flight; the destructive button is enabled.
  case idle
  /// Backend erasure (and the subsequent local cleanup) is running.
  case erasing
  /// Every step (backend, SwiftData, Keychain, UUID rotation, onboarding
  /// reset) completed successfully. The view layer surfaces a copy
  /// instructing the user to relaunch Investrum so the freshly reset
  /// onboarding gate fires.
  case erased
  /// At least one step in the pipeline failed. `reason` distinguishes
  /// "network error, nothing was erased — safe to retry" from "backend
  /// succeeded but local cleanup failed — reinstall to fully clear".
  case failed(reason: String)

  var isInFlight: Bool {
    if case .erasing = self { return true }
    return false
  }
}
