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

    XCTAssertEqual(
      announcement,
      "Your data has been erased. Please force-quit Investrum from the App "
        + "Switcher and reopen it to complete the reset."
    )
  }

  func testTransitionAnnouncementForErasedNamesTheRelaunchInstruction() {
    // The legally-significant terminal state. The user must hear the
    // force-quit instruction so they know to relaunch (and so they do
    // not retry the disabled button); pin the substring coupling.
    let announcement = SettingsAccessibility.transitionAnnouncement(
      forAccountErasure: .erased
    )

    XCTAssertNotNil(announcement)
    XCTAssertTrue(
      announcement?.contains("force-quit") ?? false,
      "Erased-state announcement should instruct the user to force-quit Investrum."
    )
    XCTAssertTrue(
      announcement?.contains("App Switcher") ?? false,
      "Erased-state announcement should reference the App Switcher so the relaunch step is unambiguous."
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
}
