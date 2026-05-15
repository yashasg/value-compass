import ComposableArchitecture
import ConcurrencyExtras
import Foundation

/// `@DependencyClient` wrapper around `MassiveAPIKeyStoring` (issue #127).
///
/// Reducers (currently `SettingsFeature` for the API key management screen)
/// consume this via `@Dependency(\.massiveAPIKey)` instead of touching
/// `KeychainStore` or `KeychainMassiveAPIKeyStore` directly. The
/// macro-synthesized `testValue` makes any unstubbed call fail loudly so
/// `TestStore`-based tests have to opt in to fake behaviour.
@DependencyClient
struct MassiveAPIKeyClient: Sendable {
  /// Returns the stored Massive API key, or `nil` if no key is persisted.
  var load: @Sendable () throws -> String?
  /// Persists `key`. Implementations trim surrounding whitespace and treat
  /// an empty / whitespace-only value as a delete.
  var save: @Sendable (_ key: String) throws -> Void
  /// Removes any persisted key. Idempotent.
  var delete: @Sendable () throws -> Void
}

extension MassiveAPIKeyClient: DependencyKey {
  static let liveValue: MassiveAPIKeyClient = {
    let store = KeychainMassiveAPIKeyStore()
    return MassiveAPIKeyClient(
      load: { try store.loadKey() },
      save: { key in try store.saveKey(key) },
      delete: { try store.deleteKey() }
    )
  }()

  static let previewValue: MassiveAPIKeyClient = {
    let storage = LockIsolated<String?>(nil)
    return MassiveAPIKeyClient(
      load: { storage.value },
      save: { key in
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        storage.setValue(trimmed.isEmpty ? nil : trimmed)
      },
      delete: { storage.setValue(nil) }
    )
  }()
}

extension DependencyValues {
  var massiveAPIKey: MassiveAPIKeyClient {
    get { self[MassiveAPIKeyClient.self] }
    set { self[MassiveAPIKeyClient.self] = newValue }
  }
}
