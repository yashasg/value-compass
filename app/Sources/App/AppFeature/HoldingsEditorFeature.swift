import ComposableArchitecture
import Foundation
import SwiftData

/// Reducer that owns the holdings editor (`HoldingsEditorView`).
///
/// Phase 1 (issue #155). Replaces the placeholder shipped in #149 with the
/// real reducer that:
///
/// - Loads the persisted `HoldingsDraft` for `portfolioID` off the main actor
///   via `ModelContainerClient.task` + `BackgroundModelActor`.
/// - Mirrors every mutation `HoldingsDraft`/`CategoryDraft`/`TickerDraft`
///   currently expose (add/delete/move category and ticker; per-row weight,
///   symbol, and market-data binding edits via `BindableAction`).
/// - Recomputes `state.issues` after every mutation so the view's warning
///   banners and the parent's "blocks calculation" check stay live without
///   the view doing the work itself.
/// - Persists by re-fetching the SwiftData `Portfolio` inside the same
///   `BackgroundModelActor` and calling the existing
///   `HoldingsDraft.apply(to:in:)`. Failures surface via `state.saveError`;
///   success fires `delegate(.saved)` so the host (legacy
///   `NavigationLink`, Phase 2 `MainFeature.path`) closes the editor.
///
/// Phase 2 (#159) wires this reducer into `MainFeature.path.holdingsEditor`
/// (the host pops the path on `.delegate(.saved)` / `.delegate(.canceled)`)
/// and the legacy `init(portfolio:)` bridge in `HoldingsEditorView` is
/// removed. SwiftUI dismissal is driven by the view today; we intentionally
/// do not depend on `@Dependency(\.dismiss)` because the legacy
/// `NavigationLink` push is not a TCA-presented destination.
@Reducer
struct HoldingsEditorFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    let portfolioID: UUID
    var draft: HoldingsDraft
    var issues: [HoldingsDraftIssue]
    var saveError: String?

    init(
      portfolioID: UUID,
      draft: HoldingsDraft = .init(),
      saveError: String? = nil
    ) {
      self.portfolioID = portfolioID
      self.draft = draft
      self.issues = draft.issues()
      self.saveError = saveError
    }
  }

  enum Action: BindableAction, Equatable, Sendable {
    case binding(BindingAction<State>)
    case task
    case draftLoaded(HoldingsDraft)
    case loadFailed(String)
    case addCategoryTapped
    case deleteCategory(id: UUID)
    case moveCategory(id: UUID, direction: MoveDirection)
    case addTicker(categoryID: UUID)
    case deleteTicker(categoryID: UUID, tickerID: UUID)
    case moveTicker(categoryID: UUID, tickerID: UUID, direction: MoveDirection)
    case saveTapped
    case saveSucceeded
    case saveFailed(String)
    case saveErrorDismissed
    case revertTapped
    case revertLoaded(HoldingsDraft)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable, Sendable {
      case saved
      case canceled
    }
  }

  @Dependency(\.modelContainer) var modelContainer

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        // Per-row text edits (category name/weight, ticker symbol, market
        // data) all flow through here because every editable field is bound
        // via `@Bindable var store`. Re-validate so warning banners and the
        // parent's "blocks save" check stay in sync.
        state.issues = state.draft.issues()
        return .none

      case .task:
        // The legacy `init(portfolio:)` bridge pre-seeds `state.draft` from
        // the SwiftData `Portfolio` synchronously, so we only need to fetch
        // the canonical disk copy when the host (Phase 2 `MainFeature.path`)
        // pushed an empty state.
        guard state.draft.categories.isEmpty, state.issues.isEmpty else {
          return .none
        }
        let portfolioID = state.portfolioID
        let modelContainer = self.modelContainer
        return .run { send in
          do {
            let draft = try await Self.loadDraft(
              portfolioID: portfolioID, modelContainer: modelContainer)
            await send(.draftLoaded(draft))
          } catch {
            await send(.loadFailed(error.localizedDescription))
          }
        }

      case .draftLoaded(let draft):
        state.draft = draft
        state.issues = draft.issues()
        state.saveError = nil
        return .none

      case .loadFailed(let message):
        state.saveError = message
        return .none

      case .addCategoryTapped:
        state.draft.addCategory()
        state.issues = state.draft.issues()
        return .none

      case .deleteCategory(let id):
        state.draft.deleteCategory(id: id)
        state.issues = state.draft.issues()
        return .none

      case .moveCategory(let id, let direction):
        state.draft.moveCategory(id: id, direction: direction)
        state.issues = state.draft.issues()
        return .none

      case .addTicker(let categoryID):
        guard let index = state.draft.categories.firstIndex(where: { $0.id == categoryID })
        else {
          return .none
        }
        state.draft.categories[index].addTicker()
        state.issues = state.draft.issues()
        return .none

      case .deleteTicker(let categoryID, let tickerID):
        guard let index = state.draft.categories.firstIndex(where: { $0.id == categoryID })
        else {
          return .none
        }
        state.draft.categories[index].deleteTicker(id: tickerID)
        state.issues = state.draft.issues()
        return .none

      case .moveTicker(let categoryID, let tickerID, let direction):
        guard let index = state.draft.categories.firstIndex(where: { $0.id == categoryID })
        else {
          return .none
        }
        state.draft.categories[index].moveTicker(id: tickerID, direction: direction)
        state.issues = state.draft.issues()
        return .none

      case .saveTapped:
        let portfolioID = state.portfolioID
        let draft = state.draft
        let modelContainer = self.modelContainer
        return .run { send in
          do {
            try await Self.persistDraft(
              draft, portfolioID: portfolioID, modelContainer: modelContainer)
            await send(.saveSucceeded)
          } catch {
            await send(.saveFailed(error.localizedDescription))
          }
        }

      case .saveSucceeded:
        state.saveError = nil
        return .send(.delegate(.saved))

      case .saveFailed(let message):
        state.saveError = message
        return .none

      case .saveErrorDismissed:
        state.saveError = nil
        return .none

      case .revertTapped:
        let portfolioID = state.portfolioID
        let modelContainer = self.modelContainer
        return .run { send in
          do {
            let draft = try await Self.loadDraft(
              portfolioID: portfolioID, modelContainer: modelContainer)
            await send(.revertLoaded(draft))
          } catch {
            await send(.loadFailed(error.localizedDescription))
          }
        }

      case .revertLoaded(let draft):
        state.draft = draft
        state.issues = draft.issues()
        state.saveError = nil
        return .none

      case .delegate:
        return .none
      }
    }
  }

  private static func loadDraft(
    portfolioID: UUID,
    modelContainer: ModelContainerClient
  ) async throws -> HoldingsDraft {
    let result = LockIsolated<HoldingsDraft>(.init())
    try await modelContainer.task { actor in
      let draft = try await actor.loadHoldingsDraft(portfolioID: portfolioID)
      result.setValue(draft)
    }
    return result.value
  }

  private static func persistDraft(
    _ draft: HoldingsDraft,
    portfolioID: UUID,
    modelContainer: ModelContainerClient
  ) async throws {
    try await modelContainer.task { actor in
      try await actor.applyHoldingsDraft(draft, portfolioID: portfolioID)
    }
  }
}

extension BackgroundModelActor {
  /// Fetches the `Portfolio` for `portfolioID` and returns a fresh
  /// `HoldingsDraft` projection. Throws `HoldingsEditorPersistenceError`
  /// when the portfolio is not found so the reducer can surface it via
  /// `state.saveError`.
  fileprivate func loadHoldingsDraft(portfolioID: UUID) throws -> HoldingsDraft {
    let descriptor = FetchDescriptor<Portfolio>(
      predicate: #Predicate { $0.id == portfolioID })
    guard let portfolio = try modelContext.fetch(descriptor).first else {
      throw HoldingsEditorPersistenceError.portfolioNotFound(portfolioID)
    }
    return HoldingsDraft(portfolio: portfolio)
  }

  /// Applies `draft` to the persisted `Portfolio` for `portfolioID` using
  /// the existing `HoldingsDraft.apply(to:in:)` validation + diffing logic.
  fileprivate func applyHoldingsDraft(_ draft: HoldingsDraft, portfolioID: UUID) throws {
    let descriptor = FetchDescriptor<Portfolio>(
      predicate: #Predicate { $0.id == portfolioID })
    guard let portfolio = try modelContext.fetch(descriptor).first else {
      throw HoldingsEditorPersistenceError.portfolioNotFound(portfolioID)
    }
    try draft.apply(to: portfolio, in: modelContext)
  }
}

enum HoldingsEditorPersistenceError: LocalizedError, Equatable {
  case portfolioNotFound(UUID)

  var errorDescription: String? {
    switch self {
    case .portfolioNotFound:
      return "Could not find this portfolio. Pull to refresh and try again."
    }
  }
}
