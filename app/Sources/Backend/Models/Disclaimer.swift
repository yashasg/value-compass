import Foundation

/// Single source of truth for the legal disclaimer.
///
/// Surfaced on the onboarding flow (first launch) and in Settings,
/// as required by the app spec.
enum Disclaimer {
  static let text: String = """
    This tool is for informational and educational purposes only. It does not \
    constitute investment advice. Past price trends do not guarantee future \
    performance. Consult a licensed financial advisor before making investment \
    decisions.
    """
}

/// Single source of truth for outbound legal-document links surfaced in
/// `SettingsView`'s `Legal` section (issue #224) and at the Massive API
/// key entry point (issue #294).
///
/// Until a hosted Privacy Policy URL is published to App Store Connect's
/// "App Privacy Policy URL" field, the in-app link points to the canonical
/// markdown source in this repository so users and App Review reviewers can
/// inspect the policy text that matches the shipping build. The URL is
/// expressed as a literal so the compiler-verified `URL(string:)!`
/// force-unwrap stays static; updating the URL after a public hosting
/// location exists requires changing only this constant and re-running the
/// re-validation hook recorded in `loop-strategy.md`.
///
/// The Massive Terms of Service and Privacy Policy URLs surfaced at the
/// API-key-entry point (App Store Review Guideline §5.2.3 — third-party
/// services) point to Massive's canonical legal pages at
/// `https://massive.com/legal/...`. The register of every third-party
/// service the app surfaces, the URLs verified against the operator's
/// site, and the re-verification trigger are recorded in
/// `docs/legal/third-party-services.md`.
enum LegalLinks {
  /// Canonical privacy-policy location (markdown source-of-truth in the
  /// public repository). Replace with the hosted-policy URL once the
  /// publisher confirms the App Store Connect "Privacy Policy URL" field.
  static let privacyPolicy: URL = URL(
    string: "https://github.com/yashasg/value-compass/blob/main/docs/legal/privacy-policy.md"
  )!

  /// Massive's published Terms of Service. Surfaced inside the Settings →
  /// Massive API Key section so the user can review the third-party
  /// terms that govern their key use before tapping Save (issue #294).
  /// Verified against `massive.com` on the most recent re-verification
  /// recorded in `docs/legal/third-party-services.md`; update both this
  /// constant and that doc together if Massive renames the page.
  static let massiveTermsOfService: URL = URL(
    string: "https://massive.com/legal/terms"
  )!

  /// Massive's published Privacy Policy. Same surfacing rationale and
  /// re-verification trigger as `massiveTermsOfService` (issue #294).
  static let massivePrivacyPolicy: URL = URL(
    string: "https://massive.com/legal/privacy"
  )!
}
