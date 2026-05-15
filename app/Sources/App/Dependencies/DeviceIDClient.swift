import ComposableArchitecture
import ConcurrencyExtras
import Foundation

/// `@DependencyClient` wrapper around `DeviceIDProvider.deviceID()`.
///
/// Phase 1 reducers consume this via `@Dependency(\.deviceID)` so they
/// never touch the keychain-backed singleton directly. `liveValue` calls
/// the existing provider; the macro-synthesized `testValue` returns the
/// declared default (`""`) and reports any unstubbed access in tests.
///
/// `rotate` removes the persisted Keychain entry so the next `deviceID()`
/// call generates a fresh UUID. Used by the Settings → "Erase All My Data"
/// flow (issue #329 §1.iii) to sever the link between pre- and
/// post-erasure traffic on the same device.
@DependencyClient
struct DeviceIDClient: Sendable {
  var deviceID: @Sendable () -> String = { "" }
  var rotate: @Sendable () throws -> Void
}

extension DeviceIDClient: DependencyKey {
  static let liveValue = DeviceIDClient(
    deviceID: { DeviceIDProvider.deviceID() },
    rotate: { try DeviceIDProvider.rotate() }
  )

  static let previewValue: DeviceIDClient = {
    let storage = LockIsolated<String>("PREVIEW-DEVICE-UUID")
    return DeviceIDClient(
      deviceID: { storage.value },
      rotate: { storage.setValue(UUID().uuidString) }
    )
  }()
}

extension DependencyValues {
  var deviceID: DeviceIDClient {
    get { self[DeviceIDClient.self] }
    set { self[DeviceIDClient.self] = newValue }
  }
}
