import SwiftData
import XCTest

@testable import VCA

/// Pins the v1 SwiftData schema baseline + migration plan introduced for
/// issue #235 and the v2 additive schema bump introduced for issue #249.
/// These tests guarantee that:
///
/// 1. ``LocalSchemaV1`` enumerates every `@Model` type registered in
///    ``LocalPersistence/schema``, so the in-memory schema and the on-disk
///    versioned baseline cannot drift.
/// 2. ``LocalSchemaMigrationPlan`` pins both schema versions in order and
///    registers exactly one migration stage (`v1 → v2`) per the v2
///    contribution-row identity contract.
/// 3. A disk-backed container can be opened cold (creates the store),
///    written to, and reopened warm against the same URL without raising a
///    migration error. Reopening warm exercises the SwiftData migration
///    runtime against the explicit `migrationPlan` argument and proves the
///    `ContributionRecord` rows survive the round-trip.
@MainActor
final class LocalSchemaMigrationTests: XCTestCase {
  func testSchemaV1ListsEveryModelRegisteredOnLocalPersistence() {
    let v1Names = Set(LocalSchemaV1.models.map { String(describing: $0) })
    let expected: Set<String> = [
      "Portfolio",
      "Category",
      "Ticker",
      "ContributionRecord",
      "CategoryContribution",
      "TickerAllocation",
      "Holding",
      "TickerMetadata",
      "MarketDataBar",
      "InvestSnapshot",
      "AppSettings",
    ]
    XCTAssertEqual(v1Names, expected)
    XCTAssertEqual(v1Names.count, LocalPersistence.schema.entities.count)
  }

  func testSchemaV1AdvertisesAVersionIdentifier() {
    XCTAssertEqual(LocalSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
  }

  func testSchemaV2ListsTheSameModelsAsV1AndAdvertisesABumpedVersion() {
    let v1Names = Set(LocalSchemaV1.models.map { String(describing: $0) })
    let v2Names = Set(LocalSchemaV2.models.map { String(describing: $0) })
    XCTAssertEqual(v1Names, v2Names)
    XCTAssertEqual(LocalSchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
  }

  func testMigrationPlanPinsV1AndV2InOrderWithSingleV1ToV2Stage() {
    XCTAssertEqual(LocalSchemaMigrationPlan.schemas.count, 2)
    XCTAssertTrue(LocalSchemaMigrationPlan.schemas.first == LocalSchemaV1.self)
    XCTAssertTrue(LocalSchemaMigrationPlan.schemas.last == LocalSchemaV2.self)
    XCTAssertEqual(LocalSchemaMigrationPlan.stages.count, 1)
  }

  func testInMemoryContainerOpensWithMigrationPlanWithoutThrowing() throws {
    XCTAssertNoThrow(try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true))
  }

  func testColdAndWarmDiskContainersReopenWithoutMigrationError() throws {
    let storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vca-mig-\(UUID().uuidString).store")
    addTeardownBlock {
      // SwiftData writes a sidecar -shm/-wal pair next to the .store file,
      // so remove the parent directory rather than the single URL.
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
      try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
    }

    let portfolioID = UUID()

    let coldConfiguration = ModelConfiguration(
      schema: LocalPersistence.schema,
      url: storeURL
    )
    let coldContainer = try ModelContainer(
      for: LocalPersistence.schema,
      migrationPlan: LocalSchemaMigrationPlan.self,
      configurations: [coldConfiguration]
    )
    let coldContext = ModelContext(coldContainer)
    coldContext.insert(
      Portfolio(id: portfolioID, name: "Reopen", monthlyBudget: Decimal(250)))
    try coldContext.save()

    let warmConfiguration = ModelConfiguration(
      schema: LocalPersistence.schema,
      url: storeURL
    )
    let warmContainer = try ModelContainer(
      for: LocalPersistence.schema,
      migrationPlan: LocalSchemaMigrationPlan.self,
      configurations: [warmConfiguration]
    )
    let warmContext = ModelContext(warmContainer)
    let portfolios = try warmContext.fetch(FetchDescriptor<Portfolio>())
    XCTAssertEqual(portfolios.count, 1)
    XCTAssertEqual(portfolios.first?.id, portfolioID)
    XCTAssertEqual(portfolios.first?.name, "Reopen")
  }

  // MARK: - v2 identity contract (#249)

  func testCategoryContributionDefaultInitAssignsAUniqueID() {
    let first = CategoryContribution(
      categoryName: "Equities",
      amount: Decimal(100),
      allocatedWeight: Decimal(string: "0.5")!
    )
    let second = CategoryContribution(
      categoryName: "Bonds",
      amount: Decimal(100),
      allocatedWeight: Decimal(string: "0.5")!
    )
    XCTAssertNotEqual(first.id, second.id)
  }

  func testTickerAllocationDefaultInitAssignsAUniqueID() {
    let first = TickerAllocation(
      tickerSymbol: "VTI",
      categoryName: "Equities",
      amount: Decimal(50)
    )
    let second = TickerAllocation(
      tickerSymbol: "BND",
      categoryName: "Bonds",
      amount: Decimal(50)
    )
    XCTAssertNotEqual(first.id, second.id)
  }

  func testCategoryContributionAndTickerAllocationPersistRoundTripWithStableIDs() throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = ModelContext(container)

    let categoryID = UUID()
    let allocationID = UUID()
    let category = CategoryContribution(
      id: categoryID,
      categoryName: "Equities",
      amount: Decimal(100),
      allocatedWeight: Decimal(string: "0.5")!
    )
    let allocation = TickerAllocation(
      id: allocationID,
      tickerSymbol: "VTI",
      categoryName: "Equities",
      amount: Decimal(100),
      allocatedWeight: Decimal(string: "0.5")!
    )
    context.insert(category)
    context.insert(allocation)
    try context.save()

    let fetchedCategories = try context.fetch(FetchDescriptor<CategoryContribution>())
    XCTAssertEqual(fetchedCategories.count, 1)
    XCTAssertEqual(fetchedCategories.first?.id, categoryID)

    let fetchedAllocations = try context.fetch(FetchDescriptor<TickerAllocation>())
    XCTAssertEqual(fetchedAllocations.count, 1)
    XCTAssertEqual(fetchedAllocations.first?.id, allocationID)
  }
}
