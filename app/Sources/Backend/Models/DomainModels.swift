import Foundation
import SwiftData

enum PortfolioValidationError: Error, Equatable {
  case emptyName
  case nonPositiveMonthlyBudget
  case invalidMAWindow(Int)
  case duplicateTickerSymbols([String])
}

enum ContributionRecordSnapshotError: LocalizedError, Equatable {
  case failedCalculation(String)

  var errorDescription: String? {
    switch self {
    case .failedCalculation(let message):
      return "Cannot save a failed calculation: \(message)"
    }
  }
}

// The `@Model` types below are nested inside ``LocalSchemaV3`` so the live
// app-facing classes are the v3 frozen snapshot — ``LocalSchemaV1`` and
// ``LocalSchemaV2`` cannot be retroactively mutated by edits here (issues
// #337 and #356). Module-scope `typealias` declarations in
// `LocalSchemaVersions.swift` keep call sites referring to `Portfolio`,
// `Category`, … without a `LocalSchemaV3.` prefix.
extension LocalSchemaV3 {

  @Model
  final class Portfolio {
    static let allowedMAWindows = [50, 200]

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

    func totalCategoryWeight() -> Decimal {
      categories.reduce(0) { $0 + $1.weight }
    }

    func duplicateTickerSymbols() -> [String] {
      var seen = Set<String>()
      var duplicates = Set<String>()

      for symbol in categories.flatMap(\.tickers).map(\.normalizedSymbol) where !symbol.isEmpty {
        if !seen.insert(symbol).inserted {
          duplicates.insert(symbol)
        }
      }

      return duplicates.sorted()
    }

    func validationErrors() -> [PortfolioValidationError] {
      var errors: [PortfolioValidationError] = []

      if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        errors.append(.emptyName)
      }

      if monthlyBudget <= 0 {
        errors.append(.nonPositiveMonthlyBudget)
      }

      if !Self.allowedMAWindows.contains(maWindow) {
        errors.append(.invalidMAWindow(maWindow))
      }

      let duplicateSymbols = duplicateTickerSymbols()
      if !duplicateSymbols.isEmpty {
        errors.append(.duplicateTickerSymbols(duplicateSymbols))
      }

      return errors
    }

    func isValid() -> Bool {
      validationErrors().isEmpty
    }

    func validate() throws {
      if let firstError = validationErrors().first {
        throw firstError
      }
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

    var parentPortfolio: Portfolio? {
      get { portfolio }
      set { portfolio = newValue }
    }

    func tickerCount() -> Int {
      tickers.count
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

    var parentCategory: Category? {
      get { category }
      set { category = newValue }
    }

    var normalizedSymbol: String {
      symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
  }

  /// Append-only contribution snapshot for a single calculation result.
  ///
  /// **Invariant: `portfolioId == portfolio?.id` whenever `portfolio` is non-nil.**
  /// `portfolioId` is the persisted denormalization of the parent's primary
  /// key — it is what the future CloudKit/sync wire format keys off, and it is
  /// what survives when the `portfolio` relationship faults out on a background
  /// `ModelActor`. The SwiftData `portfolio` relationship is the live, cascade-
  /// authoritative reference. When both are supplied at construction time they
  /// must agree; this is enforced by a `precondition` in the designated init so
  /// the mismatch surfaces at insert time instead of corrupting reads against a
  /// hydrated-then-faulted relationship later (issue #250). Sync/migration
  /// fixtures that only know the parent UUID may still pass `portfolio: nil`;
  /// the production path through `init(snapshotFor:output:date:)` always wires
  /// both with the relationship's identity as the source of truth.
  ///
  /// Cascade contract: `Portfolio.contributionRecords` declares
  /// `@Relationship(deleteRule: .cascade, inverse: \ContributionRecord.portfolio)`.
  /// SwiftData cascades on the relationship, not on `portfolioId`. Because the
  /// invariant pins the scalar to the relationship's id, a deleted parent's
  /// rows cannot become orphans whose `portfolioId` references a row that no
  /// longer exists in the store.
  @Model
  final class ContributionRecord {
    @Attribute(.unique) var id: UUID
    /// Persisted denormalization of `portfolio?.id`. See the type-level
    /// invariant — this scalar must equal `portfolio.id` whenever `portfolio`
    /// is non-nil at construction time.
    var portfolioId: UUID
    var date: Date
    var totalAmount: Decimal
    var portfolio: Portfolio?
    @Relationship(deleteRule: .cascade, inverse: \CategoryContribution.record)
    var categoryBreakdown: [CategoryContribution]
    @Relationship(deleteRule: .cascade, inverse: \TickerAllocation.record)
    var tickerAllocations: [TickerAllocation]

    /// Designated initializer for an append-only `ContributionRecord` snapshot row.
    ///
    /// `tickerAllocations:` is the canonical parameter for the per-ticker
    /// breakdown stored on this record. A legacy `breakdown:` spelling is
    /// preserved as a deprecated convenience overload below; it forwards into
    /// `tickerAllocations:` and exists solely so in-flight call sites compile
    /// while they migrate. New call sites must use `tickerAllocations:`.
    ///
    /// - Precondition: when `portfolio` is non-nil, `portfolioId` must equal
    ///   `portfolio.id`. Mismatched arguments are a programmer error (the
    ///   denormalized scalar is meant to be derived from the relationship, not
    ///   to disagree with it) and are caught here so the inconsistency cannot
    ///   reach `ModelContext.insert(_:)` and silently corrupt cascade-delete
    ///   semantics. Sync/migration fixtures that have only the parent UUID
    ///   should pass `portfolio: nil` — they are free to set the relationship
    ///   later via `portfolio.contributionRecords.append(record)` once the
    ///   `Portfolio` is hydrated.
    init(
      id: UUID = UUID(),
      portfolioId: UUID,
      date: Date = Date(),
      totalAmount: Decimal,
      portfolio: Portfolio? = nil,
      categoryBreakdown: [CategoryContribution] = [],
      tickerAllocations: [TickerAllocation] = []
    ) {
      if let portfolio {
        precondition(
          portfolio.id == portfolioId,
          """
          ContributionRecord invariant violated: portfolioId (\(portfolioId)) \
          must equal portfolio.id (\(portfolio.id)) when both are supplied. \
          portfolioId is the persisted denormalization of the relationship's \
          primary key (issue #250) — derive it from `portfolio.id` instead of \
          passing it independently.
          """
        )
      }
      self.id = id
      self.portfolioId = portfolioId
      self.date = date
      self.totalAmount = totalAmount
      self.portfolio = portfolio
      self.categoryBreakdown = categoryBreakdown
      self.tickerAllocations = tickerAllocations
    }

    /// Legacy convenience initializer that accepts the per-ticker breakdown under
    /// the historical `breakdown:` argument label. Forwards verbatim into the
    /// designated initializer's `tickerAllocations:` parameter; scheduled for
    /// removal in the next SwiftData schema bump (see #244 for the migration).
    ///
    /// Splitting the legacy spelling into its own deprecated overload removes the
    /// silent precedence behavior of the prior dual-init (where the contract was
    /// undefined when both arrays were non-empty) by making it structurally
    /// impossible to supply both `tickerAllocations:` and `breakdown:` in the
    /// same call.
    @available(
      *, deprecated,
      renamed:
        "init(id:portfolioId:date:totalAmount:portfolio:categoryBreakdown:tickerAllocations:)",
      message: "Use 'tickerAllocations:'; the 'breakdown:' alias is removed in the next schema."
    )
    convenience init(
      id: UUID = UUID(),
      portfolioId: UUID,
      date: Date = Date(),
      totalAmount: Decimal,
      portfolio: Portfolio? = nil,
      categoryBreakdown: [CategoryContribution] = [],
      breakdown: [TickerAllocation]
    ) {
      self.init(
        id: id,
        portfolioId: portfolioId,
        date: date,
        totalAmount: totalAmount,
        portfolio: portfolio,
        categoryBreakdown: categoryBreakdown,
        tickerAllocations: breakdown
      )
    }

    convenience init(
      snapshotFor portfolio: Portfolio,
      output: ContributionOutput,
      date: Date = Date()
    ) throws {
      if let error = output.error {
        throw ContributionRecordSnapshotError.failedCalculation(error.localizedDescription)
      }

      self.init(
        portfolioId: portfolio.id,
        date: date,
        totalAmount: output.totalAmount,
        portfolio: portfolio,
        categoryBreakdown: output.categoryBreakdown.map {
          CategoryContribution(
            categoryName: $0.categoryName,
            amount: $0.amount,
            allocatedWeight: $0.allocatedWeight
          )
        },
        tickerAllocations: output.allocations.map {
          TickerAllocation(
            tickerSymbol: $0.tickerSymbol,
            categoryName: $0.categoryName,
            amount: $0.amount,
            allocatedWeight: $0.allocatedWeight
          )
        }
      )
    }
  }

  /// Per-category breakdown row attached to a `ContributionRecord` snapshot.
  ///
  /// Identity contract: every row carries a stable
  /// `@Attribute(.unique) var id: UUID = UUID()` to match the convention used by
  /// `Portfolio`, `Category`, `Ticker`, and `ContributionRecord`. The id is the
  /// persisted business key — it survives `.json` export, store rebuilds, and
  /// the future CloudKit sync path; the SwiftData-synthesized
  /// `PersistentIdentifier` is not stable across any of those (issue #249).
  /// The inline `= UUID()` default is required so SwiftData's lightweight
  /// migration pass can backfill a fresh value per existing row when an older
  /// store that pre-dates this column is opened under the v2 schema; without
  /// it the schema bridge would fail before the v1→v2 `didMigrate` block ever
  /// ran (issue #298). The matching initializer default keeps construction
  /// backward compatible for existing call sites that did not specify an id.
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

  /// Per-ticker allocation row attached to a `ContributionRecord` snapshot.
  ///
  /// Identity contract matches `CategoryContribution` — see the doc comment
  /// above for the rationale (issues #249, #298). The inline `= UUID()`
  /// default on `id` is what lets SwiftData's lightweight migration bridge
  /// backfill existing v1 rows when the store is reopened under v2.
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
}
