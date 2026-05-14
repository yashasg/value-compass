import ComposableArchitecture
import Foundation

/// Reducer that owns the "update required" UI shown when the backend's
/// `X-Min-App-Version` header indicates the running app is below the minimum
/// supported version.
///
/// Replaces the placeholder reducer added in #148 (the AppFeature shell
/// skeleton). `RootView` still constructs `ForcedUpdateView` from the legacy
/// `MinAppVersionMonitor` flow until #158 wires the real `Store`; the
/// convenience `ForcedUpdateView.init(minimumVersion:)` keeps Phase 0 callers
/// compiling against this reducer in the meantime.
@Reducer
struct ForcedUpdateFeature {
  @ObservableState
  struct State: Equatable {
    var minimumVersion: String?

    init(minimumVersion: String? = nil) {
      self.minimumVersion = minimumVersion
    }
  }

  enum Action: Equatable {
    case openAppStoreTapped
  }

  @Dependency(\.openURL) var openURL
  @Dependency(\.bundleInfo) var bundleInfo

  var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case .openAppStoreTapped:
        return .run { [bundleInfo] _ in
          let url = Self.appStoreURL(appStoreID: bundleInfo.info().appStoreID)
          await openURL(url)
        }
      }
    }
  }

  /// Pure helper so the URL choice is testable without `Bundle.main`. Prefers
  /// the App Store ID configured in Info.plist (`VCAAppStoreID`, surfaced via
  /// `BundleInfoClient`) and falls back to a branded App Store search.
  static func appStoreURL(appStoreID: String?) -> URL {
    if let id = appStoreID, !id.isEmpty,
      let url = URL(string: "itms-apps://itunes.apple.com/app/id\(id)")
    {
      return url
    }
    // Static, known-good URL literal. `URL(string:)` only returns nil for
    // malformed strings; this one is well-formed.
    return URL(string: "https://apps.apple.com/search?term=Investrum")!
  }
}
