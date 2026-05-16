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
  ///   "Your API key is valid." sentence verbatim from the inline status
  ///   row so spoken text matches visible text and self-identifies the
  ///   surface when posted without surrounding context. The reducer
  ///   funnels both the Save path (`apiKeyValidationCompleted` after a
  ///   successful Keychain write) and the Re-validate path
  ///   (`apiKeyRevalidationCompleted(.valid)`, which performs no write)
  ///   into `.savedSuccessfully`, so the announcement describes the
  ///   observable outcome ("Massive accepts the stored key right now")
  ///   rather than the path ("we just wrote it") — see #493.
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
      return "Your API key is valid."
    }
  }

  /// Returns the `.accessibilityHint` string for the Settings → Massive
  /// API Key → **Save** button, given the same `draft` + `requestStatus`
  /// pair that gates ``SettingsView/canSubmitAPIKey``. Returns the empty
  /// string when the button is enabled (SwiftUI auto-suppresses empty
  /// hints) and a state-aware unblock reason when it is disabled (#386).
  ///
  /// Closes the WCAG 2.1 SC 3.3.2 (Labels or Instructions) / SC 4.1.2
  /// (Name, Role, Value) gap exposed in #386: today VoiceOver / Voice
  /// Control / Switch Control users who focus the disabled Save button
  /// hear `"Save, dimmed button"` with no programmatic association to
  /// the adjacent placeholder ("Enter API key") or the in-flight
  /// validation row, so they cannot tell what to do to enable it. The
  /// hint is computed from the same two reducer-state inputs that drive
  /// ``SettingsView/canSubmitAPIKey`` — empty trimmed draft vs. an
  /// in-flight Massive round-trip — so spoken text matches the visual
  /// disabled-reason context.
  ///
  /// - Parameters:
  ///   - draft: the current ``SettingsFeature/State/apiKeyDraft`` value.
  ///     Whitespace-only drafts are treated as empty to match the
  ///     reducer-side gate.
  ///   - requestStatus: the current
  ///     ``SettingsFeature/State/apiKeyRequestStatus`` value. Only
  ///     ``SettingsAPIKeyRequestStatus/validating`` (i.e.
  ///     ``SettingsAPIKeyRequestStatus/isInFlight`` `== true`) disables
  ///     the button on a non-empty draft; every other terminal status
  ///     (`rejected`, `networkError`, `storeError`, `savedSuccessfully`)
  ///     leaves the button enabled for a retry / replacement and the
  ///     hint stays empty.
  /// - Returns: an empty string when the button is enabled, or a single
  ///   user-facing sentence naming what the user must do to enable it.
  static func apiKeySaveDisabledHint(
    draft: String,
    requestStatus: SettingsAPIKeyRequestStatus
  ) -> String {
    let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedDraft.isEmpty {
      return "Enter an API key to enable."
    }
    if requestStatus.isInFlight {
      return "Currently validating with Massive. Please wait."
    }
    return ""
  }
}
