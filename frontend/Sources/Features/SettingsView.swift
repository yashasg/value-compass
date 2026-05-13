import SwiftUI

/// Settings screen. Spec requirement: the disclaimer must be accessible from
/// here.
struct SettingsView: View {
  var body: some View {
    Form {
      Section("About") {
        LabeledContent("Version", value: Self.appVersionString)
        LabeledContent(
          "Device ID", value: String(DeviceIDProvider.deviceID().prefix(8)) + "\u{2026}")
      }

      Section("Disclaimer") {
        Text(Disclaimer.text)
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appContentSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("settings.disclaimer")
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
