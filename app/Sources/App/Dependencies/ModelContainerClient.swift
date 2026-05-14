import ComposableArchitecture
import Foundation
import SwiftData

/// `@DependencyClient` wrapper around `LocalPersistence.makeModelContainer()`.
///
/// Reducers consume this via `@Dependency(\.modelContainer)`:
///
/// - Use `mainContext()` from a `@MainActor` context (e.g. inside a
///   `Reducer.body` that has read access to a view-resolved context) to get
///   the `MainActor`-isolated `ModelContext` SwiftData uses for view queries.
/// - Use `task(_:)` from a `.run { _ in ... }` effect to perform writes or
///   queries against an isolated `ModelActor` so the reducer never blocks
///   the main thread on disk I/O.
@DependencyClient
struct ModelContainerClient: Sendable {
  var container: @Sendable () throws -> ModelContainer
}

extension ModelContainerClient {
  /// Returns the container's main-actor context. Must be called from
  /// `@MainActor`-isolated code (matches SwiftUI's `@Environment(\.modelContext)`).
  @MainActor
  func mainContext() throws -> ModelContext {
    try container().mainContext
  }

  /// Runs `body` on a fresh `ModelActor`-isolated context backed by the
  /// shared `ModelContainer`. Use this from reducer effects so SwiftData
  /// writes are off the main actor.
  func task(_ body: @escaping @Sendable (BackgroundModelActor) async throws -> Void) async throws {
    let actor = try BackgroundModelActor(modelContainer: container())
    try await body(actor)
  }
}

extension ModelContainerClient: DependencyKey {
  static let liveValue: ModelContainerClient = {
    let cached = LockIsolated<ModelContainer?>(nil)
    return ModelContainerClient(
      container: {
        if let existing = cached.value { return existing }
        let made = try LocalPersistence.makeModelContainer()
        cached.setValue(made)
        return made
      }
    )
  }()

  static let previewValue: ModelContainerClient = {
    let cached = LockIsolated<ModelContainer?>(nil)
    return ModelContainerClient(
      container: {
        if let existing = cached.value { return existing }
        let made = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
        cached.setValue(made)
        return made
      }
    )
  }()
}

extension DependencyValues {
  var modelContainer: ModelContainerClient {
    get { self[ModelContainerClient.self] }
    set { self[ModelContainerClient.self] = newValue }
  }
}

/// `ModelActor`-isolated wrapper around a background `ModelContext`. Reducer
/// effects that need to read or mutate SwiftData entities should do so
/// inside `ModelContainerClient.task { actor in ... }` and use
/// `actor.modelContext` (which is isolated to this actor).
@ModelActor
actor BackgroundModelActor {}
