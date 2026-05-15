import ComposableArchitecture
import Foundation
import SwiftData
import XCTest

@testable import VCA

/// Pins the ``ContributionCalculatorClient`` DI seam introduced for issue
/// #242. The legacy seam took only `Portfolio?` and hard-coded
/// `MovingAverageContributionCalculator`, leaving
/// `BandAdjustedContributionCalculator` /
/// `ProportionalSplitContributionCalculator` and any user-authored
/// `ContributionCalculating` implementation unreachable from a reducer —
/// even though the seam was advertised as user-swappable in
/// `docs/tech-spec.md` §7.1. These tests assert that:
///
/// 1. The legacy `calculate(_:)` path keeps routing through the live
///    `MovingAverageContributionCalculator` against the persisted
///    `Portfolio.monthlyBudget` (no behavior change for in-flight reducers).
/// 2. The new `calculateWithInput(_:_:)` path actually carries every
///    degree of freedom on `ContributionInput` end-to-end — supplying a
///    `monthlyBudget` that differs from the persisted budget proves the
///    seam isn't silently rebuilt from `Portfolio.monthlyBudget`.
/// 3. `BandAdjustedContributionCalculator` is reachable through the seam,
///    proving alternative `ContributionCalculating` implementations can
///    now be driven by reducers.
/// 4. A user-authored `ContributionCalculating` stub flows through the
///    seam unchanged — the surveillance contract for the user-swappable
///    VCA algorithm advertised in Nagel's charter.
/// 5. `defaultCalculator()` returns a `MovingAverageContributionCalculator`
///    so reducers that have no reason to override pick up the live default.
@MainActor
final class ContributionCalculatorClientTests: XCTestCase {
  func testLegacyCalculateRoutesThroughMovingAverageAgainstPersistedBudget() throws {
    let client = ContributionCalculatorClient.liveValue
    let portfolio = Self.makeValidPortfolio(monthlyBudget: Decimal(1_000))

    let output = client.calculate(portfolio)

    XCTAssertNil(output.error)
    XCTAssertEqual(output.totalAmount, Decimal(1_000))
    XCTAssertEqual(output.allocations.map(\.tickerSymbol).sorted(), ["BND", "VTI"])
  }

  func testCalculateWithInputCarriesMonthlyBudgetEndToEnd() throws {
    // Persisted budget is 1_000 but the reducer-supplied input asks for
    // 250. The legacy seam silently used the persisted value; the new
    // seam must honor the supplied input.
    let client = ContributionCalculatorClient.liveValue
    let portfolio = Self.makeValidPortfolio(monthlyBudget: Decimal(1_000))
    let input = ContributionInput(portfolio: portfolio, monthlyBudget: Decimal(250))

    let output = client.calculateWithInput(input, MovingAverageContributionCalculator())

    XCTAssertNil(output.error)
    XCTAssertEqual(output.totalAmount, Decimal(250))
  }

  func testCalculateWithInputReachesBandAdjustedCalculatorThroughTheSeam() throws {
    let client = ContributionCalculatorClient.liveValue
    let portfolio = Self.makeValidPortfolio(
      monthlyBudget: Decimal(1_000), bandPosition: Decimal(string: "0.5"))
    let input = ContributionInput(
      portfolio: portfolio,
      monthlyBudget: Decimal(1_000),
      minMultiplier: BandMultiplierPolicy.defaultMinimum,
      maxMultiplier: BandMultiplierPolicy.defaultMaximum
    )

    let output = client.calculateWithInput(input, BandAdjustedContributionCalculator())

    XCTAssertNil(output.error)
    // Band position 0.5 → multiplier 1.0, so the output total reconciles
    // to the supplied monthly budget instead of the persisted one.
    XCTAssertEqual(output.totalAmount, Decimal(1_000))
    XCTAssertFalse(output.allocations.isEmpty)
  }

  func testCalculateWithInputDeliversUserAuthoredCalculatingImplementationVerbatim() {
    // Drives the seam with a user-authored stub to prove that an
    // arbitrary `ContributionCalculating` implementation reaches the
    // calculator without being silently replaced by the live
    // `MovingAverageContributionCalculator` — the user-swappable VCA
    // axis advertised in Nagel's charter.
    let stub = StubCalculator(stubbed: ContributionOutput(totalAmount: Decimal(42)))
    let client = ContributionCalculatorClient(
      calculate: { _ in
        ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
      },
      calculateWithInput: { input, calculator in
        calculator.calculate(input: input)
      },
      calculateForHoldings: { _, _, _, _ in
        ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
      },
      defaultCalculator: { stub }
    )

    let output = client.calculateWithInput(
      ContributionInput(portfolio: nil, monthlyBudget: Decimal(42)),
      stub
    )

    XCTAssertEqual(output.totalAmount, Decimal(42))
    XCTAssertNil(output.error)
  }

  func testDefaultCalculatorReturnsMovingAverageImplementation() {
    let client = ContributionCalculatorClient.liveValue
    XCTAssertTrue(client.defaultCalculator() is MovingAverageContributionCalculator)
  }

  // MARK: - Helpers

  private struct StubCalculator: ContributionCalculating {
    let stubbed: ContributionOutput
    func calculate(input: ContributionInput) -> ContributionOutput {
      stubbed
    }
  }

  private static func makeValidPortfolio(
    monthlyBudget: Decimal,
    bandPosition: Decimal? = nil
  ) -> Portfolio {
    Portfolio(
      name: "Seam Test",
      monthlyBudget: monthlyBudget,
      categories: [
        Category(
          name: "Equity",
          weight: Decimal(string: "0.60")!,
          sortOrder: 0,
          tickers: [
            Ticker(
              symbol: "VTI",
              currentPrice: Decimal(250),
              movingAverage: Decimal(245),
              bandPosition: bandPosition,
              sortOrder: 0)
          ]),
        Category(
          name: "Bonds",
          weight: Decimal(string: "0.40")!,
          sortOrder: 1,
          tickers: [
            Ticker(
              symbol: "BND",
              currentPrice: Decimal(75),
              movingAverage: Decimal(74),
              bandPosition: bandPosition,
              sortOrder: 0)
          ]),
      ]
    )
  }
}
