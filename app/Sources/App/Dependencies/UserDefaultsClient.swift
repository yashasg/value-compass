import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `Foundation.UserDefaults` for the
/// disclaimer/theme/language keys that `AppState` reads and writes today.
///
/// Phase 1 reducers consume this via `@Dependency(\.userDefaults)` so they
/// never touch `UserDefaults.standard` directly. The live value reads and
/// writes the real `UserDefaults.standard`; the macro-synthesized
/// `testValue` fails any unimplemented call so reducer tests must
/// explicitly stub each key access.
@DependencyClient
struct UserDefaultsClient: Sendable {
  var bool: @Sendable (_ forKey: String) -> Bool = { _ in false }
  var string: @Sendable (_ forKey: String) -> String? = { _ in nil }
  var setBool: @Sendable (_ value: Bool, _ forKey: String) -> Void
  var setString: @Sendable (_ value: String, _ forKey: String) -> Void
}

extension UserDefaultsClient: DependencyKey {
  static let liveValue: UserDefaultsClient = {
    let defaults = UserDefaults.standard
    return UserDefaultsClient(
      bool: { defaults.bool(forKey: $0) },
      string: { defaults.string(forKey: $0) },
      setBool: { defaults.set($0, forKey: $1) },
      setString: { defaults.set($0, forKey: $1) }
    )
  }()

  static let previewValue: UserDefaultsClient = {
    let storage = LockIsolated<[String: Any]>([:])
    return UserDefaultsClient(
      bool: { key in storage.value[key] as? Bool ?? false },
      string: { key in storage.value[key] as? String },
      setBool: { value, key in storage.withValue { $0[key] = value } },
      setString: { value, key in storage.withValue { $0[key] = value } }
    )
  }()
}

extension DependencyValues {
  var userDefaults: UserDefaultsClient {
    get { self[UserDefaultsClient.self] }
    set { self[UserDefaultsClient.self] = newValue }
  }
}
