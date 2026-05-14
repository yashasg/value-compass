import XCTest

@testable import VCA

@MainActor
final class BackendSyncProjectionTests: XCTestCase {
  func testProjectionMapsPortfolioMetadataAndSplitsCategoryWeightsAcrossTickers() throws {
    let portfolioID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let deviceUUID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let createdAt = Date(timeIntervalSince1970: 1_800)
    let portfolio = Portfolio(
      id: portfolioID,
      name: "Core",
      monthlyBudget: Decimal(1_000),
      maWindow: 50,
      createdAt: createdAt,
      categories: [
        Category(
          name: "Bonds",
          weight: Decimal(string: "0.40")!,
          sortOrder: 2,
          tickers: [
            Ticker(symbol: "BND", sortOrder: 1)
          ]
        ),
        Category(
          name: "Equity",
          weight: Decimal(string: "0.60")!,
          sortOrder: 1,
          tickers: [
            Ticker(
              symbol: " VTI ", currentPrice: Decimal(250), movingAverage: Decimal(245), sortOrder: 2
            ),
            Ticker(
              symbol: "VOO", currentPrice: Decimal(500), movingAverage: Decimal(490), sortOrder: 1),
          ]
        ),
      ]
    )

    let payload = try BackendSyncProjection.makePayload(for: portfolio, deviceUUID: deviceUUID)

    XCTAssertEqual(
      payload.portfolio,
      BackendPortfolioPayload(
        id: portfolioID,
        deviceUUID: deviceUUID,
        name: "Core",
        monthlyBudget: Decimal(1_000),
        maWindow: 50,
        createdAt: createdAt
      )
    )
    XCTAssertEqual(
      payload.holdings,
      [
        BackendHoldingPayload(
          portfolioID: portfolioID, ticker: "VOO", weight: Decimal(string: "0.30")!),
        BackendHoldingPayload(
          portfolioID: portfolioID, ticker: "VTI", weight: Decimal(string: "0.30")!),
        BackendHoldingPayload(
          portfolioID: portfolioID, ticker: "BND", weight: Decimal(string: "0.40")!),
      ]
    )
  }

  func testProjectionExcludesLocalOnlyFieldsByConstruction() throws {
    let portfolio = Portfolio(
      name: "Local rich model",
      monthlyBudget: Decimal(250),
      categories: [
        Category(
          name: "Do Not Sync Category Name",
          weight: 1,
          sortOrder: 9,
          tickers: [
            Ticker(
              symbol: "VXUS",
              currentPrice: Decimal(string: "55.25"),
              movingAverage: Decimal(string: "53.10"),
              sortOrder: 4
            )
          ]
        )
      ],
      contributionRecords: [
        ContributionRecord(
          portfolioId: UUID(),
          totalAmount: Decimal(250),
          breakdown: [
            TickerAllocation(tickerSymbol: "VXUS", categoryName: "Snapshot", amount: Decimal(250))
          ]
        )
      ]
    )

    let payload = try BackendSyncProjection.makePayload(for: portfolio, deviceUUID: UUID())

    XCTAssertEqual(
      payload.holdings,
      [
        BackendHoldingPayload(portfolioID: portfolio.id, ticker: "VXUS", weight: 1)
      ])
  }

  func testBackendPayloadShapeOnlyContainsV1FlatSchemaFields() throws {
    let portfolio = Portfolio(
      name: "Flat contract",
      monthlyBudget: Decimal(500),
      categories: [
        Category(
          name: "Local Category Name",
          weight: Decimal(string: "0.25")!,
          sortOrder: 99,
          tickers: [
            Ticker(
              symbol: "AAPL",
              currentPrice: Decimal(string: "1234.5678"),
              movingAverage: Decimal(string: "9876.5432"),
              bandPosition: Decimal(string: "0.8123"),
              sortOrder: 42
            )
          ]
        ),
        Category(
          name: "Second Local Category",
          weight: Decimal(string: "0.75")!,
          sortOrder: 100,
          tickers: [
            Ticker(symbol: "MSFT", sortOrder: 7)
          ]
        ),
      ],
      contributionRecords: [
        ContributionRecord(
          portfolioId: UUID(),
          totalAmount: Decimal(string: "321.09")!,
          categoryBreakdown: [
            CategoryContribution(
              categoryName: "Category History",
              amount: Decimal(string: "654.32")!,
              allocatedWeight: Decimal(string: "0.2468")!
            )
          ],
          breakdown: [
            TickerAllocation(
              tickerSymbol: "HISTORY_ONLY",
              categoryName: "Historical Snapshot",
              amount: Decimal(string: "321.09")!,
              allocatedWeight: Decimal(string: "0.4321")!
            )
          ]
        )
      ]
    )

    let payload = try BackendSyncProjection.makePayload(for: portfolio, deviceUUID: UUID())

    XCTAssertEqual(
      fieldNames(in: payload.portfolio),
      ["createdAt", "deviceUUID", "id", "maWindow", "monthlyBudget", "name"]
    )
    XCTAssertEqual(
      fieldNames(in: try XCTUnwrap(payload.holdings.first)),
      ["portfolioID", "ticker", "weight"]
    )

    let tokens = payloadTokens(payload)
    for localOnlyToken in [
      "Category History",
      "allocatedWeight",
      "bandPosition",
      "categoryBreakdown",
      "categoryName",
      "contributionRecords",
      "currentPrice",
      "Historical Snapshot",
      "HISTORY_ONLY",
      "movingAverage",
      "sortOrder",
      "tickerAllocations",
      "0.8123",
      "654.32",
      "0.2468",
      "1234.5678",
      "9876.5432",
      "321.09",
      "0.4321",
    ] {
      XCTAssertFalse(
        tokens.contains(localOnlyToken),
        "Backend payload leaked local-only token: \(localOnlyToken)"
      )
    }
  }

  func testApplyingBackendMetadataCannotOverwriteLocalCategoryGrouping() throws {
    let originalCreatedAt = Date(timeIntervalSince1970: 100)
    let portfolio = Portfolio(
      name: "Local source of truth",
      monthlyBudget: Decimal(800),
      createdAt: originalCreatedAt,
      categories: [
        Category(
          name: "Equity",
          weight: Decimal(string: "0.60")!,
          sortOrder: 1,
          tickers: [
            Ticker(symbol: "VTI", currentPrice: 250, movingAverage: 245, sortOrder: 1),
            Ticker(symbol: "VXUS", currentPrice: 55, movingAverage: 53, sortOrder: 2),
          ]
        ),
        Category(
          name: "Bonds",
          weight: Decimal(string: "0.40")!,
          sortOrder: 2,
          tickers: [
            Ticker(symbol: "BND", currentPrice: 70, movingAverage: 71, sortOrder: 1)
          ]
        ),
      ]
    )
    let originalGrouping = categoryGroupingSnapshot(portfolio)
    let backendPortfolio = BackendPortfolioPayload(
      id: portfolio.id,
      deviceUUID: UUID(),
      name: "Backend metadata",
      monthlyBudget: Decimal(900),
      maWindow: 200,
      createdAt: Date(timeIntervalSince1970: 200)
    )

    try BackendSyncProjection.applyBackendMetadata(backendPortfolio, to: portfolio)

    XCTAssertEqual(portfolio.name, "Backend metadata")
    XCTAssertEqual(portfolio.monthlyBudget, Decimal(900))
    XCTAssertEqual(portfolio.maWindow, 200)
    XCTAssertEqual(categoryGroupingSnapshot(portfolio), originalGrouping)
  }

  func testProjectionRejectsPositiveWeightEmptyCategoryInsteadOfCreatingInvalidHolding() {
    let portfolio = Portfolio(
      name: "Invalid for sync",
      monthlyBudget: Decimal(100),
      categories: [
        Category(name: "Empty", weight: 1, sortOrder: 1, tickers: [])
      ]
    )

    XCTAssertThrowsError(try BackendSyncProjection.makePayload(for: portfolio, deviceUUID: UUID()))
    { error in
      XCTAssertEqual(error as? BackendSyncProjectionError, .emptyCategory(categoryName: "Empty"))
    }
  }

  func testProjectionSkipsZeroWeightEmptyCategory() throws {
    let portfolio = Portfolio(
      name: "Draft",
      monthlyBudget: Decimal(100),
      categories: [
        Category(name: "Empty Draft", weight: 0, sortOrder: 1, tickers: []),
        Category(
          name: "Investable", weight: 1, sortOrder: 2,
          tickers: [
            Ticker(symbol: "SCHD", sortOrder: 1)
          ]),
      ]
    )

    let payload = try BackendSyncProjection.makePayload(for: portfolio, deviceUUID: UUID())

    XCTAssertEqual(
      payload.holdings,
      [
        BackendHoldingPayload(portfolioID: portfolio.id, ticker: "SCHD", weight: 1)
      ])
  }

  func testProjectionRejectsDuplicateTickerSymbolsBeforeBackendPayload() {
    let portfolio = Portfolio(
      name: "Duplicate sync symbols",
      monthlyBudget: Decimal(100),
      categories: [
        Category(
          name: "US",
          weight: Decimal(string: "0.50")!,
          sortOrder: 1,
          tickers: [
            Ticker(symbol: "VOO", sortOrder: 1)
          ]
        ),
        Category(
          name: "Growth",
          weight: Decimal(string: "0.50")!,
          sortOrder: 2,
          tickers: [
            Ticker(symbol: " voo ", sortOrder: 1)
          ]
        ),
      ]
    )

    XCTAssertThrowsError(try BackendSyncProjection.makePayload(for: portfolio, deviceUUID: UUID()))
    { error in
      XCTAssertEqual(error as? BackendSyncProjectionError, .duplicateTickerSymbols(["VOO"]))
    }
  }

  func testProjectionRejectsEmptyTickerSymbolBeforeBackendPayload() {
    let portfolio = Portfolio(
      name: "Empty sync symbol",
      monthlyBudget: Decimal(100),
      categories: [
        Category(
          name: "Invalid",
          weight: 1,
          sortOrder: 1,
          tickers: [
            Ticker(symbol: "  ", sortOrder: 1)
          ])
      ]
    )

    XCTAssertThrowsError(try BackendSyncProjection.makePayload(for: portfolio, deviceUUID: UUID()))
    { error in
      XCTAssertEqual(error as? BackendSyncProjectionError, .emptyTickerSymbol)
    }
  }

  func testProjectionRejectsInvalidBackendHoldingWeights() {
    let negativeWeightPortfolio = Portfolio(
      name: "Negative weight",
      monthlyBudget: Decimal(100),
      categories: [
        Category(
          name: "Invalid",
          weight: Decimal(string: "-0.10")!,
          sortOrder: 1,
          tickers: [
            Ticker(symbol: "BND", sortOrder: 1)
          ])
      ]
    )
    let oversizedWeightPortfolio = Portfolio(
      name: "Oversized weight",
      monthlyBudget: Decimal(100),
      categories: [
        Category(
          name: "Invalid",
          weight: Decimal(2),
          sortOrder: 1,
          tickers: [
            Ticker(symbol: "VTI", sortOrder: 1)
          ])
      ]
    )

    XCTAssertThrowsError(
      try BackendSyncProjection.makePayload(for: negativeWeightPortfolio, deviceUUID: UUID())
    ) { error in
      XCTAssertEqual(
        error as? BackendSyncProjectionError,
        .invalidHoldingWeight(ticker: "BND", weight: Decimal(string: "-0.10")!)
      )
    }
    XCTAssertThrowsError(
      try BackendSyncProjection.makePayload(for: oversizedWeightPortfolio, deviceUUID: UUID())
    ) { error in
      XCTAssertEqual(
        error as? BackendSyncProjectionError,
        .invalidHoldingWeight(ticker: "VTI", weight: Decimal(2))
      )
    }
  }

  private func fieldNames(in value: Any) -> [String] {
    Mirror(reflecting: value).children.compactMap(\.label).sorted()
  }

  private func payloadTokens(_ value: Any) -> Set<String> {
    var tokens = Set<String>()

    func visit(_ value: Any) {
      if let decimal = value as? Decimal {
        tokens.insert(NSDecimalNumber(decimal: decimal).stringValue)
        return
      }

      if let string = value as? String {
        tokens.insert(string)
        return
      }

      let mirror = Mirror(reflecting: value)
      guard let displayStyle = mirror.displayStyle else {
        tokens.insert(String(describing: value))
        return
      }

      switch displayStyle {
      case .class, .collection, .dictionary, .optional, .set, .struct, .tuple:
        for child in mirror.children {
          if let label = child.label {
            tokens.insert(label)
          }
          visit(child.value)
        }
      default:
        tokens.insert(String(describing: value))
      }
    }

    visit(value)
    return tokens
  }

  private func categoryGroupingSnapshot(_ portfolio: Portfolio) -> [String] {
    portfolio.categories.sorted { $0.sortOrder < $1.sortOrder }.map { category in
      let tickers = category.tickers.sorted { $0.sortOrder < $1.sortOrder }
        .map { ticker in
          "\(ticker.normalizedSymbol):\(ticker.sortOrder)"
        }
        .joined(separator: ",")
      return "\(category.name):\(category.id):\(category.weight):\(category.sortOrder):\(tickers)"
    }
  }
}
