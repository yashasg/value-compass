import Foundation

struct BackendPortfolioSyncPayload: Equatable {
    let portfolio: BackendPortfolioPayload
    let holdings: [BackendHoldingPayload]
}

struct BackendPortfolioPayload: Equatable {
    let id: UUID
    let deviceUUID: UUID
    let name: String
    let monthlyBudget: Decimal
    let maWindow: Int
    let createdAt: Date
}

struct BackendHoldingPayload: Equatable {
    let portfolioID: UUID
    let ticker: String
    let weight: Decimal
}

enum BackendSyncProjectionError: Error, Equatable {
    case duplicateTickerSymbols([String])
    case emptyCategory(categoryName: String)
    case emptyTickerSymbol
    case invalidHoldingWeight(ticker: String, weight: Decimal)
    case invalidMAWindow(Int)
    case nonPositiveBudget
}

/// Maps the richer SwiftData model to the flat v1 backend schema described in
/// docs/db-tech-spec.md and docs/services-tech-spec.md.
enum BackendSyncProjection {
    static func makePayload(
        for portfolio: Portfolio,
        deviceUUID: UUID
    ) throws -> BackendPortfolioSyncPayload {
        guard portfolio.monthlyBudget > 0 else {
            throw BackendSyncProjectionError.nonPositiveBudget
        }

        guard [50, 200].contains(portfolio.maWindow) else {
            throw BackendSyncProjectionError.invalidMAWindow(portfolio.maWindow)
        }

        let categories = portfolio.categories.sorted {
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            if $0.name != $1.name {
                return $0.name < $1.name
            }
            return $0.id.uuidString < $1.id.uuidString
        }

        let duplicateSymbols = portfolio.duplicateTickerSymbols()
        if !duplicateSymbols.isEmpty {
            throw BackendSyncProjectionError.duplicateTickerSymbols(duplicateSymbols)
        }

        let holdings = try categories.flatMap { category in
            let tickers = category.tickers.sorted {
                if $0.sortOrder != $1.sortOrder {
                    return $0.sortOrder < $1.sortOrder
                }
                if $0.symbol != $1.symbol {
                    return $0.symbol < $1.symbol
                }
                return $0.id.uuidString < $1.id.uuidString
            }

            guard !tickers.isEmpty else {
                if category.weight == 0 {
                    return [BackendHoldingPayload]()
                }
                throw BackendSyncProjectionError.emptyCategory(categoryName: category.name)
            }

            let normalizedSymbols = tickers.map(\.normalizedSymbol)
            for normalizedSymbol in normalizedSymbols {
                guard !normalizedSymbol.isEmpty else {
                    throw BackendSyncProjectionError.emptyTickerSymbol
                }
            }

            let holdingWeight = category.weight / Decimal(tickers.count)
            guard isBackendHoldingWeight(holdingWeight) else {
                throw BackendSyncProjectionError.invalidHoldingWeight(ticker: normalizedSymbols[0], weight: holdingWeight)
            }

            return normalizedSymbols.map { normalizedSymbol in
                return BackendHoldingPayload(
                    portfolioID: portfolio.id,
                    ticker: normalizedSymbol,
                    weight: holdingWeight
                )
            }
        }

        return BackendPortfolioSyncPayload(
            portfolio: BackendPortfolioPayload(
                id: portfolio.id,
                deviceUUID: deviceUUID,
                name: portfolio.name,
                monthlyBudget: portfolio.monthlyBudget,
                maWindow: portfolio.maWindow,
                createdAt: portfolio.createdAt
            ),
            holdings: holdings
        )
    }

    private static func isBackendHoldingWeight(_ weight: Decimal) -> Bool {
        NSDecimalNumber(decimal: weight) != .notANumber && weight >= 0 && weight <= 1
    }
}
