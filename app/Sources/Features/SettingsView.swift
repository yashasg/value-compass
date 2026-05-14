import SwiftUI

/// Settings screen. Spec requirement: the disclaimer must be accessible from
/// here.
struct SettingsView: View {
  @EnvironmentObject private var appState: AppState
  @State private var isDisclaimerExpanded = false

  var body: some View {
    Form {
      Section("Preferences") {
        Picker("Theme", selection: $appState.appTheme) {
          ForEach(AppTheme.allCases) { theme in
            Text(theme.label).tag(theme)
          }
        }
        .accessibilityIdentifier("settings.theme")

        Picker("Language", selection: $appState.appLanguage) {
          ForEach(AppLanguage.allCases) { language in
            Text(language.label).tag(language)
          }
        }
        .accessibilityIdentifier("settings.language")
      }

      Section("About") {
        LabeledContent("Version", value: Self.appVersionString)
        LabeledContent(
          "Device ID", value: String(DeviceIDProvider.deviceID().prefix(8)) + "\u{2026}")
      }

      Section("Legal") {
        DisclosureGroup("Disclaimer", isExpanded: $isDisclaimerExpanded) {
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
  }

  private static var appVersionString: String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    let build = info?["CFBundleVersion"] as? String ?? "0"
    return "\(short) (\(build))"
  }
}
