import Foundation

/// Provides the value of the `X-App-Attest` HTTP header attached to every
/// backend request that requires App Attest (every request except `/health`,
/// see ``APIClient/appAttestRequired(for:)``).
///
/// **MVP behavior — placeholder token.** Real cryptographic attestation via
/// `DCAppAttestService` is intentionally deferred for v1. Production traffic
/// is fronted by Cloudflare / Apple App Attest infrastructure that performs
/// the actual verification (see `backend/api/main.py:require_app_attest`,
/// which only checks for a non-empty header). This provider returns a
/// non-empty placeholder so reducers using the shared `APIClient` transport
/// satisfy that contract today and don't fail with `401 appAttestMissing`
/// for `/schema/version`, `/portfolio/status`, `/portfolio/data`, and
/// `/portfolio/holdings`.
///
/// Debug builds (and CI smoke tests) can override the placeholder by
/// declaring `VCAAppAttestToken` in their `Info.plist`. When no override is
/// configured, the value falls back to ``mvpPlaceholderToken``.
///
/// Tracked follow-up: replace the placeholder with a `DCAppAttestService`
/// integration that generates a per-request assertion and threads it through
/// `APIClient.send`.
enum AppAttestProvider {
  /// `Info.plist` key that, when set to a non-empty string, overrides the
  /// MVP placeholder. Useful for local debug builds talking to a real
  /// staging backend that expects a specific seed token.
  static let infoDictionaryKey = "VCAAppAttestToken"

  /// Non-empty placeholder used when no `Info.plist` override is configured.
  /// The backend's `require_app_attest` dependency only enforces non-empty,
  /// so this value is sufficient to keep protected routes reachable until
  /// real `DCAppAttestService` attestation lands.
  static let mvpPlaceholderToken = "unsigned-mvp"

  /// Returns the value to attach to the `X-App-Attest` header.
  ///
  /// Reads ``infoDictionaryKey`` from the supplied dictionary
  /// (defaults to `Bundle.main.infoDictionary`), trimming whitespace.
  /// Falls back to ``mvpPlaceholderToken`` when the key is missing or
  /// resolves to an empty/whitespace-only string.
  static func currentToken(
    infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
  ) -> String {
    if let raw = infoDictionary[infoDictionaryKey] as? String {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        return trimmed
      }
    }
    return mvpPlaceholderToken
  }
}
