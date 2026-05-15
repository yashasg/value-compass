import Foundation

/// The user-swappable seam for Value Compass's pluggable contribution algorithm.
///
/// Conformers map a fully validated ``ContributionInput`` to a
/// ``ContributionOutput`` whose ``ContributionOutput/allocations`` describe how
/// the monthly budget should be split across the portfolio's tickers. The seam
/// is consumed end-to-end through ``ContributionCalculationService/calculate(input:calculator:)``
/// and is the integration point for user-authored algorithms — see issue #238.
///
/// # Pre-conditions guaranteed by ``ContributionInputValidator``
///
/// When called through ``ContributionCalculationService``, the validator runs
/// before this method and rejects any input that violates the contract below.
/// Conformers therefore may rely on the following invariants:
///
/// - ``ContributionInput/portfolio`` is non-`nil`.
/// - ``ContributionInput/monthlyBudget`` is strictly greater than `0`.
/// - ``Portfolio/categories`` is non-empty and category weights sum to `1`.
/// - Each category has at least one ticker.
/// - For every ticker, ``MarketDataSnapshot/quote(for:)`` returns a quote whose
///   ``MarketDataQuote/currentPrice`` and ``MarketDataQuote/movingAverage`` are
///   both non-`nil` and strictly greater than `0`.
///
/// Conformers invoked **outside** the service (e.g. from tests calling
/// `calculate(input:)` directly) must not assume the validator has run.
/// Re-validate, or guard locally and return ``ContributionOutput/failure(_:)``
/// — never crash. The validator runs first in every shipping conformer
/// (`MovingAverageContributionCalculator`, `BandAdjustedContributionCalculator`,
/// `ProportionalSplitContributionCalculator`); user-authored conformers should
/// do the same.
///
/// # Post-conditions enforced by ``ContributionOutputValidator``
///
/// After this method returns, the service rejects outputs that violate any of:
///
/// - No ``TickerContributionAllocation/amount`` is negative.
/// - The sum of ``ContributionOutput/allocations`` matches
///   ``ContributionOutput/totalAmount`` within cent-level tolerance.
/// - ``ContributionOutput/totalAmount`` matches the original
///   ``ContributionInput/monthlyBudget`` within cent-level tolerance.
///
/// # Error channel
///
/// The canonical error channel is ``ContributionOutput/error`` (a
/// `LocalizedError?`), populated via ``ContributionOutput/failure(_:)``. The
/// protocol method is **non-throwing** by design: throws are reserved for
/// callers that already know how to bubble failures, and the seam needs to be
/// driven from TCA reducers that store errors as state. Reserved cases live in
/// ``ContributionCalculationError``.
///
/// For invariants this protocol documents as guaranteed by the validator,
/// returning ``ContributionOutput/failure(_:)`` is still preferred over
/// `preconditionFailure` so that direct-call paths (tests, ad-hoc tooling) do
/// not crash the process.
///
/// # Calculator-private input dependencies
///
/// Some indicators required by particular algorithms are not validated by
/// ``ContributionInputValidator`` and are therefore **calculator-private input
/// dependencies**. Conformers that depend on them must guard locally and
/// return ``ContributionOutput/failure(_:)``.
///
/// - ``MarketDataQuote/bandPosition`` is not validator-checked. Band-style
///   conformers (e.g. ``BandAdjustedContributionCalculator``) guard for it and
///   return ``ContributionCalculationError/missingBandPosition(_:)`` when
///   absent.
protocol ContributionCalculating: Sendable {
  func calculate(input: ContributionInput) -> ContributionOutput
}

enum BandMultiplierPolicy {
  // Normalized band position is 0...1, so raw multiplier naturally spans 0.5...1.5.
  static let midpoint = Decimal(string: "0.5")!
  static let defaultMinimum = Decimal(string: "0.5")!
  static let defaultMaximum = Decimal(string: "1.5")!
}

struct ContributionInput {
  let portfolio: Portfolio?
  let monthlyBudget: Decimal
  let marketDataSnapshot: MarketDataSnapshot
  let minMultiplier: Decimal
  let maxMultiplier: Decimal

  init(
    portfolio: Portfolio?,
    monthlyBudget: Decimal? = nil,
    marketDataSnapshot: MarketDataSnapshot? = nil,
    minMultiplier: Decimal = BandMultiplierPolicy.defaultMinimum,
    maxMultiplier: Decimal = BandMultiplierPolicy.defaultMaximum
  ) {
    self.portfolio = portfolio
    self.monthlyBudget = monthlyBudget ?? portfolio?.monthlyBudget ?? 0
    self.marketDataSnapshot = marketDataSnapshot ?? MarketDataSnapshot(portfolio: portfolio)
    self.minMultiplier = minMultiplier
    self.maxMultiplier = maxMultiplier
  }
}

struct MarketDataSnapshot: Equatable {
  var quotesBySymbol: [String: MarketDataQuote]

  init(quotesBySymbol: [String: MarketDataQuote] = [:]) {
    var normalizedQuotes: [String: MarketDataQuote] = [:]
    for symbol in quotesBySymbol.keys.sorted() {
      normalizedQuotes[Self.normalizedSymbol(symbol)] = quotesBySymbol[symbol]
    }
    self.quotesBySymbol = normalizedQuotes
  }

  init(portfolio: Portfolio?) {
    var quotesBySymbol: [String: MarketDataQuote] = [:]
    for ticker in portfolio?.categories.flatMap(\.tickers) ?? [] {
      let symbol = ticker.normalizedSymbol
      guard !symbol.isEmpty else {
        continue
      }
      quotesBySymbol[symbol] = MarketDataQuote(
        currentPrice: ticker.currentPrice,
        movingAverage: ticker.movingAverage,
        bandPosition: ticker.bandPosition
      )
    }
    self.init(quotesBySymbol: quotesBySymbol)
  }

  func quote(for symbol: String) -> MarketDataQuote? {
    quotesBySymbol[Self.normalizedSymbol(symbol)]
  }

  private static func normalizedSymbol(_ symbol: String) -> String {
    symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  }
}

struct MarketDataQuote: Equatable {
  let currentPrice: Decimal?
  let movingAverage: Decimal?
  let bandPosition: Decimal?

  init(
    currentPrice: Decimal?,
    movingAverage: Decimal?,
    bandPosition: Decimal? = nil
  ) {
    self.currentPrice = currentPrice
    self.movingAverage = movingAverage
    self.bandPosition = bandPosition
  }
}

struct ContributionOutput {
  let totalAmount: Decimal
  let categoryBreakdown: [CategoryContributionResult]
  let allocations: [TickerContributionAllocation]
  let error: LocalizedError?

  init(
    totalAmount: Decimal = 0,
    categoryBreakdown: [CategoryContributionResult] = [],
    allocations: [TickerContributionAllocation] = [],
    error: LocalizedError? = nil
  ) {
    self.totalAmount = totalAmount
    self.categoryBreakdown = categoryBreakdown
    self.allocations = allocations
    self.error = error
  }

  static func failure(_ error: LocalizedError) -> ContributionOutput {
    ContributionOutput(error: error)
  }
}

struct CategoryContributionResult: Equatable {
  let categoryName: String
  let amount: Decimal
  let allocatedWeight: Decimal
}

struct TickerContributionAllocation: Equatable {
  let tickerSymbol: String
  let categoryName: String
  let amount: Decimal
  let allocatedWeight: Decimal
}

enum ContributionCalculationError: LocalizedError, Equatable {
  case missingPortfolio
  case invalidBudget
  case noCategories
  case categoryWeightsDoNotSumTo100
  case categoryHasNoTickers(String)
  case missingMarketData(String)
  case missingBandPosition(String)
  case invalidMarketData(String)
  case negativeAllocation(String)
  case outputTotalMismatch(expected: Decimal, actual: Decimal)
  case allocationTotalMismatch(expected: Decimal, actual: Decimal)

  var errorDescription: String? {
    switch self {
    case .missingPortfolio:
      return "A portfolio is required before calculating."
    case .invalidBudget:
      return "Monthly budget must be greater than 0."
    case .noCategories:
      return "Add at least one category before calculating."
    case .categoryWeightsDoNotSumTo100:
      return "Category weights must add up to 100% before calculating."
    case .categoryHasNoTickers(let categoryName):
      return "\(categoryName) has no tickers."
    case .missingMarketData(let symbol):
      return "\(symbol) is missing current price or moving average."
    case .missingBandPosition(let symbol):
      return "\(symbol) is missing band position."
    case .invalidMarketData(let symbol):
      return "\(symbol) market data must be greater than 0."
    case .negativeAllocation(let symbol):
      return "\(symbol) produced a negative allocation."
    case .outputTotalMismatch(let expected, let actual):
      return "Calculation total \(actual) but must equal \(expected)."
    case .allocationTotalMismatch(let expected, let actual):
      return "Allocations total \(actual) but must equal \(expected)."
    }
  }
}

enum ContributionCalculationService {
  /// Legacy entry point used by reducers that have not yet migrated to the
  /// full-shape seam (issue #242 step 2). Builds a `ContributionInput`
  /// from `Portfolio.monthlyBudget` + the `Portfolio.tickers` graph and
  /// delegates to ``calculate(input:calculator:)``.
  static func calculate(
    portfolio: Portfolio?,
    calculator: any ContributionCalculating = MovingAverageContributionCalculator()
  ) -> ContributionOutput {
    calculate(input: ContributionInput(portfolio: portfolio), calculator: calculator)
  }

  /// Full-shape entry point used by ``ContributionCalculatorClient``'s
  /// `calculateWithInput` seam. Lets a reducer supply every degree of
  /// freedom on `ContributionInput` (monthly budget, market-data
  /// snapshot, min/max multipliers) and pick which `ContributionCalculating`
  /// implementation to run — required by #128 (Massive market-data
  /// snapshot), #130 (Invest with required capital), and #131 (snapshots
  /// that record their input). See issue #242.
  static func calculate(
    input: ContributionInput,
    calculator: any ContributionCalculating
  ) -> ContributionOutput {
    if let validationError = ContributionInputValidator.validate(input) {
      return .failure(validationError)
    }

    let output = calculator.calculate(input: input)
    if output.error != nil {
      return output
    }

    if let contractError = ContributionOutputValidator.validate(
      output, expectedTotal: input.monthlyBudget)
    {
      return .failure(contractError)
    }

    return output
  }
}

enum ContributionInputValidator {
  static func validate(_ input: ContributionInput) -> ContributionCalculationError? {
    guard let portfolio = input.portfolio else {
      return .missingPortfolio
    }

    guard input.monthlyBudget > 0 else {
      return .invalidBudget
    }

    let categories = portfolio.categories.sorted { $0.sortOrder < $1.sortOrder }
    guard !categories.isEmpty else {
      return .noCategories
    }

    guard categories.reduce(Decimal(0), { $0 + $1.weight }) == 1 else {
      return .categoryWeightsDoNotSumTo100
    }

    for category in categories {
      let tickers = category.tickers.sorted { $0.sortOrder < $1.sortOrder }
      guard !tickers.isEmpty else {
        return .categoryHasNoTickers(category.displayName)
      }

      for ticker in tickers {
        let symbol = ticker.normalizedSymbol
        guard
          let quote = input.marketDataSnapshot.quote(for: symbol),
          let currentPrice = quote.currentPrice,
          let movingAverage = quote.movingAverage
        else {
          return .missingMarketData(symbol)
        }

        guard currentPrice > 0, movingAverage > 0 else {
          return .invalidMarketData(symbol)
        }
      }
    }

    return nil
  }
}

enum ContributionOutputValidator {
  static func validate(_ output: ContributionOutput, expectedTotal: Decimal)
    -> ContributionCalculationError?
  {
    for allocation in output.allocations where allocation.amount < 0 {
      return .negativeAllocation(allocation.tickerSymbol)
    }

    let actualTotal = output.allocations.reduce(Decimal(0)) { $0 + $1.amount }
    let tolerance = Decimal(string: "0.01")!
    guard abs(actualTotal - output.totalAmount) <= tolerance else {
      return .allocationTotalMismatch(expected: output.totalAmount, actual: actualTotal)
    }

    guard abs(output.totalAmount - expectedTotal) <= tolerance else {
      return .outputTotalMismatch(expected: expectedTotal, actual: output.totalAmount)
    }

    return nil
  }

}

struct MovingAverageContributionCalculator: ContributionCalculating {
  func calculate(input: ContributionInput) -> ContributionOutput {
    if let validationError = ContributionInputValidator.validate(input) {
      return .failure(validationError)
    }

    guard let portfolio = input.portfolio else {
      return .failure(ContributionCalculationError.missingPortfolio)
    }

    let categories = portfolio.categories.sorted { $0.sortOrder < $1.sortOrder }
    let categoryAmounts = split(input.monthlyBudget, across: categories.map(\.weight))
    var categoryResults: [CategoryContributionResult] = []
    var allocations: [TickerContributionAllocation] = []

    for (category, categoryAmount) in zip(categories, categoryAmounts) {
      let tickers = category.tickers.sorted { $0.sortOrder < $1.sortOrder }
      var rawMultipliers: [Decimal] = []
      rawMultipliers.reserveCapacity(tickers.count)
      for ticker in tickers {
        let symbol = ticker.normalizedSymbol
        let quote = input.marketDataSnapshot.quote(for: symbol)
        guard
          let currentPrice = quote?.currentPrice,
          let movingAverage = quote?.movingAverage
        else {
          return .failure(ContributionCalculationError.missingMarketData(symbol))
        }
        rawMultipliers.append(movingAverage / currentPrice)
      }
      let multiplierTotal = rawMultipliers.reduce(Decimal(0), +)
      let normalizedWeights =
        multiplierTotal == 0
        ? Array(repeating: Decimal(1) / Decimal(tickers.count), count: tickers.count)
        : rawMultipliers.map { $0 / multiplierTotal }
      let tickerAmounts = split(categoryAmount, across: normalizedWeights)

      categoryResults.append(
        CategoryContributionResult(
          categoryName: category.displayName,
          amount: categoryAmount,
          allocatedWeight: category.weight
        ))

      for (ticker, values) in zip(tickers, zip(tickerAmounts, normalizedWeights)) {
        let (tickerAmount, signalWeight) = values
        allocations.append(
          TickerContributionAllocation(
            tickerSymbol: ticker.normalizedSymbol,
            categoryName: category.displayName,
            amount: tickerAmount,
            allocatedWeight: rounded(signalWeight, scale: 4)
          ))
      }
    }

    return ContributionOutput(
      totalAmount: input.monthlyBudget,
      categoryBreakdown: categoryResults,
      allocations: allocations
    )
  }

  private func split(_ total: Decimal, across weights: [Decimal]) -> [Decimal] {
    var amounts = weights.map { rounded(total * $0) }
    applyRemainder(total: total, to: &amounts)
    return amounts
  }

  private func applyRemainder(total: Decimal, to amounts: inout [Decimal]) {
    guard let lastIndex = amounts.indices.last else {
      return
    }

    let roundedTotal = rounded(total)
    let currentTotal = amounts.reduce(Decimal(0), +)
    amounts[lastIndex] = rounded(amounts[lastIndex] + roundedTotal - currentTotal)
  }

  private func rounded(_ value: Decimal, scale: Int = 2) -> Decimal {
    var input = value
    var output = Decimal()
    NSDecimalRound(&output, &input, scale, .plain)
    return output
  }
}

struct BandAdjustedContributionCalculator: ContributionCalculating {
  func calculate(input: ContributionInput) -> ContributionOutput {
    if let validationError = ContributionInputValidator.validate(input) {
      return .failure(validationError)
    }

    guard let portfolio = input.portfolio else {
      return .failure(ContributionCalculationError.missingPortfolio)
    }

    let categories = portfolio.categories.sorted { $0.sortOrder < $1.sortOrder }
    let categoryTargets = split(input.monthlyBudget, across: categories.map(\.weight))
    var categoryResults: [CategoryContributionResult] = []
    var allocations: [TickerContributionAllocation] = []

    for (category, categoryTarget) in zip(categories, categoryTargets) {
      let tickers = category.tickers.sorted { $0.sortOrder < $1.sortOrder }
      let tickerTargets = splitEvenly(categoryTarget, count: tickers.count)
      var categoryAmount = Decimal(0)
      var categoryAllocations: [TickerContributionAllocation] = []

      for (ticker, targetAmount) in zip(tickers, tickerTargets) {
        let symbol = ticker.normalizedSymbol
        guard let position = input.marketDataSnapshot.quote(for: symbol)?.bandPosition else {
          return .failure(ContributionCalculationError.missingBandPosition(symbol))
        }

        let multiplier = clamp(
          1 + (BandMultiplierPolicy.midpoint - position),
          min: input.minMultiplier,
          max: input.maxMultiplier
        )
        let amount = rounded(targetAmount * multiplier)
        categoryAmount += amount
        categoryAllocations.append(
          TickerContributionAllocation(
            tickerSymbol: symbol,
            categoryName: category.displayName,
            amount: amount,
            allocatedWeight: multiplier
          ))
      }

      categoryResults.append(
        CategoryContributionResult(
          categoryName: category.displayName,
          amount: rounded(categoryAmount),
          allocatedWeight: category.weight
        ))
      allocations.append(contentsOf: categoryAllocations)
    }

    return ContributionOutput(
      totalAmount: allocations.reduce(Decimal(0)) { $0 + $1.amount },
      categoryBreakdown: categoryResults,
      allocations: allocations
    )
  }

  private func split(_ total: Decimal, across weights: [Decimal]) -> [Decimal] {
    var amounts = weights.map { rounded(total * $0) }
    applyRemainder(total: total, to: &amounts)
    return amounts
  }

  private func splitEvenly(_ total: Decimal, count: Int) -> [Decimal] {
    guard count > 0 else {
      return []
    }

    var amounts = Array(repeating: rounded(total / Decimal(count)), count: count)
    applyRemainder(total: total, to: &amounts)
    return amounts
  }

  private func applyRemainder(total: Decimal, to amounts: inout [Decimal]) {
    guard let lastIndex = amounts.indices.last else {
      return
    }

    let roundedTotal = rounded(total)
    let currentTotal = amounts.reduce(Decimal(0), +)
    amounts[lastIndex] = rounded(amounts[lastIndex] + roundedTotal - currentTotal)
  }

  private func rounded(_ value: Decimal, scale: Int = 2) -> Decimal {
    var input = value
    var output = Decimal()
    NSDecimalRound(&output, &input, scale, .plain)
    return output
  }

  private func clamp(_ value: Decimal, min: Decimal, max: Decimal) -> Decimal {
    Swift.max(min, Swift.min(max, value))
  }
}

struct ProportionalSplitContributionCalculator: ContributionCalculating {
  func calculate(input: ContributionInput) -> ContributionOutput {
    if let validationError = ContributionInputValidator.validate(input) {
      return .failure(validationError)
    }

    guard let portfolio = input.portfolio else {
      return .failure(ContributionCalculationError.missingPortfolio)
    }

    let categories = portfolio.categories.sorted { $0.sortOrder < $1.sortOrder }
    let categoryAmounts = split(input.monthlyBudget, across: categories.map(\.weight))

    var categoryResults: [CategoryContributionResult] = []
    var allocations: [TickerContributionAllocation] = []

    for (category, categoryAmount) in zip(categories, categoryAmounts) {
      categoryResults.append(
        CategoryContributionResult(
          categoryName: category.displayName,
          amount: categoryAmount,
          allocatedWeight: category.weight
        ))

      let tickers = category.tickers.sorted { $0.sortOrder < $1.sortOrder }
      let tickerAmounts = splitEvenly(categoryAmount, count: tickers.count)
      for (ticker, tickerAmount) in zip(tickers, tickerAmounts) {
        allocations.append(
          TickerContributionAllocation(
            tickerSymbol: ticker.normalizedSymbol,
            categoryName: category.displayName,
            amount: tickerAmount,
            allocatedWeight: categoryAmount == 0
              ? 0 : rounded(tickerAmount / categoryAmount, scale: 4)
          ))
      }
    }

    return ContributionOutput(
      totalAmount: input.monthlyBudget,
      categoryBreakdown: categoryResults,
      allocations: allocations
    )
  }

  private func split(_ total: Decimal, across weights: [Decimal]) -> [Decimal] {
    var amounts = weights.map { rounded(total * $0) }
    applyRemainder(total: total, to: &amounts)
    return amounts
  }

  private func splitEvenly(_ total: Decimal, count: Int) -> [Decimal] {
    guard count > 0 else {
      return []
    }

    var amounts = Array(repeating: rounded(total / Decimal(count)), count: count)
    applyRemainder(total: total, to: &amounts)
    return amounts
  }

  private func applyRemainder(total: Decimal, to amounts: inout [Decimal]) {
    guard let lastIndex = amounts.indices.last else {
      return
    }

    let roundedTotal = rounded(total)
    let currentTotal = amounts.reduce(Decimal(0), +)
    amounts[lastIndex] = rounded(amounts[lastIndex] + roundedTotal - currentTotal)
  }

  private func rounded(_ value: Decimal, scale: Int = 2) -> Decimal {
    var input = value
    var output = Decimal()
    NSDecimalRound(&output, &input, scale, .plain)
    return output
  }
}

extension Category {
  fileprivate var displayName: String {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedName.isEmpty ? "Unnamed Category" : trimmedName
  }
}
