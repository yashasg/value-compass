import ComposableArchitecture
import SwiftUI

/// Settings screen. Spec requirement: the disclaimer must be accessible from
/// here.
///
/// Reads from `SettingsFeature` and routes preference changes through the
/// reducer's effects so persistence is fully testable.
struct SettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  /// Convenience initializer for legacy callers (`MainView`,
  /// `PortfolioListView` legacy bridge) that construct `SettingsView` without
  /// a parent store. Spawns a self-contained `SettingsFeature` store; the
  /// reducer's `.task` effect immediately rehydrates `theme` / `language`
  /// from `UserDefaults` (via `@Dependency(\.userDefaults)`) and persists
  /// future binding changes the same way, so behavior is bit-identical to
  /// the legacy `AppState`-backed path. Removed when `MainFeature.shell`
  /// passes a scoped settings store directly (#159).
  init() {
    self.init(
      store: Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
      }
    )
  }

  var body: some View {
    Form {
      Section("Preferences") {
        Picker("Theme", selection: $store.theme) {
          ForEach(AppTheme.allCases) { theme in
            Text(theme.label).tag(theme)
          }
        }
        .accessibilityIdentifier("settings.theme")

        Picker("Language", selection: $store.language) {
          ForEach(AppLanguage.allCases) { language in
            Text(language.label).tag(language)
          }
        }
        .accessibilityIdentifier("settings.language")
      }

      Section("About") {
        LabeledContent("Version", value: store.appVersion)
        LabeledContent("Device ID", value: store.deviceIDPrefix)
      }

      Section("Legal") {
        DisclosureGroup("Disclaimer", isExpanded: $store.isDisclaimerExpanded) {
          Text(Disclaimer.text)
            .valueCompassTextStyle(.bodySmall)
            .foregroundStyle(Color.appContentSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("settings.disclaimer")
        }
        .accessibilityIdentifier("settings.disclaimer.toggle")
      }
    }
    .navigationTitle("Settings")
    .tint(Color.appPrimary)
    .task { store.send(.task) }
  }
}

#Preview("SettingsView") {
  NavigationStack {
    SettingsView(
      store: Store(
        initialState: SettingsFeature.State(
          theme: .system,
          language: .system,
          appVersion: "1.0.0 (1)",
          deviceIDPrefix: "12345678\u{2026}"
        )
      ) {
        SettingsFeature()
      }
    )
  }
}
