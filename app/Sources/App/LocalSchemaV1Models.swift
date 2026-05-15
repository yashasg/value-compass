import Foundation
import SwiftData

// Frozen V1 baseline for every `@Model` type that shipped in the
// `LocalSchemaV1` on-disk schema (issue #337). These nested classes are
// intentionally separate from the live app-facing classes (which back
// ``LocalSchemaV2``) so future edits to the live shape cannot retroactively
// mutate the V1 schema. The app never instantiates these types directly.
//
// **Where V1-typed rows are reachable.** SwiftData only exposes the source
// schema's types to the `willMigrate` callback of a
// `MigrationStage.custom(fromVersion: LocalSchemaV1.self, …)`. The current
// `LocalSchemaMigrationPlan.migrateV1toV2` stage runs in `didMigrate`, which
// already sees the *destination* (V2) schema and fetches via the
// `Portfolio`/`CategoryContribution`/… typealiases (resolved to
// `LocalSchemaV2.*`). Future migration stages that need to read the v1 on-disk
// shape — for example to rewrite a column before SwiftData's lightweight
// bridge runs — must do so from `willMigrate` and fetch
// `LocalSchemaV1.<Type>` directly; the same fetches from `didMigrate` would
// resolve against the v2 entity graph instead.
//
// **V1 → V2 delta.** ``LocalSchemaV1/CategoryContribution`` and
// ``LocalSchemaV1/TickerAllocation`` *do not* declare an `id` column — that
// `@Attribute(.unique) var id: UUID` was added in V2 to give each
// contribution-breakdown row a stable business key (issues #249 and #298).
// Every other entity is bit-identical to its ``LocalSchemaV2`` counterpart.
//
// **What is intentionally omitted.** The V1 baseline declares only the
// persisted schema surface: stored properties, `@Attribute` modifiers, and
// `@Relationship` declarations. App-level behaviour — validation helpers,
// snapshot convenience initializers, the `portfolioId ↔ portfolio.id`
// precondition (issue #250), the deprecated `breakdown:` overload — lives on
// the V2 types because it represents *current* app contracts, not the
// historical on-disk shape. Future migrations only need the schema surface
// to read v1 stores correctly; the behavior layers above are V2's concern.
extension LocalSchemaV1 {

  @Model
  final class Portfolio {
    @Attribute(.unique) var id: UUID
    var name: String
    var monthlyBudget: Decimal
    var maWindow: Int
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Category.portfolio) var categories: [Category]
    @Relationship(deleteRule: .cascade, inverse: \ContributionRecord.portfolio)
    var contributionRecords: [ContributionRecord]

    init(
      id: UUID = UUID(),
      name: String,
      monthlyBudget: Decimal,
      maWindow: Int = 50,
      createdAt: Date = Date(),
      categories: [Category] = [],
      contributionRecords: [ContributionRecord] = []
    ) {
      self.id = id
      self.name = name
      self.monthlyBudget = monthlyBudget
      self.maWindow = maWindow
      self.createdAt = createdAt
      self.categories = categories
      self.contributionRecords = contributionRecords
    }
  }

  @Model
  final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var weight: Decimal
    var sortOrder: Int
    var portfolio: Portfolio?
    @Relationship(deleteRule: .cascade, inverse: \Ticker.category) var tickers: [Ticker]

    init(
      id: UUID = UUID(),
      name: String,
      weight: Decimal,
      sortOrder: Int,
      portfolio: Portfolio? = nil,
      tickers: [Ticker] = []
    ) {
      self.id = id
      self.name = name
      self.weight = weight
      self.sortOrder = sortOrder
      self.portfolio = portfolio
      self.tickers = tickers
    }
  }

  @Model
  final class Ticker {
    @Attribute(.unique) var id: UUID
    var symbol: String
    var currentPrice: Decimal?
    var movingAverage: Decimal?
    var bandPosition: Decimal?
    var sortOrder: Int
    var category: Category?

    init(
      id: UUID = UUID(),
      symbol: String,
      currentPrice: Decimal? = nil,
      movingAverage: Decimal? = nil,
      bandPosition: Decimal? = nil,
      sortOrder: Int,
      category: Category? = nil
    ) {
      self.id = id
      self.symbol = symbol
      self.currentPrice = currentPrice
      self.movingAverage = movingAverage
      self.bandPosition = bandPosition
      self.sortOrder = sortOrder
      self.category = category
    }
  }

  @Model
  final class ContributionRecord {
    @Attribute(.unique) var id: UUID
    var portfolioId: UUID
    var date: Date
    var totalAmount: Decimal
    var portfolio: Portfolio?
    @Relationship(deleteRule: .cascade, inverse: \CategoryContribution.record)
    var categoryBreakdown: [CategoryContribution]
    @Relationship(deleteRule: .cascade, inverse: \TickerAllocation.record)
    var tickerAllocations: [TickerAllocation]

    init(
      id: UUID = UUID(),
      portfolioId: UUID,
      date: Date = Date(),
      totalAmount: Decimal,
      portfolio: Portfolio? = nil,
      categoryBreakdown: [CategoryContribution] = [],
      tickerAllocations: [TickerAllocation] = []
    ) {
      self.id = id
      self.portfolioId = portfolioId
      self.date = date
      self.totalAmount = totalAmount
      self.portfolio = portfolio
      self.categoryBreakdown = categoryBreakdown
      self.tickerAllocations = tickerAllocations
    }
  }

  /// V1 baseline for the per-category breakdown row. **Intentionally omits**
  /// the `@Attribute(.unique) var id: UUID` column — that field was introduced
  /// in V2 (issues #249, #298) and is the entire V1 → V2 delta on this entity.
  /// The live V2 shape lives at ``LocalSchemaV2/CategoryContribution``.
  @Model
  final class CategoryContribution {
    var categoryName: String
    var amount: Decimal
    var allocatedWeight: Decimal
    var record: ContributionRecord?

    init(
      categoryName: String,
      amount: Decimal,
      allocatedWeight: Decimal,
      record: ContributionRecord? = nil
    ) {
      self.categoryName = categoryName
      self.amount = amount
      self.allocatedWeight = allocatedWeight
      self.record = record
    }
  }

  /// V1 baseline for the per-ticker allocation row. **Intentionally omits**
  /// the `@Attribute(.unique) var id: UUID` column — that field was introduced
  /// in V2 (issues #249, #298) and is the entire V1 → V2 delta on this entity.
  /// The live V2 shape lives at ``LocalSchemaV2/TickerAllocation``.
  @Model
  final class TickerAllocation {
    var tickerSymbol: String
    var categoryName: String
    var amount: Decimal
    var allocatedWeight: Decimal
    var record: ContributionRecord?

    init(
      tickerSymbol: String,
      categoryName: String,
      amount: Decimal,
      allocatedWeight: Decimal = 0,
      record: ContributionRecord? = nil
    ) {
      self.tickerSymbol = tickerSymbol
      self.categoryName = categoryName
      self.amount = amount
      self.allocatedWeight = allocatedWeight
      self.record = record
    }
  }

  @Model
  final class Holding {
    @Attribute(.unique) var id: UUID
    var portfolioId: UUID
    var symbol: String
    var costBasis: Decimal
    var shares: Decimal
    var sortOrder: Int
    var createdAt: Date

    init(
      id: UUID = UUID(),
      portfolioId: UUID,
      symbol: String,
      costBasis: Decimal = 0,
      shares: Decimal = 0,
      sortOrder: Int = 0,
      createdAt: Date = Date()
    ) {
      self.id = id
      self.portfolioId = portfolioId
      self.symbol = symbol
      self.costBasis = costBasis
      self.shares = shares
      self.sortOrder = sortOrder
      self.createdAt = createdAt
    }
  }

  @Model
  final class TickerMetadata {
    @Attribute(.unique) var symbol: String
    var name: String
    var exchange: String
    var assetClass: String
    var isActive: Bool

    init(
      symbol: String,
      name: String,
      exchange: String,
      assetClass: String,
      isActive: Bool = true
    ) {
      self.symbol = symbol
      self.name = name
      self.exchange = exchange
      self.assetClass = assetClass
      self.isActive = isActive
    }
  }

  @Model
  final class MarketDataBar {
    @Attribute(.unique) var id: String
    var symbol: String
    var date: Date
    var open: Decimal
    var high: Decimal
    var low: Decimal
    var close: Decimal
    var volume: Int
    var fetchedAt: Date

    init(
      id: String,
      symbol: String,
      date: Date,
      open: Decimal,
      high: Decimal,
      low: Decimal,
      close: Decimal,
      volume: Int = 0,
      fetchedAt: Date = Date()
    ) {
      self.id = id
      self.symbol = symbol
      self.date = date
      self.open = open
      self.high = high
      self.low = low
      self.close = close
      self.volume = volume
      self.fetchedAt = fetchedAt
    }
  }

  @Model
  final class InvestSnapshot {
    @Attribute(.unique) var id: UUID
    var portfolioId: UUID
    var capturedAt: Date
    var capitalAmount: Decimal
    var maWindow: Int
    var marketDataWindowStart: Date
    var marketDataWindowEnd: Date
    var compositionJSON: String
    var warningsJSON: String

    init(
      id: UUID = UUID(),
      portfolioId: UUID,
      capturedAt: Date = Date(),
      capitalAmount: Decimal,
      maWindow: Int,
      marketDataWindowStart: Date,
      marketDataWindowEnd: Date,
      compositionJSON: String,
      warningsJSON: String = "[]"
    ) {
      self.id = id
      self.portfolioId = portfolioId
      self.capturedAt = capturedAt
      self.capitalAmount = capitalAmount
      self.maWindow = maWindow
      self.marketDataWindowStart = marketDataWindowStart
      self.marketDataWindowEnd = marketDataWindowEnd
      self.compositionJSON = compositionJSON
      self.warningsJSON = warningsJSON
    }
  }

  @Model
  final class AppSettings {
    @Attribute(.unique) var id: UUID
    var themePreference: String
    var backgroundRefreshEnabled: Bool
    var notificationsOptIn: Bool
    var hasAcceptedDisclaimer: Bool

    init(
      id: UUID,
      themePreference: String,
      backgroundRefreshEnabled: Bool = false,
      notificationsOptIn: Bool = false,
      hasAcceptedDisclaimer: Bool = false
    ) {
      self.id = id
      self.themePreference = themePreference
      self.backgroundRefreshEnabled = backgroundRefreshEnabled
      self.notificationsOptIn = notificationsOptIn
      self.hasAcceptedDisclaimer = hasAcceptedDisclaimer
    }
  }
}
