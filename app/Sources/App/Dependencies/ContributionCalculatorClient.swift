import ComposableArchitecture
import Foundation

/// `@DependencyClient` wrapper around `ContributionCalculationService`.
///
/// Reducers consume this via `@Dependency(\.contributionCalculator)` to run
/// the local Value-Cost-Averaging math without taking a direct reference to
/// `MovingAverageContributionCalculator`. Tests can stub `calculate` to drive
/// the reducer with deterministic outputs.
///
/// Lives at this scope because only `PortfolioDetailFeature` (issue #154)
/// needs it today; the broader Phase 0 dependency-interfaces issue (#164)
/// intentionally deferred calculation client wiring.
///
/// The `calculate` closure runs on `@MainActor` because `Portfolio` is a
/// SwiftData `@Model` class and is `MainActor`-isolated when accessed via
/// the main `ModelContext`.
@DependencyClient
struct ContributionCalculatorClient {
  var calculate: @MainActor (_ portfolio: Portfolio?) -> ContributionOutput = { _ in
    ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
  }
}

extension ContributionCalculatorClient: DependencyKey {
  static let liveValue = ContributionCalculatorClient(
    calculate: { portfolio in
      ContributionCalculationService.calculate(
        portfolio: portfolio,
        calculator: MovingAverageContributionCalculator()
      )
    }
  )

  static let previewValue = ContributionCalculatorClient(
    calculate: { _ in ContributionOutput(totalAmount: 0) }
  )
}

extension DependencyValues {
  var contributionCalculator: ContributionCalculatorClient {
    get { self[ContributionCalculatorClient.self] }
    set { self[ContributionCalculatorClient.self] = newValue }
  }
}
