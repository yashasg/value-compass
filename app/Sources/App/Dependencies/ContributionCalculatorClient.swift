import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `ContributionCalculationService`.
///
/// Reducers consume this via `@Dependency(\.contributionCalculator)` to run
/// the local Value-Cost-Averaging math without taking a direct reference to
/// `MovingAverageContributionCalculator`. Tests can stub the closures to
/// drive the reducer with deterministic outputs.
///
/// ## Surface
///
/// - ``calculate``: legacy seam that runs the live
///   `MovingAverageContributionCalculator` against `Portfolio.monthlyBudget`.
///   Reducers already on this path (`PortfolioDetailFeature`,
///   `ContributionResultFeature`) keep working bit-for-bit. Will be marked
///   `@available(*, deprecated)` once #130 lands and every call site has
///   migrated to ``calculateWithInput``.
/// - ``calculateWithInput``: full-shape seam introduced for #242. The
///   reducer supplies every degree of freedom on `ContributionInput`
///   (monthly budget, `MarketDataSnapshot`, `min/max` multipliers) and
///   picks which `ContributionCalculating` implementation to run. This is
///   the path #128 (Massive client → `MarketDataBar` → snapshot), #130
///   (Invest with required capital), and #131 (snapshots that record their
///   input) need; without it `BandAdjustedContributionCalculator` and
///   `ProportionalSplitContributionCalculator` are unreachable from any
///   reducer.
/// - ``calculateForHoldings``: MVP-path seam introduced for #359. Drives
///   `calculateWithInput` from a flat `[Holding]` array + caller-supplied
///   `MarketDataSnapshot` so reducers can run a `ContributionCalculating`
///   conformer against the MVP shape without traversing the legacy
///   `Portfolio → Category → Ticker` graph. Required once #123 retires
///   `Ticker`; available now so call sites can be wired ahead of time.
/// - ``defaultCalculator``: live factory that returns the implementation
///   `MovingAverageContributionCalculator` to inject when a reducer has no
///   reason to override. Tests can swap this to drive end-to-end coverage
///   of an alternative `ContributionCalculating` through the reducer
///   without touching the live wiring.
///
/// All closures are `@MainActor` because `Portfolio` is a SwiftData
/// `@Model` class and is `MainActor`-isolated when accessed via the main
/// `ModelContext`. The protocol requires `Sendable` so existential
/// `any ContributionCalculating` values can travel across the seam.
@DependencyClient
struct ContributionCalculatorClient: Sendable {
  var calculate: @MainActor @Sendable (_ portfolio: Portfolio?) -> ContributionOutput = { _ in
    ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
  }

  var calculateWithInput:
    @MainActor @Sendable (_ input: ContributionInput, _ calculator: any ContributionCalculating)
      -> ContributionOutput = { _, _ in
        ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
      }

  /// MVP-path seam (issue #359). Drives `calculateWithInput` from a flat
  /// `[Holding]` array + a caller-supplied `MarketDataSnapshot`, without
  /// requiring reducers to traverse the legacy `Portfolio → Category →
  /// Ticker` graph. Internally wraps the inputs into a
  /// ``ContributionInput`` via
  /// ``ContributionInput/init(holdings:monthlyBudget:marketDataSnapshot:minMultiplier:maxMultiplier:)``
  /// so existing ``ContributionCalculating`` conformers keep running
  /// unchanged. Once `Ticker` is retired (#123), only the
  /// `ContributionInput` synthesis step needs to be replaced — this seam
  /// is stable.
  var calculateForHoldings:
    @MainActor @Sendable (
      _ holdings: [Holding],
      _ monthlyBudget: Decimal,
      _ marketDataSnapshot: MarketDataSnapshot,
      _ calculator: any ContributionCalculating
    ) -> ContributionOutput = { _, _, _, _ in
      ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
    }

  var defaultCalculator: @MainActor @Sendable () -> any ContributionCalculating = {
    MovingAverageContributionCalculator()
  }
}

extension ContributionCalculatorClient: DependencyKey {
  static let liveValue = ContributionCalculatorClient(
    calculate: { portfolio in
      ContributionCalculationService.calculate(
        portfolio: portfolio,
        calculator: MovingAverageContributionCalculator()
      )
    },
    calculateWithInput: { input, calculator in
      ContributionCalculationService.calculate(input: input, calculator: calculator)
    },
    calculateForHoldings: { holdings, monthlyBudget, marketDataSnapshot, calculator in
      let input = ContributionInput(
        holdings: holdings,
        monthlyBudget: monthlyBudget,
        marketDataSnapshot: marketDataSnapshot
      )
      return ContributionCalculationService.calculate(input: input, calculator: calculator)
    },
    defaultCalculator: { MovingAverageContributionCalculator() }
  )

  static let previewValue = ContributionCalculatorClient(
    calculate: { _ in ContributionOutput(totalAmount: 0) },
    calculateWithInput: { _, _ in ContributionOutput(totalAmount: 0) },
    calculateForHoldings: { _, _, _, _ in ContributionOutput(totalAmount: 0) },
    defaultCalculator: { MovingAverageContributionCalculator() }
  )
}

extension DependencyValues {
  var contributionCalculator: ContributionCalculatorClient {
    get { self[ContributionCalculatorClient.self] }
    set { self[ContributionCalculatorClient.self] = newValue }
  }
}
