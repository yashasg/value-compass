import SwiftUI

/// Cross-cutting app state owned by `VCAApp` and injected as an
/// `@EnvironmentObject` into the view tree.
@MainActor
final class AppState: ObservableObject {
  @Published var hasSeenDisclaimer: Bool {
    didSet {
      userDefaults.set(hasSeenDisclaimer, forKey: Self.disclaimerKey)
    }
  }

  @Published var appTheme: AppTheme {
    didSet {
      userDefaults.set(appTheme.rawValue, forKey: Self.themeKey)
    }
  }

  @Published var appLanguage: AppLanguage {
    didSet {
      userDefaults.set(appLanguage.rawValue, forKey: Self.languageKey)
    }
  }

  static let disclaimerKey = "com.valuecompass.hasSeenDisclaimer"
  static let legacyOnboardingKey = "com.valuecompass.hasCompletedOnboarding"
  static let themeKey = "com.valuecompass.appTheme"
  static let languageKey = "com.valuecompass.appLanguage"
  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
    let migratedHasSeenDisclaimer =
      userDefaults.bool(forKey: Self.disclaimerKey)
      || userDefaults.bool(forKey: Self.legacyOnboardingKey)
    if migratedHasSeenDisclaimer {
      userDefaults.set(true, forKey: Self.disclaimerKey)
    }
    self.hasSeenDisclaimer = migratedHasSeenDisclaimer
    self.appTheme =
      AppTheme(rawValue: userDefaults.string(forKey: Self.themeKey) ?? "") ?? .system
    self.appLanguage =
      AppLanguage(rawValue: userDefaults.string(forKey: Self.languageKey) ?? "") ?? .system
  }

  var hasCompletedOnboarding: Bool {
    get { hasSeenDisclaimer }
    set { hasSeenDisclaimer = newValue }
  }
}

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
