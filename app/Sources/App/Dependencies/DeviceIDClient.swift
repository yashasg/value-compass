import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `DeviceIDProvider.deviceID()`.
///
/// Phase 1 reducers consume this via `@Dependency(\.deviceID)` so they
/// never touch the keychain-backed singleton directly. `liveValue` calls
/// the existing provider; the macro-synthesized `testValue` returns the
/// declared default (`""`) and reports any unstubbed access in tests.
@DependencyClient
struct DeviceIDClient: Sendable {
  var deviceID: @Sendable () -> String = { "" }
}

extension DeviceIDClient: DependencyKey {
  static let liveValue = DeviceIDClient(
    deviceID: { DeviceIDProvider.deviceID() }
  )

  static let previewValue = DeviceIDClient(
    deviceID: { "PREVIEW-DEVICE-UUID" }
  )
}

extension DependencyValues {
  var deviceID: DeviceIDClient {
    get { self[DeviceIDClient.self] }
    set { self[DeviceIDClient.self] = newValue }
  }
}
