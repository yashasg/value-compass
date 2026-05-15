import Foundation
import SwiftData

// Frozen V2 baseline for every `@Model` type that shipped in the
// `LocalSchemaV2` on-disk schema (issue #337 frozen-snapshot invariant
// applied to the V2→V3 bump introduced for issue #356). These nested
// classes are intentionally separate from the live app-facing classes
// (which now back ``LocalSchemaV3``) so future edits to the live shape
// cannot retroactively mutate the V2 schema. The app never instantiates
// these types directly.
//
// **Where V2-typed rows are reachable.** SwiftData only exposes the
// source schema's types to the `willMigrate` callback of a
// `MigrationStage.custom(fromVersion: LocalSchemaV2.self, …)`. The
// current ``LocalSchemaMigrationPlan/migrateV2toV3`` stage is
// `.lightweight(…)` because the V2 → V3 delta is additive — every new
// column on V3 entities is `Decimal?` defaulting to `nil`, which
// SwiftData's lightweight bridge handles automatically. Future custom
// stages targeting V2 must read V2-typed rows from `willMigrate`; the
// same fetches from `didMigrate` would resolve against the V3 entity
// graph instead.
//
// **V2 → V3 delta.** ``LocalSchemaV3/Holding`` adds eight optional
// indicator columns matching the wire shape of
// `Components.Schemas.HoldingOut` — `currentPrice`, `sma50`, `sma200`,
// `midline`, `atr`, `upperBand`, `lowerBand`, and `bandPosition`. Every
// other entity is bit-identical to its ``LocalSchemaV2`` counterpart.
//
// **What is intentionally omitted.** The V2 baseline declares only the
// persisted schema surface: stored properties, `@Attribute` modifiers,
// and `@Relationship` declarations. App-level behaviour — validation
// helpers, the snapshot convenience initializer, the
// `portfolioId ↔ portfolio.id` precondition (issue #250), the
// deprecated `breakdown:` overload — lives on the V3 types because it
// represents *current* app contracts, not the historical on-disk
// shape. Future migrations only need the schema surface to read v2
// stores correctly; the behaviour layers above are V3's concern.
extension LocalSchemaV2 {

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

  /// V2 baseline for the per-category breakdown row. The
  /// `@Attribute(.unique) var id: UUID = UUID()` column (issue #249)
  /// is the entire V1 → V2 delta on this entity; the live V3 shape
  /// lives at ``LocalSchemaV3/CategoryContribution``.
  @Model
  final class CategoryContribution {
    @Attribute(.unique) var id: UUID = UUID()
    var categoryName: String
    var amount: Decimal
    var allocatedWeight: Decimal
    var record: ContributionRecord?

    init(
      id: UUID = UUID(),
      categoryName: String,
      amount: Decimal,
      allocatedWeight: Decimal,
      record: ContributionRecord? = nil
    ) {
      self.id = id
      self.categoryName = categoryName
      self.amount = amount
      self.allocatedWeight = allocatedWeight
      self.record = record
    }
  }

  /// V2 baseline for the per-ticker allocation row. Identity contract
  /// matches V2.CategoryContribution — the `id: UUID` column added in
  /// V2 (issues #249, #298) lives here; the live V3 shape lives at
  /// ``LocalSchemaV3/TickerAllocation``.
  @Model
  final class TickerAllocation {
    @Attribute(.unique) var id: UUID = UUID()
    var tickerSymbol: String
    var categoryName: String
    var amount: Decimal
    var allocatedWeight: Decimal
    var record: ContributionRecord?

    init(
      id: UUID = UUID(),
      tickerSymbol: String,
      categoryName: String,
      amount: Decimal,
      allocatedWeight: Decimal = 0,
      record: ContributionRecord? = nil
    ) {
      self.id = id
      self.tickerSymbol = tickerSymbol
      self.categoryName = categoryName
      self.amount = amount
      self.allocatedWeight = allocatedWeight
      self.record = record
    }
  }

  /// V2 baseline for the MVP `Holding` shape (additive issue #219).
  /// **Intentionally omits** the eight indicator columns
  /// (`currentPrice`, `sma50`, `sma200`, `midline`, `atr`, `upperBand`,
  /// `lowerBand`, `bandPosition`) — those columns are the entire
  /// V2 → V3 delta on this entity (issue #356). The live V3 shape
  /// lives at ``LocalSchemaV3/Holding``.
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
