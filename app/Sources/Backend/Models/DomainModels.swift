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

@Model
final class ContributionRecord {
  @Attribute(.unique) var id: UUID
  var portfolioId: UUID
  var date: Date
  var totalAmount: Decimal
  var portfolio: Portfolio?
  @Relationship(deleteRule: .cascade, inverse: \CategoryContribution.record) var categoryBreakdown:
    [CategoryContribution]
  @Relationship(deleteRule: .cascade, inverse: \TickerAllocation.record) var tickerAllocations:
    [TickerAllocation]

  /// Designated initializer for an append-only `ContributionRecord` snapshot row.
  ///
  /// `tickerAllocations:` is the canonical parameter for the per-ticker
  /// breakdown stored on this record. A legacy `breakdown:` spelling is
  /// preserved as a deprecated convenience overload below; it forwards into
  /// `tickerAllocations:` and exists solely so in-flight call sites compile
  /// while they migrate. New call sites must use `tickerAllocations:`.
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
    renamed: "init(id:portfolioId:date:totalAmount:portfolio:categoryBreakdown:tickerAllocations:)",
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
/// Identity contract: every row carries a stable `@Attribute(.unique) var id: UUID`
/// to match the convention used by `Portfolio`, `Category`, `Ticker`, and
/// `ContributionRecord`. The id is the persisted business key — it survives
/// `.json` export, store rebuilds, and the future CloudKit sync path; the
/// SwiftData-synthesized `PersistentIdentifier` is not stable across any of
/// those (issue #249). The default `UUID()` initializer keeps construction
/// backward compatible for existing call sites that did not specify an id.
@Model
final class CategoryContribution {
  @Attribute(.unique) var id: UUID
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
/// above for the rationale (issue #249).
@Model
final class TickerAllocation {
  @Attribute(.unique) var id: UUID
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
