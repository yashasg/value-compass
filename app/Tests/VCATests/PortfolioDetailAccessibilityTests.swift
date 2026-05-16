import Foundation
import XCTest

@testable import VCA

/// Pins `PortfolioDetailAccessibility.announcement(for:)` — the VoiceOver
/// string posted by `PortfolioDetailContent.calculateSection` when the
/// `calculationOutput` state transitions from `nil` to a value (#352).
///
/// Closes the WCAG 2.2 SC 4.1.3 gap: a screen-reader user taps Calculate,
/// focus stays on the button, and the inserted result block is silent by
/// default. The view posts this string via `UIAccessibility.post` so the
/// outcome reaches AT users without a focus change. Each branch — success,
/// failure, singular vs. plural allocations — is asserted here so future
/// refactors of the announcement copy or the on-screen summary fall out
/// of sync deliberately, not silently.
final class PortfolioDetailAccessibilityTests: XCTestCase {
  func testAnnouncementForErrorOutputReturnsLocalizedDescription() {
    let output = ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
    let message = PortfolioDetailAccessibility.announcement(for: output)
    XCTAssertEqual(message, ContributionCalculationError.missingPortfolio.localizedDescription)
  }

  func testAnnouncementForSuccessIncludesAmountAndAllocationCountPlural() {
    let output = ContributionOutput(
      totalAmount: Decimal(string: "1234.56")!,
      categoryBreakdown: [],
      allocations: [
        TickerContributionAllocation(
          tickerSymbol: "VTI", categoryName: "Core",
          amount: Decimal(string: "617.28")!, allocatedWeight: Decimal(string: "0.5")!),
        TickerContributionAllocation(
          tickerSymbol: "BND", categoryName: "Bonds",
          amount: Decimal(string: "617.28")!, allocatedWeight: Decimal(string: "0.5")!),
      ],
      error: nil
    )
    let message = PortfolioDetailAccessibility.announcement(for: output)
    XCTAssertEqual(
      message,
      "Calculation complete. Monthly contribution $1234.56. 2 ticker allocations ready."
    )
  }

  func testAnnouncementForSuccessUsesSingularAllocationWhenExactlyOne() {
    let output = ContributionOutput(
      totalAmount: Decimal(string: "100")!,
      categoryBreakdown: [],
      allocations: [
        TickerContributionAllocation(
          tickerSymbol: "VTI", categoryName: "Core",
          amount: Decimal(string: "100")!, allocatedWeight: Decimal(string: "1")!)
      ],
      error: nil
    )
    let message = PortfolioDetailAccessibility.announcement(for: output)
    XCTAssertEqual(
      message,
      "Calculation complete. Monthly contribution $100. 1 ticker allocation ready."
    )
  }

  func testAnnouncementForSuccessWithZeroAllocationsUsesPlural() {
    let output = ContributionOutput(
      totalAmount: Decimal.zero,
      categoryBreakdown: [],
      allocations: [],
      error: nil
    )
    let message = PortfolioDetailAccessibility.announcement(for: output)
    XCTAssertEqual(
      message,
      "Calculation complete. Monthly contribution $0. 0 ticker allocations ready."
    )
  }

  // MARK: - Calculate disabled-button hint (#386)

  func testCalculateDisabledHintIsEmptyWhenCanCalculateIsTrue() {
    // SwiftUI auto-suppresses an empty `.accessibilityHint(_:)`. The
    // enabled state must return "" so the button does not narrate
    // unblock instructions when there is nothing to unblock.
    XCTAssertEqual(
      PortfolioDetailAccessibility.calculateDisabledHint(canCalculate: true),
      ""
    )
  }

  func testCalculateDisabledHintNamesHoldingsAsTheUnblockReasonWhenDisabled() {
    // The visible "Warnings must be resolved before calculating."
    // banner at `portfolio.detail.calculateBlocked` is a separate AT
    // element. VoiceOver / Voice Control / Switch Control users who
    // focus the disabled button directly hear "Calculate, dimmed
    // button" with no programmatic link to the warning, so the hint
    // must name the source of the warnings (the holdings list) so the
    // user knows where to go to fix them.
    XCTAssertEqual(
      PortfolioDetailAccessibility.calculateDisabledHint(canCalculate: false),
      "Resolve warnings in the holdings list to enable."
    )
  }

  func testCalculateDisabledHintNamesHoldingsListSurface() {
    // Pin the verbatim mention of "holdings" because the unblock
    // route is "tap Edit Holdings to fix the warning". A future
    // copy edit that drops "holdings" (e.g. "Resolve warnings to
    // enable.") would leave AT users without a route — the visible
    // banner only says "warnings", not where to find them.
    let hint = PortfolioDetailAccessibility.calculateDisabledHint(canCalculate: false)
    XCTAssertTrue(
      hint.lowercased().contains("holdings"),
      "Disabled-state hint should name the holdings surface so AT users have a route to fix the warning."
    )
  }

  func testCalculateDisabledHintIsNonEmptyWhenDisabled() {
    // Defensive: an empty disabled-state hint would silently regress
    // to the default `"Calculate, dimmed button"` announcement and
    // recreate the #386 gap. Pin "disabled is always audible".
    let hint = PortfolioDetailAccessibility.calculateDisabledHint(canCalculate: false)
    XCTAssertFalse(
      hint.isEmpty,
      "Disabled-state hint must not be empty — an empty hint silently restores the #386 'dimmed with no reason' gap."
    )
  }
}
