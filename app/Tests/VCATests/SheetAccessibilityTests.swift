import SwiftUI
import XCTest

@testable import VCA

/// Pins the ``SheetAccessibility`` catalog that governs the modal-context
/// trait set added to the root content of every `.sheet(item:)`
/// presentation in the app (#260).
///
/// The SwiftUI modifier surface (`.accessibilityAddTraits(_:)` on the
/// sheet's content root) is a view-tree decoration not introspectable
/// without a UI host, but the trait set it consumes is a pure
/// value-level contract — what assistive technologies perceive as the
/// difference between *"this is a modal container, ignore what's
/// behind it"* and *"this is a navigation push, keep the previous
/// screen reachable"*. The trait set is the contract that must not
/// regress.
@MainActor
final class SheetAccessibilityTests: XCTestCase {
  // MARK: - sheetContentTraits

  func testSheetContentTraitsIsExactlyIsModal() {
    XCTAssertEqual(
      SheetAccessibility.sheetContentTraits,
      .isModal,
      "The sheet-content trait set must equal AccessibilityTraits.isModal "
        + "exactly. A subset that drops .isModal would silently strand "
        + "VoiceOver users behind the sheet; a superset would mislabel "
        + "the sheet root with unrelated semantics (e.g., .isButton would "
        + "make the entire sheet read as a tappable control)."
    )
  }

  func testSheetContentTraitsContainsIsModal() {
    XCTAssertTrue(
      SheetAccessibility.sheetContentTraits.contains(.isModal),
      "Sheet content must carry .isModal so VoiceOver, Voice Control, "
        + "and Switch Control treat the sheet as a modal container and "
        + "stop surfacing the underlying list / detail view. Without it, "
        + "the sheet reads as a navigation push to assistive technologies."
    )
  }

  func testSheetContentTraitsIsNotEmpty() {
    XCTAssertFalse(
      SheetAccessibility.sheetContentTraits.isEmpty,
      "An empty trait set is the SwiftUI default for an unannotated "
        + ".sheet content root and would make this composer a no-op. The "
        + "convention pin guards against an accidental simplification "
        + "that drops the trait entirely."
    )
  }

  func testSheetContentTraitsDoesNotCarryNavigationOrButtonRoles() {
    // The sheet root is a container, not a header / button / link /
    // tab-bar / search-field. Lock these out so a future merge that
    // builds the trait set by OR-ing in additional traits can't
    // silently change the spoken role of the sheet root.
    let traits = SheetAccessibility.sheetContentTraits

    XCTAssertFalse(
      traits.contains(.isHeader),
      "Sheet root is a modal container, not a heading.")
    XCTAssertFalse(
      traits.contains(.isButton),
      "Sheet root is a modal container, not a tappable control.")
    XCTAssertFalse(
      traits.contains(.isLink),
      "Sheet root is a modal container, not a link.")
    XCTAssertFalse(
      traits.contains(.isTabBar),
      "Sheet root is a modal container, not a tab bar.")
    XCTAssertFalse(
      traits.contains(.isSearchField),
      "Sheet root is a modal container, not a search field.")
  }
}
