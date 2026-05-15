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

      apiKeySection

      Section("About") {
        LabeledContent("Version", value: store.appVersion)
        LabeledContent("Device ID", value: store.deviceIDPrefix)
      }

      dataPrivacySection

      Section("Legal") {
        DisclosureGroup("Disclaimer", isExpanded: $store.isDisclaimerExpanded) {
          Text(Disclaimer.text)
            .valueCompassTextStyle(.bodySmall)
            .foregroundStyle(Color.appContentSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("settings.disclaimer")
        }
        .accessibilityIdentifier("settings.disclaimer.toggle")

        Link(destination: LegalLinks.privacyPolicy) {
          HStack {
            Text("Privacy Policy")
            Spacer()
            Image(systemName: "arrow.up.right.square")
              .foregroundStyle(Color.appContentSecondary)
              .accessibilityHidden(true)
          }
          .contentShape(Rectangle())
        }
        .accessibilityIdentifier("settings.privacyPolicy.link")
        .accessibilityHint("Opens the Investrum Privacy Policy in your browser.")
      }
    }
    .navigationTitle("Settings")
    .tint(Color.appPrimary)
    .task { store.send(.task) }
    .confirmationDialog(
      $store.scope(state: \.dataErasureConfirmation, action: \.dataErasureConfirmation)
    )
  }

  // MARK: - Massive API key (issue #127)

  /// Massive API key management section. Always renders an entry field for a
  /// new / replacement key plus a status row that adapts to whether a key is
  /// already stored. The raw key never appears in `apiKeyMaskedDisplay`; the
  /// reducer only forwards a bullet-prefixed suffix.
  ///
  /// A `Section` footer plus two `Link` rows surface Massive's Terms of
  /// Service and Privacy Policy so the user can review the third-party data
  /// flow that the saved key triggers (issue #294 — App Store Review
  /// Guideline §5.2.3, GDPR Art. 13(1)(e), and Cal. Civ. Code §1798.130).
  /// Saving a key POSTs it to `https://api.massive.com` under the user's
  /// `Authorization: Bearer` header; the disclosure must therefore be
  /// reachable before the Save action.
  @ViewBuilder
  private var apiKeySection: some View {
    Section {
      apiKeyStatusRow
      apiKeyEntryRow
      apiKeyRequestStatusRow

      if let loadError = store.apiKeyLoadError {
        Text("Stored key could not be read: \(loadError)")
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appNegative)
          .accessibilityIdentifier("settings.apiKey.loadError")
      }

      Link(destination: LegalLinks.massiveTermsOfService) {
        HStack {
          Text("Massive Terms of Service")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .foregroundStyle(Color.appContentSecondary)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
      }
      .accessibilityIdentifier("settings.apiKey.massiveTerms.link")
      .accessibilityHint("Opens Massive's Terms of Service in your browser.")

      Link(destination: LegalLinks.massivePrivacyPolicy) {
        HStack {
          Text("Massive Privacy Policy")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .foregroundStyle(Color.appContentSecondary)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
      }
      .accessibilityIdentifier("settings.apiKey.massivePrivacy.link")
      .accessibilityHint("Opens Massive's Privacy Policy in your browser.")
    } header: {
      Text("Massive API Key")
    } footer: {
      Text(
        "Your key is sent to Massive (api.massive.com) to authenticate "
          + "market-data requests. Your use of the key is governed by "
          + "Massive's Terms of Service and Privacy Policy, linked below."
      )
      .accessibilityIdentifier("settings.apiKey.thirdPartyDisclosure")
    }
  }

  @ViewBuilder
  private var apiKeyStatusRow: some View {
    switch store.apiKeyStatus {
    case .noStoredKey:
      Text("No API key saved.")
        .valueCompassTextStyle(.bodySmall)
        .foregroundStyle(Color.appContentSecondary)
        .accessibilityIdentifier("settings.apiKey.status.empty")
    case .storedAndValid:
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Saved key")
            .valueCompassTextStyle(.bodySmall)
            .foregroundStyle(Color.appContentSecondary)
          Text(store.apiKeyMaskedDisplay ?? "")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.apiKeyMaskedAccessibilityLabel ?? "Saved API key")
        .accessibilityIdentifier("settings.apiKey.maskedDisplay")
        Spacer()
        Button("Re-validate") {
          store.send(.revalidateStoredKeyTapped)
        }
        .accessibilityIdentifier("settings.apiKey.revalidate")
        .disabled(store.apiKeyRequestStatus.isInFlight)

        Button(role: .destructive) {
          store.send(.removeAPIKeyTapped)
        } label: {
          Text("Remove")
        }
        .accessibilityIdentifier("settings.apiKey.remove")
        .disabled(store.apiKeyRequestStatus.isInFlight)
      }
    case .storedButLastCheckFailed(let reason):
      VStack(alignment: .leading, spacing: 4) {
        Text("Saved key may be invalid: \(reason)")
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appNegative)
          .accessibilityIdentifier("settings.apiKey.status.failed")
        if let mask = store.apiKeyMaskedDisplay {
          Text(mask)
            .accessibilityLabel(store.apiKeyMaskedAccessibilityLabel ?? "Saved API key")
            .accessibilityIdentifier("settings.apiKey.maskedDisplay")
        }
        HStack {
          Button("Re-validate") {
            store.send(.revalidateStoredKeyTapped)
          }
          .accessibilityIdentifier("settings.apiKey.revalidate")
          .disabled(store.apiKeyRequestStatus.isInFlight)

          Button(role: .destructive) {
            store.send(.removeAPIKeyTapped)
          } label: {
            Text("Remove")
          }
          .accessibilityIdentifier("settings.apiKey.remove")
          .disabled(store.apiKeyRequestStatus.isInFlight)
        }
      }
    }
  }

  @ViewBuilder
  private var apiKeyEntryRow: some View {
    HStack {
      SecureField("Enter API key", text: $store.apiKeyDraft)
        .textContentType(.password)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .accessibilityIdentifier("settings.apiKey.draftField")

      Button("Save") {
        store.send(.saveAPIKeyTapped)
      }
      .accessibilityIdentifier("settings.apiKey.save")
      .disabled(
        store.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          || store.apiKeyRequestStatus.isInFlight)
    }
  }

  @ViewBuilder
  private var apiKeyRequestStatusRow: some View {
    switch store.apiKeyRequestStatus {
    case .idle:
      EmptyView()
    case .validating:
      HStack(spacing: 8) {
        ProgressView()
        Text("Validating with Massive…")
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appContentSecondary)
      }
      .accessibilityIdentifier("settings.apiKey.request.validating")
    case .rejected(let reason):
      Text("Rejected: \(reason)")
        .valueCompassTextStyle(.bodySmall)
        .foregroundStyle(Color.appNegative)
        .accessibilityIdentifier("settings.apiKey.request.rejected")
    case .networkError(let reason):
      Text("Network error: \(reason)")
        .valueCompassTextStyle(.bodySmall)
        .foregroundStyle(Color.appNegative)
        .accessibilityIdentifier("settings.apiKey.request.networkError")
    case .storeError(let reason):
      Text("Could not save key: \(reason)")
        .valueCompassTextStyle(.bodySmall)
        .foregroundStyle(Color.appNegative)
        .accessibilityIdentifier("settings.apiKey.request.storeError")
    case .savedSuccessfully:
      Text("API key saved.")
        .valueCompassTextStyle(.bodySmall)
        .foregroundStyle(Color.appPositive)
        .accessibilityIdentifier("settings.apiKey.request.saved")
    }
  }

  // MARK: - Data & Privacy (issue #329)

  /// "Erase All My Data" surface mandated by App Store §5.1.1(v), GDPR
  /// Art. 17, and CCPA §1798.105. Renders as a destructive `Button`
  /// (`role: .destructive`) inside a dedicated section so it cannot be
  /// confused with the local-only API-key removal above. The actual
  /// confirmation dialog + irreversible chain is owned by
  /// `SettingsFeature` — this view only dispatches `eraseAllDataTapped`
  /// and renders the status row.
  @ViewBuilder
  private var dataPrivacySection: some View {
    Section {
      Button(role: .destructive) {
        store.send(.eraseAllDataTapped)
      } label: {
        HStack {
          Text("Erase All My Data")
          Spacer()
          if case .deleting = store.dataErasureStatus {
            ProgressView()
          }
        }
      }
      .accessibilityIdentifier("settings.dataErasure.eraseAllData")
      .accessibilityHint(
        "Permanently deletes your portfolios, holdings, and saved key from this device and the server."
      )
      .disabled(store.dataErasureStatus.isInFlight)

      dataErasureStatusRow
    } header: {
      Text("Data & Privacy")
    } footer: {
      Text(
        "Erasing your data removes every portfolio, holding, and "
          + "calculation history entry from this device and from Value "
          + "Compass's servers, rotates your anonymous device identity, "
          + "and signs you back to the welcome screen."
      )
      .accessibilityIdentifier("settings.dataErasure.disclosure")
    }
  }

  @ViewBuilder
  private var dataErasureStatusRow: some View {
    switch store.dataErasureStatus {
    case .idle, .awaitingConfirmation:
      EmptyView()
    case .deleting:
      HStack(spacing: 8) {
        ProgressView()
        Text("Erasing your data…")
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appContentSecondary)
      }
      .accessibilityIdentifier("settings.dataErasure.status.deleting")
    case .succeeded:
      HStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(Color.appPositive)
          .accessibilityHidden(true)
        Text("Your data has been erased.")
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appPositive)
      }
      .accessibilityIdentifier("settings.dataErasure.status.succeeded")
    case .failed(let reason):
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(Color.appNegative)
            .accessibilityHidden(true)
          Text("Could not erase your data.")
            .valueCompassTextStyle(.bodySmall)
            .foregroundStyle(Color.appNegative)
        }
        Text(reason)
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appContentSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("settings.dataErasure.status.failed")
    }
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
