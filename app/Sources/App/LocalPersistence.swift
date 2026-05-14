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

  /// Process-wide cache for the disk-backed `ModelContainer`. Both
  /// `VCAApp` (for SwiftUI's `@Environment(\.modelContext)`) and
  /// `ModelContainerClient.liveValue` (for TCA reducer effects) call into
  /// `makeModelContainer()`; sharing a single instance keeps writes from
  /// reducer effects immediately visible to SwiftData-fetch-backed views.
  /// In-memory containers (used by tests) intentionally bypass the cache.
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
