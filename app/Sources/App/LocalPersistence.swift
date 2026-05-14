import ConcurrencyExtras
import SwiftData

enum LocalPersistence {
  static var schema: Schema {
    Schema([
      Portfolio.self,
      Category.self,
      Ticker.self,
      ContributionRecord.self,
      CategoryContribution.self,
      TickerAllocation.self,
    ])
  }

  /// Process-wide cache for the disk-backed `ModelContainer`. `VCAApp`
  /// installs the container into the SwiftUI environment so reducer-driven
  /// views can resolve `@Environment(\.modelContext)` if they ever need to,
  /// and `ModelContainerClient.liveValue` (used by TCA reducer effects on
  /// `BackgroundModelActor`) hands the same container to every actor.
  /// Sharing one instance keeps writes from any background actor immediately
  /// visible to subsequent fetches on the main context. In-memory containers
  /// (used by tests) intentionally bypass the cache.
  private static let sharedDiskContainer = LockIsolated<ModelContainer?>(nil)

  static func makeModelContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
    if isStoredInMemoryOnly {
      return try makeUncachedContainer(isStoredInMemoryOnly: true)
    }

    return try sharedDiskContainer.withValue { cached in
      if let cached {
        return cached
      }
      let made = try makeUncachedContainer(isStoredInMemoryOnly: false)
      cached = made
      return made
    }
  }

  private static func makeUncachedContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
    let configuration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: isStoredInMemoryOnly
    )
    return try ModelContainer(for: schema, configurations: [configuration])
  }
}
