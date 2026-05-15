import Foundation

/// Pure composer for the Settings status-announcement seams (#473, #479).
/// Same family as ``OnboardingAccessibility`` (#330) and
/// ``MainAccessibility`` (#343): the SwiftUI `.appAnnounceOnChange`
/// modifier in ``SettingsView`` is a view-tree decoration not
/// introspectable without a UI host, but the closure it consumes —
/// "given the new status, what string (if any) does VoiceOver hear?" —
/// is a pure value-level contract this enum pins.
///
/// Two state machines flow through Settings → Privacy & Data and
/// Settings → Massive API Key. Both surface inline `Text` rows on
/// reducer transitions that SwiftUI does not natively announce to
/// assistive technologies. WCAG 2.2 SC 4.1.3 (Status Messages) and
/// Apple HIG → Accessibility → Notifications and announcements require
/// these status changes be programmatically perceivable to assistive
/// technologies without moving focus.
enum SettingsAccessibility {
  /// Returns the AT announcement string for the given
  /// ``SettingsAccountErasureStatus`` transition, or `nil` to skip
  /// posting an announcement.
  ///
  /// - ``SettingsAccountErasureStatus/idle``: returns `nil`. The initial
  ///   pre-tap state is silent so the helper does not chatter on the
  ///   first render (or on a hypothetical reset to idle), matching the
  ///   precedent set by ``OnboardingAccessibility/transitionAnnouncement(forAcknowledged:)``.
  /// - ``SettingsAccountErasureStatus/erasing``: returns a short
  ///   "operation started" sentence so the user knows the multi-second
  ///   pipeline (backend `DELETE /portfolio` → SwiftData wipe → Keychain
  ///   wipe → device-UUID rotation → onboarding-gate reset) is running
  ///   and the now-disabled button has not silently failed.
  /// - ``SettingsAccountErasureStatus/erased``: returns the pair of
  ///   inline status-row sentences ("Your data has been erased."
  ///   followed by "Returning to the welcome screen…") joined with a
  ///   single ASCII space so spoken text matches visible text. This is
  ///   the legally-significant terminal state; the user must hear the
  ///   completion sentence and the in-process auto-return so they do
  ///   not retry the now-disabled button or assume the flow stalled.
  ///   Post-#471 / PR #475: the previous "force-quit … App Switcher"
  ///   instruction is no longer required because ``AppFeature`` swaps
  ///   the destination back to onboarding in-process (HIG → Launching →
  ///   Quitting forbids quit/relaunch instructions).
  /// - ``SettingsAccountErasureStatus/failed(reason:)``: forwards the
  ///   reducer-supplied failure reason. The reasons are already
  ///   user-facing sentences (e.g., "Could not reach the server: …. Your
  ///   data was not erased — please try again when you're online.") so
  ///   spoken text matches visible text.
  static func transitionAnnouncement(
    forAccountErasure status: SettingsAccountErasureStatus
  ) -> String? {
    switch status {
    case .idle:
      return nil
    case .erasing:
      return "Erasing your data. This may take a few seconds."
    case .erased:
      return "Your data has been erased. Returning to the welcome screen\u{2026}"
    case .failed(let reason):
      return reason
    }
  }

  /// Returns the AT announcement string for the given
  /// ``SettingsAPIKeyRequestStatus`` transition, or `nil` to skip posting
  /// an announcement.
  ///
  /// The Massive API-key save flow is the gate to the only third-party
  /// integration the app depends on (`docs/legal/third-party-services.md`,
  /// #294). A VoiceOver user who taps Save and hears nothing cannot tell
  /// whether the key was accepted, rejected, networked-out, or failed to
  /// land in the Keychain — so every non-idle transition is audible.
  ///
  /// - ``SettingsAPIKeyRequestStatus/idle``: returns `nil`. Matches the
  ///   ``transitionAnnouncement(forAccountErasure:)`` precedent — the
  ///   pre-tap baseline (and the post-dismiss / post-remove reset to
  ///   idle) is silent so the helper does not chatter.
  /// - ``SettingsAPIKeyRequestStatus/validating``: returns a short
  ///   "operation started" sentence so the user knows the round-trip to
  ///   Massive is in flight and the now-disabled Save button has not
  ///   silently failed. Prepends "your API key" so the announcement is
  ///   self-describing even when posted out of focus context.
  /// - ``SettingsAPIKeyRequestStatus/rejected(reason:)``: forwards the
  ///   reducer-supplied rejection reason, prefixed with "API key
  ///   rejected:" so the spoken text identifies the surface (the
  ///   reasons themselves — e.g. "API key cannot be empty." or Massive's
  ///   validator messages — are already user-facing sentences).
  /// - ``SettingsAPIKeyRequestStatus/networkError(reason:)``: forwards the
  ///   reducer-supplied connectivity reason, prefixed with "Network
  ///   error:" so VoiceOver users hear whether to retry online vs.
  ///   re-enter the key.
  /// - ``SettingsAPIKeyRequestStatus/storeError(reason:)``: forwards the
  ///   Keychain-write failure reason so the user knows the key never
  ///   landed on disk and a retry (or a Keychain-lock check) is needed.
  /// - ``SettingsAPIKeyRequestStatus/savedSuccessfully``: returns the
  ///   "API key saved." sentence verbatim from the inline status row so
  ///   spoken text matches visible text and self-identifies the
  ///   surface when posted without surrounding context.
  static func transitionAnnouncement(
    forAPIKeyRequest status: SettingsAPIKeyRequestStatus
  ) -> String? {
    switch status {
    case .idle:
      return nil
    case .validating:
      return "Validating your API key with Massive…"
    case .rejected(let reason):
      return "API key rejected: \(reason)"
    case .networkError(let reason):
      return "Network error: \(reason)"
    case .storeError(let reason):
      return "Could not save your API key: \(reason)"
    case .savedSuccessfully:
      return "API key saved."
    }
  }
}
