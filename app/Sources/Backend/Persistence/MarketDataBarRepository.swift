import Foundation
import SwiftData

/// Narrow persistence seam for shared end-of-day market data.
///
/// The repository exposes only what the Massive client (#128) and Invest
/// calculation (#130) need today: bulk upsert by `(symbol, date)`, range
/// fetch, latest-bar lookup, and full purge for the "reset all data" flow
/// (#133).
///
/// Bars are unique by `MarketDataBar.id` — the canonical
/// `"<SYMBOL>|<yyyy-MM-dd-UTC>"` identifier produced by `MarketDataBar.makeID`.
/// `upsert` matches incoming rows on that id and mutates them in place if
/// they already exist, so the Massive client can re-emit the same date
/// without duplicating rows or losing referential identity.
struct MarketDataBarRepository {
  let context: ModelContext

  /// Upsert one or more bars. Existing bars are mutated in place; new bars
  /// are inserted. Caller decides when to `save`, so a wrapping refresh
  /// transaction can batch many upserts.
  func upsert(_ bars: [MarketDataBar]) throws {
    guard !bars.isEmpty else { return }
    let ids = bars.map(\.id)
    let descriptor = FetchDescriptor<MarketDataBar>(
      predicate: #Predicate<MarketDataBar> { ids.contains($0.id) }
    )
    let existing = try context.fetch(descriptor)
    let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

    for bar in bars {
      if let row = existingByID[bar.id] {
        row.symbol = bar.symbol
        row.date = bar.date
        row.open = bar.open
        row.high = bar.high
        row.low = bar.low
        row.close = bar.close
        row.volume = bar.volume
        row.fetchedAt = bar.fetchedAt
      } else {
        context.insert(bar)
      }
    }
  }

  /// All bars for a symbol, ascending by date.
  func bars(for symbol: String) throws -> [MarketDataBar] {
    let normalized = MarketDataBar.normalize(symbol: symbol)
    let descriptor = FetchDescriptor<MarketDataBar>(
      predicate: #Predicate<MarketDataBar> { $0.symbol == normalized },
      sortBy: [SortDescriptor(\.date, order: .forward)]
    )
    return try context.fetch(descriptor)
  }

  /// Latest bar (by `date`) for a symbol, if any.
  func latestBar(for symbol: String) throws -> MarketDataBar? {
    let normalized = MarketDataBar.normalize(symbol: symbol)
    var descriptor = FetchDescriptor<MarketDataBar>(
      predicate: #Predicate<MarketDataBar> { $0.symbol == normalized },
      sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  /// Removes every market-data bar. Used by the "full local reset" flow in
  /// #133. Does not save — wrap in the same transaction as the rest of the
  /// reset so partial state can never reach disk.
  func deleteAll() throws {
    try context.delete(model: MarketDataBar.self)
  }
}
