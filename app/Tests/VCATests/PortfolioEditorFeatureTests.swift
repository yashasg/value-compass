import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import SwiftData
import XCTest

@testable import VCA

/// `TestStore` coverage for `PortfolioEditorFeature` (issue #191, part of
/// #185).
///
/// Pins the create/edit sheet surface: the `.task` no-op in `.create` mode,
/// the hydrate-from-store path in `.edit` mode, every validation branch on
/// `.saveTapped`, the persist happy paths (create + edit), the throwing-
/// container failure path, the `.cancelTapped` dismiss flow, and the
/// `binding` rule that clears `state.validationError` after a previously
/// surfaced error.
@MainActor
final class PortfolioEditorFeatureTests: XCTestCase {
  // MARK: - .task

  func testTaskInCreateModeIsNoOp() async {
    let store = TestStore(
      initialState: PortfolioEditorFeature.State(mode: .create)
    ) {
      PortfolioEditorFeature()
    }

    await store.send(.task)
  }

  func testTaskInEditModeHydratesDraftFromStore() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    context.insert(
      Portfolio(
        id: portfolioID, name: "Growth",
        monthlyBudget: Decimal(string: "1234.5")!, maWindow: 200,
        createdAt: Date(timeIntervalSince1970: 1_000_000)))
    try context.save()

    let store = TestStore(
      initialState: PortfolioEditorFeature.State(mode: .edit(portfolioID))
    ) {
      PortfolioEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    let expectedDraft = PortfolioFormDraft(
      name: "Growth", monthlyBudget: Decimal(string: "1234.5")!, maWindow: 200)

    await store.send(.task)
    await store.receive(\.draftHydrated) {
      $0.draft = expectedDraft
    }
  }

  // MARK: - .saveTapped validation branches

  func testSaveTappedEmptyNameSurfacesValidationError() async {
    let store = TestStore(
      initialState: PortfolioEditorFeature.State(
        mode: .create,
        draft: PortfolioFormDraft(name: "  ", monthlyBudgetText: "100", maWindow: 50))
    ) {
      PortfolioEditorFeature()
    }

    await store.send(.saveTapped)
    await store.receive(\.validationFailed) {
      $0.validationError = .emptyName
    }
  }

  func testSaveTappedInvalidBudgetSurfacesValidationError() async {
    let store = TestStore(
      initialState: PortfolioEditorFeature.State(
        mode: .create,
        draft: PortfolioFormDraft(name: "Growth", monthlyBudgetText: "abc", maWindow: 50))
    ) {
      PortfolioEditorFeature()
    }

    await store.send(.saveTapped)
    await store.receive(\.validationFailed) {
      $0.validationError = .invalidBudget
    }
  }

  func testSaveTappedNonPositiveBudgetSurfacesValidationError() async {
    let store = TestStore(
      initialState: PortfolioEditorFeature.State(
        mode: .create,
        draft: PortfolioFormDraft(name: "Growth", monthlyBudgetText: "0", maWindow: 50))
    ) {
      PortfolioEditorFeature()
    }

    await store.send(.saveTapped)
    await store.receive(\.validationFailed) {
      $0.validationError = .invalidBudget
    }
  }

  func testSaveTappedInvalidMAWindowSurfacesValidationError() async {
    let store = TestStore(
      initialState: PortfolioEditorFeature.State(
        mode: .create,
        draft: PortfolioFormDraft(name: "Growth", monthlyBudgetText: "100", maWindow: 99))
    ) {
      PortfolioEditorFeature()
    }

    await store.send(.saveTapped)
    await store.receive(\.validationFailed) {
      $0.validationError = .invalidMAWindow(99)
    }
  }

  // MARK: - .saveTapped happy paths

  func testSaveTappedCreatesPortfolioAndDismisses() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let dismissCalls = LockIsolated(0)

    let store = TestStore(
      initialState: PortfolioEditorFeature.State(
        mode: .create,
        draft: PortfolioFormDraft(name: "Growth", monthlyBudgetText: "1000", maWindow: 50))
    ) {
      PortfolioEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
      $0.dismiss = DismissEffect { dismissCalls.withValue { $0 += 1 } }
    }

    await store.send(.saveTapped)
    await store.receive(\.savedSuccessfully)
    await store.receive(\.delegate.saved)

    XCTAssertEqual(dismissCalls.value, 1)

    let context = container.mainContext
    let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
    XCTAssertEqual(portfolios.count, 1)
    XCTAssertEqual(portfolios.first?.name, "Growth")
    XCTAssertEqual(portfolios.first?.monthlyBudget, Decimal(1000))
    XCTAssertEqual(portfolios.first?.maWindow, 50)
  }

  func testSaveTappedUpdatesPortfolioAndDismisses() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    context.insert(
      Portfolio(
        id: portfolioID, name: "Old Name",
        monthlyBudget: Decimal(100), maWindow: 50,
        createdAt: Date(timeIntervalSince1970: 1_000_000)))
    try context.save()

    let dismissCalls = LockIsolated(0)
    let store = TestStore(
      initialState: PortfolioEditorFeature.State(
        mode: .edit(portfolioID),
        draft: PortfolioFormDraft(name: "New Name", monthlyBudgetText: "500", maWindow: 200))
    ) {
      PortfolioEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
      $0.dismiss = DismissEffect { dismissCalls.withValue { $0 += 1 } }
    }

    await store.send(.saveTapped)
    await store.receive(\.savedSuccessfully)
    await store.receive(\.delegate.saved)

    XCTAssertEqual(dismissCalls.value, 1)

    let updated = try context.fetch(
      FetchDescriptor<Portfolio>(predicate: #Predicate { $0.id == portfolioID })
    ).first
    XCTAssertEqual(updated?.name, "New Name")
    XCTAssertEqual(updated?.monthlyBudget, Decimal(500))
    XCTAssertEqual(updated?.maWindow, 200)
  }

  // MARK: - .saveTapped persistence failure

  func testSaveTappedWithThrowingContainerSurfacesSaveError() async {
    struct BoomError: LocalizedError {
      var errorDescription: String? { "boom!" }
    }

    let store = TestStore(
      initialState: PortfolioEditorFeature.State(
        mode: .create,
        draft: PortfolioFormDraft(name: "Growth", monthlyBudgetText: "1000", maWindow: 50))
    ) {
      PortfolioEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw BoomError() }
    }

    await store.send(.saveTapped)
    await store.receive(\.saveFailed) {
      $0.saveError = "boom!"
    }
  }

  // MARK: - .cancelTapped

  func testCancelTappedEmitsDelegateAndDismisses() async {
    let dismissCalls = LockIsolated(0)
    let store = TestStore(
      initialState: PortfolioEditorFeature.State(mode: .create)
    ) {
      PortfolioEditorFeature()
    } withDependencies: {
      $0.dismiss = DismissEffect { dismissCalls.withValue { $0 += 1 } }
    }

    await store.send(.cancelTapped)
    await store.receive(\.delegate.canceled)

    XCTAssertEqual(dismissCalls.value, 1)
  }

  // MARK: - binding clears validation error

  func testBindingClearsPriorValidationError() async {
    var initialState = PortfolioEditorFeature.State(
      mode: .create,
      draft: PortfolioFormDraft(name: "", monthlyBudgetText: "100", maWindow: 50))
    initialState.validationError = .emptyName

    let store = TestStore(initialState: initialState) {
      PortfolioEditorFeature()
    }

    await store.send(.binding(.set(\.draft.name, "Growth"))) {
      $0.draft.name = "Growth"
      $0.validationError = nil
    }
  }
}
