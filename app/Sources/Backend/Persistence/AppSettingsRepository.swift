import Foundation
import SwiftData

/// Loads (or seeds) the singleton `AppSettings` row. The MVP only ever has
/// zero or one `AppSettings` row, keyed by `AppSettings.singletonID`, so
/// reducers can call `loadOrSeed()` without coordinating who creates it.
struct AppSettingsRepository {
  let context: ModelContext

  /// Returns the singleton row, creating it with defaults if it doesn't
  /// exist yet. Saves only when a new row is seeded.
  func loadOrSeed() throws -> AppSettings {
    let id = AppSettings.singletonID
    let descriptor = FetchDescriptor<AppSettings>(
      predicate: #Predicate<AppSettings> { $0.id == id }
    )
    if let existing = try context.fetch(descriptor).first {
      return existing
    }
    let seeded = AppSettings()
    context.insert(seeded)
    try context.save()
    return seeded
  }

  /// Removes the singleton settings row. Used by the "full local reset"
  /// flow in #133. Does not save — the reset transaction owns the save.
  func deleteAll() throws {
    try context.delete(model: AppSettings.self)
  }
}
