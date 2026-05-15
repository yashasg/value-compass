import ComposableArchitecture
import Foundation
import SwiftData

/// Reducer that drives `PortfolioEditorView` — the create/edit sheet
/// reachable from `PortfolioListView`. Owns the `PortfolioFormDraft` (moved
/// from `MainView.swift`), surfaces validation errors, and persists changes
/// through `@Dependency(\.modelContainer)` so the sibling list refreshes
/// after `delegate(.saved)`.
@Reducer
struct PortfolioEditorFeature {
  @ObservableState
  struct State: Equatable {
    @CasePathable
    enum Mode: Equatable {
      case create
      case edit(UUID)
    }

    let mode: Mode
    var draft: PortfolioFormDraft = .init()
    /// Snapshot of `draft` captured at presentation time (and again after the
    /// edit-mode load resolves via `.draftHydrated`). The discard-confirmation
    /// flow (#325) compares `draft` against `baseline` to detect unsaved edits
    /// before allowing Cancel / swipe-down dismissal to drop user content.
    var baseline: PortfolioFormDraft = .init()
    var validationError: PortfolioEditorValidationError?
    var saveError: String?
    /// Drives the "Discard Changes?" confirmation dialog presented when the
    /// user taps Cancel (or attempts a sheet swipe-down on iOS 17+) while the
    /// draft diverges from `baseline`. Reset by `.confirmDiscard` / `.keepEditing`.
    var pendingCancellation: Bool = false

    init(mode: Mode, draft: PortfolioFormDraft = .init()) {
      self.mode = mode
      self.draft = draft
      self.baseline = draft
    }

    /// `true` when the user has typed into the form since presentation or the
    /// last successful hydration. Used by the view to gate
    /// `.interactiveDismissDisabled` and by the reducer to decide whether
    /// `.cancelTapped` opens the discard-confirmation dialog or dismisses
    /// straight through.
    var hasUnsavedChanges: Bool {
      draft != baseline
    }

    var navigationTitle: String {
      switch mode {
      case .create: return "Create Portfolio"
      case .edit: return "Edit Portfolio"
      }
    }
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case task
    case draftHydrated(PortfolioFormDraft)
    case saveTapped
    case savedSuccessfully(UUID)
    case saveFailed(String)
    case validationFailed(PortfolioEditorValidationError)
    case cancelTapped
    case confirmDiscard
    case keepEditing
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case saved(UUID)
      case canceled
    }
  }

  @Dependency(\.modelContainer) var modelContainer
  @Dependency(\.dismiss) var dismiss

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        state.validationError = nil
        return .none

      case .task:
        switch state.mode {
        case .create:
          return .none
        case .edit(let id):
          return .run { send in
            if let draft = try await loadDraft(id: id) {
              await send(.draftHydrated(draft))
            }
          } catch: { _, _ in
          }
        }

      case .draftHydrated(let draft):
        state.draft = draft
        state.baseline = draft
        return .none

      case .saveTapped:
        let validatedValues: PortfolioEditorValues
        do {
          validatedValues = try state.draft.validatedValues()
        } catch let validationError as PortfolioEditorValidationError {
          return .send(.validationFailed(validationError))
        } catch {
          return .send(.saveFailed(error.localizedDescription))
        }

        state.validationError = nil
        let mode = state.mode
        return .run { send in
          do {
            let id = try await persist(mode: mode, values: validatedValues)
            await send(.savedSuccessfully(id))
          } catch {
            await send(.saveFailed(error.localizedDescription))
          }
        }

      case .savedSuccessfully(let id):
        return .run { send in
          await send(.delegate(.saved(id)))
          await dismiss()
        }

      case .saveFailed(let message):
        state.saveError = message
        return .none

      case .validationFailed(let error):
        state.validationError = error
        return .none

      case .cancelTapped:
        // HIG Modality + Sheets: if the user has unsaved edits, ask for
        // confirmation before discarding instead of dismissing silently
        // (#325). When the draft still matches `baseline`, fall through to
        // the original dismiss path so a clean Cancel stays a one-tap action.
        if state.hasUnsavedChanges {
          state.pendingCancellation = true
          return .none
        }
        return .run { send in
          await send(.delegate(.canceled))
          await dismiss()
        }

      case .confirmDiscard:
        state.pendingCancellation = false
        return .run { send in
          await send(.delegate(.canceled))
          await dismiss()
        }

      case .keepEditing:
        state.pendingCancellation = false
        return .none

      case .delegate:
        return .none
      }
    }
  }

  private func loadDraft(id: UUID) async throws -> PortfolioFormDraft? {
    try await withCheckedThrowingContinuation { continuation in
      Task {
        do {
          let found = LockIsolated<PortfolioFormDraft?>(nil)
          try await modelContainer.task { actor in
            let draft = try await actor.loadPortfolioDraft(id: id)
            found.setValue(draft)
          }
          continuation.resume(returning: found.value)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func persist(mode: State.Mode, values: PortfolioEditorValues) async throws -> UUID {
    try await withCheckedThrowingContinuation { continuation in
      Task {
        do {
          let savedID = LockIsolated<UUID?>(nil)
          try await modelContainer.task { actor in
            let id = try await actor.upsertPortfolio(mode: mode, values: values)
            savedID.setValue(id)
          }
          guard let id = savedID.value else {
            throw PortfolioEditorPersistenceError.missingPortfolio
          }
          continuation.resume(returning: id)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}

/// Mirrors the legacy `PortfolioEditorMode.title` helper so the new editor
/// view can resolve labels purely from reducer state.
enum PortfolioEditorPersistenceError: LocalizedError, Equatable {
  case missingPortfolio

  var errorDescription: String? {
    switch self {
    case .missingPortfolio:
      return "Portfolio could not be found."
    }
  }
}

/// Editable form values backing `PortfolioEditorFeature.State`. Moved from
/// `MainView.swift` so the editor reducer owns the draft logic and other
/// MVVM views (e.g. `PortfolioDetailView`) keep using the `displayText`
/// helper at module scope.
struct PortfolioFormDraft: Equatable {
  var name: String = ""
  var monthlyBudgetText: String = ""
  var maWindow: Int = Portfolio.allowedMAWindows[0]

  init(
    name: String = "", monthlyBudgetText: String = "", maWindow: Int = Portfolio.allowedMAWindows[0]
  ) {
    self.name = name
    self.monthlyBudgetText = monthlyBudgetText
    self.maWindow = maWindow
  }

  init(portfolio: Portfolio) {
    self.name = portfolio.name
    self.monthlyBudgetText = Self.displayText(for: portfolio.monthlyBudget)
    self.maWindow = portfolio.maWindow
  }

  init(name: String, monthlyBudget: Decimal, maWindow: Int) {
    self.name = name
    self.monthlyBudgetText = Self.displayText(for: monthlyBudget)
    self.maWindow = maWindow
  }

  func validatedValues() throws -> PortfolioEditorValues {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      throw PortfolioEditorValidationError.emptyName
    }

    guard
      let budget = Decimal(
        string: monthlyBudgetText.trimmingCharacters(in: .whitespacesAndNewlines)),
      budget > 0
    else {
      throw PortfolioEditorValidationError.invalidBudget
    }

    guard Portfolio.allowedMAWindows.contains(maWindow) else {
      throw PortfolioEditorValidationError.invalidMAWindow(maWindow)
    }

    return PortfolioEditorValues(name: trimmedName, monthlyBudget: budget, maWindow: maWindow)
  }

  func makePortfolio() throws -> Portfolio {
    let values = try validatedValues()
    return Portfolio(
      name: values.name, monthlyBudget: values.monthlyBudget, maWindow: values.maWindow)
  }

  func apply(to portfolio: Portfolio) throws {
    let values = try validatedValues()
    portfolio.name = values.name
    portfolio.monthlyBudget = values.monthlyBudget
    portfolio.maWindow = values.maWindow
  }

  static func displayText(for amount: Decimal) -> String {
    NSDecimalNumber(decimal: amount).stringValue
  }
}

/// Validated values produced by `PortfolioFormDraft.validatedValues()`.
/// Moved from `MainView.swift`.
struct PortfolioEditorValues: Equatable, Sendable {
  let name: String
  let monthlyBudget: Decimal
  let maWindow: Int
}

/// Validation errors surfaced by `PortfolioFormDraft.validatedValues()`.
/// Moved from `MainView.swift`.
enum PortfolioEditorValidationError: LocalizedError, Equatable {
  case emptyName
  case invalidBudget
  case invalidMAWindow(Int)

  var errorDescription: String? {
    switch self {
    case .emptyName:
      return "Portfolio name is required."
    case .invalidBudget:
      return "Monthly budget must be greater than 0."
    case .invalidMAWindow:
      return "Moving average window must be 50 or 200 days."
    }
  }
}

extension BackgroundModelActor {
  /// Hydrates a `PortfolioFormDraft` from the persisted portfolio with
  /// `id`, returning `nil` when the portfolio no longer exists. Performed
  /// inside the actor so the SwiftData model never escapes its isolation.
  func loadPortfolioDraft(id: UUID) throws -> PortfolioFormDraft? {
    let descriptor = FetchDescriptor<Portfolio>(
      predicate: #Predicate { $0.id == id }
    )
    guard let portfolio = try modelContext.fetch(descriptor).first else { return nil }
    return PortfolioFormDraft(portfolio: portfolio)
  }

  /// Inserts (`.create`) or updates (`.edit`) the portfolio described by
  /// `values`. Returns the resulting identifier so the editor can surface
  /// it via `delegate(.saved)`.
  func upsertPortfolio(
    mode: PortfolioEditorFeature.State.Mode,
    values: PortfolioEditorValues
  ) throws -> UUID {
    switch mode {
    case .create:
      let portfolio = Portfolio(
        name: values.name,
        monthlyBudget: values.monthlyBudget,
        maWindow: values.maWindow
      )
      modelContext.insert(portfolio)
      try modelContext.save()
      return portfolio.id

    case .edit(let id):
      let descriptor = FetchDescriptor<Portfolio>(
        predicate: #Predicate { $0.id == id }
      )
      guard let portfolio = try modelContext.fetch(descriptor).first else {
        throw PortfolioEditorPersistenceError.missingPortfolio
      }
      portfolio.name = values.name
      portfolio.monthlyBudget = values.monthlyBudget
      portfolio.maWindow = values.maWindow
      try modelContext.save()
      return portfolio.id
    }
  }
}
