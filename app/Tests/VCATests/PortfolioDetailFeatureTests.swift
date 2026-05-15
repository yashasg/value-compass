import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import SwiftData
import XCTest

@testable import VCA

/// `TestStore` coverage for `PortfolioDetailFeature` (issue #192, part of
/// #185).
///
/// Pins the per-portfolio detail surface: the `.task` snapshot reload through
/// `\.modelContainer.task` (happy + throwing-container paths), the
/// snapshot-mutation rule on `.snapshotChanged(_:)`, the navigation delegates
/// emitted by `.editHoldingsTapped` / `.openHistoryTapped`, every branch of
/// the `.calculateTapped` effect (no-op when `canCalculate == false`, happy
/// path with a stubbed `\.contributionCalculator`, and the throwing-container
/// failure path that maps to `ContributionCalculationError.missingPortfolio`),
/// the `.calculationCompleted` write into `state.calculationOutput` /
/// `state.lastError`, and the three branches of `.viewResultTapped`
/// (no-output / success / failure).
@MainActor
final class PortfolioDetailFeatureTests: XCTestCase {
  // MARK: - .task

  func testTaskWithSeededContainerLoadsSnapshot() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    context.insert(
      Portfolio(
        id: portfolioID, name: "Growth",
        monthlyBudget: Decimal(string: "1234.5")!, maWindow: 200,
        createdAt: Date(timeIntervalSince1970: 1_000_000)))
    try context.save()

    let initialSnapshot = Self.makeSnapshot(id: portfolioID, name: "Stale")
    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: initialSnapshot)
    ) {
      PortfolioDetailFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    let expectedSnapshot = PortfolioDetailSnapshot(
      id: portfolioID,
      name: "Growth",
      monthlyBudget: Decimal(string: "1234.5")!,
      maWindow: 200,
      categories: [],
      marketDataCompleteCount: 0,
      marketDataIncompleteCount: 0,
      canCalculate: false
    )

    await store.send(.task)
    await store.receive(\.snapshotChanged) {
      $0.snapshot = expectedSnapshot
    }
  }

  func testTaskWithThrowingContainerSwallowsError() async {
    struct StubContainerError: Error {}

    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Untouched")

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: snapshot)
    ) {
      PortfolioDetailFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubContainerError() }
    }

    // No `.snapshotChanged` should be received and no state should change.
    await store.send(.task)
  }

  // MARK: - .snapshotChanged

  func testSnapshotChangedWritesSnapshotIntoState() async {
    let portfolioID = UUID()
    let initialSnapshot = Self.makeSnapshot(id: portfolioID, name: "Old")
    let updatedSnapshot = Self.makeSnapshot(id: portfolioID, name: "New")

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: initialSnapshot)
    ) {
      PortfolioDetailFeature()
    }

    await store.send(.snapshotChanged(updatedSnapshot)) {
      $0.snapshot = updatedSnapshot
    }
  }

  // MARK: - .editHoldingsTapped

  func testEditHoldingsTappedPresentsHoldingsEditorSheet() async {
    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth")

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: snapshot)
    ) {
      PortfolioDetailFeature()
    }

    // HIG #229: editor is presented as a sheet on this reducer instead of
    // pushed onto `MainFeature.path`, so the action populates the
    // `@Presents` slot directly with no delegate emitted.
    await store.send(.editHoldingsTapped) {
      $0.holdingsEditor = HoldingsEditorFeature.State(portfolioID: portfolioID)
    }
  }

  func testHoldingsEditorSavedDelegateDismissesSheetAndRefreshes() async throws {
    let portfolioID = UUID()
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth")
    var initialState = PortfolioDetailFeature.State(
      portfolioID: portfolioID, snapshot: snapshot)
    initialState.holdingsEditor = HoldingsEditorFeature.State(portfolioID: portfolioID)

    let store = TestStore(initialState: initialState) {
      PortfolioDetailFeature()
    } withDependencies: {
      // No portfolio is persisted in this in-memory container, so the
      // refreshing `.task` effect reads back `nil` and emits no
      // `.snapshotChanged` follow-up. We disable exhaustivity to skip
      // asserting on the unrelated refresh-effect lifecycle.
      $0.modelContainer.container = { container }
    }
    store.exhaustivity = .off

    await store.send(.holdingsEditor(.presented(.delegate(.saved)))) {
      $0.holdingsEditor = nil
    }
    await store.receive(\.task)
  }

  func testHoldingsEditorCanceledDelegateDismissesSheet() async {
    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth")
    var initialState = PortfolioDetailFeature.State(
      portfolioID: portfolioID, snapshot: snapshot)
    initialState.holdingsEditor = HoldingsEditorFeature.State(portfolioID: portfolioID)

    let store = TestStore(initialState: initialState) {
      PortfolioDetailFeature()
    }

    await store.send(.holdingsEditor(.presented(.delegate(.canceled)))) {
      $0.holdingsEditor = nil
    }
  }

  // MARK: - .calculateTapped

  func testCalculateTappedIsNoOpWhenCanCalculateFalse() async {
    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth", canCalculate: false)

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: snapshot)
    ) {
      PortfolioDetailFeature()
    }

    // No `.calculationCompleted` should be received because `canCalculate`
    // gates the entire effect; no calculator dependency override is needed.
    await store.send(.calculateTapped)
  }

  func testCalculateTappedHappyPathRunsCalculatorAndCompletes() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    context.insert(
      Portfolio(
        id: portfolioID, name: "Growth",
        monthlyBudget: Decimal(100), maWindow: 50,
        createdAt: Date(timeIntervalSince1970: 1_000_000)))
    try context.save()

    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth", canCalculate: true)
    let expectedOutput = ContributionOutput(totalAmount: Decimal(100))

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: snapshot)
    ) {
      PortfolioDetailFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
      $0.contributionCalculator.calculate = { @MainActor _ in expectedOutput }
    }

    await store.send(.calculateTapped)
    await store.receive(\.calculationCompleted) {
      $0.calculationOutput = expectedOutput
      $0.lastError = nil
    }
  }

  func testCalculateTappedFailurePathWhenContainerThrows() async {
    struct StubContainerError: Error {}

    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth", canCalculate: true)
    let expectedOutput = ContributionOutput.failure(
      ContributionCalculationError.missingPortfolio)

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: snapshot)
    ) {
      PortfolioDetailFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubContainerError() }
      // The calculator is captured by the effect closure even though the
      // catch branch never invokes it; stub it to keep the dependency
      // tracker quiet without contributing to the assertion.
      $0.contributionCalculator.calculate = { @MainActor _ in
        ContributionOutput()
      }
    }

    await store.send(.calculateTapped)
    await store.receive(\.calculationCompleted) {
      $0.calculationOutput = expectedOutput
      $0.lastError = ContributionCalculationError.missingPortfolio.localizedDescription
    }
  }

  // MARK: - .calculationCompleted

  func testCalculationCompletedWritesOutputAndLastError() async {
    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth")
    let failureOutput = ContributionOutput.failure(
      ContributionCalculationError.invalidBudget)

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: snapshot)
    ) {
      PortfolioDetailFeature()
    }

    await store.send(.calculationCompleted(failureOutput)) {
      $0.calculationOutput = failureOutput
      $0.lastError = ContributionCalculationError.invalidBudget.localizedDescription
    }
  }

  // MARK: - .viewResultTapped

  func testViewResultTappedIsNoOpWhenNoOutput() async {
    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth")

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: snapshot)
    ) {
      PortfolioDetailFeature()
    }

    // No delegate should be emitted while `state.calculationOutput == nil`.
    await store.send(.viewResultTapped)
  }

  func testViewResultTappedEmitsDelegateWhenOutputIsSuccess() async {
    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth")
    let successOutput = ContributionOutput(totalAmount: Decimal(250))

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID,
        snapshot: snapshot,
        calculationOutput: successOutput)
    ) {
      PortfolioDetailFeature()
    }

    await store.send(.viewResultTapped)
    await store.receive(\.delegate.openCalculationResult)
  }

  func testViewResultTappedIsNoOpWhenOutputHasError() async {
    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth")
    let failureOutput = ContributionOutput.failure(
      ContributionCalculationError.missingPortfolio)

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID,
        snapshot: snapshot,
        calculationOutput: failureOutput,
        lastError: failureOutput.error?.localizedDescription)
    ) {
      PortfolioDetailFeature()
    }

    // Failures must not surface the result sheet — no delegate should fire.
    await store.send(.viewResultTapped)
  }

  // MARK: - .openHistoryTapped

  func testOpenHistoryTappedEmitsOpenHistoryDelegate() async {
    let portfolioID = UUID()
    let snapshot = Self.makeSnapshot(id: portfolioID, name: "Growth")

    let store = TestStore(
      initialState: PortfolioDetailFeature.State(
        portfolioID: portfolioID, snapshot: snapshot)
    ) {
      PortfolioDetailFeature()
    }

    await store.send(.openHistoryTapped)
    await store.receive(\.delegate.openHistory)
  }

  // MARK: - Helpers

  /// Builds a minimal, deterministic `PortfolioDetailSnapshot` directly via
  /// the synthesized memberwise initializer. The snapshot type is `internal`
  /// and its `init(portfolio:)` projection requires a SwiftData `Portfolio`,
  /// so reducer tests construct snapshots by hand to keep cases focused on
  /// the reducer's behavior rather than the projection logic.
  private static func makeSnapshot(
    id: UUID, name: String, canCalculate: Bool = false
  ) -> PortfolioDetailSnapshot {
    PortfolioDetailSnapshot(
      id: id,
      name: name,
      monthlyBudget: Decimal(100),
      maWindow: 50,
      categories: [],
      marketDataCompleteCount: 0,
      marketDataIncompleteCount: 0,
      canCalculate: canCalculate
    )
  }
}
