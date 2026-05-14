import ComposableArchitecture

/// Reducer that drives `SettingsView` — the preferences / about / legal screen
/// reachable from the portfolio toolbar (compact) and the iPad split-view
/// sidebar.
///
/// Persists `theme` and `language` selections to `UserDefaults` via
/// `@Dependency(\.userDefaults)` so the same keys read by `AppState` keep
/// surviving across launches. App version + device ID are pulled from
/// `@Dependency(\.bundleInfo)` and `@Dependency(\.deviceID)` so the view never
/// reaches into `Bundle.main` or the keychain-backed `DeviceIDProvider`.
///
/// Phase 2 (#158) replaces the legacy `AppState`-backed bridge in
/// `SettingsView.init()` once the real `Store` is wired at app entry.
@Reducer
struct SettingsFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var theme: AppTheme = .system
    var language: AppLanguage = .system
    var isDisclaimerExpanded: Bool = false
    var appVersion: String = ""
    var deviceIDPrefix: String = ""
  }

  enum Action: BindableAction, Equatable, Sendable {
    case binding(BindingAction<State>)
    case task
  }

  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.bundleInfo) var bundleInfo
  @Dependency(\.deviceID) var deviceID

  /// `UserDefaults` keys mirrored from `AppState` so reducer reads/writes hit
  /// the same persisted values the legacy `AppState` does. #158 deletes
  /// `AppState` once the `Store` is wired at app entry.
  private enum DefaultsKey {
    static let theme = "com.valuecompass.appTheme"
    static let language = "com.valuecompass.appLanguage"
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .task:
        let storedTheme = userDefaults.string(forKey: DefaultsKey.theme) ?? ""
        state.theme = AppTheme(rawValue: storedTheme) ?? .system
        let storedLanguage = userDefaults.string(forKey: DefaultsKey.language) ?? ""
        state.language = AppLanguage(rawValue: storedLanguage) ?? .system
        let info = bundleInfo.info()
        state.appVersion = "\(info.shortVersionString) (\(info.bundleVersion))"
        state.deviceIDPrefix = String(deviceID.deviceID().prefix(8)) + "\u{2026}"
        return .none

      case .binding(\.theme):
        userDefaults.setString(value: state.theme.rawValue, forKey: DefaultsKey.theme)
        return .none

      case .binding(\.language):
        userDefaults.setString(value: state.language.rawValue, forKey: DefaultsKey.language)
        return .none

      case .binding:
        return .none
      }
    }
  }
}
