import Foundation

/// Pure composer for the Settings → Privacy & Data → "Erase All My Data"
/// status announcement seam (#473). Same family as
/// ``OnboardingAccessibility`` (#330) and ``MainAccessibility`` (#343):
/// the SwiftUI `.appAnnounceOnChange` modifier in ``SettingsView`` is a
/// view-tree decoration not introspectable without a UI host, but the
/// closure it consumes — "given the new ``SettingsAccountErasureStatus``,
/// what string (if any) does VoiceOver hear?" — is a pure value-level
/// contract this enum pins.
///
/// The GDPR Art. 17 / CCPA §1798.105 / App Store §5.1.1(v) right-to-
/// erasure flow is destructive and irreversible; a VoiceOver user must
/// hear feedback for every state transition so they know whether to
/// retry, force-quit-and-relaunch, or escalate. WCAG 2.2 SC 4.1.3
/// (Status Messages) and Apple HIG → Accessibility → Notifications and
/// announcements require these status changes be programmatically
/// perceivable to assistive technologies without moving focus.
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
  /// - ``SettingsAccountErasureStatus/erased``: returns the
  ///   relaunch-instruction sentence verbatim from the inline status row
  ///   so spoken text matches visible text. This is the legally-
  ///   significant terminal state; the user must hear it.
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
      return
        "Your data has been erased. Please force-quit Investrum from the App "
        + "Switcher and reopen it to complete the reset."
    case .failed(let reason):
      return reason
    }
  }
}
