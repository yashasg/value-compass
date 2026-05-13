import Foundation

protocol ContributionCalculating {
    func calculate(input: ContributionInput) -> ContributionOutput
}

struct ContributionInput {
    let portfolio: Portfolio?
    let monthlyBudget: Decimal
    let marketDataSnapshot: MarketDataSnapshot

    init(
        portfolio: Portfolio?,
        monthlyBudget: Decimal? = nil,
        marketDataSnapshot: MarketDataSnapshot? = nil
    ) {
        self.portfolio = portfolio
        self.monthlyBudget = monthlyBudget ?? portfolio?.monthlyBudget ?? 0
        self.marketDataSnapshot = marketDataSnapshot ?? MarketDataSnapshot(portfolio: portfolio)
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
                movingAverage: ticker.movingAverage
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
    static func calculate(
        portfolio: Portfolio?,
        calculator: any ContributionCalculating = ProportionalSplitContributionCalculator()
    ) -> ContributionOutput {
        let input = ContributionInput(portfolio: portfolio)
        if let validationError = ContributionInputValidator.validate(input) {
            return .failure(validationError)
        }

        let output = calculator.calculate(input: input)
        if output.error != nil {
            return output
        }

        if let contractError = ContributionOutputValidator.validate(output, expectedTotal: input.monthlyBudget) {
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
    static func validate(_ output: ContributionOutput, expectedTotal: Decimal) -> ContributionCalculationError? {
        for allocation in output.allocations where allocation.amount < 0 {
            return .negativeAllocation(allocation.tickerSymbol)
        }

        let tolerance = Decimal(string: "0.01")!
        guard abs(output.totalAmount - expectedTotal) <= tolerance else {
            return .outputTotalMismatch(expected: expectedTotal, actual: output.totalAmount)
        }

        let actualTotal = output.allocations.reduce(Decimal(0)) { $0 + $1.amount }
        guard abs(actualTotal - expectedTotal) <= tolerance else {
            return .allocationTotalMismatch(expected: expectedTotal, actual: actualTotal)
        }

        return nil
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
            categoryResults.append(CategoryContributionResult(
                categoryName: category.displayName,
                amount: categoryAmount,
                allocatedWeight: category.weight
            ))

            let tickers = category.tickers.sorted { $0.sortOrder < $1.sortOrder }
            let tickerAmounts = splitEvenly(categoryAmount, count: tickers.count)
            for (ticker, tickerAmount) in zip(tickers, tickerAmounts) {
                allocations.append(TickerContributionAllocation(
                    tickerSymbol: ticker.normalizedSymbol,
                    categoryName: category.displayName,
                    amount: tickerAmount,
                    allocatedWeight: categoryAmount == 0 ? 0 : rounded(tickerAmount / categoryAmount, scale: 4)
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

private extension Category {
    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Unnamed Category" : trimmedName
    }
}
