import XCTest

@testable import VCA

/// Pins the ``SettingsAccessibility`` seam that powers the
/// Settings → Privacy & Data → "Erase All My Data" status announcements
/// (#473). The SwiftUI `.appAnnounceOnChange` modifier itself is a
/// view-tree decoration not introspectable without a UI host, but the
/// closure it consumes is a pure value-level contract — given the new
/// ``SettingsAccountErasureStatus``, what string (if any) does
/// VoiceOver hear?
///
/// These transitions are what AT users perceive during a destructive,
/// irreversible GDPR Art. 17 / CCPA §1798.105 flow, so the spoken
/// strings are the contract that must not regress.
@MainActor
final class SettingsAccessibilityTests: XCTestCase {
  // MARK: - Transition announcement: idle

  func testTransitionAnnouncementForIdleIsSilent() {
    XCTAssertNil(
      SettingsAccessibility.transitionAnnouncement(forAccountErasure: .idle)
    )
  }

  // MARK: - Transition announcement: erasing

  func testTransitionAnnouncementForErasingIsAStartedSentence() {
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAccountErasure: .erasing
    )

    XCTAssertEqual(
      announcement,
      "Erasing your data. This may take a few seconds."
    )
  }

  func testTransitionAnnouncementForErasingIsNonEmpty() {
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAccountErasure: .erasing
    )

    XCTAssertNotNil(announcement)
    XCTAssertFalse(
      announcement?.isEmpty ?? true,
      "Erasing-state announcement must not be empty — the helper drops empty strings."
    )
  }

  // MARK: - Transition announcement: erased

  func testTransitionAnnouncementForErasedAcknowledgesCompletion() {
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAccountErasure: .erased
    )

    // Byte-for-byte match against the two visible `Text` nodes in
    // `SettingsView.accountErasureStatusRow` (`.erased` case), joined
    // with a single ASCII space. The trailing ellipsis is U+2026 to
    // match the visible copy verbatim. If either visible string is
    // edited without this composer being updated, this assertion trips
    // and re-pins spoken-text == visible-text on the legally-
    // significant GDPR Art. 17 / CCPA §1798.105 terminal state.
    XCTAssertEqual(
      announcement,
      "Your data has been erased. Returning to the welcome screen\u{2026}"
    )
  }

  func testTransitionAnnouncementForErasedAnnouncesAutomaticReturn() {
    // The legally-significant terminal state. Post-#471 / PR #475 the
    // user is auto-routed back to onboarding in-process (HIG →
    // Launching → Quitting forbids quit/relaunch instructions), so the
    // spoken announcement must name the welcome screen return — never
    // the previous "force-quit … App Switcher" copy that violates HIG
    // and contradicts the in-process route swap firing underneath the
    // announcement.
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAccountErasure: .erased
    )

    XCTAssertNotNil(announcement)
    XCTAssertTrue(
      announcement?.contains("welcome screen") ?? false,
      "Erased-state announcement should name the welcome-screen return so AT users hear what's happening on-screen."
    )
    XCTAssertFalse(
      announcement?.contains("force-quit") ?? true,
      "Erased-state announcement must not instruct the user to force-quit — HIG → Launching → Quitting forbids this; PR #475 removed it from the visible copy."
    )
    XCTAssertFalse(
      announcement?.contains("App Switcher") ?? true,
      "Erased-state announcement must not reference the App Switcher — the in-process route swap (PR #475) makes the instruction factually wrong."
    )
  }

  // MARK: - Transition announcement: failed

  func testTransitionAnnouncementForFailedForwardsReasonVerbatim() {
    // The reducer-supplied reason is already a user-facing sentence
    // (e.g., "Could not reach the server: timed out. Your data was not
    // erased — please try again when you're online."), so spoken text
    // matches visible text. Pin the verbatim forward so future copy
    // edits in the reducer also reach VoiceOver users.
    let reason =
      "Could not reach the server: timed out. Your data was not erased — please try again when you're online."
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAccountErasure: .failed(reason: reason)
    )

    XCTAssertEqual(announcement, reason)
  }

  func testTransitionAnnouncementForFailedPreservesNonEmptyReason() {
    // Defensive: any non-empty failure reason must surface non-empty so
    // the `.appAnnounceOnChange` helper actually posts it (the helper
    // drops empty strings to avoid VoiceOver chatter, which would
    // otherwise silently swallow a legitimate failure announcement).
    let reasons = [
      "Backend rejected the request.",
      "Network error",
      "Local cleanup failed — please reinstall Investrum to fully clear local data.",
    ]
    for reason in reasons {
      let announcement = SettingsAccessibility.transitionAnnouncement(
        forAccountErasure: .failed(reason: reason)
      )
      XCTAssertEqual(
        announcement, reason,
        "Failed-state announcement should forward the reason '\(reason)' verbatim."
      )
      XCTAssertFalse(
        announcement?.isEmpty ?? true,
        "Failed-state announcement for reason '\(reason)' must not collapse to empty."
      )
    }
  }

  // MARK: - Coverage: non-idle cases are all audible

  func testEveryNonIdleStatusHasANonEmptyAnnouncement() {
    // A nil / empty announcement on a destructive-flow status surface
    // would mean a VoiceOver user gets no feedback on a legally-
    // significant transition. Pin "everything but idle is audible" so
    // a future enum case (e.g. a `.partiallyErased`) can not silently
    // ship without an AT announcement.
    let nonIdleCases: [SettingsAccountErasureStatus] = [
      .erasing,
      .erased,
      .failed(reason: "test reason"),
    ]
    for status in nonIdleCases {
      let announcement = SettingsAccessibility.transitionAnnouncement(
        forAccountErasure: status
      )
      XCTAssertNotNil(announcement, "\(status) has no announcement.")
      XCTAssertFalse(
        announcement?.isEmpty ?? true,
        "\(status) announcement is empty."
      )
    }
  }

  // MARK: - API-key request transition announcement: idle

  func testTransitionAnnouncementForAPIKeyIdleIsSilent() {
    XCTAssertNil(
      SettingsAccessibility.transitionAnnouncement(forAPIKeyRequest: .idle)
    )
  }

  // MARK: - API-key request transition announcement: validating

  func testTransitionAnnouncementForAPIKeyValidatingIsAStartedSentence() {
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAPIKeyRequest: .validating
    )

    XCTAssertEqual(
      announcement,
      "Validating your API key with Massive…"
    )
  }

  func testTransitionAnnouncementForAPIKeyValidatingIsNonEmpty() {
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAPIKeyRequest: .validating
    )

    XCTAssertNotNil(announcement)
    XCTAssertFalse(
      announcement?.isEmpty ?? true,
      "Validating-state announcement must not be empty — the helper drops empty strings."
    )
  }

  // MARK: - API-key request transition announcement: rejected

  func testTransitionAnnouncementForAPIKeyRejectedForwardsReason() {
    // The reducer-supplied rejection reasons are already user-facing
    // sentences (e.g. "API key cannot be empty.", "Massive said the key
    // looks malformed."), so the announcement appends them verbatim
    // after a self-describing "API key rejected:" prefix. The prefix
    // makes the announcement self-describing when posted without the
    // surrounding row's "Rejected:" visual prefix in focus context.
    let reasons = [
      "API key cannot be empty.",
      "Massive said the key looks malformed.",
      "Key length is below the minimum accepted by Massive.",
    ]
    for reason in reasons {
      let announcement = SettingsAccessibility.transitionAnnouncement(
        forAPIKeyRequest: .rejected(reason: reason)
      )
      XCTAssertEqual(
        announcement, "API key rejected: \(reason)",
        "Rejected-state announcement should wrap the reason '\(reason)' with the self-describing prefix."
      )
      XCTAssertFalse(
        announcement?.isEmpty ?? true,
        "Rejected-state announcement for reason '\(reason)' must not collapse to empty."
      )
    }
  }

  // MARK: - API-key request transition announcement: networkError

  func testTransitionAnnouncementForAPIKeyNetworkErrorForwardsReason() {
    // Network-error reasons distinguish "offline, retry when online"
    // from "Massive responded with HTTP N, please try again". Forward
    // them verbatim so VoiceOver users get the same retry guidance
    // sighted users get from the inline row.
    let reasons = [
      "The Internet connection appears to be offline.",
      "Massive responded with HTTP 503. Please try again.",
      "Request timed out.",
    ]
    for reason in reasons {
      let announcement = SettingsAccessibility.transitionAnnouncement(
        forAPIKeyRequest: .networkError(reason: reason)
      )
      XCTAssertEqual(
        announcement, "Network error: \(reason)",
        "Network-error announcement should wrap the reason '\(reason)' with the self-describing prefix."
      )
      XCTAssertFalse(
        announcement?.isEmpty ?? true,
        "Network-error announcement for reason '\(reason)' must not collapse to empty."
      )
    }
  }

  // MARK: - API-key request transition announcement: storeError

  func testTransitionAnnouncementForAPIKeyStoreErrorForwardsReason() {
    // Keychain-write failures are surfaced separately so the user knows
    // the network round-trip succeeded but the key never landed on
    // disk — a different remedy (Keychain lock, restart) than a network
    // error.
    let reason = "errSecItemNotFound"
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAPIKeyRequest: .storeError(reason: reason)
    )

    XCTAssertEqual(
      announcement, "Could not save your API key: \(reason)"
    )
    XCTAssertFalse(
      announcement?.isEmpty ?? true,
      "Store-error announcement must not collapse to empty."
    )
  }

  // MARK: - API-key request transition announcement: savedSuccessfully

  func testTransitionAnnouncementForAPIKeySavedSuccessfullyDescribesValidity() {
    // The reducer funnels both Save (post-Keychain-write) and
    // Re-validate (no write, just re-confirms the stored key) into
    // `.savedSuccessfully`. The announcement must describe the
    // observable outcome — Massive accepts the stored key — rather
    // than the path, so a Re-validate-only tick does not falsely tell
    // the user something was written this cycle (#493).
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAPIKeyRequest: .savedSuccessfully
    )

    XCTAssertEqual(announcement, "Your API key is valid.")
  }

  func testTransitionAnnouncementForAPIKeySavedSuccessfullyNamesTheSurface() {
    // The success announcement must self-identify the surface ("API
    // key") because it is posted without focus context — a VoiceOver
    // user who tapped Save or Re-validate and swiped away should still
    // hear which key Massive is confirming and not just a bare
    // "valid".
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAPIKeyRequest: .savedSuccessfully
    )

    XCTAssertNotNil(announcement)
    XCTAssertTrue(
      announcement?.lowercased().contains("api key") ?? false,
      "Saved-state announcement should reference 'API key' so VoiceOver users can identify the surface out of context."
    )
  }

  // MARK: - Coverage: every non-idle API-key case is audible

  func testEveryNonIdleAPIKeyRequestStatusHasANonEmptyAnnouncement() {
    // Pin "everything but idle is audible" so a future
    // `SettingsAPIKeyRequestStatus` case (e.g. a `.rateLimited(retryAfter:)`)
    // cannot silently ship without an AT announcement. The API-key
    // surface is the only third-party-integration gate in the app
    // (`docs/legal/third-party-services.md`, #294); a silent transition
    // here blocks a VoiceOver user from completing setup.
    let nonIdleCases: [SettingsAPIKeyRequestStatus] = [
      .validating,
      .rejected(reason: "rejected reason"),
      .networkError(reason: "network reason"),
      .storeError(reason: "store reason"),
      .savedSuccessfully,
    ]
    for status in nonIdleCases {
      let announcement = SettingsAccessibility.transitionAnnouncement(
        forAPIKeyRequest: status
      )
      XCTAssertNotNil(announcement, "\(status) has no announcement.")
      XCTAssertFalse(
        announcement?.isEmpty ?? true,
        "\(status) announcement is empty."
      )
    }
  }

  // MARK: - API-key Save disabled-button hint (#386)

  func testAPIKeySaveDisabledHintIsEmptyOnNonEmptyDraftAndIdleStatus() {
    // The button is enabled when the trimmed draft is non-empty and no
    // request is in flight. SwiftUI auto-suppresses an empty
    // `.accessibilityHint(_:)` so the enabled state must return "" —
    // a non-empty enabled-state hint would chatter "Double tap to
    // activate" follow-ups with no unblock context.
    XCTAssertEqual(
      SettingsAccessibility.apiKeySaveDisabledHint(
        draft: "sk-live-abc123",
        requestStatus: .idle
      ),
      ""
    )
  }

  func testAPIKeySaveDisabledHintNamesTheEmptyDraftAsTheUnblockReason() {
    // The most common disabled cause: user has not typed anything. The
    // adjacent `SecureField` placeholder ("Enter API key") is a
    // separate AT element, so a Voice Control / Switch Control / direct-
    // focus VoiceOver user needs the unblock-reason here on the button.
    XCTAssertEqual(
      SettingsAccessibility.apiKeySaveDisabledHint(
        draft: "",
        requestStatus: .idle
      ),
      "Enter an API key to enable."
    )
  }

  func testAPIKeySaveDisabledHintTreatsWhitespaceOnlyDraftAsEmpty() {
    // Mirror the reducer-side `canSubmitAPIKey` trim — a whitespace-
    // only draft also fails the gate, so spoken text must match the
    // same threshold the visible disabled state uses. Without this
    // parity, a user who only typed a tab/space would hear "double
    // tap to activate" but the button would still be dimmed.
    let whitespaceVariants = [" ", "  ", "\t", "\n", " \t \n "]
    for draft in whitespaceVariants {
      XCTAssertEqual(
        SettingsAccessibility.apiKeySaveDisabledHint(
          draft: draft,
          requestStatus: .idle
        ),
        "Enter an API key to enable.",
        "Whitespace-only draft '\(draft.debugDescription)' should be treated as empty."
      )
    }
  }

  func testAPIKeySaveDisabledHintNamesInFlightValidationAsTheUnblockReason() {
    // The second disabled cause: a Massive round-trip is already
    // running. The button stays dimmed for the round-trip window so
    // the user does not double-submit; the hint tells AT users
    // *why* it is dimmed (i.e., "wait, do not retry") rather than the
    // default "Save, dimmed button" which sounds like a permanent
    // failure.
    XCTAssertEqual(
      SettingsAccessibility.apiKeySaveDisabledHint(
        draft: "sk-live-abc123",
        requestStatus: .validating
      ),
      "Currently validating with Massive. Please wait."
    )
  }

  func testAPIKeySaveDisabledHintPrefersEmptyDraftReasonOverInFlightWhenBoth() {
    // Defensive: if both gates fail at once (empty draft *and*
    // somehow in-flight — currently unreachable but possible after a
    // future reducer refactor), the empty-draft reason is the
    // actionable one. Pin the precedence so a future refactor cannot
    // silently flip to "please wait" while the user has nothing to
    // wait for.
    XCTAssertEqual(
      SettingsAccessibility.apiKeySaveDisabledHint(
        draft: "",
        requestStatus: .validating
      ),
      "Enter an API key to enable."
    )
  }

  func testAPIKeySaveDisabledHintIsEmptyForEveryTerminalRequestStatus() {
    // Every non-`validating` status leaves the button enabled (so the
    // user can retry / replace the key), so the hint must collapse to
    // "" — a non-empty hint on an enabled button is unwanted chatter.
    // Pins parity with `SettingsAPIKeyRequestStatus.isInFlight`.
    let terminalStatuses: [SettingsAPIKeyRequestStatus] = [
      .idle,
      .rejected(reason: "API key cannot be empty."),
      .networkError(reason: "The Internet connection appears to be offline."),
      .storeError(reason: "errSecItemNotFound"),
      .savedSuccessfully,
    ]
    for status in terminalStatuses {
      XCTAssertEqual(
        SettingsAccessibility.apiKeySaveDisabledHint(
          draft: "sk-live-abc123",
          requestStatus: status
        ),
        "",
        "Non-in-flight status \(status) on a non-empty draft should produce no hint."
      )
    }
  }

  // MARK: - SC 1.4.1 Use-of-Color glyph mapping (issue #415)

  func testAPIKeyRequestStatusGlyphIsNilForIdle() {
    // `idle` renders no inline status row, so the helper must return
    // nil — emitting a glyph for a row that does not appear would
    // mis-document the surface. Pins the precedent set by
    // `transitionAnnouncement(forAPIKeyRequest:)` which also returns
    // nil for `.idle`.
    XCTAssertNil(SettingsAccessibility.apiKeyRequestStatusGlyph(for: .idle))
  }

  func testAPIKeyRequestStatusGlyphIsNilForValidating() {
    // `validating` renders a `ProgressView` + neutral body-copy
    // sentence ("Validating with Massive…"); there is no error or
    // success tint to pair a glyph with. Pins that the helper does
    // *not* emit a glyph for an in-flight state — a future regression
    // that added an icon here would compete with the spinner.
    XCTAssertNil(
      SettingsAccessibility.apiKeyRequestStatusGlyph(for: .validating)
    )
  }

  func testAPIKeyRequestStatusGlyphForRejected() {
    // Rejection is a Massive-validated negative outcome; `xmark.octagon`
    // matches the SF Symbol vocabulary "stop / not accepted" semantics
    // and is distinct from the generic warning triangle so VoiceOver
    // users who later pivot to a sighted secondary device get the
    // semantic differentiation for free.
    XCTAssertEqual(
      SettingsAccessibility.apiKeyRequestStatusGlyph(
        for: .rejected(reason: "API key cannot be empty.")
      ),
      "xmark.octagon"
    )
  }

  func testAPIKeyRequestStatusGlyphForNetworkError() {
    // Connectivity failure mode gets the network-specific glyph so a
    // user in Grayscale Color Filter mode can tell at a glance whether
    // the failure means "retry online" vs. "fix the key value" — both
    // surfaces use the same negative tint, the glyph is what
    // distinguishes them.
    XCTAssertEqual(
      SettingsAccessibility.apiKeyRequestStatusGlyph(
        for: .networkError(reason: "Offline.")
      ),
      "wifi.exclamationmark"
    )
  }

  func testAPIKeyRequestStatusGlyphForStoreError() {
    // Keychain-write failure is the most severe local-storage class
    // failure on the surface; uses the filled exclamation-triangle to
    // signal "blocker" rather than "warning", matching the codebase
    // convention for blocking-failure surfaces (HoldingsEditor
    // `Warning: no tickers` uses the non-filled variant for warnings).
    XCTAssertEqual(
      SettingsAccessibility.apiKeyRequestStatusGlyph(
        for: .storeError(reason: "errSecItemNotFound")
      ),
      "exclamationmark.triangle.fill"
    )
  }

  func testAPIKeyRequestStatusGlyphForSavedSuccessfully() {
    // Terminal success state — the only positive-tint surface in the
    // section. `checkmark.circle.fill` is Apple's canonical
    // "confirmed / valid" glyph (HIG → SF Symbols → Status); pinning
    // it pre-empts a future regression that picks a non-status icon.
    XCTAssertEqual(
      SettingsAccessibility.apiKeyRequestStatusGlyph(for: .savedSuccessfully),
      "checkmark.circle.fill"
    )
  }

  func testAPIKeyStoredButLastCheckFailedGlyphIsNonEmpty() {
    // The Massive `apiKeyStatus == .storedButLastCheckFailed(...)` row
    // pairs the negative tint with a warning triangle. Glyph constant
    // is asserted here so a future "" or removal regression is caught
    // even when the view-tree symbol cannot be introspected directly.
    XCTAssertEqual(
      SettingsAccessibility.apiKeyStoredButLastCheckFailedGlyph,
      "exclamationmark.triangle"
    )
  }

  func testAPIKeyLoadErrorGlyphIsNonEmpty() {
    // Keychain `load` failure is rendered with the filled warning
    // glyph (same vocabulary as `.storeError`) — both are local-disk
    // failure modes for the same Keychain item.
    XCTAssertEqual(
      SettingsAccessibility.apiKeyLoadErrorGlyph,
      "exclamationmark.triangle.fill"
    )
  }

  func testPortfolioEditorValidationErrorGlyph() {
    // Portfolio Editor inline validation row pairs the error tint
    // with `exclamationmark.circle` — same glyph the codebase uses
    // for the `HoldingsEditor` "Warning: no tickers" hint, keeping
    // editor-validation vocabulary uniform across the two surfaces.
    XCTAssertEqual(
      SettingsAccessibility.portfolioEditorValidationErrorGlyph,
      "exclamationmark.circle"
    )
  }

  func testAllSC141GlyphsAreNonEmpty() {
    // Backstop guard against a future refactor that swaps a glyph
    // constant for `""` — Apple renders an empty `systemImage` as a
    // blank placeholder, silently re-introducing the SC 1.4.1
    // "color-only signal" failure this issue fixed.
    XCTAssertFalse(SettingsAccessibility.apiKeyStoredButLastCheckFailedGlyph.isEmpty)
    XCTAssertFalse(SettingsAccessibility.apiKeyLoadErrorGlyph.isEmpty)
    XCTAssertFalse(SettingsAccessibility.portfolioEditorValidationErrorGlyph.isEmpty)
    for status: SettingsAPIKeyRequestStatus in [
      .rejected(reason: "x"),
      .networkError(reason: "x"),
      .storeError(reason: "x"),
      .savedSuccessfully,
    ] {
      let glyph = SettingsAccessibility.apiKeyRequestStatusGlyph(for: status)
      XCTAssertNotNil(glyph, "Status \(status) must map to an SF Symbol.")
      XCTAssertFalse(
        glyph?.isEmpty ?? true,
        "Status \(status) glyph must be a non-empty SF Symbol name."
      )
    }
  }
}
