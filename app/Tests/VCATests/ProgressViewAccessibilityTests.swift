import XCTest

@testable import VCA

/// Pins the ``ProgressViewAccessibility`` catalog that governs the
/// spoken contract of every bare `ProgressView()` in the app (#371).
///
/// The SwiftUI modifier surface (`.accessibilityLabel(_:)`,
/// `.accessibilityHidden(_:)`, `.accessibilityElement(children: .combine)`)
/// is a view-tree decoration not introspectable without a UI host, but
/// the labels and the convention pin it consumes are pure value-level
/// contracts that AT users perceive as the *first thing the app says*
/// (the launching window) or as the duration of multi-second network
/// round-trips (Massive API-key validation, account erasure). The
/// strings and the decorative-spinner convention pin are the contract
/// that must not regress.
@MainActor
final class ProgressViewAccessibilityTests: XCTestCase {
  // MARK: - launchingLabel

  func testLaunchingLabelEmbedsAppBrandDisplayName() {
    XCTAssertTrue(
      ProgressViewAccessibility.launchingLabel.contains(AppBrand.displayName),
      "Launching-window spinner label must embed the brand string so the "
        + "first AT announcement identifies the app instead of speaking "
        + "the localized SwiftUI default 'In progress' with no context."
    )
  }

  func testLaunchingLabelIsExactlyBrandedLoadingSentence() {
    XCTAssertEqual(
      ProgressViewAccessibility.launchingLabel,
      "\(AppBrand.displayName), loading"
    )
  }

  func testLaunchingLabelIsNonEmpty() {
    XCTAssertFalse(
      ProgressViewAccessibility.launchingLabel.isEmpty,
      "Empty .accessibilityLabel(_:) is treated by SwiftUI as 'no label "
        + "supplied' and assistive technologies fall back to the generic "
        + "'In progress' default — defeating the entire fix."
    )
  }

  func testLaunchingLabelDoesNotEndWithEllipsis() {
    XCTAssertFalse(
      ProgressViewAccessibility.launchingLabel.hasSuffix("…"),
      "Apple's spoken-label convention for state is verb-form "
        + "comma-separated ('Investrum, loading') — not a sentence with a "
        + "trailing ellipsis. VoiceOver pronounces the ellipsis explicitly "
        + "on some voices, which would read awkwardly at every launch."
    )
  }

  // MARK: - decorativeSpinnerIsAccessibilityHidden

  func testDecorativeSpinnerConventionPinIsTrue() {
    XCTAssertTrue(
      ProgressViewAccessibility.decorativeSpinnerIsAccessibilityHidden,
      "Decorative spinners paired with a visible Text row must be marked "
        + ".accessibilityHidden(true) so the combined parent reads as a "
        + "single AT element labeled by the adjacent text. Flipping this "
        + "to false re-introduces the duplicated 'in progress' + "
        + "'Validating with Massive…' pair this catalog was created to "
        + "eliminate."
    )
  }

  // MARK: - apiKeyValidatingRowAccessibilityIdentifier

  func testAPIKeyValidatingRowIdentifierIsStable() {
    XCTAssertEqual(
      ProgressViewAccessibility.apiKeyValidatingRowAccessibilityIdentifier,
      "settings.apiKey.request.validating"
    )
  }

  // MARK: - accountErasingRowAccessibilityIdentifier

  func testAccountErasingRowIdentifierIsStable() {
    XCTAssertEqual(
      ProgressViewAccessibility.accountErasingRowAccessibilityIdentifier,
      "settings.erase.status.erasing"
    )
  }

  // MARK: - Cross-catalog invariants

  func testDecorativeSpinnerRowIdentifiersAreDisjoint() {
    XCTAssertNotEqual(
      ProgressViewAccessibility.apiKeyValidatingRowAccessibilityIdentifier,
      ProgressViewAccessibility.accountErasingRowAccessibilityIdentifier,
      "Each decorative-spinner surface must own a distinct AT identifier so "
        + "UI tests can disambiguate the Massive validating row from the "
        + "account-erasure erasing row."
    )
  }

  func testDecorativeSpinnerRowIdentifiersAreNonEmpty() {
    XCTAssertFalse(
      ProgressViewAccessibility.apiKeyValidatingRowAccessibilityIdentifier
        .isEmpty
    )
    XCTAssertFalse(
      ProgressViewAccessibility.accountErasingRowAccessibilityIdentifier
        .isEmpty
    )
  }
}
