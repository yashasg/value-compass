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

  static func makeModelContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
    let configuration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: isStoredInMemoryOnly
    )
    return try ModelContainer(for: schema, configurations: [configuration])
  }
}
