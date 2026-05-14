import ComposableArchitecture
import Foundation

/// Snapshot of the `Bundle.main` values the app reads to identify itself
/// and locate its backend. Aggregated here so reducers don't reach into
/// `Bundle.main.infoDictionary` directly.
struct BundleInfo: Equatable, Sendable {
  var shortVersionString: String
  var bundleVersion: String
  var appStoreID: String?
  var apiBaseURLString: String?
}

/// `@DependencyClient` wrapper around `Bundle.main.infoDictionary`.
///
/// Centralizes the version, build number, App Store ID, and `VCAAPIBaseURL`
/// reads currently scattered across `SettingsView`, `ForcedUpdateView`,
/// `MinAppVersionMonitor`, and `APIClient`. Phase 1 reducers consume this
/// via `@Dependency(\.bundleInfo)`.
@DependencyClient
struct BundleInfoClient: Sendable {
  var info: @Sendable () -> BundleInfo = {
    BundleInfo(
      shortVersionString: "0.0.0",
      bundleVersion: "0",
      appStoreID: nil,
      apiBaseURLString: nil
    )
  }
}

extension BundleInfoClient: DependencyKey {
  static let liveValue: BundleInfoClient = {
    return BundleInfoClient(
      info: {
        let dict = Bundle.main.infoDictionary ?? [:]
        return BundleInfo(
          shortVersionString: dict["CFBundleShortVersionString"] as? String ?? "0.0.0",
          bundleVersion: dict["CFBundleVersion"] as? String ?? "0",
          appStoreID: (dict["VCAAppStoreID"] as? String).flatMap { $0.isEmpty ? nil : $0 },
          apiBaseURLString: (dict["VCAAPIBaseURL"] as? String).flatMap {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
          }
        )
      }
    )
  }()

  static let previewValue = BundleInfoClient(
    info: {
      BundleInfo(
        shortVersionString: "1.0.0",
        bundleVersion: "1",
        appStoreID: nil,
        apiBaseURLString: nil
      )
    }
  )
}

extension DependencyValues {
  var bundleInfo: BundleInfoClient {
    get { self[BundleInfoClient.self] }
    set { self[BundleInfoClient.self] = newValue }
  }
}
