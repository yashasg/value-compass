import XCTest

@testable import VCA

@MainActor
final class ContributionRecordInitTests: XCTestCase {
  func testCanonicalInitStoresTickerAllocationsVerbatim() {
    let portfolioID = UUID()
    let allocation = TickerAllocation(
      tickerSymbol: "VTI",
      categoryName: "Equities",
      amount: Decimal(100),
      allocatedWeight: Decimal(string: "0.5")!
    )

    let record = ContributionRecord(
      portfolioId: portfolioID,
      totalAmount: Decimal(100),
      tickerAllocations: [allocation]
    )

    XCTAssertEqual(record.portfolioId, portfolioID)
    XCTAssertEqual(record.totalAmount, Decimal(100))
    XCTAssertEqual(record.tickerAllocations.count, 1)
    XCTAssertEqual(record.tickerAllocations.first?.tickerSymbol, "VTI")
    XCTAssertTrue(record.categoryBreakdown.isEmpty)
  }

  // The `breakdown:` overload is intentionally deprecated; the overload exists
  // only so in-flight callers compile while they migrate to `tickerAllocations:`
  // and is scheduled for removal in the next SwiftData schema bump (#244).
  // Silence the deprecation warning at the test call site so the source-compat
  // contract has explicit coverage until it is removed.
  @available(*, deprecated)
  func testDeprecatedBreakdownInitForwardsIntoTickerAllocations() {
    let portfolioID = UUID()
    let allocation = TickerAllocation(
      tickerSymbol: "BND",
      categoryName: "Bonds",
      amount: Decimal(40),
      allocatedWeight: Decimal(string: "0.4")!
    )

    let record = ContributionRecord(
      portfolioId: portfolioID,
      totalAmount: Decimal(40),
      breakdown: [allocation]
    )

    XCTAssertEqual(record.portfolioId, portfolioID)
    XCTAssertEqual(record.tickerAllocations.count, 1)
    XCTAssertEqual(record.tickerAllocations.first?.tickerSymbol, "BND")
    XCTAssertEqual(record.tickerAllocations.first?.categoryName, "Bonds")
    XCTAssertEqual(record.tickerAllocations.first?.amount, Decimal(40))
  }

  @available(*, deprecated)
  func testDeprecatedBreakdownInitPreservesCategoryBreakdown() {
    let category = CategoryContribution(
      categoryName: "Equities",
      amount: Decimal(60),
      allocatedWeight: Decimal(string: "0.6")!
    )
    let allocation = TickerAllocation(
      tickerSymbol: "VTI",
      categoryName: "Equities",
      amount: Decimal(60),
      allocatedWeight: Decimal(string: "0.6")!
    )

    let record = ContributionRecord(
      portfolioId: UUID(),
      totalAmount: Decimal(60),
      categoryBreakdown: [category],
      breakdown: [allocation]
    )

    XCTAssertEqual(record.categoryBreakdown.count, 1)
    XCTAssertEqual(record.categoryBreakdown.first?.categoryName, "Equities")
    XCTAssertEqual(record.tickerAllocations.count, 1)
    XCTAssertEqual(record.tickerAllocations.first?.tickerSymbol, "VTI")
  }
}
