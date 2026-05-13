import SwiftUI
import XCTest
@testable import VCA

final class NavigationShellTests: XCTestCase {
    func testCompactWidthUsesNavigationStack() {
        XCTAssertEqual(MainView.navigationShellKind(for: .compact), .stack)
    }

    func testRegularWidthUsesNavigationSplitView() {
        XCTAssertEqual(MainView.navigationShellKind(for: .regular), .splitView)
    }

    func testPortfolioDraftTrimsAndValidatesPortfolioValues() throws {
        let draft = PortfolioFormDraft(name: "  Long Term  ", monthlyBudgetText: "250.75", maWindow: 200)

        let values = try draft.validatedValues()

        XCTAssertEqual(values.name, "Long Term")
        XCTAssertEqual(values.monthlyBudget, Decimal(string: "250.75"))
        XCTAssertEqual(values.maWindow, 200)
    }

    func testPortfolioDraftRejectsInvalidValuesBeforeSave() {
        XCTAssertThrowsError(try PortfolioFormDraft(name: " ", monthlyBudgetText: "100", maWindow: 50).validatedValues()) { error in
            XCTAssertEqual(error as? PortfolioEditorValidationError, .emptyName)
        }
        XCTAssertThrowsError(try PortfolioFormDraft(name: "Core", monthlyBudgetText: "0", maWindow: 50).validatedValues()) { error in
            XCTAssertEqual(error as? PortfolioEditorValidationError, .invalidBudget)
        }
        XCTAssertThrowsError(try PortfolioFormDraft(name: "Core", monthlyBudgetText: "100", maWindow: 100).validatedValues()) { error in
            XCTAssertEqual(error as? PortfolioEditorValidationError, .invalidMAWindow(100))
        }
    }

    func testPortfolioDraftCreatesAndUpdatesModelOnlyOnApply() throws {
        let created = try PortfolioFormDraft(name: "Core", monthlyBudgetText: "1000", maWindow: 50).makePortfolio()

        XCTAssertEqual(created.name, "Core")
        XCTAssertEqual(created.monthlyBudget, Decimal(1_000))
        XCTAssertEqual(created.maWindow, 50)

        let editDraft = PortfolioFormDraft(name: "Core Updated", monthlyBudgetText: "1500", maWindow: 200)
        XCTAssertEqual(created.name, "Core")

        try editDraft.apply(to: created)

        XCTAssertEqual(created.name, "Core Updated")
        XCTAssertEqual(created.monthlyBudget, Decimal(1_500))
        XCTAssertEqual(created.maWindow, 200)
    }

    func testHoldingsDraftValidatesWeightsAndDuplicateSymbols() {
        let draft = HoldingsDraft(categories: [
            CategoryDraft(name: "US", weightPercentText: "60", tickers: [
                TickerDraft(symbol: " vti ", currentPrice: Decimal(250), movingAverage: Decimal(245), sortOrder: 0),
            ]),
            CategoryDraft(name: "Growth", weightPercentText: "30", tickers: [
                TickerDraft(symbol: "VTI", currentPrice: Decimal(250), movingAverage: Decimal(245), sortOrder: 0),
            ]),
        ])

        XCTAssertEqual(draft.duplicateTickerSymbols(), ["VTI"])
        XCTAssertEqual(draft.issues(), [
            .categoryWeightsDoNotSumTo100,
            .duplicateTickerSymbols(["VTI"]),
        ])
        XCTAssertFalse(draft.canCalculate())
        XCTAssertEqual(draft.saveBlockingIssues(), [.duplicateTickerSymbols(["VTI"])])
    }

    func testHoldingsDraftAllowsWarningOnlySaveButBlocksCalculation() {
        let draft = HoldingsDraft(categories: [
            CategoryDraft(name: "Bonds", weightPercentText: "100"),
        ])

        XCTAssertEqual(draft.issues(), [.categoryHasNoTickers("Bonds")])
        XCTAssertTrue(draft.saveBlockingIssues().isEmpty)
        XCTAssertFalse(draft.canCalculate())
    }

    func testHoldingsDraftReordersCategoriesAndTickers() {
        var draft = HoldingsDraft(categories: [
            CategoryDraft(id: UUID(), name: "First", weightPercentText: "50", sortOrder: 0),
            CategoryDraft(id: UUID(), name: "Second", weightPercentText: "50", sortOrder: 1, tickers: [
                TickerDraft(id: UUID(), symbol: "AAA", sortOrder: 0),
                TickerDraft(id: UUID(), symbol: "BBB", sortOrder: 1),
            ]),
        ])

        let firstID = draft.categories[0].id
        let secondID = draft.categories[1].id
        let firstTickerID = draft.categories[1].tickers[0].id
        let secondTickerID = draft.categories[1].tickers[1].id

        draft.moveCategory(id: secondID, direction: .up)
        draft.categories[0].moveTicker(id: secondTickerID, direction: .up)

        XCTAssertEqual(draft.categories.map(\.id), [secondID, firstID])
        XCTAssertEqual(draft.categories.map(\.sortOrder), [0, 1])
        XCTAssertEqual(draft.categories[0].tickers.map(\.id), [secondTickerID, firstTickerID])
        XCTAssertEqual(draft.categories[0].tickers.map(\.sortOrder), [0, 1])
    }

    func testTickerDraftFormatsAndValidatesManualMarketData() {
        var ticker = TickerDraft(
            symbol: "vti",
            currentPrice: Decimal(string: "250.5"),
            movingAverage: Decimal(string: "245"),
            sortOrder: 0
        )

        XCTAssertEqual(ticker.currentPriceText, "250.50")
        XCTAssertEqual(ticker.movingAverageText, "245.00")
        XCTAssertEqual(ticker.currentPrice, Decimal(string: "250.50"))
        XCTAssertEqual(ticker.movingAverage, Decimal(245))
        XCTAssertTrue(ticker.hasCompleteMarketData)
        XCTAssertFalse(ticker.hasInvalidMarketData)

        ticker.currentPriceText = "0"
        XCTAssertTrue(ticker.hasInvalidMarketData)
        XCTAssertFalse(ticker.hasCompleteMarketData)
        XCTAssertEqual(ticker.marketDataStatusMessage, "Price and moving average must be greater than 0.")
    }

    func testHoldingsDraftBlocksCalculationForMissingOrInvalidMarketData() {
        let missingMarketDataDraft = HoldingsDraft(categories: [
            CategoryDraft(name: "Equity", weightPercentText: "100", tickers: [
                TickerDraft(symbol: "VTI", currentPrice: Decimal(250), sortOrder: 0),
            ]),
        ])

        XCTAssertEqual(missingMarketDataDraft.issues(), [.missingTickerMarketData("VTI")])
        XCTAssertTrue(missingMarketDataDraft.saveBlockingIssues().isEmpty)
        XCTAssertFalse(missingMarketDataDraft.canCalculate())

        var invalidTicker = TickerDraft(symbol: "BND", sortOrder: 0)
        invalidTicker.currentPriceText = "-1"
        invalidTicker.movingAverageText = "74"
        let invalidMarketDataDraft = HoldingsDraft(categories: [
            CategoryDraft(name: "Bonds", weightPercentText: "100", tickers: [invalidTicker]),
        ])

        XCTAssertEqual(invalidMarketDataDraft.issues(), [.invalidTickerMarketData("BND")])
        XCTAssertEqual(invalidMarketDataDraft.saveBlockingIssues(), [.invalidTickerMarketData("BND")])
        XCTAssertFalse(invalidMarketDataDraft.canCalculate())
    }

    func testContributionHistoryGroupsRecordsByMonthNewestFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let may12 = date(year: 2026, month: 5, day: 12, calendar: calendar)
        let may2 = date(year: 2026, month: 5, day: 2, calendar: calendar)
        let april30 = date(year: 2026, month: 4, day: 30, calendar: calendar)
        let mayRecent = ContributionRecord(portfolioId: UUID(), date: may12, totalAmount: Decimal(600))
        let april = ContributionRecord(portfolioId: UUID(), date: april30, totalAmount: Decimal(250))
        let mayOlder = ContributionRecord(portfolioId: UUID(), date: may2, totalAmount: Decimal(400))

        let sections = ContributionHistoryMonthSection.group(
            records: [mayOlder, april, mayRecent],
            calendar: calendar
        )

        XCTAssertEqual(sections.map(\.title), ["May 2026", "April 2026"])
        XCTAssertEqual(sections[0].records.map(\.id), [mayRecent.id, mayOlder.id])
        XCTAssertEqual(sections[0].totalAmount, Decimal(1_000))
        XCTAssertEqual(sections[1].records.map(\.id), [april.id])
        XCTAssertEqual(sections[1].totalAmount, Decimal(250))
    }

    private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ))!
    }
}
