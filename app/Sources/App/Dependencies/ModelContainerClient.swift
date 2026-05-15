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
/// - Use `wipe()` from the Settings → "Erase All My Data" flow
///   (issue #329 §1.ii) to drop every row in every configuration backing
///   the container before re-arming the onboarding gate.
@DependencyClient
struct ModelContainerClient: Sendable {
  var container: @Sendable () throws -> ModelContainer
  /// Drops every persisted entity in every configuration without
  /// tearing the `ModelContainer` itself down. Backed by SwiftData's
  /// `ModelContext.delete(model:)` API (iOS 17+) applied to every
  /// `@Model` type the container knows about so subsequent fetches see
  /// an empty store.
  var wipe: @Sendable () async throws -> Void
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
    let resolveContainer: @Sendable () throws -> ModelContainer = {
      if let existing = cached.value { return existing }
      let made = try LocalPersistence.makeModelContainer()
      cached.setValue(made)
      return made
    }
    return ModelContainerClient(
      container: resolveContainer,
      wipe: {
        let container = try resolveContainer()
        try await ModelContainerClient.wipe(container: container)
      }
    )
  }()

  static let previewValue: ModelContainerClient = {
    let cached = LockIsolated<ModelContainer?>(nil)
    let resolveContainer: @Sendable () throws -> ModelContainer = {
      if let existing = cached.value { return existing }
      let made = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
      cached.setValue(made)
      return made
    }
    return ModelContainerClient(
      container: resolveContainer,
      wipe: {
        let container = try resolveContainer()
        try await ModelContainerClient.wipe(container: container)
      }
    )
  }()

  /// Shared wipe implementation: iterate every `@Model` type advertised
  /// by the *current* `LocalSchemaMigrationPlan` and call
  /// `ModelContext.delete(model:includeSubclasses:)` to drop every row
  /// of that entity in a single `save()`. Run on a background
  /// `ModelActor` so the wipe never blocks the main actor.
  ///
  /// `Schema.Entity` does not expose its backing `PersistentModel` type
  /// in iOS 17.0 (the `mappedType` property only landed in iOS 18+), so
  /// driving the wipe from the schema entities is not portable to our
  /// minimum deployment target. The migration plan's
  /// `schemas.last!.models` is the canonical "live model set" — it's
  /// already the source of truth `LocalPersistence.makeModelContainer`
  /// uses to build the running container, so a future schema bump that
  /// appends `LocalSchemaV3` to the plan is automatically reflected
  /// here without touching this file.
  private static func wipe(container: ModelContainer) async throws {
    guard let currentVersion = LocalSchemaMigrationPlan.schemas.last else {
      return
    }
    let modelTypes = currentVersion.models
    let actor = try BackgroundModelActor(modelContainer: container)
    try await actor.deleteAllEntities(modelTypes: modelTypes)
  }
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
actor BackgroundModelActor {
  /// Drops every persisted row of every passed-in `@Model` type by
  /// calling `ModelContext.delete(model:includeSubclasses:)` per type.
  /// The Settings → "Erase All My Data" flow (issue #329) uses this
  /// after the backend `DELETE /portfolio` succeeds so the local
  /// SwiftData mirror reflects the server-side erasure before
  /// onboarding re-fires.
  ///
  /// `ModelContext.delete(model:where:includeSubclasses:)` is preferred
  /// over `ModelContainer.deleteAllData()` because the latter tears the
  /// container down and re-creates the store (forcing every observer of
  /// `\.modelContext` to re-resolve); per-entity batch deletes keep the
  /// container live and only invalidate the rows.
  ///
  /// The model-type list is passed in (rather than read from
  /// `modelContainer.schema.entities`) because `Schema.Entity` does not
  /// expose its backing `PersistentModel.Type` on iOS 17 — see
  /// `ModelContainerClient.wipe(container:)` for the call site.
  func deleteAllEntities(modelTypes: [any PersistentModel.Type]) throws {
    for modelType in modelTypes {
      try deleteAll(modelType)
    }
    try modelContext.save()
  }

  /// Type-erased helper so the generic `delete(model:)` call infers the
  /// concrete `PersistentModel` from `modelType`. Without this the
  /// caller would have to know each `@Model` type at compile time.
  private func deleteAll<Model: PersistentModel>(_ modelType: Model.Type) throws {
    try modelContext.delete(model: Model.self, includeSubclasses: true)
  }
}
