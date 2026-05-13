import Foundation
import SwiftData

@Model
final class Portfolio {
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
}

@Model
final class ContributionRecord {
    @Attribute(.unique) var id: UUID
    var portfolioId: UUID
    var date: Date
    var totalAmount: Decimal
    var portfolio: Portfolio?
    @Relationship(deleteRule: .cascade, inverse: \TickerAllocation.record) var breakdown: [TickerAllocation]

    init(
        id: UUID = UUID(),
        portfolioId: UUID,
        date: Date = Date(),
        totalAmount: Decimal,
        portfolio: Portfolio? = nil,
        breakdown: [TickerAllocation] = []
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.date = date
        self.totalAmount = totalAmount
        self.portfolio = portfolio
        self.breakdown = breakdown
    }
}

@Model
final class TickerAllocation {
    var tickerSymbol: String
    var categoryName: String
    var amount: Decimal
    var record: ContributionRecord?

    init(
        tickerSymbol: String,
        categoryName: String,
        amount: Decimal,
        record: ContributionRecord? = nil
    ) {
        self.tickerSymbol = tickerSymbol
        self.categoryName = categoryName
        self.amount = amount
        self.record = record
    }
}
