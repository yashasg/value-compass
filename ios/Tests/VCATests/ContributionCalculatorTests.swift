import XCTest
@testable import VCA

final class ContributionCalculatorTests: XCTestCase {
    func testProportionalSplitCalculatorAllocatesByCategoryWeightThenEquallyByTicker() {
        let portfolio = makeValidPortfolio(monthlyBudget: Decimal(1_000))
        let output = ProportionalSplitContributionCalculator().calculate(input: ContributionInput(portfolio: portfolio))

        XCTAssertNil(output.error)
        XCTAssertEqual(output.totalAmount, Decimal(1_000))
        XCTAssertEqual(output.categoryBreakdown, [
            CategoryContributionResult(categoryName: "Equity", amount: Decimal(600), allocatedWeight: Decimal(string: "0.60")!),
            CategoryContributionResult(categoryName: "Bonds", amount: Decimal(400), allocatedWeight: Decimal(string: "0.40")!),
        ])
        XCTAssertEqual(output.allocations, [
            TickerContributionAllocation(tickerSymbol: "VTI", categoryName: "Equity", amount: Decimal(300), allocatedWeight: Decimal(string: "0.5000")!),
            TickerContributionAllocation(tickerSymbol: "VXUS", categoryName: "Equity", amount: Decimal(300), allocatedWeight: Decimal(string: "0.5000")!),
            TickerContributionAllocation(tickerSymbol: "BND", categoryName: "Bonds", amount: Decimal(400), allocatedWeight: Decimal(string: "1.0000")!),
        ])
    }

    func testProportionalSplitCalculatorRoundsToCentsAndPreservesBudgetTotal() {
        let portfolio = Portfolio(
            name: "Rounding",
            monthlyBudget: Decimal(string: "100.00")!,
            categories: [
                Category(name: "One", weight: Decimal(string: "0.3333")!, sortOrder: 0, tickers: [
                    Ticker(symbol: "AAA", currentPrice: 1, movingAverage: 1, sortOrder: 0),
                ]),
                Category(name: "Two", weight: Decimal(string: "0.3333")!, sortOrder: 1, tickers: [
                    Ticker(symbol: "BBB", currentPrice: 1, movingAverage: 1, sortOrder: 0),
                ]),
                Category(name: "Three", weight: Decimal(string: "0.3334")!, sortOrder: 2, tickers: [
                    Ticker(symbol: "CCC", currentPrice: 1, movingAverage: 1, sortOrder: 0),
                ]),
            ]
        )

        let output = ProportionalSplitContributionCalculator().calculate(input: ContributionInput(portfolio: portfolio))

        XCTAssertNil(output.error)
        XCTAssertEqual(output.allocations.map(\.amount), [
            Decimal(string: "33.33")!,
            Decimal(string: "33.33")!,
            Decimal(string: "33.34")!,
        ])
        XCTAssertEqual(output.allocations.reduce(Decimal(0)) { $0 + $1.amount }, Decimal(100))
    }

    func testInputValidationRunsBeforeCallingCalculator() {
        let invalidPortfolio = makeValidPortfolio(monthlyBudget: 0)
        let spy = SpyCalculator(output: ContributionOutput(totalAmount: 0, allocations: []))

        let output = ContributionCalculationService.calculate(portfolio: invalidPortfolio, calculator: spy)

        XCTAssertEqual(output.error as? ContributionCalculationError, .invalidBudget)
        XCTAssertEqual(spy.callCount, 0)
    }

    func testServiceCallsCalculatorSeamForValidPortfolio() {
        let portfolio = makeValidPortfolio(monthlyBudget: Decimal(250))
        let spy = SpyCalculator(output: ContributionOutput(
            totalAmount: Decimal(250),
            allocations: [
                TickerContributionAllocation(tickerSymbol: "VTI", categoryName: "Equity", amount: Decimal(250), allocatedWeight: 1),
            ]
        ))

        let output = ContributionCalculationService.calculate(portfolio: portfolio, calculator: spy)

        XCTAssertNil(output.error)
        XCTAssertEqual(spy.callCount, 1)
    }

    func testValidationRequiresPortfolioCategoriesWeightsTickersAndMarketData() {
        XCTAssertEqual(
            ProportionalSplitContributionCalculator().calculate(input: ContributionInput(portfolio: nil)).error as? ContributionCalculationError,
            .missingPortfolio
        )

        let emptyPortfolio = Portfolio(name: "Empty", monthlyBudget: Decimal(100))
        XCTAssertEqual(
            ProportionalSplitContributionCalculator().calculate(input: ContributionInput(portfolio: emptyPortfolio)).error as? ContributionCalculationError,
            .noCategories
        )

        let badWeights = Portfolio(
            name: "Bad Weights",
            monthlyBudget: Decimal(100),
            categories: [
                Category(name: "Equity", weight: Decimal(string: "0.50")!, sortOrder: 0, tickers: [
                    Ticker(symbol: "VTI", currentPrice: 1, movingAverage: 1, sortOrder: 0),
                ]),
            ]
        )
        XCTAssertEqual(
            ProportionalSplitContributionCalculator().calculate(input: ContributionInput(portfolio: badWeights)).error as? ContributionCalculationError,
            .categoryWeightsDoNotSumTo100
        )

        let noTickers = Portfolio(
            name: "No Tickers",
            monthlyBudget: Decimal(100),
            categories: [
                Category(name: "Equity", weight: 1, sortOrder: 0),
            ]
        )
        XCTAssertEqual(
            ProportionalSplitContributionCalculator().calculate(input: ContributionInput(portfolio: noTickers)).error as? ContributionCalculationError,
            .categoryHasNoTickers("Equity")
        )

        let missingMarketData = Portfolio(
            name: "Missing Data",
            monthlyBudget: Decimal(100),
            categories: [
                Category(name: "Equity", weight: 1, sortOrder: 0, tickers: [
                    Ticker(symbol: "VTI", currentPrice: 1, movingAverage: nil, sortOrder: 0),
                ]),
            ]
        )
        XCTAssertEqual(
            ProportionalSplitContributionCalculator().calculate(input: ContributionInput(portfolio: missingMarketData)).error as? ContributionCalculationError,
            .missingMarketData("VTI")
        )
    }

    func testServiceRejectsInvalidOutputContract() {
        let portfolio = makeValidPortfolio(monthlyBudget: Decimal(100))
        let negativeOutput = ContributionOutput(
            totalAmount: Decimal(100),
            allocations: [
                TickerContributionAllocation(tickerSymbol: "VTI", categoryName: "Equity", amount: Decimal(-1), allocatedWeight: 1),
            ]
        )
        let negativeResult = ContributionCalculationService.calculate(
            portfolio: portfolio,
            calculator: SpyCalculator(output: negativeOutput)
        )

        XCTAssertEqual(negativeResult.error as? ContributionCalculationError, .negativeAllocation("VTI"))

        let mismatchOutput = ContributionOutput(
            totalAmount: Decimal(100),
            allocations: [
                TickerContributionAllocation(tickerSymbol: "VTI", categoryName: "Equity", amount: Decimal(50), allocatedWeight: 1),
            ]
        )
        let mismatchResult = ContributionCalculationService.calculate(
            portfolio: portfolio,
            calculator: SpyCalculator(output: mismatchOutput)
        )

        XCTAssertEqual(
            mismatchResult.error as? ContributionCalculationError,
            .allocationTotalMismatch(expected: Decimal(100), actual: Decimal(50))
        )
    }

    private func makeValidPortfolio(monthlyBudget: Decimal) -> Portfolio {
        Portfolio(
            name: "Core",
            monthlyBudget: monthlyBudget,
            categories: [
                Category(name: "Equity", weight: Decimal(string: "0.60")!, sortOrder: 0, tickers: [
                    Ticker(symbol: "VTI", currentPrice: Decimal(250), movingAverage: Decimal(245), sortOrder: 0),
                    Ticker(symbol: "VXUS", currentPrice: Decimal(60), movingAverage: Decimal(58), sortOrder: 1),
                ]),
                Category(name: "Bonds", weight: Decimal(string: "0.40")!, sortOrder: 1, tickers: [
                    Ticker(symbol: "BND", currentPrice: Decimal(75), movingAverage: Decimal(74), sortOrder: 0),
                ]),
            ]
        )
    }
}

private final class SpyCalculator: ContributionCalculating {
    private(set) var callCount = 0
    private let output: ContributionOutput

    init(output: ContributionOutput) {
        self.output = output
    }

    func calculate(input: ContributionInput) -> ContributionOutput {
        callCount += 1
        return output
    }
}
