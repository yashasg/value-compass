import SwiftData
import XCTest

@testable import VCA

@MainActor
final class MVPModelsPersistenceTests: XCTestCase {
  // MARK: - Holding

  func testHoldingNormalizesSymbolForCaseInsensitiveLookups() {
    let holding = Holding(portfolioId: UUID(), symbol: " vti ")
    XCTAssertEqual(holding.normalizedSymbol, "VTI")
  }

  func testHoldingPersistsAndRoundTripsThroughInMemoryContainer() throws {
    let context = try makeInMemoryContext()
    let portfolioID = UUID()
    let holding = Holding(
      portfolioId: portfolioID,
      symbol: "VOO",
      costBasis: Decimal(string: "412.34")!,
      shares: Decimal(string: "10.5")!,
      sortOrder: 2
    )

    context.insert(holding)
    try context.save()

    let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<Holding>()).first)
    XCTAssertEqual(fetched.symbol, "VOO")
    XCTAssertEqual(fetched.portfolioId, portfolioID)
    XCTAssertEqual(fetched.costBasis, Decimal(string: "412.34"))
    XCTAssertEqual(fetched.shares, Decimal(string: "10.5"))
    XCTAssertEqual(fetched.sortOrder, 2)
  }

  // MARK: - TickerMetadata

  func testTickerMetadataUpsertsBySymbolKey() throws {
    let context = try makeInMemoryContext()
    context.insert(TickerMetadata(symbol: "spy", name: "Old", exchange: "NYSE", assetClass: .etf))
    try context.save()

    // Upsert by deleting the existing row and inserting fresh — the
    // @Attribute(.unique) constraint would otherwise raise on duplicate insert.
    if let existing = try context.fetch(
      FetchDescriptor<TickerMetadata>(
        predicate: #Predicate<TickerMetadata> { $0.symbol == "SPY" }
      )
    ).first {
      context.delete(existing)
    }
    context.insert(
      TickerMetadata(symbol: "SPY", name: "S&P 500 ETF", exchange: "NYSE", assetClass: .etf))
    try context.save()

    let rows = try context.fetch(FetchDescriptor<TickerMetadata>())
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.name, "S&P 500 ETF")
    XCTAssertEqual(rows.first?.assetClassValue, .etf)
  }

  // MARK: - MarketDataBar

  func testMarketDataBarIDIsStableAcrossTimeZonesForSameUTCDay() {
    let utcCalendar = Calendar.utc
    let dateAt0900PT = utcCalendar.date(
      from: DateComponents(year: 2024, month: 1, day: 15, hour: 17))!
    let dateAt1700UTC = utcCalendar.date(
      from: DateComponents(year: 2024, month: 1, day: 15, hour: 17))!

    XCTAssertEqual(
      MarketDataBar.makeID(symbol: " aapl ", date: dateAt0900PT),
      MarketDataBar.makeID(symbol: "AAPL", date: dateAt1700UTC)
    )
    XCTAssertEqual(MarketDataBar.makeID(symbol: "AAPL", date: dateAt1700UTC), "AAPL|2024-01-15")
  }

  func testMarketDataBarRepositoryUpsertReplacesExistingRowsByCompoundID() throws {
    let context = try makeInMemoryContext()
    let repo = MarketDataBarRepository(context: context)
    let day = Calendar.utc.date(from: DateComponents(year: 2024, month: 1, day: 15))!

    try repo.upsert([
      MarketDataBar(
        symbol: "AAPL", date: day, open: 1, high: 2, low: 0, close: 1.5, volume: 100)
    ])
    try context.save()

    try repo.upsert([
      MarketDataBar(
        symbol: "AAPL", date: day, open: 10, high: 20, low: 9, close: 18, volume: 999)
    ])
    try context.save()

    let bars = try repo.bars(for: "AAPL")
    XCTAssertEqual(bars.count, 1)
    XCTAssertEqual(bars.first?.close, Decimal(18))
    XCTAssertEqual(bars.first?.volume, 999)
  }

  func testMarketDataBarRepositoryRangeAndLatestQueriesUseSymbolAndDateOrdering() throws {
    let context = try makeInMemoryContext()
    let repo = MarketDataBarRepository(context: context)
    let day1 = Calendar.utc.date(from: DateComponents(year: 2024, month: 1, day: 12))!
    let day2 = Calendar.utc.date(from: DateComponents(year: 2024, month: 1, day: 13))!
    let day3 = Calendar.utc.date(from: DateComponents(year: 2024, month: 1, day: 14))!

    try repo.upsert([
      MarketDataBar(symbol: "AAPL", date: day3, open: 0, high: 0, low: 0, close: 30),
      MarketDataBar(symbol: "AAPL", date: day1, open: 0, high: 0, low: 0, close: 10),
      MarketDataBar(symbol: "AAPL", date: day2, open: 0, high: 0, low: 0, close: 20),
      MarketDataBar(symbol: "VOO", date: day2, open: 0, high: 0, low: 0, close: 410),
    ])
    try context.save()

    let aaplBars = try repo.bars(for: "aapl")
    XCTAssertEqual(aaplBars.map(\.close), [Decimal(10), Decimal(20), Decimal(30)])

    XCTAssertEqual(try repo.latestBar(for: "AAPL")?.close, Decimal(30))
    XCTAssertEqual(try repo.latestBar(for: "VOO")?.close, Decimal(410))
    XCTAssertNil(try repo.latestBar(for: "MISSING"))
  }

  func testMarketDataBarRepositoryDeleteAllRemovesEveryBar() throws {
    let context = try makeInMemoryContext()
    let repo = MarketDataBarRepository(context: context)
    let day = Calendar.utc.date(from: DateComponents(year: 2024, month: 1, day: 15))!

    try repo.upsert([
      MarketDataBar(symbol: "AAPL", date: day, open: 1, high: 1, low: 1, close: 1),
      MarketDataBar(symbol: "VOO", date: day, open: 2, high: 2, low: 2, close: 2),
    ])
    try context.save()

    try repo.deleteAll()
    try context.save()

    XCTAssertEqual(try context.fetch(FetchDescriptor<MarketDataBar>()).count, 0)
  }

  // MARK: - InvestSnapshot

  func testInvestSnapshotRoundTripsCompositionAndWarningsAsJSON() throws {
    let portfolioID = UUID()
    let composition = [
      CategorySnapshotInput(
        name: "Equity", weight: Decimal(string: "0.7")!, symbols: ["VTI", "VXUS"]),
      CategorySnapshotInput(
        name: "Bonds", weight: Decimal(string: "0.3")!, symbols: ["BND"]),
    ]
    let snapshot = try InvestSnapshot(
      portfolioId: portfolioID,
      capitalAmount: Decimal(1_000),
      maWindow: 50,
      marketDataWindowStart: Date(timeIntervalSince1970: 1_700_000_000),
      marketDataWindowEnd: Date(timeIntervalSince1970: 1_700_864_000),
      composition: composition,
      warnings: ["Stale market data: BND"]
    )

    let context = try makeInMemoryContext()
    context.insert(snapshot)
    try context.save()

    let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<InvestSnapshot>()).first)
    XCTAssertEqual(fetched.portfolioId, portfolioID)
    XCTAssertEqual(fetched.capitalAmount, Decimal(1_000))
    XCTAssertEqual(try fetched.decodedComposition(), composition)
    XCTAssertEqual(try fetched.decodedWarnings(), ["Stale market data: BND"])
  }

  func testInvestSnapshotPinsCategorySnapshotInputCompositionJSONShape() throws {
    let composition = [
      CategorySnapshotInput(
        name: "Equity", weight: Decimal(string: "0.7")!, symbols: ["VTI", "VXUS"])
    ]
    let canonicalCompositionJSON =
      "[{\"name\":\"Equity\",\"symbols\":[\"VTI\",\"VXUS\"],\"weight\":0.7}]"
    let snapshot = try InvestSnapshot(
      portfolioId: UUID(),
      capitalAmount: Decimal(1_000),
      maWindow: 50,
      marketDataWindowStart: Date(timeIntervalSince1970: 1_700_000_000),
      marketDataWindowEnd: Date(timeIntervalSince1970: 1_700_864_000),
      composition: composition
    )

    XCTAssertEqual(snapshot.compositionJSON, canonicalCompositionJSON)
    XCTAssertEqual(snapshot.warningsJSON, "[]")
    XCTAssertEqual(
      try JSONDecoder().decode(
        [CategorySnapshotInput].self,
        from: Data(canonicalCompositionJSON.utf8)
      ),
      composition
    )
  }

  // MARK: - AppSettings

  func testAppSettingsRepositorySeedsSingletonExactlyOnce() throws {
    let context = try makeInMemoryContext()
    let repo = AppSettingsRepository(context: context)

    let first = try repo.loadOrSeed()
    let second = try repo.loadOrSeed()

    XCTAssertEqual(first.id, AppSettings.singletonID)
    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(try context.fetch(FetchDescriptor<AppSettings>()).count, 1)
    XCTAssertEqual(first.themePreferenceValue, .system)
    XCTAssertFalse(first.backgroundRefreshEnabled)
    XCTAssertFalse(first.hasAcceptedDisclaimer)
  }

  func testAppSettingsRepositoryDeleteAllRemovesSingleton() throws {
    let context = try makeInMemoryContext()
    let repo = AppSettingsRepository(context: context)
    _ = try repo.loadOrSeed()

    try repo.deleteAll()
    try context.save()

    XCTAssertEqual(try context.fetch(FetchDescriptor<AppSettings>()).count, 0)
  }

  // MARK: - PortfolioCascadeDeleter

  func testPortfolioCascadeDeleterRemovesHoldingsSnapshotsAndPortfolio() throws {
    let context = try makeInMemoryContext()
    let portfolio = Portfolio(name: "Core", monthlyBudget: Decimal(1_000))
    context.insert(portfolio)
    let portfolioID = portfolio.id

    context.insert(Holding(portfolioId: portfolioID, symbol: "VTI"))
    context.insert(Holding(portfolioId: portfolioID, symbol: "BND"))
    let snapshot = try InvestSnapshot(
      portfolioId: portfolioID,
      capitalAmount: Decimal(500),
      maWindow: 50,
      marketDataWindowStart: Date(timeIntervalSince1970: 1_700_000_000),
      marketDataWindowEnd: Date(timeIntervalSince1970: 1_700_864_000),
      composition: []
    )
    context.insert(snapshot)
    try context.save()

    let day = Calendar.utc.date(from: DateComponents(year: 2024, month: 1, day: 15))!
    let bar = MarketDataBar(symbol: "VTI", date: day, open: 1, high: 1, low: 1, close: 1)
    context.insert(bar)
    try context.save()

    try PortfolioCascadeDeleter(context: context).delete(portfolioID: portfolioID)

    XCTAssertEqual(try context.fetch(FetchDescriptor<Holding>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<InvestSnapshot>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<Portfolio>()).count, 0)
    // Shared market data must outlive any single portfolio.
    XCTAssertEqual(try context.fetch(FetchDescriptor<MarketDataBar>()).count, 1)
  }

  func testPortfolioCascadeDeleterLeavesUnrelatedPortfoliosAndDataIntact() throws {
    let context = try makeInMemoryContext()
    let target = Portfolio(name: "Target", monthlyBudget: Decimal(500))
    let other = Portfolio(name: "Untouched", monthlyBudget: Decimal(700))
    context.insert(target)
    context.insert(other)

    context.insert(Holding(portfolioId: target.id, symbol: "VTI"))
    context.insert(Holding(portfolioId: other.id, symbol: "VOO"))
    try context.save()

    try PortfolioCascadeDeleter(context: context).delete(portfolioID: target.id)

    let remainingHoldings = try context.fetch(FetchDescriptor<Holding>())
    XCTAssertEqual(remainingHoldings.map(\.symbol), ["VOO"])
    XCTAssertEqual(remainingHoldings.first?.portfolioId, other.id)
    XCTAssertEqual(try context.fetch(FetchDescriptor<Portfolio>()).count, 1)
  }

  // MARK: - Helpers

  private func makeInMemoryContext() throws -> ModelContext {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    return ModelContext(container)
  }
}

extension Calendar {
  fileprivate static var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    return calendar
  }
}
