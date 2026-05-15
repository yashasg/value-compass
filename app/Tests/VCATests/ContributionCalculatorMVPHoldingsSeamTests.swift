import ComposableArchitecture
import Foundation
import SwiftData
import XCTest

@testable import VCA

/// Pins the MVP-path seam introduced for issue #359. Before this seam,
/// every shipping `ContributionCalculating` conformer read
/// `input.portfolio.categories.flatMap(\.tickers)` to find symbols and
/// derive its market-data snapshot — meaning that once the legacy
/// `Portfolio → Category → Ticker` graph is retired by the MVP holdings
/// migration (#123), every conformer silently returns
/// `.missingMarketData(symbol)` for every symbol in the (now-empty)
/// `categories` array.
///
/// These tests verify that:
///
/// 1. `MarketDataSnapshot(holdings:)` exists today as a stub factory that
///    returns an empty snapshot until #356 adds indicator fields to
///    `LocalSchemaV2.Holding`. The factory's signature is the contract
///    seam — call sites can wire it ahead of the data becoming available.
/// 2. `ContributionInput(holdings:monthlyBudget:marketDataSnapshot:…)`
///    carries the supplied snapshot and budget end-to-end, so reducer
///    and test code driving the seam never has to construct a `Ticker`
///    or `Category` directly.
/// 3. `MovingAverageContributionCalculator` runs through the new seam
///    against MVP `[Holding]` rows + a non-empty `MarketDataSnapshot`
///    without emitting `.missingMarketData(symbol)`.
/// 4. `BandAdjustedContributionCalculator` is reachable through the new
///    seam with band-position quotes — proving alternative
///    `ContributionCalculating` implementations are now driveable on
///    the MVP path.
/// 5. `ProportionalSplitContributionCalculator` is **documented as
///    blocked** when the holdings have zero market-data coverage (the
///    shared validator gates on `currentPrice` + `movingAverage`). A
///    follow-up to #359 owns the validator relaxation; this test pins
///    the current behavior so the follow-up's surface change is
///    visible.
/// 6. Existing `ContributionCalculating` conformer behavior on the
///    legacy `Ticker`-backed path is bit-identical (regression-free).
@MainActor
final class ContributionCalculatorMVPHoldingsSeamTests: XCTestCase {

  // MARK: - AC1: MarketDataSnapshot(holdings:) is a stub today

  func testMarketDataSnapshotFromHoldingsIsEmptyUntilIssue356LandsIndicatorFields() {
    let holdings = [
      Self.makeHolding(symbol: "VTI", sortOrder: 0),
      Self.makeHolding(symbol: "BND", sortOrder: 1),
    ]

    let snapshot = MarketDataSnapshot(holdings: holdings)

    XCTAssertTrue(
      snapshot.quotesBySymbol.isEmpty,
      "`MarketDataSnapshot(holdings:)` must return an empty snapshot until #356 "
        + "adds indicator fields to `LocalSchemaV2.Holding`. A non-empty result "
        + "here means the stub silently started carrying quotes from a source "
        + "this test wasn't aware of — re-pin the factory before promoting it.")
    XCTAssertNil(snapshot.quote(for: "VTI"))
    XCTAssertNil(snapshot.quote(for: "BND"))
  }

  // MARK: - AC2: ContributionInput(holdings:…) carries the supplied snapshot + budget

  func testContributionInputFromHoldingsCarriesSuppliedSnapshotAndBudget() {
    let holdings = [
      Self.makeHolding(symbol: "VTI", sortOrder: 0),
      Self.makeHolding(symbol: "BND", sortOrder: 1),
    ]
    let snapshot = MarketDataSnapshot(quotesBySymbol: [
      "VTI": MarketDataQuote(currentPrice: 250, movingAverage: 245),
      "BND": MarketDataQuote(currentPrice: 75, movingAverage: 74),
    ])

    let input = ContributionInput(
      holdings: holdings,
      monthlyBudget: Decimal(500),
      marketDataSnapshot: snapshot
    )

    XCTAssertEqual(input.monthlyBudget, Decimal(500))
    XCTAssertEqual(input.marketDataSnapshot, snapshot)
    XCTAssertEqual(input.marketDataSnapshot.quote(for: "VTI")?.currentPrice, Decimal(250))
    XCTAssertEqual(input.marketDataSnapshot.quote(for: "BND")?.currentPrice, Decimal(75))
  }

  // MARK: - AC3 + AC4: MovingAverage drives through the seam on MVP holdings

  func testCalculateForHoldingsRunsMovingAverageAgainstMVPHoldings() {
    let client = ContributionCalculatorClient.liveValue
    let holdings = [
      Self.makeHolding(symbol: "VTI", sortOrder: 0),
      Self.makeHolding(symbol: "BND", sortOrder: 1),
    ]
    let snapshot = MarketDataSnapshot(quotesBySymbol: [
      "VTI": MarketDataQuote(currentPrice: 250, movingAverage: 245),
      "BND": MarketDataQuote(currentPrice: 75, movingAverage: 74),
    ])

    let output = client.calculateForHoldings(
      holdings,
      Decimal(1_000),
      snapshot,
      MovingAverageContributionCalculator()
    )

    XCTAssertNil(
      output.error,
      "MVP holdings + non-empty market-data snapshot must reach "
        + "`MovingAverageContributionCalculator` without producing "
        + "`.missingMarketData(symbol)` — #359 contract.")
    XCTAssertEqual(output.totalAmount, Decimal(1_000))
    XCTAssertEqual(output.allocations.map(\.tickerSymbol).sorted(), ["BND", "VTI"])
  }

  // MARK: - AC4 (alternate implementation): BandAdjusted drives through the seam

  func testCalculateForHoldingsReachesBandAdjustedCalculatorOnMVPHoldings() {
    let client = ContributionCalculatorClient.liveValue
    let holdings = [
      Self.makeHolding(symbol: "VTI", sortOrder: 0),
      Self.makeHolding(symbol: "BND", sortOrder: 1),
    ]
    let snapshot = MarketDataSnapshot(quotesBySymbol: [
      "VTI": MarketDataQuote(
        currentPrice: 250, movingAverage: 245, bandPosition: Decimal(string: "0.5")),
      "BND": MarketDataQuote(
        currentPrice: 75, movingAverage: 74, bandPosition: Decimal(string: "0.5")),
    ])

    let output = client.calculateForHoldings(
      holdings,
      Decimal(1_000),
      snapshot,
      BandAdjustedContributionCalculator()
    )

    XCTAssertNil(output.error)
    XCTAssertEqual(output.totalAmount, Decimal(1_000))
    XCTAssertFalse(output.allocations.isEmpty)
  }

  // MARK: - AC5: ProportionalSplit is documented as blocked (validator-gated)

  func testProportionalSplitCalculatorIsBlockedWhenHoldingsHaveNoMarketDataCoverage() {
    // Pins the AC5 "documented as blocked" branch. The proportional
    // split has no logical market-data dependency, but
    // `ContributionInputValidator` gates every conformer on
    // `currentPrice` + `movingAverage`. A follow-up to #359 owns
    // relaxing the validator so weight-only algorithms run without
    // market-data coverage. Until then, this test pins the current
    // behavior so the relaxation's surface change is visible in diff.
    let client = ContributionCalculatorClient.liveValue
    let holdings = [Self.makeHolding(symbol: "VTI", sortOrder: 0)]

    let output = client.calculateForHoldings(
      holdings,
      Decimal(1_000),
      MarketDataSnapshot(holdings: holdings),
      ProportionalSplitContributionCalculator()
    )

    XCTAssertEqual(
      output.error as? ContributionCalculationError,
      .missingMarketData("VTI"),
      "Documented behavior today: the shared validator rejects the "
        + "proportional split on the MVP path with zero coverage. "
        + "When this assertion flips, update "
        + "`ProportionalSplitContributionCalculator`'s doc comment and "
        + "the AC5 documentation in the #359 PR.")
  }

  // MARK: - AC6: Legacy Ticker-backed path is unchanged

  func testLegacyTickerBackedCalculationIsUnchangedByMVPSeam() {
    let portfolio = Portfolio(
      name: "Legacy",
      monthlyBudget: Decimal(1_000),
      categories: [
        Category(
          name: "Equity",
          weight: 1,
          sortOrder: 0,
          tickers: [
            Ticker(
              symbol: "VTI", currentPrice: 250, movingAverage: 245, sortOrder: 0)
          ])
      ]
    )

    let output = ContributionCalculationService.calculate(
      portfolio: portfolio,
      calculator: MovingAverageContributionCalculator()
    )

    XCTAssertNil(output.error)
    XCTAssertEqual(output.totalAmount, Decimal(1_000))
    XCTAssertEqual(output.allocations.map(\.tickerSymbol), ["VTI"])
    XCTAssertEqual(output.allocations.map(\.amount), [Decimal(1_000)])
  }

  // MARK: - Helpers

  private static func makeHolding(symbol: String, sortOrder: Int) -> Holding {
    Holding(
      portfolioId: UUID(),
      symbol: symbol,
      costBasis: 0,
      shares: 0,
      sortOrder: sortOrder
    )
  }
}
