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
}
