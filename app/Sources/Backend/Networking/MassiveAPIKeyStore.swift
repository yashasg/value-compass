import Foundation

/// Errors surfaced by `MassiveAPIKeyStoring` implementations. The wrapped
/// description is human-readable but intentionally contains no key material.
enum MassiveAPIKeyStoreError: Error, Equatable, Sendable {
  case underlying(String)
}

/// Persists the user's Massive API key for issue #127.
///
/// Implementations must keep the secret out of SwiftData, `UserDefaults`,
/// logs, fixtures, and any value that crosses the App/Feature boundary —
/// callers receive the raw key only when explicitly loading it for a
/// validation request.
protocol MassiveAPIKeyStoring: Sendable {
  /// Returns the stored key, or `nil` when no key has been saved.
  func loadKey() throws -> String?

  /// Persists `key` after trimming surrounding whitespace. Saving an empty
  /// string is treated as a delete so callers can normalise the "user
  /// cleared the field" path through a single entry point.
  func saveKey(_ key: String) throws

  /// Removes any persisted key. Idempotent — calling on an empty store is
  /// not an error.
  func deleteKey() throws
}

/// Default `MassiveAPIKeyStoring` implementation backed by `KeychainStore`.
///
/// The key is bound to a dedicated keychain account so it cannot collide
/// with `DeviceIDProvider` or any other future secret. Errors from the
/// underlying Security framework are wrapped in
/// `MassiveAPIKeyStoreError.underlying(...)` to keep call sites (and tests)
/// from depending on `OSStatus`.
///
/// The backing get/save/remove operations are injectable so the policy
/// (trim, empty == delete, non-empty get returns value, empty get returns
/// nil) is unit-testable without exercising the real iOS Keychain — which
/// is unreachable from non-host XCTest bundles on the simulator
/// (`errSecMissingEntitlement = -34018`).
struct KeychainMassiveAPIKeyStore: MassiveAPIKeyStoring {
  /// Default keychain account name used for the Massive API key.
  ///
  /// Namespaced under `com.valuecompass.massive.*` so future Massive-related
  /// secrets (refresh tokens, etc.) can share the prefix without disturbing
  /// the existing entry.
  static let defaultKeychainAccount = "com.valuecompass.massive.apiKey"

  let account: String
  private let _load: @Sendable (String) throws -> String?
  private let _save: @Sendable (String, String) throws -> Void
  private let _remove: @Sendable (String) throws -> Void

  init(
    account: String = Self.defaultKeychainAccount,
    load: @escaping @Sendable (String) throws -> String? = KeychainStore.get,
    save: @escaping @Sendable (String, String) throws -> Void = { value, key in
      try KeychainStore.set(value, for: key)
    },
    remove: @escaping @Sendable (String) throws -> Void = KeychainStore.remove
  ) {
    self.account = account
    self._load = load
    self._save = save
    self._remove = remove
  }

  func loadKey() throws -> String? {
    do {
      guard let raw = try _load(account), !raw.isEmpty else {
        return nil
      }
      return raw
    } catch {
      throw MassiveAPIKeyStoreError.underlying(String(describing: error))
    }
  }

  func saveKey(_ key: String) throws {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      try deleteKey()
      return
    }
    do {
      try _save(trimmed, account)
    } catch {
      throw MassiveAPIKeyStoreError.underlying(String(describing: error))
    }
  }

  func deleteKey() throws {
    do {
      try _remove(account)
    } catch {
      throw MassiveAPIKeyStoreError.underlying(String(describing: error))
    }
  }
}

/// Renders a Massive API key for UI display without leaking the full secret.
///
/// Returns a string of the form `"••••WXYZ"` for keys with at least four
/// usable characters, falling back to all-bullets for shorter strings (and
/// `nil` for empty/whitespace-only input). Callers should pass this through
/// the view layer rather than storing the raw key in reducer state.
enum MassiveAPIKeyMask {
  static let bulletCount = 4

  static func mask(_ key: String) -> String? {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let bullets = String(repeating: "\u{2022}", count: bulletCount)
    if trimmed.count <= bulletCount {
      return bullets
    }
    let suffix = String(trimmed.suffix(bulletCount))
    return bullets + suffix
  }
}
