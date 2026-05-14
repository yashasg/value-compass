import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `KeychainStore`.
///
/// Phase 1 reducers consume this via `@Dependency(\.keychain)` instead of
/// calling `KeychainStore.set(_:for:)` / `KeychainStore.get(_:)` directly.
/// `liveValue` delegates to the existing `KeychainStore` implementation;
/// the macro-synthesized `testValue` makes any unstubbed call fail loudly.
@DependencyClient
struct KeychainClient: Sendable {
  var get: @Sendable (_ key: String) throws -> String?
  var set: @Sendable (_ value: String, _ for: String) throws -> Void
}

extension KeychainClient: DependencyKey {
  static let liveValue = KeychainClient(
    get: { key in try KeychainStore.get(key) },
    set: { value, key in try KeychainStore.set(value, for: key) }
  )

  static let previewValue: KeychainClient = {
    let storage = LockIsolated<[String: String]>([:])
    return KeychainClient(
      get: { key in storage.value[key] },
      set: { value, key in storage.withValue { $0[key] = value } }
    )
  }()
}

extension DependencyValues {
  var keychain: KeychainClient {
    get { self[KeychainClient.self] }
    set { self[KeychainClient.self] = newValue }
  }
}
