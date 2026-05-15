import XCTest

@testable import VCA

/// Pins the `OnboardingAccessibility` seam that powers the
/// disclaimer→setup-intro transition's focus motion and status
/// announcement (#330). The view modifiers themselves are SwiftUI
/// view-tree decorations not introspectable without a UI host, but the
/// underlying composer is a pure value-level contract:
///
/// * which `FocusTarget` AT focus must land on, given the
///   `hasAcknowledgedDisclaimer` flag, and
/// * what string (if any) is announced through the central
///   `AccessibilityAnnouncer` env-seam on each transition.
///
/// These two surfaces are what AT users perceive when the screen swaps,
/// so they are the contract that must not regress.
@MainActor
final class OnboardingAccessibilityTests: XCTestCase {
  // MARK: - Focus target

  func testFocusTargetForUnacknowledgedIsDisclaimerHeader() {
    XCTAssertEqual(
      OnboardingAccessibility.focusTarget(forAcknowledged: false),
      .disclaimerHeader
    )
  }

  func testFocusTargetForAcknowledgedIsSetupIntroHeader() {
    XCTAssertEqual(
      OnboardingAccessibility.focusTarget(forAcknowledged: true),
      .setupIntroHeader
    )
  }

  func testFocusTargetsAreDistinct() {
    XCTAssertNotEqual(
      OnboardingAccessibility.FocusTarget.disclaimerHeader,
      OnboardingAccessibility.FocusTarget.setupIntroHeader
    )
  }

  // MARK: - Transition announcement

  func testTransitionAnnouncementOnAcknowledgeReadsTheNewStepHeader() {
    let announcement = OnboardingAccessibility.transitionAnnouncement(
      forAcknowledged: true
    )

    XCTAssertEqual(
      announcement,
      "Disclaimer acknowledged. Create your first portfolio."
    )
  }

  func testTransitionAnnouncementOnUnacknowledgeIsSilent() {
    // The acknowledgement is one-way through the live UI; a hypothetical
    // reset path must not chatter announcements at first launch.
    XCTAssertNil(
      OnboardingAccessibility.transitionAnnouncement(forAcknowledged: false)
    )
  }

  func testTransitionAnnouncementForAcknowledgeMatchesNewStepHeadingExactly() {
    // The announcement must contain the exact heading copy of the
    // setup-intro step ("Create your first portfolio") so a VoiceOver
    // user who arrives on the new screen mid-announcement gets the same
    // heading text echoed back. This pins the heading-string coupling.
    let announcement = OnboardingAccessibility.transitionAnnouncement(
      forAcknowledged: true
    )

    XCTAssertNotNil(announcement)
    XCTAssertTrue(
      announcement?.contains("Create your first portfolio") ?? false,
      "Announcement should echo the setup-intro heading verbatim."
    )
  }
}
