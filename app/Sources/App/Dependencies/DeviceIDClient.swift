import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `DeviceIDProvider.deviceID()`.
///
/// Phase 1 reducers consume this via `@Dependency(\.deviceID)` so they
/// never touch the keychain-backed singleton directly. `liveValue` calls
/// the existing provider; the macro-synthesized `testValue` returns the
/// declared default (`""`) and reports any unstubbed access in tests.
///
/// Issue #329 adds `rotate` so the "Erase All My Data" Settings flow can
/// discard the persisted UUID after a successful backend erasure without
/// touching the Keychain directly.
@DependencyClient
struct DeviceIDClient: Sendable {
  var deviceID: @Sendable () -> String = { "" }
  /// Discards the persisted device UUID so the next `deviceID()` call
  /// mints a fresh value. Used by the account-erasure flow after the
  /// backend `DELETE /portfolio` succeeds; throws on Keychain failure so
  /// the flow can surface the error rather than silently completing with
  /// a stale identifier.
  var rotate: @Sendable () throws -> Void
}

extension DeviceIDClient: DependencyKey {
  static let liveValue = DeviceIDClient(
    deviceID: { DeviceIDProvider.deviceID() },
    rotate: { try DeviceIDProvider.rotate() }
  )

  static let previewValue = DeviceIDClient(
    deviceID: { "PREVIEW-DEVICE-UUID" },
    rotate: {}
  )
}

extension DependencyValues {
  var deviceID: DeviceIDClient {
    get { self[DeviceIDClient.self] }
    set { self[DeviceIDClient.self] = newValue }
  }
}
