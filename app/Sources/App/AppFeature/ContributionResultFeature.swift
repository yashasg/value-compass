import ComposableArchitecture
import Foundation
import SwiftData

/// Reducer that drives `ContributionResultView` — the post-calculation
/// "required capital" surface today rendered inline in `PortfolioDetailView`.
/// Replaces the Phase 0 placeholder.
///
/// State holds a value-typed `ContributionOutput` plus the alert payloads
/// required by the existing UX. Persistence runs through
/// `@Dependency(\.modelContainer)` so the SwiftData write happens on a
/// `BackgroundModelActor` rather than the main thread; the calculator is
/// stubbed via `@Dependency(\.contributionCalculator)` so retry uses the
/// same code path tests can fake out.
///
/// `MainFeature.path` consumes the `Delegate` cases below to push history
/// onto the surrounding `NavigationStack` / `NavigationSplitView`; the
/// reducer no longer carries a Phase-1 navigation latch.
@Reducer
struct ContributionResultFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    let portfolioID: UUID
    var output: ContributionOutput
    var saveError: String?
    var saveConfirmation: String?

    init(
      portfolioID: UUID,
      output: ContributionOutput,
      saveError: String? = nil,
      saveConfirmation: String? = nil
    ) {
      self.portfolioID = portfolioID
      self.output = output
      self.saveError = saveError
      self.saveConfirmation = saveConfirmation
    }
  }

  enum Action: Equatable, Sendable {
    case retryTapped
    case saveTapped
    case openHistoryTapped
    case saveErrorDismissed
    case saveConfirmationDismissed
    case calculationCompleted(ContributionOutput)
    case persistFailed(String)
    case persistSucceeded(savedTotal: Decimal, portfolioName: String)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable, Sendable {
      case openHistory(portfolioID: UUID)
    }
  }

  @Dependency(\.modelContainer) var modelContainer
  @Dependency(\.contributionCalculator) var contributionCalculator

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .retryTapped:
        let id = state.portfolioID
        return .run { [modelContainer, contributionCalculator] send in
          let output = await MainActor.run { () -> ContributionOutput in
            do {
              let context = try modelContainer.mainContext()
              let descriptor = FetchDescriptor<Portfolio>(
                predicate: #Predicate { $0.id == id }
              )
              if let portfolio = try context.fetch(descriptor).first {
                return contributionCalculator.calculate(portfolio)
              }
              return ContributionOutput.failure(
                ContributionCalculationError.missingPortfolio
              )
            } catch {
              // Preserve the underlying SwiftData / container error so the
              // user sees a useful message instead of the generic
              // "missing portfolio" string. Phase 2 (#159) routes this
              // through a typed error in `ContributionCalculationError`.
              return ContributionOutput.failure(
                PersistenceErrorShim(underlying: error)
              )
            }
          }
          await send(.calculationCompleted(output))
        }

      case .saveTapped:
        guard state.output.error == nil else { return .none }
        let id = state.portfolioID
        let output = state.output
        return .run { [modelContainer] send in
          do {
            let result = try await Self.persist(
              modelContainer: modelContainer,
              id: id,
              output: output
            )
            await send(
              .persistSucceeded(
                savedTotal: result.savedTotal,
                portfolioName: result.portfolioName
              )
            )
          } catch {
            await send(.persistFailed(error.localizedDescription))
          }
        }

      case .openHistoryTapped:
        let id = state.portfolioID
        return .send(.delegate(.openHistory(portfolioID: id)))

      case .saveErrorDismissed:
        state.saveError = nil
        return .none

      case .saveConfirmationDismissed:
        state.saveConfirmation = nil
        return .none

      case .calculationCompleted(let output):
        state.output = output
        return .none

      case .persistFailed(let message):
        state.saveError = message
        return .none

      case .persistSucceeded(let savedTotal, let portfolioName):
        state.saveConfirmation = Self.confirmationMessage(
          savedTotal: savedTotal,
          portfolioName: portfolioName
        )
        return .none

      case .delegate:
        return .none
      }
    }
  }

  /// Performs the SwiftData write inside a `BackgroundModelActor` so the
  /// reducer effect never blocks the main thread. Returns the persisted
  /// total + portfolio name so the reducer can render the confirmation
  /// alert without re-reading the model.
  private static func persist(
    modelContainer: ModelContainerClient,
    id: UUID,
    output: ContributionOutput
  ) async throws -> (savedTotal: Decimal, portfolioName: String) {
    try await withCheckedThrowingContinuation { continuation in
      Task {
        do {
          let collected = LockIsolated<(Decimal, String)?>(nil)
          try await modelContainer.task { actor in
            let result = try await actor.persistContributionRecord(
              portfolioID: id,
              output: output
            )
            collected.setValue(result)
          }
          if let value = collected.value {
            continuation.resume(returning: (value.0, value.1))
          } else {
            continuation.resume(
              throwing: ContributionRecordSnapshotError.failedCalculation(
                "Portfolio not found."
              )
            )
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  static func confirmationMessage(
    savedTotal: Decimal,
    portfolioName: String
  ) -> String {
    "Saved \(savedTotal.appCurrencyFormatted()) for \(portfolioName)."
  }
}

/// Wraps an arbitrary `Error` (typically a SwiftData fetch / model-container
/// failure surfaced from `.retryTapped`) so the reducer can hand it to
/// `ContributionOutput.failure(_:)` while preserving the original message
/// instead of squashing every failure to `.missingPortfolio`. Phase 2 (#159)
/// folds this into a typed `ContributionCalculationError.persistenceFailure`
/// once `ContributionCalculator.swift` is in scope to modify.
struct PersistenceErrorShim: LocalizedError, @unchecked Sendable {
  let underlying: Error
  var errorDescription: String? { underlying.localizedDescription }
}

extension BackgroundModelActor {
  /// Persists a `ContributionRecord` snapshot for the portfolio identified
  /// by `portfolioID`. Returns the persisted total amount and the
  /// portfolio name so the reducer can render the confirmation alert
  /// without a follow-up read on the main thread. Throws if the portfolio
  /// cannot be found or `ContributionRecord(snapshotFor:output:)` rejects
  /// the input.
  func persistContributionRecord(
    portfolioID: UUID,
    output: ContributionOutput
  ) async throws -> (Decimal, String) {
    let descriptor = FetchDescriptor<Portfolio>(
      predicate: #Predicate { $0.id == portfolioID }
    )
    guard let portfolio = try modelContext.fetch(descriptor).first else {
      throw ContributionRecordSnapshotError.failedCalculation(
        "Portfolio not found."
      )
    }
    let record = try ContributionRecord(snapshotFor: portfolio, output: output)
    modelContext.insert(record)
    try modelContext.save()
    return (record.totalAmount, portfolio.name)
  }
}
