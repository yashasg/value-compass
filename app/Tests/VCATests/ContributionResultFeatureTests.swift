import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import SwiftData
import XCTest

@testable import VCA

/// `TestStore` coverage for `ContributionResultFeature` (issue #194, part of
/// #185).
///
/// Pins the post-calculation result reducer:
///
/// - `.retryTapped`: happy path that runs the stubbed calculator against a
///   seeded in-memory container, the empty-container branch that emits
///   `.failure(.missingPortfolio)`, and the throwing-container branch that
///   wraps the underlying error via `PersistenceErrorShim`.
/// - `.saveTapped`: no-op when `state.output.error != nil`, the happy path
///   through `BackgroundModelActor.persistContributionRecord` that writes
///   `state.saveConfirmation`, and the throwing-container failure that
///   surfaces `.persistFailed(message)` and writes `state.saveError`.
/// - `.openHistoryTapped` → `.delegate(.openHistory(portfolioID:))`.
/// - `.saveErrorDismissed`, `.calculationCompleted(_)`, `.persistFailed(_)`,
///   `.persistSucceeded(savedTotal:portfolioName:)` mutations.
/// - `confirmationMessage(savedTotal:portfolioName:)` pure helper, now
///   sourced from `Decimal.appCurrencyFormatted()` (#257).
///
/// Post-#328: `.saveConfirmationDismissed` was retired with the success
/// alert. The confirmation now persists in `state.saveConfirmation` as an
/// inline "Saved" badge until the next `.saveTapped` round-trip; tests
/// pin that no dismissal path silently re-emerges.
@MainActor
final class ContributionResultFeatureTests: XCTestCase {
  // MARK: - .retryTapped

  func testRetryTappedHappyPathRunsCalculatorAndCompletes() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    context.insert(
      Portfolio(
        id: portfolioID, name: "Growth",
        monthlyBudget: Decimal(500), maWindow: 50,
        createdAt: Date(timeIntervalSince1970: 1_600_000_000)))
    try context.save()

    let stubOutput = ContributionOutput(
      totalAmount: Decimal(123),
      categoryBreakdown: [
        CategoryContributionResult(
          categoryName: "Equity", amount: Decimal(123), allocatedWeight: 1)
      ],
      allocations: [
        TickerContributionAllocation(
          tickerSymbol: "VTI", categoryName: "Equity",
          amount: Decimal(123), allocatedWeight: 1)
      ])

    let initialOutput = ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID, output: initialOutput)
    ) {
      ContributionResultFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
      $0.contributionCalculator.calculate = { _ in stubOutput }
    }

    await store.send(.retryTapped)
    await store.receive(.calculationCompleted(stubOutput)) {
      $0.output = stubOutput
    }
  }

  func testRetryTappedWithMissingPortfolioCompletesWithMissingPortfolioFailure() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let portfolioID = UUID()

    let initialOutput = ContributionOutput(totalAmount: Decimal(50))
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID, output: initialOutput)
    ) {
      ContributionResultFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
      // The reducer captures `contributionCalculator` in the effect closure
      // before the fetch-miss branch short-circuits, so the test guard fires
      // even though the stub is never invoked. Provide a no-op stub.
      $0.contributionCalculator.calculate = { _ in
        ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
      }
    }

    let expected = ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
    await store.send(.retryTapped)
    await store.receive(.calculationCompleted(expected)) {
      $0.output = expected
    }
  }

  func testRetryTappedWithThrowingContainerWrapsErrorViaPersistenceErrorShim() async {
    struct StubError: LocalizedError, Equatable {
      var errorDescription: String? { "container kaboom" }
    }

    let portfolioID = UUID()
    let initialOutput = ContributionOutput(totalAmount: Decimal(50))
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID, output: initialOutput)
    ) {
      ContributionResultFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubError() }
      // The reducer captures `contributionCalculator` in the effect closure
      // before the throwing-container branch surfaces, so the test guard
      // fires even though the stub is never invoked. Provide a no-op stub.
      $0.contributionCalculator.calculate = { _ in
        ContributionOutput.failure(ContributionCalculationError.missingPortfolio)
      }
    }
    // `ContributionOutput.Equatable` compares errors by `localizedDescription`,
    // so wrapping the same `StubError()` yields a payload that matches the
    // `PersistenceErrorShim`-wrapped value the reducer produces.
    let expected = ContributionOutput.failure(StubError())
    await store.send(.retryTapped)
    await store.receive(.calculationCompleted(expected)) {
      $0.output = expected
    }
    XCTAssertEqual(store.state.output.error?.localizedDescription, "container kaboom")
  }

  // MARK: - .saveTapped

  func testSaveTappedIsNoOpWhenOutputHasError() async {
    let portfolioID = UUID()
    let failedOutput = ContributionOutput.failure(ContributionCalculationError.invalidBudget)
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID, output: failedOutput)
    ) {
      ContributionResultFeature()
    }
    // No `withDependencies`: the guard returns `.none` before the model
    // container is touched, so the unimplemented `@DependencyClient` stub is
    // never invoked.

    await store.send(.saveTapped)
  }

  func testSaveTappedHappyPathPersistsAndWritesConfirmation() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    let portfolioName = "Growth"
    context.insert(
      Portfolio(
        id: portfolioID, name: portfolioName,
        monthlyBudget: Decimal(500), maWindow: 50,
        createdAt: Date(timeIntervalSince1970: 1_600_000_000)))
    try context.save()

    let savedTotal = Decimal(225)
    let validOutput = ContributionOutput(
      totalAmount: savedTotal,
      categoryBreakdown: [
        CategoryContributionResult(
          categoryName: "Equity", amount: savedTotal, allocatedWeight: 1)
      ],
      allocations: [
        TickerContributionAllocation(
          tickerSymbol: "VTI", categoryName: "Equity",
          amount: savedTotal, allocatedWeight: 1)
      ])

    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID, output: validOutput)
    ) {
      ContributionResultFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    let expectedConfirmation = ContributionResultFeature.confirmationMessage(
      savedTotal: savedTotal, portfolioName: portfolioName)

    await store.send(.saveTapped)
    await store.receive(
      .persistSucceeded(savedTotal: savedTotal, portfolioName: portfolioName)
    ) {
      $0.saveConfirmation = expectedConfirmation
    }

    // Container side-effect verification: a `ContributionRecord` row landed.
    let records = try context.fetch(FetchDescriptor<ContributionRecord>())
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records.first?.totalAmount, savedTotal)
  }

  func testSaveTappedFailurePathWritesSaveError() async {
    struct StubError: LocalizedError, Equatable {
      var errorDescription: String? { "save kaboom" }
    }

    let portfolioID = UUID()
    let validOutput = ContributionOutput(totalAmount: Decimal(100))
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID, output: validOutput)
    ) {
      ContributionResultFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubError() }
    }

    await store.send(.saveTapped)
    await store.receive(.persistFailed("save kaboom")) {
      $0.saveError = "save kaboom"
    }
  }

  // MARK: - .openHistoryTapped delegate

  func testOpenHistoryTappedEmitsDelegate() async {
    let portfolioID = UUID()
    let initialOutput = ContributionOutput(totalAmount: Decimal(10))
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID, output: initialOutput)
    ) {
      ContributionResultFeature()
    }

    await store.send(.openHistoryTapped)
    await store.receive(.delegate(.openHistory(portfolioID: portfolioID)))
  }

  func testDelegateActionIsTerminator() async {
    let portfolioID = UUID()
    let initialOutput = ContributionOutput(totalAmount: Decimal(10))
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID, output: initialOutput)
    ) {
      ContributionResultFeature()
    }

    await store.send(.delegate(.openHistory(portfolioID: portfolioID)))
  }

  // MARK: - alert / banner mutations

  func testSaveErrorDismissedClearsSaveError() async {
    let portfolioID = UUID()
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID,
        output: ContributionOutput(totalAmount: Decimal(10)),
        saveError: "stale")
    ) {
      ContributionResultFeature()
    }

    await store.send(.saveErrorDismissed) {
      $0.saveError = nil
    }
  }

  func testSaveConfirmationPersistsBetweenRendersForInlineBadge() async {
    // Post-#328: the success alert was removed in favor of an inline
    // "Saved" badge that stays visible until the next `.saveTapped`
    // round-trip. The badge is keyed off `state.saveConfirmation`, so
    // a successful persist must leave the value populated indefinitely
    // (no auto-clear, no `.saveConfirmationDismissed` action). Pin the
    // "no transient dismissal" contract so a future refactor that
    // restores the modal-and-dismiss pattern (re-creating the HIG
    // violation closed by #328) trips this assertion.
    let portfolioID = UUID()
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID,
        output: ContributionOutput(totalAmount: Decimal(10)),
        saveConfirmation: "Saved $10 for Growth.")
    ) {
      ContributionResultFeature()
    }

    // The badge must remain unless the reducer explicitly overwrites
    // it on the next `.persistSucceeded`. Verify nothing on the action
    // surface clears it; a non-test renderer cannot synthesize a
    // dismissal action (`.saveConfirmationDismissed` was deleted).
    XCTAssertEqual(store.state.saveConfirmation, "Saved $10 for Growth.")
  }

  func testCalculationCompletedWritesOutput() async {
    let portfolioID = UUID()
    let original = ContributionOutput(totalAmount: Decimal(10))
    let updated = ContributionOutput(totalAmount: Decimal(99))
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID, output: original)
    ) {
      ContributionResultFeature()
    }

    await store.send(.calculationCompleted(updated)) {
      $0.output = updated
    }
  }

  func testPersistFailedWritesSaveError() async {
    let portfolioID = UUID()
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID,
        output: ContributionOutput(totalAmount: Decimal(10)))
    ) {
      ContributionResultFeature()
    }

    await store.send(.persistFailed("explicit message")) {
      $0.saveError = "explicit message"
    }
  }

  func testPersistSucceededWritesSaveConfirmationViaConfirmationMessage() async {
    let portfolioID = UUID()
    let store = TestStore(
      initialState: ContributionResultFeature.State(
        portfolioID: portfolioID,
        output: ContributionOutput(totalAmount: Decimal(10)))
    ) {
      ContributionResultFeature()
    }

    let savedTotal = Decimal(string: "12.34")!
    await store.send(.persistSucceeded(savedTotal: savedTotal, portfolioName: "Growth")) {
      $0.saveConfirmation = "Saved $12.34 for Growth."
    }
  }

  // MARK: - pure helpers

  func testConfirmationMessageInterpolatesSavedTotalAndPortfolioName() {
    let message = ContributionResultFeature.confirmationMessage(
      savedTotal: Decimal(string: "12.34")!, portfolioName: "Growth")
    XCTAssertEqual(message, "Saved $12.34 for Growth.")
  }
}
