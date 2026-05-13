import Foundation
import SwiftData

enum PortfolioValidationError: Error, Equatable {
    case emptyName
    case nonPositiveMonthlyBudget
    case invalidMAWindow(Int)
    case duplicateTickerSymbols([String])
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
    @Relationship(deleteRule: .cascade, inverse: \ContributionRecord.portfolio) var contributionRecords: [ContributionRecord]

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
    var sortOrder: Int
    var category: Category?

    init(
        id: UUID = UUID(),
        symbol: String,
        currentPrice: Decimal? = nil,
        movingAverage: Decimal? = nil,
        sortOrder: Int,
        category: Category? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.currentPrice = currentPrice
        self.movingAverage = movingAverage
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
    @Relationship(deleteRule: .cascade, inverse: \CategoryContribution.record) var categoryBreakdown: [CategoryContribution]
    @Relationship(deleteRule: .cascade, inverse: \TickerAllocation.record) var tickerAllocations: [TickerAllocation]

    init(
        id: UUID = UUID(),
        portfolioId: UUID,
        date: Date = Date(),
        totalAmount: Decimal,
        portfolio: Portfolio? = nil,
        categoryBreakdown: [CategoryContribution] = [],
        tickerAllocations: [TickerAllocation] = [],
        breakdown: [TickerAllocation] = []
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.date = date
        self.totalAmount = totalAmount
        self.portfolio = portfolio
        self.categoryBreakdown = categoryBreakdown
        self.tickerAllocations = tickerAllocations.isEmpty ? breakdown : tickerAllocations
    }
}

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
