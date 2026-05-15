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

  func testTransitionAnnouncementForAPIKeySavedAcknowledgesSuccess() {
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAPIKeyRequest: .savedSuccessfully
    )

    XCTAssertEqual(announcement, "API key saved.")
  }

  func testTransitionAnnouncementForAPIKeySavedNamesTheSurface() {
    // The success announcement must self-identify the surface ("API
    // key") because it is posted without focus context — a VoiceOver
    // user who tapped Save and swiped away should still hear "API key
    // saved" and not just a bare "saved".
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
}
