import XCTest

@testable import VCA

final class BackendSyncProjectionTests: XCTestCase {
  @MainActor
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

  @MainActor
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

  @MainActor
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

  @MainActor
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
}
