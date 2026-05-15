import Foundation
import XCTest

@testable import VCA

/// Pins `FinancialRowAccessibility` — the VoiceOver label/value composer
/// for the multi-text "financial row" surfaces called out in #227 (per-
/// ticker allocation rows in `ContributionResultView`, per-ticker market-
/// data rows in `PortfolioDetailView`, and per-ticker breakdown rows in
/// `ContributionHistoryView`'s detail surface).
///
/// Each row is collapsed into a single accessibility element with an
/// explicit `label = symbol/category` and `value = financial breakdown`.
/// These tests pin the exact spoken strings so future refactors of the
/// on-screen layout cannot silently regress the VoiceOver contract (WCAG
/// 2.2 SC 1.3.1 / SC 4.1.2).
final class FinancialRowAccessibilityTests: XCTestCase {
  // MARK: - ContributionResultView allocation rows

  func testResultAllocationLabelIsTickerSymbol() {
    let allocation = TickerContributionAllocation(
      tickerSymbol: "VTI",
      categoryName: "Core",
      amount: Decimal(string: "250.00")!,
      allocatedWeight: Decimal(string: "0.25")!
    )
    XCTAssertEqual(
      FinancialRowAccessibility.label(forResultAllocation: allocation), "VTI")
  }

  func testResultAllocationValueJoinsCurrencyAndPercent() {
    let allocation = TickerContributionAllocation(
      tickerSymbol: "VTI",
      categoryName: "Core",
      amount: Decimal(string: "250.00")!,
      allocatedWeight: Decimal(string: "0.25")!
    )
    XCTAssertEqual(
      FinancialRowAccessibility.value(forResultAllocation: allocation),
      "\(Decimal(string: "250.00")!.appCurrencyFormatted()), \(Decimal(string: "0.25")!.appPercentFormatted())"
    )
  }

  // MARK: - ContributionResultView category header rows

  func testResultCategoryLabelIsCategoryName() {
    let category = CategoryContributionResult(
      categoryName: "Core",
      amount: Decimal(string: "750.00")!,
      allocatedWeight: Decimal(string: "0.75")!
    )
    XCTAssertEqual(
      FinancialRowAccessibility.label(forResultCategory: category), "Core")
  }

  func testResultCategoryValueIsCurrencyFormattedAmount() {
    let category = CategoryContributionResult(
      categoryName: "Core",
      amount: Decimal(string: "750.00")!,
      allocatedWeight: Decimal(string: "0.75")!
    )
    XCTAssertEqual(
      FinancialRowAccessibility.value(forResultCategory: category),
      Decimal(string: "750.00")!.appCurrencyFormatted()
    )
  }

  // MARK: - PortfolioDetailView ticker market-data rows

  func testTickerLabelIsNormalizedSymbol() {
    let ticker = TickerSnapshot(
      id: UUID(),
      normalizedSymbol: "VTI",
      currentPrice: Decimal(string: "234.56")!,
      movingAverage: Decimal(string: "230.10")!,
      currentPriceText: "234.56",
      movingAverageText: "230.10",
      hasCompleteMarketData: true
    )
    XCTAssertEqual(
      FinancialRowAccessibility.label(forTicker: ticker), "VTI")
  }

  func testTickerValueWithCompleteMarketDataIncludesPriceMovingAverageAndReadyStatus() {
    let ticker = TickerSnapshot(
      id: UUID(),
      normalizedSymbol: "VTI",
      currentPrice: Decimal(string: "234.56")!,
      movingAverage: Decimal(string: "230.10")!,
      currentPriceText: "234.56",
      movingAverageText: "230.10",
      hasCompleteMarketData: true
    )
    XCTAssertEqual(
      FinancialRowAccessibility.value(forTicker: ticker, maWindow: 200),
      "Price \(Decimal(string: "234.56")!.appCurrencyFormatted()), 200-day moving average \(Decimal(string: "230.10")!.appCurrencyFormatted()), status Ready"
    )
  }

  func testTickerValueWithMissingMarketDataReturnsMissingSentinel() {
    let ticker = TickerSnapshot(
      id: UUID(),
      normalizedSymbol: "VTI",
      currentPrice: nil,
      movingAverage: nil,
      currentPriceText: "",
      movingAverageText: "",
      hasCompleteMarketData: false
    )
    XCTAssertEqual(
      FinancialRowAccessibility.value(forTicker: ticker, maWindow: 50),
      "Missing market data"
    )
  }

  func testTickerValueWithPartialMarketDataIsTreatedAsMissing() {
    // `hasCompleteMarketData` is the projection's authoritative flag.
    // Either-only price or MA must still speak "Missing market data" so
    // the AT-visible status matches the visible "Missing" badge.
    let priceOnly = TickerSnapshot(
      id: UUID(),
      normalizedSymbol: "BND",
      currentPrice: Decimal(string: "75.00")!,
      movingAverage: nil,
      currentPriceText: "75.00",
      movingAverageText: "",
      hasCompleteMarketData: false
    )
    XCTAssertEqual(
      FinancialRowAccessibility.value(forTicker: priceOnly, maWindow: 200),
      "Missing market data"
    )
  }

  // MARK: - ContributionHistoryView detail breakdown rows

  func testHistoryAllocationLabelIsTickerSymbol() {
    let allocation = TickerAllocationSnapshot(
      id: UUID(),
      tickerSymbol: "VTI",
      categoryName: "Core",
      amount: Decimal(string: "250.00")!,
      allocatedWeight: Decimal(string: "0.25")!
    )
    XCTAssertEqual(
      FinancialRowAccessibility.label(forHistoryAllocation: allocation), "VTI")
  }

  func testHistoryAllocationValueJoinsCurrencyAndCategoryName() {
    let allocation = TickerAllocationSnapshot(
      id: UUID(),
      tickerSymbol: "VTI",
      categoryName: "Core",
      amount: Decimal(string: "250.00")!,
      allocatedWeight: Decimal(string: "0.25")!
    )
    XCTAssertEqual(
      FinancialRowAccessibility.value(forHistoryAllocation: allocation),
      "\(Decimal(string: "250.00")!.appCurrencyFormatted()), Core"
    )
  }
}
