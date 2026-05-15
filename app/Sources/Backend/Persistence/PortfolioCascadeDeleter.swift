import Foundation
import SwiftData

/// Performs the MVP "delete portfolio" semantics: explicitly removes every
/// `Holding` and `InvestSnapshot` row owned by the portfolio (matched by
/// `portfolioId` UUID), then deletes the `Portfolio` itself.
///
/// Per the schema contract in `MVPModels.swift`, MVP rows reference
/// `Portfolio` by id — *not* by SwiftData `@Relationship` — so SwiftData will
/// not cascade them on its own. This deleter centralizes the manual cascade
/// so feature reducers and the eventual full-reset flow (#133) only have one
/// well-tested path to call.
///
/// Categories and the legacy `ContributionRecord` rows continue to be
/// removed automatically by the existing `@Relationship(.cascade)`
/// declarations on `Portfolio`.
///
/// `MarketDataBar` rows are intentionally **not** deleted: shared market
/// data must outlive any single portfolio so subsequent calculations can
/// reuse already-fetched bars.
struct PortfolioCascadeDeleter {
  let context: ModelContext

  /// Delete every row owned by `portfolioID`, then the portfolio. Saves the
  /// context once, so callers see a single transaction either complete or
  /// throw.
  func delete(portfolioID: UUID) throws {
    let holdingDescriptor = FetchDescriptor<Holding>(
      predicate: #Predicate<Holding> { $0.portfolioId == portfolioID }
    )
    for holding in try context.fetch(holdingDescriptor) {
      context.delete(holding)
    }

    let snapshotDescriptor = FetchDescriptor<InvestSnapshot>(
      predicate: #Predicate<InvestSnapshot> { $0.portfolioId == portfolioID }
    )
    for snapshot in try context.fetch(snapshotDescriptor) {
      context.delete(snapshot)
    }

    let portfolioDescriptor = FetchDescriptor<Portfolio>(
      predicate: #Predicate<Portfolio> { $0.id == portfolioID }
    )
    if let portfolio = try context.fetch(portfolioDescriptor).first {
      context.delete(portfolio)
    }

    try context.save()
  }
}
