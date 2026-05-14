import ComposableArchitecture
import SwiftData
import SwiftUI

/// SwiftUI app entry point.
///
/// Phase 2 (#158): a single `Store` rooted at `AppFeature` drives every
/// subsequent reduction. The legacy `AppState`, `MinAppVersionMonitor.shared`,
/// and `PushNotificationManager.shared` SwiftUI state objects are gone — the
/// equivalent state lives in `AppFeature.State` and the cross-process bridges
/// in `MinAppVersionClient` / `PushNotificationsClient`.
///
/// `modelContainer` survives because SwiftData `@Model` lifecycles still need
/// it (queries inside views, `BackgroundModelActor` for reducer effects). The
/// preferred color scheme is read from the `UserDefaults` key
/// `AppPreferenceKeys.theme` and refreshed on `UserDefaults.didChangeNotification`
/// so a theme switch in `SettingsView` (which writes through
/// `SettingsFeature` → `UserDefaultsClient`) propagates back to the root.
@main
struct VCAApp: App {
  #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  #endif

  @State private var preferredScheme: ColorScheme? = VCAApp.loadPreferredColorScheme()

  private let modelContainer: ModelContainer
  private let store: StoreOf<AppFeature>

  init() {
    do {
      self.modelContainer = try LocalPersistence.makeModelContainer()
    } catch {
      fatalError("Unable to initialize SwiftData container: \(error)")
    }
    self.store = Store(initialState: AppFeature.State()) {
      AppFeature()
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView(store: store)
        .modelContainer(modelContainer)
        .preferredColorScheme(preferredScheme)
        .onReceive(
          NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
        ) { _ in
          let next = VCAApp.loadPreferredColorScheme()
          if next != preferredScheme {
            preferredScheme = next
          }
        }
    }
  }

  /// Reads the persisted theme from `UserDefaults.standard` and returns the
  /// SwiftUI color scheme it maps to. `nil` means "follow system" — both for
  /// missing/invalid persisted values and for the explicit `.system` choice.
  static func loadPreferredColorScheme(
    userDefaults: UserDefaults = .standard
  ) -> ColorScheme? {
    let raw = userDefaults.string(forKey: AppPreferenceKeys.theme) ?? ""
    return AppTheme(rawValue: raw)?.preferredColorScheme
  }
}
