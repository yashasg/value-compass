import Foundation

/// Provides a stable per-device UUID, persisted in the Keychain so that it
/// survives app reinstall (within the device-only accessibility constraint).
///
/// The backend identifies anonymous installs by this value. It is generated
/// lazily on first access. The Settings → "Erase All My Data" flow
/// (issue #329) is the only legitimate caller of `rotate()`, which severs
/// the link between the pre- and post-erasure identity on the same device.
enum DeviceIDProvider {
  private static let keychainKey = "com.valuecompass.deviceUUID"

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

  /// Removes the persisted device UUID so the next `deviceID()` call
  /// generates and persists a fresh one. Used by the Settings → "Erase
  /// All My Data" flow (issue #329 §1.iii) to break the join between
  /// pre- and post-erasure backend traffic.
  ///
  /// Treats "no entry to remove" as success (delegated to
  /// `KeychainStore.remove`) so the caller can sequence this step
  /// idempotently inside a larger erasure transaction.
  static func rotate() throws {
    try KeychainStore.remove(keychainKey)
  }
}
