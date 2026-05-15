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
}
