import SwiftUI

/// User-facing color theme stored in `UserDefaults` and surfaced through
/// `SettingsFeature`. Replaces the `AppTheme` previously housed in
/// `AppState.swift` (deleted in #158 when the legacy `ObservableObject`
/// singleton was removed).
enum AppTheme: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var label: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }

  var preferredColorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}

/// User-facing language stored in `UserDefaults` and surfaced through
/// `SettingsFeature`. Replaces the `AppLanguage` previously housed in
/// `AppState.swift`.
enum AppLanguage: String, CaseIterable, Identifiable {
  case system
  case english

  var id: String { rawValue }

  var label: String {
    switch self {
    case .system: return "System"
    case .english: return "English"
    }
  }
}

/// `UserDefaults` keys that span features (disclaimer gate, theme, language).
/// Owned here so neither `AppFeature` nor `SettingsFeature` has to redeclare
/// the literal strings — both reducers reference these constants via their
/// `@Dependency(\.userDefaults)` reads/writes.
enum AppPreferenceKeys {
  static let disclaimer = "com.valuecompass.hasSeenDisclaimer"
  static let legacyOnboarding = "com.valuecompass.hasCompletedOnboarding"
  static let theme = "com.valuecompass.appTheme"
  static let language = "com.valuecompass.appLanguage"
}
