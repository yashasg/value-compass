import Foundation

/// Provides a stable per-device UUID, persisted in the Keychain so that it
/// survives app reinstall (within the device-only accessibility constraint).
///
/// The backend identifies anonymous installs by this value. It is generated
/// lazily on first access and never rotated client-side.
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
}
