import XCTest

@testable import VCA

/// Pins the per-row action catalog that powers the three input-mode
/// surfaces on `PortfolioListView` and `ContributionHistoryView` (#341):
///
/// * `.swipeActions` — touch
/// * `.contextMenu` — pointer (right-click) + long-press
/// * `.accessibilityAction(named:)` — Voice Control / Switch Control /
///   Full Keyboard Access / VoiceOver Actions rotor (#285)
///
/// The view-tree wiring itself is not introspectable without a UI host,
/// but the catalog the views consume is a pure value-level contract.
/// If the visible label, destructive role, icon, or kind drifts on a
/// single surface, this test trips first.
final class RowContextActionsTests: XCTestCase {

  // MARK: - PortfolioListView per-row actions

  func testPortfolioRowContextActionsExposesEditAndDeleteInDisplayOrder() {
    XCTAssertEqual(
      PortfolioRowContextActions.all.map(\.kind),
      [.edit, .delete],
      "PortfolioListView context-menu must render Edit above Delete so "
        + "the destructive option sits at the bottom (HIG → Context menus, "
        + "Patterns → Confirming an action)."
    )
  }

  func testPortfolioRowContextActionsEditIsNonDestructiveWithPencilIcon() {
    XCTAssertEqual(PortfolioRowContextActions.edit.title, "Edit")
    XCTAssertEqual(PortfolioRowContextActions.edit.systemImage, "pencil")
    XCTAssertFalse(
      PortfolioRowContextActions.edit.isDestructive,
      "Edit must not adopt the .destructive role — it opens the editor sheet, "
        + "not a confirmation-required destruction."
    )
    XCTAssertEqual(PortfolioRowContextActions.edit.kind, .edit)
  }

  func testPortfolioRowContextActionsDeleteIsDestructiveWithTrashIcon() {
    XCTAssertEqual(PortfolioRowContextActions.delete.title, "Delete")
    XCTAssertEqual(PortfolioRowContextActions.delete.systemImage, "trash")
    XCTAssertTrue(
      PortfolioRowContextActions.delete.isDestructive,
      "Delete must adopt .destructive so the context-menu row renders in red "
        + "(HIG → Context menus: destructive actions are visually distinguished)."
    )
    XCTAssertEqual(PortfolioRowContextActions.delete.kind, .delete)
  }

  func testPortfolioRowContextActionsTitlesMatchPortfolioListSwipeActionTitles() {
    // The swipe-actions block on `PortfolioListView` hard-codes the
    // strings "Edit" and "Delete" (and binds Delete to .destructive)
    // — see `PortfolioListContent.body`. The context-menu must mirror
    // those exact labels so a user who learns "Delete" / "Edit" via
    // swipe sees the same words via right-click / long-press.
    XCTAssertEqual(
      PortfolioRowContextActions.all.map(\.title),
      ["Edit", "Delete"]
    )
    XCTAssertEqual(
      PortfolioRowContextActions.all.map(\.isDestructive),
      [false, true]
    )
  }

  // MARK: - ContributionHistoryView per-row actions

  func testContributionHistoryRowContextActionsExposesOnlyDelete() {
    XCTAssertEqual(
      ContributionHistoryRowContextActions.all.map(\.kind),
      [.delete],
      "ContributionHistoryView rows expose Delete only — the row's tap "
        + "is the navigation-link 'open' action and does not belong in "
        + "the per-row context menu."
    )
  }

  func testContributionHistoryRowContextActionsDeleteIsDestructiveWithTrashIcon() {
    XCTAssertEqual(ContributionHistoryRowContextActions.delete.title, "Delete")
    XCTAssertEqual(ContributionHistoryRowContextActions.delete.systemImage, "trash")
    XCTAssertTrue(
      ContributionHistoryRowContextActions.delete.isDestructive,
      "Delete must adopt .destructive so the context-menu row renders in red "
        + "and so the matching swipe button stays visually consistent."
    )
    XCTAssertEqual(ContributionHistoryRowContextActions.delete.kind, .delete)
  }

  func testContributionHistoryRowContextActionsTitleMatchesSwipeActionTitle() {
    // The swipe-actions block on `ContributionHistoryView` hard-codes
    // "Delete" with .destructive role — see
    // `ContributionHistoryContent.body`. The context-menu must mirror
    // that exact label so a swipe-Delete user and a right-click-Delete
    // user converge on the same word.
    XCTAssertEqual(
      ContributionHistoryRowContextActions.all.map(\.title),
      ["Delete"]
    )
    XCTAssertEqual(
      ContributionHistoryRowContextActions.all.map(\.isDestructive),
      [true]
    )
  }

  // MARK: - Cross-catalog invariants

  func testEveryDestructiveActionAcrossCatalogsUsesTrashIcon() {
    let destructiveIcons =
      (PortfolioRowContextActions.all + ContributionHistoryRowContextActions.all)
      .filter(\.isDestructive)
      .map(\.systemImage)

    XCTAssertFalse(
      destructiveIcons.isEmpty,
      "At least one destructive row action must exist — both list "
        + "surfaces expose Delete."
    )
    XCTAssertTrue(
      destructiveIcons.allSatisfy { $0 == "trash" },
      "All destructive row actions across MVP list surfaces must use the "
        + "trash SF Symbol so users learn one icon-shape for destructive "
        + "intent across the app."
    )
  }
}
