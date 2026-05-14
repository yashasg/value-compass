import ComposableArchitecture
import SwiftUI

/// Settings screen. Spec requirement: the disclaimer must be accessible from
/// here.
///
/// Reads from `SettingsFeature` and routes preference changes through the
/// reducer's effects so persistence is fully testable.
struct SettingsView: View {
  private let mode: Mode

  init(store: StoreOf<SettingsFeature>) {
    self.mode = .store(store)
  }

  /// Phase 1 → Phase 2 bridge: `MainView` still constructs `SettingsView()`
  /// without arguments and reads/writes preferences via
  /// `@EnvironmentObject AppState`. Until #158 wires the real `Store` and
  /// removes `AppState`, render through `SettingsLegacyBridge` which owns a
  /// short-lived `Store` and mirrors changes back to `AppState` so the rest
  /// of the app keeps observing them.
  init() {
    self.mode = .legacy
  }

  var body: some View {
    switch mode {
    case .store(let store):
      SettingsContent(store: store)
    case .legacy:
      SettingsLegacyBridge()
    }
  }

  private enum Mode {
    case store(StoreOf<SettingsFeature>)
    case legacy
  }
}

private struct SettingsContent: View {
  @Bindable var store: StoreOf<SettingsFeature>

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

/// Phase 1 bridge between the legacy `MainView` (which still calls
/// `SettingsView()` and mutates `AppState.appTheme` / `AppState.appLanguage`)
/// and the new `SettingsFeature`. Owns a short-lived `Store` whose only
/// deviation from the production reducer is an extra `Reduce` that mirrors
/// `theme`/`language` changes back into `AppState` so the rest of the app
/// (which still observes `AppState`) keeps reacting to the user's selections.
///
/// Removed in #158 once the real `Store` is wired at app entry and `AppState`
/// is deleted.
private struct SettingsLegacyBridge: View {
  @EnvironmentObject private var appState: AppState
  @StateObject private var holder = LegacySettingsStoreHolder()

  var body: some View {
    SettingsContent(store: holder.store(syncing: appState))
  }
}

@MainActor
private final class LegacySettingsStoreHolder: ObservableObject {
  private var cachedStore: StoreOf<SettingsFeature>?

  func store(syncing appState: AppState) -> StoreOf<SettingsFeature> {
    if let cachedStore {
      return cachedStore
    }
    let initial = SettingsFeature.State(
      theme: appState.appTheme,
      language: appState.appLanguage
    )
    let store = Store(initialState: initial) {
      SettingsFeature()
      Reduce<SettingsFeature.State, SettingsFeature.Action> { state, action in
        switch action {
        case .binding(\.theme):
          let newTheme = state.theme
          return .run { _ in
            await MainActor.run { appState.appTheme = newTheme }
          }
        case .binding(\.language):
          let newLanguage = state.language
          return .run { _ in
            await MainActor.run { appState.appLanguage = newLanguage }
          }
        default:
          return .none
        }
      }
    }
    cachedStore = store
    return store
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
