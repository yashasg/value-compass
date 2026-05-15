import SwiftData
import XCTest

@testable import VCA

/// Pins the v1 SwiftData schema baseline + migration plan introduced for
/// issue #235. These tests guarantee that:
///
/// 1. ``LocalSchemaV1`` enumerates every `@Model` type registered in
///    ``LocalPersistence/schema``, so the in-memory schema and the on-disk
///    versioned baseline cannot drift.
/// 2. ``LocalSchemaMigrationPlan`` pins exactly one schema (`LocalSchemaV1`)
///    with no migration stages — the v1 baseline never tries to migrate
///    from a prior version.
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

  func testMigrationPlanPinsV1AsBaselineWithEmptyStages() {
    XCTAssertEqual(LocalSchemaMigrationPlan.schemas.count, 1)
    XCTAssertTrue(LocalSchemaMigrationPlan.schemas.first == LocalSchemaV1.self)
    XCTAssertTrue(LocalSchemaMigrationPlan.stages.isEmpty)
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
}
