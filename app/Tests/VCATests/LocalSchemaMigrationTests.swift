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
/// 3. ``LocalSchemaV1`` and ``LocalSchemaV2`` are *frozen* snapshots — their
///    `models` arrays must reference distinct nested `@Model` types so a
///    future edit to a live `@Model` class cannot retroactively change the
///    v1 on-disk shape (issue #337). The frozen baseline must also carry the
///    documented v1 → v2 field-level delta: `CategoryContribution` and
///    `TickerAllocation` ship the `id: UUID` column in v2 but not in v1.
/// 4. A disk-backed container can be opened cold (creates the store),
///    written to, and reopened warm against the same URL without raising a
///    migration error. Reopening warm exercises the SwiftData migration
///    runtime against the explicit `migrationPlan` argument and proves the
///    `ContributionRecord` rows survive the round-trip.
@MainActor
final class LocalSchemaMigrationTests: XCTestCase {
  func testSchemaV1ListsEveryModelRegisteredOnLocalPersistence() {
    let v1Names = Set(LocalSchemaV1.models.map { entityName(for: $0) })
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

  func testSchemaV2AdvertisesABumpedVersionIdentifier() {
    XCTAssertEqual(LocalSchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
  }

  func testSchemaV2ListsTheSameEntityNamesAsV1() {
    let v1Names = Set(LocalSchemaV1.models.map { entityName(for: $0) })
    let v2Names = Set(LocalSchemaV2.models.map { entityName(for: $0) })
    XCTAssertEqual(v1Names, v2Names)
  }

  /// Frozen-snapshot invariant: ``LocalSchemaV1`` and ``LocalSchemaV2`` must
  /// reference *distinct* `@Model` class objects. If the two `models` arrays
  /// ever share live class identity, an edit to any of those classes would
  /// silently mutate `LocalSchemaV1` — making the v1 baseline useless for
  /// migration. Issue #337.
  func testSchemaV1AndV2DoNotShareLiveModelTypes() {
    let v1Identifiers = Set(LocalSchemaV1.models.map { ObjectIdentifier($0) })
    let v2Identifiers = Set(LocalSchemaV2.models.map { ObjectIdentifier($0) })
    XCTAssertTrue(
      v1Identifiers.isDisjoint(with: v2Identifiers),
      """
      LocalSchemaV1 and LocalSchemaV2 share at least one live @Model class. \
      Each schema version must own its own frozen snapshot of every entity \
      so future edits to the live shape cannot retroactively mutate the v1 \
      on-disk baseline. Move the live class into LocalSchemaV2 and add a \
      frozen V1 copy to LocalSchemaV1Models.swift (issue #337).
      """
    )
  }

  /// Asserts the v1 → v2 field-level delta documented in
  /// `LocalSchemaV1Models.swift`: V2 ships an `id: UUID` column on
  /// `CategoryContribution` and `TickerAllocation`, V1 does not. The test
  /// fails closed if either side drifts — protecting both the v2 unique-key
  /// contract (issue #249) and the v1 baseline that the migration stage
  /// targets (issue #337).
  func testSchemaV1AndV2DifferOnContributionBreakdownIdentityColumn() throws {
    let v1Schema = Schema(versionedSchema: LocalSchemaV1.self)
    let v2Schema = Schema(versionedSchema: LocalSchemaV2.self)

    let v1CategoryContribution = try XCTUnwrap(
      v1Schema.entities.first { $0.name == "CategoryContribution" }
    )
    let v2CategoryContribution = try XCTUnwrap(
      v2Schema.entities.first { $0.name == "CategoryContribution" }
    )
    let v1TickerAllocation = try XCTUnwrap(
      v1Schema.entities.first { $0.name == "TickerAllocation" }
    )
    let v2TickerAllocation = try XCTUnwrap(
      v2Schema.entities.first { $0.name == "TickerAllocation" }
    )

    XCTAssertFalse(
      v1CategoryContribution.properties.contains(where: { $0.name == "id" }),
      "LocalSchemaV1.CategoryContribution must NOT expose an 'id' column — that field is the v1→v2 delta."
    )
    XCTAssertTrue(
      v2CategoryContribution.properties.contains(where: { $0.name == "id" }),
      "LocalSchemaV2.CategoryContribution must expose an 'id' column (issue #249)."
    )
    XCTAssertFalse(
      v1TickerAllocation.properties.contains(where: { $0.name == "id" }),
      "LocalSchemaV1.TickerAllocation must NOT expose an 'id' column — that field is the v1→v2 delta."
    )
    XCTAssertTrue(
      v2TickerAllocation.properties.contains(where: { $0.name == "id" }),
      "LocalSchemaV2.TickerAllocation must expose an 'id' column (issue #249)."
    )
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

  /// Compatibility test (#337): a disk-backed store created with the *current*
  /// v2 model graph (which now lives under nested `LocalSchemaV2.*` types) can
  /// be reopened by the same `LocalSchemaMigrationPlan` without losing any of
  /// the 11 v2 entities. This guards against the failure mode flagged on the
  /// schema-freeze PR — namely, that renaming v2 model classes from
  /// module-scope to nested types could (in theory) change the on-disk class
  /// identity SwiftData keys entities by, even while the `versionIdentifier`
  /// stays at 2.0.0. If that ever broke, this round-trip would either throw
  /// at warm reopen or come back with empty fetches.
  func testV2DiskContainerRoundTripsEveryEntityAcrossReopens() throws {
    let storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vca-mig-v2-\(UUID().uuidString).store")
    addTeardownBlock {
      try? FileManager.default.removeItem(at: storeURL)
      try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
      try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
    }

    let portfolioID = UUID()
    let categoryID = UUID()
    let tickerID = UUID()
    let recordID = UUID()
    let categoryContributionID = UUID()
    let tickerAllocationID = UUID()
    let holdingID = UUID()
    let snapshotID = UUID()
    let appSettingsID = UUID()
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    // Cold open: fresh store at `storeURL`, write one row of every v2 entity.
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

    let portfolio = Portfolio(
      id: portfolioID,
      name: "Roundtrip",
      monthlyBudget: Decimal(500),
      createdAt: referenceDate
    )
    let category = Category(
      id: categoryID,
      name: "Equities",
      weight: Decimal(1),
      sortOrder: 0,
      portfolio: portfolio
    )
    let ticker = Ticker(
      id: tickerID,
      symbol: "VTI",
      sortOrder: 0,
      category: category
    )
    let record = ContributionRecord(
      id: recordID,
      portfolioId: portfolioID,
      date: referenceDate,
      totalAmount: Decimal(500),
      portfolio: portfolio
    )
    let categoryContribution = CategoryContribution(
      id: categoryContributionID,
      categoryName: "Equities",
      amount: Decimal(500),
      allocatedWeight: Decimal(1),
      record: record
    )
    let tickerAllocation = TickerAllocation(
      id: tickerAllocationID,
      tickerSymbol: "VTI",
      categoryName: "Equities",
      amount: Decimal(500),
      allocatedWeight: Decimal(1),
      record: record
    )
    let holding = Holding(
      id: holdingID,
      portfolioId: portfolioID,
      symbol: "VTI",
      costBasis: Decimal(100),
      shares: Decimal(5),
      sortOrder: 0,
      createdAt: referenceDate
    )
    let tickerMetadata = TickerMetadata(
      symbol: "VTI",
      name: "Vanguard Total Stock Market",
      exchange: "NYSE",
      assetClass: .etf
    )
    let marketDataBar = MarketDataBar(
      symbol: "VTI",
      date: referenceDate,
      open: Decimal(string: "100.00")!,
      high: Decimal(string: "101.00")!,
      low: Decimal(string: "99.00")!,
      close: Decimal(string: "100.50")!,
      volume: 1_000,
      fetchedAt: referenceDate
    )
    let investSnapshot = InvestSnapshot(
      id: snapshotID,
      portfolioId: portfolioID,
      capturedAt: referenceDate,
      capitalAmount: Decimal(500),
      maWindow: 50,
      marketDataWindowStart: referenceDate,
      marketDataWindowEnd: referenceDate,
      compositionJSON: "[]",
      warningsJSON: "[]"
    )
    let appSettings = AppSettings(
      id: appSettingsID,
      themePreference: .system
    )

    coldContext.insert(portfolio)
    coldContext.insert(category)
    coldContext.insert(ticker)
    coldContext.insert(record)
    coldContext.insert(categoryContribution)
    coldContext.insert(tickerAllocation)
    coldContext.insert(holding)
    coldContext.insert(tickerMetadata)
    coldContext.insert(marketDataBar)
    coldContext.insert(investSnapshot)
    coldContext.insert(appSettings)
    try coldContext.save()

    // Warm reopen: same URL, same schema + migration plan. Confirms the v2
    // shape stored under the nested `LocalSchemaV2.*` class identities is
    // still readable on a subsequent process boot.
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

    XCTAssertEqual(try warmContext.fetch(FetchDescriptor<Portfolio>()).first?.id, portfolioID)
    XCTAssertEqual(
      try warmContext.fetch(FetchDescriptor<LocalSchemaV2.Category>()).first?.id, categoryID)
    XCTAssertEqual(try warmContext.fetch(FetchDescriptor<Ticker>()).first?.id, tickerID)
    XCTAssertEqual(
      try warmContext.fetch(FetchDescriptor<ContributionRecord>()).first?.id, recordID)
    XCTAssertEqual(
      try warmContext.fetch(FetchDescriptor<CategoryContribution>()).first?.id,
      categoryContributionID)
    XCTAssertEqual(
      try warmContext.fetch(FetchDescriptor<TickerAllocation>()).first?.id,
      tickerAllocationID)
    XCTAssertEqual(try warmContext.fetch(FetchDescriptor<Holding>()).first?.id, holdingID)
    XCTAssertEqual(
      try warmContext.fetch(FetchDescriptor<TickerMetadata>()).first?.symbol, "VTI")
    XCTAssertEqual(
      try warmContext.fetch(FetchDescriptor<MarketDataBar>()).first?.symbol, "VTI")
    XCTAssertEqual(
      try warmContext.fetch(FetchDescriptor<InvestSnapshot>()).first?.id, snapshotID)
    XCTAssertEqual(
      try warmContext.fetch(FetchDescriptor<AppSettings>()).first?.id, appSettingsID)
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

  // MARK: - Helpers

  /// Returns the SwiftData entity name for a `@Model` type. Nested types
  /// (e.g. `LocalSchemaV1.Portfolio`) report a dotted name from
  /// `String(describing:)` but SwiftData keys entities off the simple class
  /// name, so strip any enclosing namespace prefix.
  private func entityName(for type: any PersistentModel.Type) -> String {
    let described = String(describing: type)
    return described.split(separator: ".").last.map(String.init) ?? described
  }
}
