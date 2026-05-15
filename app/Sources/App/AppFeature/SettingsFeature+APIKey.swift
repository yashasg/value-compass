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
