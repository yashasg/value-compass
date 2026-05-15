import ComposableArchitecture
import Foundation
import SwiftData

/// Reducer that drives `PortfolioListView` — the post-onboarding portfolio
/// inventory with create/edit/delete and (on iPad) selection. Replaces the
/// Phase 0 placeholder.
///
/// The reducer projects SwiftData `Portfolio` rows into `PortfolioSnapshot`
/// values so reducer state is `Equatable`/`Sendable` and decoupled from the
/// `@Model` class. Persistence happens through
/// `@Dependency(\.modelContainer)`; the `task` action loads the initial
/// snapshot list and refreshes it whenever the editor reports a save.
///
/// Phase 2 (#159) wires `MainFeature.path` to push `PortfolioDetailFeature`
/// when `delegate(.portfolioOpened)` fires; until then the legacy bridge in
/// `PortfolioListView` mirrors selection back into the `MainView` binding so
/// the existing iPad split view keeps working.
@Reducer
struct PortfolioListFeature {
  @ObservableState
  struct State: Equatable {
    var portfolios: [PortfolioSnapshot] = []
    @Presents var editor: PortfolioEditorFeature.State?
    var saveError: String?
    var selectedPortfolioID: UUID?
    /// Portfolio the user has staged for deletion via the swipe action.
    /// Non-nil while the destructive `.confirmationDialog` in
    /// `PortfolioListView` is presented. Holding the full snapshot (not
    /// just the id) lets the dialog title and message name the portfolio
    /// without re-fetching, and matches the same `pendingDeletion` /
    /// `confirmDelete` / `cancelDelete` flow that
    /// `ContributionHistoryFeature` already uses (issue #232 — confirm
    /// destructive cascade-delete before destroying categories, tickers,
    /// and saved contribution history).
    var pendingDeletion: PortfolioSnapshot?
    /// Whether the toolbar should expose the Settings link. The legacy
    /// `MainView` toggles this based on the navigation shell (compact stack
    /// shows the link, iPad split view does not because Settings is its own
    /// sidebar slot). Phase 2 (#159) wires the same toggle from
    /// `MainFeature`.
    var showsSettingsLink: Bool = true
  }

  enum Action: Equatable {
    case task
    case portfoliosLoaded([PortfolioSnapshot])
    case createTapped
    case editTapped(id: UUID)
    case deleteTapped(id: UUID)
    case confirmDelete
    case cancelDelete
    case selected(id: UUID?)
    case editor(PresentationAction<PortfolioEditorFeature.Action>)
    case saveErrorDismissed
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case portfolioOpened(UUID)
    }
  }

  @Dependency(\.modelContainer) var modelContainer

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .run { [modelContainer] send in
          do {
            let snapshots = try await Self.loadSnapshots(modelContainer: modelContainer)
            await send(.portfoliosLoaded(snapshots))
          } catch {
            await send(.portfoliosLoaded([]))
          }
        }

      case .portfoliosLoaded(let snapshots):
        state.portfolios = snapshots
        if let selected = state.selectedPortfolioID,
          !state.portfolios.contains(where: { $0.id == selected })
        {
          state.selectedPortfolioID = nil
        }
        if let pending = state.pendingDeletion,
          !state.portfolios.contains(where: { $0.id == pending.id })
        {
          state.pendingDeletion = nil
        }
        return .none

      case .createTapped:
        state.editor = PortfolioEditorFeature.State(mode: .create)
        return .none

      case .editTapped(let id):
        state.editor = PortfolioEditorFeature.State(mode: .edit(id))
        return .none

      case .deleteTapped(let id):
        guard let snapshot = state.portfolios.first(where: { $0.id == id }) else {
          return .none
        }
        state.pendingDeletion = snapshot
        return .none

      case .confirmDelete:
        guard let pending = state.pendingDeletion else { return .none }
        state.pendingDeletion = nil
        return .run { [modelContainer] send in
          do {
            try await Self.deleteSnapshot(modelContainer: modelContainer, id: pending.id)
            let snapshots = try await Self.loadSnapshots(modelContainer: modelContainer)
            await send(.portfoliosLoaded(snapshots))
          } catch {
            let snapshots =
              (try? await Self.loadSnapshots(modelContainer: modelContainer)) ?? []
            await send(.portfoliosLoaded(snapshots))
          }
        }

      case .cancelDelete:
        state.pendingDeletion = nil
        return .none

      case .selected(let id):
        state.selectedPortfolioID = id
        if let id {
          return .send(.delegate(.portfolioOpened(id)))
        }
        return .none

      case .editor(.presented(.delegate(.saved))):
        return .run { [modelContainer] send in
          do {
            let snapshots = try await Self.loadSnapshots(modelContainer: modelContainer)
            await send(.portfoliosLoaded(snapshots))
          } catch {
          }
        }

      case .editor:
        return .none

      case .saveErrorDismissed:
        state.saveError = nil
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$editor, action: \.editor) {
      PortfolioEditorFeature()
    }
  }

  private static func loadSnapshots(
    modelContainer: ModelContainerClient
  ) async throws -> [PortfolioSnapshot] {
    try await withCheckedThrowingContinuation { continuation in
      Task {
        do {
          let collected = LockIsolated<[PortfolioSnapshot]>([])
          try await modelContainer.task { actor in
            let snapshots = try await actor.loadPortfolioSnapshots()
            collected.setValue(snapshots)
          }
          continuation.resume(returning: collected.value)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private static func deleteSnapshot(
    modelContainer: ModelContainerClient,
    id: UUID
  ) async throws {
    try await modelContainer.task { actor in
      try await actor.deletePortfolio(id: id)
    }
  }
}

/// Sendable projection of `Portfolio` for use in `PortfolioListFeature`
/// state. SwiftData `@Model` classes are `MainActor`-isolated and not
/// `Sendable`, so the reducer mirrors only the fields the list/sidebar UI
/// reads.
struct PortfolioSnapshot: Equatable, Identifiable, Sendable {
  let id: UUID
  let name: String
  let monthlyBudget: Decimal
  let maWindow: Int
  let createdAt: Date
  let categoryCount: Int
}

extension BackgroundModelActor {
  /// Fetches portfolios sorted newest-first and projects them to
  /// `PortfolioSnapshot` values inside the actor's isolation so the call
  /// site can return the result across actor boundaries.
  func loadPortfolioSnapshots() throws -> [PortfolioSnapshot] {
    let descriptor = FetchDescriptor<Portfolio>(
      sortBy: [SortDescriptor(\Portfolio.createdAt, order: .reverse)]
    )
    let portfolios = try modelContext.fetch(descriptor)
    return portfolios.map { portfolio in
      PortfolioSnapshot(
        id: portfolio.id,
        name: portfolio.name,
        monthlyBudget: portfolio.monthlyBudget,
        maWindow: portfolio.maWindow,
        createdAt: portfolio.createdAt,
        categoryCount: portfolio.categories.count
      )
    }
  }

  /// Deletes the portfolio with the given identifier through
  /// `PortfolioCascadeDeleter` so the `Holding` and `InvestSnapshot` rows
  /// owned by `id` (referenced by `portfolioId` UUID, not by SwiftData
  /// `@Relationship`) are removed in the same transaction. Calling
  /// `modelContext.delete(portfolio)` directly would leak orphan MVP rows —
  /// see the cascade contract documented in `MVPModels.swift` and the helper
  /// at `Backend/Persistence/PortfolioCascadeDeleter.swift`.
  ///
  /// No-op when the portfolio is not present (e.g. already deleted from
  /// another context): the deleter's fetch returns empty and `save()`
  /// becomes a no-op.
  func deletePortfolio(id: UUID) throws {
    try PortfolioCascadeDeleter(context: modelContext).delete(portfolioID: id)
  }
}
