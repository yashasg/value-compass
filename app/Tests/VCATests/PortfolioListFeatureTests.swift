import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import SwiftData
import XCTest

@testable import VCA

/// `TestStore` coverage for `PortfolioListFeature` (issue #191, part of #185).
///
/// Pins the post-onboarding portfolio inventory surface: the `.task` load via
/// `\.modelContainer`, the `selectedPortfolioID` reconciliation rule on
/// `.portfoliosLoaded(_)`, the create / edit / delete flows, the
/// `.selected(id:)` delegate routing, and the editor-saved delegate that
/// re-runs the load. Pairs with `PortfolioEditorFeatureTests` because the
/// list reducer presents the editor via `@Presents` and the parent-side
/// reload behavior on `delegate(.saved)` is asserted here.
@MainActor
final class PortfolioListFeatureTests: XCTestCase {
  // MARK: - .task happy + error paths

  func testTaskWithEmptyContainerLoadsEmptyPortfolios() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)

    let store = TestStore(initialState: PortfolioListFeature.State()) {
      PortfolioListFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    await store.send(.task)
    await store.receive(\.portfoliosLoaded) {
      $0.portfolios = []
    }
  }

  func testTaskWithSeededPortfoliosLoadsNewestFirst() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let olderID = UUID()
    let newerID = UUID()
    let olderDate = Date(timeIntervalSince1970: 1_000_000)
    let newerDate = Date(timeIntervalSince1970: 2_000_000)

    context.insert(
      Portfolio(
        id: olderID, name: "Older", monthlyBudget: Decimal(100), maWindow: 50,
        createdAt: olderDate))
    context.insert(
      Portfolio(
        id: newerID, name: "Newer", monthlyBudget: Decimal(200), maWindow: 200,
        createdAt: newerDate))
    try context.save()

    let newerSnap = PortfolioSnapshot(
      id: newerID, name: "Newer", monthlyBudget: Decimal(200), maWindow: 200,
      createdAt: newerDate, categoryCount: 0)
    let olderSnap = PortfolioSnapshot(
      id: olderID, name: "Older", monthlyBudget: Decimal(100), maWindow: 50,
      createdAt: olderDate, categoryCount: 0)

    let store = TestStore(initialState: PortfolioListFeature.State()) {
      PortfolioListFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    await store.send(.task)
    await store.receive(\.portfoliosLoaded) {
      $0.portfolios = [newerSnap, olderSnap]
    }
  }

  func testTaskWithThrowingContainerFallsBackToEmpty() async {
    struct StubContainerError: Error {}

    let store = TestStore(initialState: PortfolioListFeature.State()) {
      PortfolioListFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubContainerError() }
    }

    await store.send(.task)
    await store.receive(\.portfoliosLoaded) {
      $0.portfolios = []
    }
  }

  // MARK: - .portfoliosLoaded reconciliation

  func testPortfoliosLoadedClearsSelectionWhenNoLongerPresent() async {
    let removedID = UUID()
    var initialState = PortfolioListFeature.State()
    initialState.selectedPortfolioID = removedID

    let store = TestStore(initialState: initialState) {
      PortfolioListFeature()
    }

    await store.send(.portfoliosLoaded([])) {
      $0.portfolios = []
      $0.selectedPortfolioID = nil
    }
  }

  func testPortfoliosLoadedKeepsSelectionWhenStillPresent() async {
    let stayingID = UUID()
    let date = Date(timeIntervalSince1970: 1_500_000)
    let snap = PortfolioSnapshot(
      id: stayingID, name: "Stays", monthlyBudget: Decimal(100), maWindow: 50,
      createdAt: date, categoryCount: 0)
    var initialState = PortfolioListFeature.State()
    initialState.selectedPortfolioID = stayingID

    let store = TestStore(initialState: initialState) {
      PortfolioListFeature()
    }

    await store.send(.portfoliosLoaded([snap])) {
      $0.portfolios = [snap]
    }
  }

  // MARK: - Editor presentation

  func testCreateTappedPresentsEditorInCreateMode() async {
    let store = TestStore(initialState: PortfolioListFeature.State()) {
      PortfolioListFeature()
    }

    await store.send(.createTapped) {
      $0.editor = PortfolioEditorFeature.State(mode: .create)
    }
  }

  func testEditTappedPresentsEditorInEditMode() async {
    let editingID = UUID()
    let store = TestStore(initialState: PortfolioListFeature.State()) {
      PortfolioListFeature()
    }

    await store.send(.editTapped(id: editingID)) {
      $0.editor = PortfolioEditorFeature.State(mode: .edit(editingID))
    }
  }

  // MARK: - .deleteTapped

  func testDeleteTappedRemovesPortfolioAndReloads() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let deletedID = UUID()
    let keptID = UUID()
    let deletedDate = Date(timeIntervalSince1970: 1_000_000)
    let keptDate = Date(timeIntervalSince1970: 2_000_000)

    context.insert(
      Portfolio(
        id: deletedID, name: "Delete me", monthlyBudget: Decimal(100), maWindow: 50,
        createdAt: deletedDate))
    context.insert(
      Portfolio(
        id: keptID, name: "Keep me", monthlyBudget: Decimal(200), maWindow: 200,
        createdAt: keptDate))
    try context.save()

    let keptSnap = PortfolioSnapshot(
      id: keptID, name: "Keep me", monthlyBudget: Decimal(200), maWindow: 200,
      createdAt: keptDate, categoryCount: 0)

    let store = TestStore(initialState: PortfolioListFeature.State()) {
      PortfolioListFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    await store.send(.deleteTapped(id: deletedID))
    await store.receive(\.portfoliosLoaded) {
      $0.portfolios = [keptSnap]
    }
  }

  // MARK: - .selected delegate routing

  func testSelectedSomeIDStoresAndEmitsDelegate() async {
    let openedID = UUID()
    let store = TestStore(initialState: PortfolioListFeature.State()) {
      PortfolioListFeature()
    }

    await store.send(.selected(id: openedID)) {
      $0.selectedPortfolioID = openedID
    }
    await store.receive(\.delegate.portfolioOpened)
  }

  func testSelectedNilStoresAndEmitsNoDelegate() async {
    let priorID = UUID()
    var initialState = PortfolioListFeature.State()
    initialState.selectedPortfolioID = priorID

    let store = TestStore(initialState: initialState) {
      PortfolioListFeature()
    }

    await store.send(.selected(id: nil)) {
      $0.selectedPortfolioID = nil
    }
  }

  // MARK: - editor delegate(.saved) triggers reload

  func testEditorSavedDelegateRefreshesPortfolios() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let savedID = UUID()
    let date = Date(timeIntervalSince1970: 3_000_000)
    context.insert(
      Portfolio(
        id: savedID, name: "Saved", monthlyBudget: Decimal(300), maWindow: 50,
        createdAt: date))
    try context.save()

    var initialState = PortfolioListFeature.State()
    initialState.editor = PortfolioEditorFeature.State(mode: .create)

    let store = TestStore(initialState: initialState) {
      PortfolioListFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    let expectedSnap = PortfolioSnapshot(
      id: savedID, name: "Saved", monthlyBudget: Decimal(300), maWindow: 50,
      createdAt: date, categoryCount: 0)

    await store.send(.editor(.presented(.delegate(.saved(savedID)))))
    await store.receive(\.portfoliosLoaded) {
      $0.portfolios = [expectedSnap]
    }
  }

  // MARK: - .saveErrorDismissed

  func testSaveErrorDismissedClearsSaveError() async {
    var initialState = PortfolioListFeature.State()
    initialState.saveError = "Could not save"

    let store = TestStore(initialState: initialState) {
      PortfolioListFeature()
    }

    await store.send(.saveErrorDismissed) {
      $0.saveError = nil
    }
  }
}
