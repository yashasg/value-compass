import SwiftData
import XCTest

@testable import VCA

@MainActor
final class LocalPersistenceTests: XCTestCase {
  func testInMemoryContainerSavesAndFetchesPortfolio() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)
    let portfolio = Portfolio(name: "Core Portfolio", monthlyBudget: Decimal(1_000), maWindow: 50)

    context.insert(portfolio)
    try context.save()

    let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
    XCTAssertEqual(portfolios.count, 1)
    XCTAssertEqual(portfolios.first?.name, "Core Portfolio")
    XCTAssertEqual(portfolios.first?.monthlyBudget, Decimal(1_000))
    XCTAssertEqual(portfolios.first?.maWindow, 50)
  }

  func testPortfolioValidationRejectsInvalidBudgetAndMAWindow() {
    let portfolio = Portfolio(name: "Invalid", monthlyBudget: 0, maWindow: 100)

    XCTAssertFalse(portfolio.isValid())
    XCTAssertEqual(
      portfolio.validationErrors(),
      [
        .nonPositiveMonthlyBudget,
        .invalidMAWindow(100),
      ])
    XCTAssertThrowsError(try portfolio.validate()) { error in
      XCTAssertEqual(error as? PortfolioValidationError, .nonPositiveMonthlyBudget)
    }
  }

  func testPortfolioHelpersCalculateCategoryWeightAndTickerCount() {
    let equity = Category(
      name: "Equity", weight: Decimal(string: "0.60")!, sortOrder: 1,
      tickers: [
        Ticker(symbol: "VTI", sortOrder: 1),
        Ticker(symbol: "VXUS", sortOrder: 2),
      ])
    let bonds = Category(name: "Bonds", weight: Decimal(string: "0.40")!, sortOrder: 2)
    let portfolio = Portfolio(
      name: "Core", monthlyBudget: Decimal(500), categories: [equity, bonds])

    XCTAssertEqual(portfolio.totalCategoryWeight(), 1)
    XCTAssertEqual(equity.tickerCount(), 2)
    XCTAssertTrue(portfolio.isValid())
  }

  func testDuplicateTickerSymbolsAreRejectedAcrossCategories() {
    let portfolio = Portfolio(
      name: "Duplicate symbols",
      monthlyBudget: Decimal(500),
      categories: [
        Category(
          name: "US", weight: Decimal(string: "0.50")!, sortOrder: 1,
          tickers: [
            Ticker(symbol: " vti ", sortOrder: 1)
          ]),
        Category(
          name: "Growth", weight: Decimal(string: "0.50")!, sortOrder: 2,
          tickers: [
            Ticker(symbol: "VTI", sortOrder: 1)
          ]),
      ]
    )

    XCTAssertEqual(portfolio.duplicateTickerSymbols(), ["VTI"])
    XCTAssertEqual(portfolio.validationErrors(), [.duplicateTickerSymbols(["VTI"])])
    XCTAssertFalse(portfolio.isValid())
  }

  func testRelationshipsPersistAndLoadFromSwiftData() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)
    let portfolio = Portfolio(
      name: "Offline Portfolio",
      monthlyBudget: Decimal(750),
      categories: [
        Category(
          name: "Equity", weight: Decimal(string: "0.70")!, sortOrder: 1,
          tickers: [
            Ticker(
              symbol: "VTI", currentPrice: Decimal(250), movingAverage: Decimal(245), sortOrder: 1),
            Ticker(
              symbol: "VXUS", currentPrice: Decimal(60), movingAverage: Decimal(58), sortOrder: 2),
          ]),
        Category(
          name: "Bonds", weight: Decimal(string: "0.30")!, sortOrder: 2,
          tickers: [
            Ticker(
              symbol: "BND", currentPrice: Decimal(75), movingAverage: Decimal(74), sortOrder: 1)
          ]),
      ]
    )

    context.insert(portfolio)
    try context.save()

    let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<Portfolio>()).first)
    XCTAssertEqual(fetched.categories.count, 2)
    XCTAssertEqual(fetched.categories.flatMap(\.tickers).count, 3)
    XCTAssertEqual(
      fetched.categories.first { $0.name == "Equity" }?.parentPortfolio?.id, fetched.id)
    XCTAssertEqual(
      fetched.categories.flatMap(\.tickers).first { $0.symbol == "VTI" }?.parentCategory?.name,
      "Equity")
  }

  func testHoldingsDraftAppliesCategoriesTickersAndSortOrderToSwiftData() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)
    let portfolio = Portfolio(name: "Editable", monthlyBudget: Decimal(1_000))
    context.insert(portfolio)

    let equityID = UUID()
    let bondsID = UUID()
    let vtiID = UUID()
    let bndID = UUID()
    let draft = HoldingsDraft(categories: [
      CategoryDraft(
        id: equityID, name: "Equity", weightPercentText: "70", sortOrder: 0,
        tickers: [
          TickerDraft(
            id: vtiID, symbol: " vti ", currentPrice: Decimal(string: "250.25"),
            movingAverage: Decimal(245), bandPosition: Decimal(string: "0.4"), sortOrder: 0)
        ]),
      CategoryDraft(
        id: bondsID, name: "Bonds", weightPercentText: "30", sortOrder: 1,
        tickers: [
          TickerDraft(
            id: bndID, symbol: "bnd", currentPrice: Decimal(75),
            movingAverage: Decimal(string: "74.50"), bandPosition: Decimal(string: "0.6"),
            sortOrder: 0)
        ]),
    ])

    try draft.apply(to: portfolio, in: context)

    let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<Portfolio>()).first)
    let categories = fetched.categories.sorted { $0.sortOrder < $1.sortOrder }
    XCTAssertEqual(categories.map(\.id), [equityID, bondsID])
    XCTAssertEqual(categories.map(\.weight), [Decimal(string: "0.7"), Decimal(string: "0.3")])
    XCTAssertEqual(categories[0].tickers.map(\.symbol), ["VTI"])
    XCTAssertEqual(categories[1].tickers.map(\.symbol), ["BND"])
    XCTAssertEqual(categories[0].tickers[0].currentPrice, Decimal(string: "250.25"))
    XCTAssertEqual(categories[0].tickers[0].movingAverage, Decimal(245))
    XCTAssertEqual(categories[0].tickers[0].bandPosition, Decimal(string: "0.4"))
    XCTAssertEqual(categories[1].tickers[0].currentPrice, Decimal(75))
    XCTAssertEqual(categories[1].tickers[0].movingAverage, Decimal(string: "74.50"))
    XCTAssertEqual(categories[1].tickers[0].bandPosition, Decimal(string: "0.6"))
  }

  func testHoldingsDraftDeletesRemovedCategoriesAndTickers() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)
    let equity = Category(
      name: "Equity", weight: Decimal(string: "0.70")!, sortOrder: 0,
      tickers: [
        Ticker(symbol: "VTI", sortOrder: 0),
        Ticker(symbol: "VXUS", sortOrder: 1),
      ])
    let bonds = Category(
      name: "Bonds", weight: Decimal(string: "0.30")!, sortOrder: 1,
      tickers: [
        Ticker(symbol: "BND", sortOrder: 0)
      ])
    let portfolio = Portfolio(
      name: "Editable", monthlyBudget: Decimal(1_000), categories: [equity, bonds])
    context.insert(portfolio)
    try context.save()

    let draft = HoldingsDraft(categories: [
      CategoryDraft(
        id: equity.id, name: "Stocks", weightPercentText: "100", sortOrder: 0,
        tickers: [
          TickerDraft(id: equity.tickers[0].id, symbol: "VOO", sortOrder: 0)
        ])
    ])

    try draft.apply(to: portfolio, in: context)

    let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<Portfolio>()).first)
    XCTAssertEqual(fetched.categories.count, 1)
    XCTAssertEqual(fetched.categories[0].name, "Stocks")
    XCTAssertEqual(fetched.categories[0].tickers.count, 1)
    XCTAssertEqual(fetched.categories[0].tickers[0].symbol, "VOO")
    XCTAssertEqual(try context.fetch(FetchDescriptor<VCA.Category>()).count, 1)
    XCTAssertEqual(try context.fetch(FetchDescriptor<VCA.Ticker>()).count, 1)
  }

  func testPortfolioDeleteRemovesSavedPortfolio() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)
    let portfolio = Portfolio(name: "Delete Me", monthlyBudget: Decimal(250), maWindow: 50)

    context.insert(portfolio)
    try context.save()
    XCTAssertEqual(try context.fetch(FetchDescriptor<Portfolio>()).count, 1)

    context.delete(portfolio)
    try context.save()

    XCTAssertTrue(try context.fetch(FetchDescriptor<Portfolio>()).isEmpty)
  }

  func testPortfolioDeleteCascadesContributionHistory() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)
    let portfolio = Portfolio(name: "Delete History", monthlyBudget: Decimal(250), maWindow: 50)
    let record = ContributionRecord(
      portfolioId: portfolio.id,
      totalAmount: Decimal(250),
      portfolio: portfolio,
      categoryBreakdown: [
        CategoryContribution(categoryName: "Equity", amount: Decimal(250), allocatedWeight: 1)
      ],
      tickerAllocations: [
        TickerAllocation(
          tickerSymbol: "VTI", categoryName: "Equity", amount: Decimal(250), allocatedWeight: 1)
      ]
    )
    portfolio.contributionRecords = [record]

    context.insert(portfolio)
    try context.save()
    XCTAssertEqual(try context.fetch(FetchDescriptor<ContributionRecord>()).count, 1)
    XCTAssertEqual(try context.fetch(FetchDescriptor<CategoryContribution>()).count, 1)
    XCTAssertEqual(try context.fetch(FetchDescriptor<TickerAllocation>()).count, 1)

    context.delete(portfolio)
    try context.save()

    XCTAssertTrue(try context.fetch(FetchDescriptor<Portfolio>()).isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<ContributionRecord>()).isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<CategoryContribution>()).isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<TickerAllocation>()).isEmpty)
  }

  func testOfflineWorkflowPersistsMultiplePortfoliosMarketDataAndIsolatedHistory() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)
    let corePortfolio = Portfolio(name: "Core Offline", monthlyBudget: Decimal(1_000))
    let incomePortfolio = Portfolio(name: "Income Offline", monthlyBudget: Decimal(500))
    context.insert(corePortfolio)
    context.insert(incomePortfolio)

    try HoldingsDraft(categories: [
      CategoryDraft(
        name: "Equity", weightPercentText: "70", sortOrder: 0,
        tickers: [
          TickerDraft(
            symbol: "vti", currentPrice: Decimal(250), movingAverage: Decimal(245),
            bandPosition: Decimal(string: "0.3"), sortOrder: 0),
          TickerDraft(
            symbol: "vxus", currentPrice: Decimal(60), movingAverage: Decimal(58),
            bandPosition: Decimal(string: "0.7"), sortOrder: 1),
        ]),
      CategoryDraft(
        name: "Bonds", weightPercentText: "30", sortOrder: 1,
        tickers: [
          TickerDraft(
            symbol: "bnd", currentPrice: Decimal(75), movingAverage: Decimal(74),
            bandPosition: Decimal(string: "0.5"), sortOrder: 0)
        ]),
    ]).apply(to: corePortfolio, in: context)
    try HoldingsDraft(categories: [
      CategoryDraft(
        name: "Dividend", weightPercentText: "100", sortOrder: 0,
        tickers: [
          TickerDraft(
            symbol: "schd", currentPrice: Decimal(80), movingAverage: Decimal(79),
            bandPosition: Decimal(string: "0.4"), sortOrder: 0)
        ])
    ]).apply(to: incomePortfolio, in: context)
    try context.save()

    let coreOutput = ContributionCalculationService.calculate(portfolio: corePortfolio)
    let incomeOutput = ContributionCalculationService.calculate(portfolio: incomePortfolio)
    XCTAssertNil(coreOutput.error)
    XCTAssertNil(incomeOutput.error)
    context.insert(
      try ContributionRecord(
        snapshotFor: corePortfolio, output: coreOutput, date: Date(timeIntervalSince1970: 10)))
    context.insert(
      try ContributionRecord(
        snapshotFor: incomePortfolio, output: incomeOutput, date: Date(timeIntervalSince1970: 20)))
    try context.save()

    let coreDraft = HoldingsDraft(portfolio: corePortfolio)
    var editedCoreDraft = coreDraft
    editedCoreDraft.categories[0].name = "Global Equity"
    try editedCoreDraft.apply(to: corePortfolio, in: context)
    try context.save()

    let invalidDraft = HoldingsDraft(categories: [
      CategoryDraft(
        name: "Cash", weightPercentText: "100", sortOrder: 0,
        tickers: [
          TickerDraft(symbol: "cash", currentPrice: nil, movingAverage: nil, sortOrder: 0)
        ])
    ])
    try invalidDraft.apply(to: incomePortfolio, in: context)
    try context.save()
    XCTAssertEqual(
      ContributionCalculationService.calculate(portfolio: incomePortfolio).error
        as? ContributionCalculationError,
      .missingMarketData("CASH"))

    var retryDraft = HoldingsDraft(portfolio: incomePortfolio)
    retryDraft.categories[0].tickers[0].currentPriceText = "1.00"
    retryDraft.categories[0].tickers[0].movingAverageText = "1.00"
    retryDraft.categories[0].tickers[0].bandPositionText = "0.50"
    try retryDraft.apply(to: incomePortfolio, in: context)
    let retryOutput = ContributionCalculationService.calculate(portfolio: incomePortfolio)
    XCTAssertNil(retryOutput.error)
    context.insert(
      try ContributionRecord(
        snapshotFor: incomePortfolio, output: retryOutput, date: Date(timeIntervalSince1970: 30)))
    try context.save()

    let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
    XCTAssertEqual(portfolios.count, 2)
    XCTAssertEqual(
      corePortfolio.categories
        .first { $0.name == "Global Equity" }?
        .tickers
        .first { $0.normalizedSymbol == "VTI" }?
        .currentPrice,
      Decimal(250))

    let records = try context.fetch(FetchDescriptor<ContributionRecord>())
    let coreRecords = records.filter { $0.portfolioId == corePortfolio.id }
    let incomeRecords = records.filter { $0.portfolioId == incomePortfolio.id }
    XCTAssertEqual(coreRecords.count, 1)
    XCTAssertEqual(incomeRecords.count, 2)
    XCTAssertEqual(coreRecords.first?.totalAmount, Decimal(1_000))
    XCTAssertEqual(incomeRecords.map(\.totalAmount).sorted(), [Decimal(500), Decimal(500)])
    XCTAssertEqual(
      coreRecords.first?.tickerAllocations.map(\.tickerSymbol).sorted(), ["BND", "VTI", "VXUS"])
    XCTAssertEqual(
      incomeRecords.flatMap(\.tickerAllocations).map(\.tickerSymbol).sorted(), ["CASH", "SCHD"])
  }

  func testContributionRecordStoresImmutableSnapshotOffline() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)
    let portfolioID = UUID()
    let portfolio = Portfolio(
      id: portfolioID,
      name: "Snapshot Source",
      monthlyBudget: Decimal(1_000),
      categories: [
        Category(
          name: "Equity", weight: 1, sortOrder: 1,
          tickers: [
            Ticker(
              symbol: "VTI", currentPrice: Decimal(250), movingAverage: Decimal(245), sortOrder: 1)
          ])
      ]
    )
    let record = ContributionRecord(
      portfolioId: portfolioID,
      date: Date(timeIntervalSince1970: 1_000),
      totalAmount: Decimal(1_000),
      portfolio: portfolio,
      categoryBreakdown: [
        CategoryContribution(categoryName: "Equity", amount: Decimal(1_000), allocatedWeight: 1)
      ],
      tickerAllocations: [
        TickerAllocation(
          tickerSymbol: "VTI", categoryName: "Equity", amount: Decimal(1_000), allocatedWeight: 1)
      ]
    )
    portfolio.contributionRecords = [record]

    context.insert(portfolio)
    try context.save()
    portfolio.name = "Edited Later"
    portfolio.categories[0].tickers[0].symbol = "VOO"
    try context.save()

    let fetchedRecord = try XCTUnwrap(context.fetch(FetchDescriptor<ContributionRecord>()).first)
    XCTAssertEqual(fetchedRecord.portfolioId, portfolioID)
    XCTAssertEqual(fetchedRecord.totalAmount, Decimal(1_000))
    XCTAssertEqual(fetchedRecord.categoryBreakdown.first?.categoryName, "Equity")
    XCTAssertEqual(fetchedRecord.categoryBreakdown.first?.allocatedWeight, 1)
    XCTAssertEqual(fetchedRecord.tickerAllocations.first?.tickerSymbol, "VTI")
    XCTAssertEqual(fetchedRecord.tickerAllocations.first?.allocatedWeight, 1)
  }

  func testContributionRecordSnapshotMapsResultBreakdownAndRejectsFailures() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)
    let portfolio = Portfolio(name: "Result Source", monthlyBudget: Decimal(1_000))
    let output = ContributionOutput(
      totalAmount: Decimal(1_000),
      categoryBreakdown: [
        CategoryContributionResult(
          categoryName: "Equity", amount: Decimal(600), allocatedWeight: Decimal(string: "0.60")!),
        CategoryContributionResult(
          categoryName: "Bonds", amount: Decimal(400), allocatedWeight: Decimal(string: "0.40")!),
      ],
      allocations: [
        TickerContributionAllocation(
          tickerSymbol: "VTI", categoryName: "Equity", amount: Decimal(300),
          allocatedWeight: Decimal(string: "0.50")!),
        TickerContributionAllocation(
          tickerSymbol: "VXUS", categoryName: "Equity", amount: Decimal(300),
          allocatedWeight: Decimal(string: "0.50")!),
        TickerContributionAllocation(
          tickerSymbol: "BND", categoryName: "Bonds", amount: Decimal(400),
          allocatedWeight: Decimal(1)),
      ]
    )

    context.insert(portfolio)
    let record = try ContributionRecord(
      snapshotFor: portfolio,
      output: output,
      date: Date(timeIntervalSince1970: 2_000)
    )
    context.insert(record)
    try context.save()

    portfolio.monthlyBudget = Decimal(2_000)
    try context.save()

    let fetchedRecord = try XCTUnwrap(context.fetch(FetchDescriptor<ContributionRecord>()).first)
    XCTAssertEqual(fetchedRecord.portfolioId, portfolio.id)
    XCTAssertEqual(fetchedRecord.totalAmount, Decimal(1_000))
    XCTAssertEqual(
      fetchedRecord.categoryBreakdown.map(\.categoryName).sorted(), ["Bonds", "Equity"])
    XCTAssertEqual(
      fetchedRecord.tickerAllocations.map(\.tickerSymbol).sorted(), ["BND", "VTI", "VXUS"])

    XCTAssertThrowsError(
      try ContributionRecord(
        snapshotFor: portfolio,
        output: .failure(ContributionCalculationError.noCategories)
      )
    ) { error in
      XCTAssertEqual(
        error as? ContributionRecordSnapshotError,
        .failedCalculation(ContributionCalculationError.noCategories.localizedDescription)
      )
    }
  }
}
