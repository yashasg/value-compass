import Foundation

/// Provides a stable per-device UUID, persisted in the Keychain so that it
/// survives app reinstall (within the device-only accessibility constraint).
///
/// The backend identifies anonymous installs by this value. It is generated
/// lazily on first access and rotated only as part of the "Erase All My
/// Data" Settings flow (issue #329) — the GDPR Art. 17 / CCPA §1798.105
/// erasure path that wipes the calling device's backend rows and detaches
/// subsequent traffic from the cleared identity.
enum DeviceIDProvider {
  /// Keychain account under which the device UUID is stored. Exposed
  /// `internal` so `rotate()` and tests can purge / pin the same key the
  /// `deviceID()` accessor reads from without re-deriving the literal.
  static let keychainKey = "com.valuecompass.deviceUUID"

  /// Returns the persisted device UUID, generating and storing one on
  /// first call. If the keychain is unavailable the UUID is returned but
  /// not persisted; the next call will generate a fresh one.
  @discardableResult
  static func deviceID() -> String {
    // `try?` over a throwing `String?`-returning function yields a
    // `String??`. Use a `do/try` block instead — it's clearer and
    // distinguishes "no entry yet" from "keychain failure".
    do {
      if let existing = try KeychainStore.get(keychainKey) {
        return existing
      }
    } catch {
      // Keychain unavailable; fall through and return a fresh UUID
      // without persisting it.
    }
    let new = UUID().uuidString
    try? KeychainStore.set(new, for: keychainKey)
    return new
  }

  /// Discards the persisted device UUID so the next `deviceID()` call
  /// mints a fresh value. Used by the "Erase All My Data" Settings flow
  /// (issue #329) AFTER the backend `DELETE /portfolio` succeeds, so the
  /// next outbound request advertises a clean identity the backend has
  /// no rows against.
  ///
  /// Errors propagate from `KeychainStore.remove` (which already treats
  /// `errSecItemNotFound` as success). Callers — currently only the
  /// erasure flow — must surface failures to the user because rotating the
  /// UUID is a contract the published Privacy Policy makes (see
  /// `docs/legal/privacy-policy.md` §6).
  static func rotate() throws {
    try KeychainStore.remove(keychainKey)
  }
}
