import Foundation
import XCTest

@testable import VCA

/// Pins the announcement composers introduced in #293 for the three editor
/// surfaces whose inline status messages were previously silent to VoiceOver
/// (WCAG 2.2 SC 4.1.3 — Status Messages).
///
/// SwiftUI does not let unit tests introspect view modifiers, so each helper
/// is a pure value-producing function whose output is the string the view
/// hands to `UIAccessibility.post(notification: .announcement, ...)`. The
/// tests below pin every branch — including the singular/plural fork on
/// allocation count and the count-transition cases on the holdings editor —
/// so future copy or threshold changes have to be deliberate.
final class EditorAccessibilityTests: XCTestCase {
  // MARK: - PortfolioEditorAccessibility

  func testPortfolioEditorAnnouncementForEmptyNameReturnsLocalizedDescription() {
    let message = PortfolioEditorAccessibility.announcement(for: .emptyName)
    XCTAssertEqual(
      message,
      PortfolioEditorValidationError.emptyName.localizedDescription
    )
  }

  func testPortfolioEditorAnnouncementForInvalidBudgetReturnsLocalizedDescription() {
    let message = PortfolioEditorAccessibility.announcement(for: .invalidBudget)
    XCTAssertEqual(
      message,
      PortfolioEditorValidationError.invalidBudget.localizedDescription
    )
  }

  func testPortfolioEditorAnnouncementForInvalidMAWindowReturnsLocalizedDescription() {
    let message = PortfolioEditorAccessibility.announcement(for: .invalidMAWindow(123))
    XCTAssertEqual(
      message,
      PortfolioEditorValidationError.invalidMAWindow(123).localizedDescription
    )
  }

  // MARK: - HoldingsEditorAccessibility

  func testHoldingsEditorAnnouncementReturnsNilWhenIssueCountUnchanged() {
    XCTAssertNil(
      HoldingsEditorAccessibility.announcement(
        forIssueCountChangeFrom: 0,
        to: 0,
        firstIssueMessage: nil
      )
    )
    XCTAssertNil(
      HoldingsEditorAccessibility.announcement(
        forIssueCountChangeFrom: 2,
        to: 2,
        firstIssueMessage: "Anything"
      )
    )
  }

  func testHoldingsEditorAnnouncementSpeaksClearedWhenAllIssuesResolve() {
    let message = HoldingsEditorAccessibility.announcement(
      forIssueCountChangeFrom: 3,
      to: 0,
      firstIssueMessage: nil
    )
    XCTAssertEqual(message, "Holdings warnings cleared.")
  }

  func testHoldingsEditorAnnouncementForFirstIssueIncludesCountAndFirstMessage() {
    let message = HoldingsEditorAccessibility.announcement(
      forIssueCountChangeFrom: 0,
      to: 1,
      firstIssueMessage: HoldingsDraftIssue.categoryWeightsDoNotSumTo100.message
    )
    XCTAssertEqual(
      message,
      "1 holdings warning. Category weights must add up to 100% before calculating."
    )
  }

  func testHoldingsEditorAnnouncementForFirstBatchUsesPluralWord() {
    let message = HoldingsEditorAccessibility.announcement(
      forIssueCountChangeFrom: 0,
      to: 3,
      firstIssueMessage: HoldingsDraftIssue.emptyCategoryName.message
    )
    XCTAssertEqual(
      message,
      "3 holdings warnings. Category names are required."
    )
  }

  func testHoldingsEditorAnnouncementForFirstBatchWithEmptyMessageOmitsTrailingSentence() {
    let message = HoldingsEditorAccessibility.announcement(
      forIssueCountChangeFrom: 0,
      to: 2,
      firstIssueMessage: ""
    )
    XCTAssertEqual(message, "2 holdings warnings.")
  }

  func testHoldingsEditorAnnouncementForGrowingCountReportsNewTotal() {
    let message = HoldingsEditorAccessibility.announcement(
      forIssueCountChangeFrom: 1,
      to: 3,
      firstIssueMessage: HoldingsDraftIssue.emptyTickerSymbol.message
    )
    XCTAssertEqual(message, "Now 3 holdings warnings.")
  }

  func testHoldingsEditorAnnouncementForShrinkingCountReportsNewTotal() {
    let message = HoldingsEditorAccessibility.announcement(
      forIssueCountChangeFrom: 4,
      to: 1,
      firstIssueMessage: HoldingsDraftIssue.emptyTickerSymbol.message
    )
    XCTAssertEqual(message, "Now 1 holdings warning.")
  }

  // MARK: - ContributionResultAccessibility

  func testContributionResultAnnouncementForErrorReturnsLocalizedDescription() {
    let output = ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
    let message = ContributionResultAccessibility.announcement(for: output)
    XCTAssertEqual(
      message,
      ContributionCalculationError.missingPortfolio.localizedDescription
    )
  }

  func testContributionResultAnnouncementForSuccessIncludesAmountAndPluralAllocations() {
    let output = ContributionOutput(
      totalAmount: Decimal(string: "1234.56")!,
      categoryBreakdown: [],
      allocations: [
        TickerContributionAllocation(
          tickerSymbol: "VTI",
          categoryName: "Core",
          amount: Decimal(string: "617.28")!,
          allocatedWeight: Decimal(string: "0.5")!
        ),
        TickerContributionAllocation(
          tickerSymbol: "BND",
          categoryName: "Bonds",
          amount: Decimal(string: "617.28")!,
          allocatedWeight: Decimal(string: "0.5")!
        ),
      ],
      error: nil
    )
    let message = ContributionResultAccessibility.announcement(for: output)
    XCTAssertEqual(
      message,
      "Calculation complete. Monthly contribution $1234.56. 2 ticker allocations ready."
    )
  }

  func testContributionResultAnnouncementForSingleAllocationUsesSingularWord() {
    let output = ContributionOutput(
      totalAmount: Decimal(string: "100")!,
      categoryBreakdown: [],
      allocations: [
        TickerContributionAllocation(
          tickerSymbol: "VTI",
          categoryName: "Core",
          amount: Decimal(string: "100")!,
          allocatedWeight: Decimal(string: "1")!
        )
      ],
      error: nil
    )
    let message = ContributionResultAccessibility.announcement(for: output)
    XCTAssertEqual(
      message,
      "Calculation complete. Monthly contribution $100. 1 ticker allocation ready."
    )
  }

  func testContributionResultAnnouncementForZeroAllocationsUsesPluralWord() {
    let output = ContributionOutput(
      totalAmount: Decimal(string: "0")!,
      categoryBreakdown: [],
      allocations: [],
      error: nil
    )
    let message = ContributionResultAccessibility.announcement(for: output)
    XCTAssertEqual(
      message,
      "Calculation complete. Monthly contribution $0. 0 ticker allocations ready."
    )
  }
}
