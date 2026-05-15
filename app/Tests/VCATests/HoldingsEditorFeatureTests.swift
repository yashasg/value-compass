import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import SwiftData
import XCTest

@testable import VCA

/// `TestStore` coverage for `HoldingsEditorFeature` (issue #193, part of
/// #185).
///
/// Pins the holdings editor reducer:
///
/// - `.task` no-op when the legacy `init(portfolio:)` bridge has pre-seeded
///   `state.draft`, the happy path that loads via
///   `\.modelContainer.task` + `BackgroundModelActor.loadHoldingsDraft`,
///   and the throwing-container failure that surfaces via
///   `state.saveError`.
/// - Every add / delete / move action against `HoldingsDraft` /
///   `CategoryDraft` (including the `firstIndex(where:)` guards that no-op
///   on a bogus `categoryID`).
/// - The `.binding(_)` recompute rule that keeps `state.issues` in sync
///   with per-row text edits (covered through a top-level `\.draft`
///   binding which also exercises the `BindingReducer` write).
/// - `.saveTapped` happy path through `BackgroundModelActor.applyHoldingsDraft`,
///   the throwing-container failure path that writes `state.saveError`,
///   and the `.saveSucceeded` → `.delegate(.saved)` follow-up.
/// - `.saveErrorDismissed`, `.revertTapped` happy + failure paths, and the
///   `.delegate` no-op terminator.
@MainActor
final class HoldingsEditorFeatureTests: XCTestCase {
  // MARK: - .task

  func testTaskIsNoOpWhenStateIsPreSeeded() async {
    // The legacy `init(portfolio:)` bridge synchronously seeds
    // `state.draft`, so the reducer's guard short-circuits and never hits
    // the async loader.
    let portfolioID = UUID()
    let categoryID = UUID()
    let preSeededDraft = HoldingsDraft(categories: [
      Self.makeValidCategory(id: categoryID)
    ])
    let state = HoldingsEditorFeature.State(
      portfolioID: portfolioID, draft: preSeededDraft)

    let store = TestStore(initialState: state) {
      HoldingsEditorFeature()
    }

    // No `.draftLoaded` and no `.loadFailed` should be received because the
    // guard returns `.none` before the dependency is touched.
    await store.send(.task)
  }

  func testTaskWithEmptyStateLoadsDraftFromContainer() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    let categoryID = UUID()
    let tickerID = UUID()
    context.insert(
      Portfolio(
        id: portfolioID, name: "Growth",
        monthlyBudget: Decimal(500), maWindow: 50,
        createdAt: Date(timeIntervalSince1970: 1_000_000),
        categories: [
          Category(
            id: categoryID, name: "US Stocks",
            weight: Decimal(string: "1.0")!, sortOrder: 0,
            tickers: [
              Ticker(
                id: tickerID, symbol: "VTI",
                currentPrice: Decimal(300), movingAverage: Decimal(280),
                sortOrder: 0)
            ])
        ]))
    try context.save()

    // The reducer's `.task` guard requires both `categories.isEmpty` and
    // `state.issues.isEmpty`. The synthesized `init(...)` always derives
    // `issues = draft.issues()` so an empty draft seeds `[.noCategories]`.
    // Force-clear `state.issues` so the load actually runs (mirrors the
    // host pushing a freshly-built state).
    var state = HoldingsEditorFeature.State(portfolioID: portfolioID)
    state.issues = []

    let store = TestStore(initialState: state) {
      HoldingsEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    let expectedDraft = HoldingsDraft(categories: [
      CategoryDraft(
        id: categoryID,
        name: "US Stocks",
        weightPercentText: "100",
        sortOrder: 0,
        tickers: [
          TickerDraft(
            id: tickerID,
            symbol: "VTI",
            currentPrice: Decimal(300),
            movingAverage: Decimal(280),
            bandPosition: nil,
            sortOrder: 0)
        ])
    ])

    await store.send(.task)
    await store.receive(.draftLoaded(expectedDraft)) {
      $0.draft = expectedDraft
      $0.issues = expectedDraft.issues()
      $0.saveError = nil
    }
  }

  func testTaskWithThrowingContainerWritesSaveError() async {
    struct StubError: LocalizedError, Equatable {
      var errorDescription: String? { "boom" }
    }

    let portfolioID = UUID()
    var state = HoldingsEditorFeature.State(portfolioID: portfolioID)
    state.issues = []

    let store = TestStore(initialState: state) {
      HoldingsEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubError() }
    }

    await store.send(.task)
    await store.receive(.loadFailed("boom")) {
      $0.saveError = "boom"
    }
  }

  // MARK: - Mutations: addCategory / deleteCategory / moveCategory

  func testAddCategoryTappedAppendsCategoryAndRecomputesIssues() async {
    let portfolioID = UUID()
    let store = TestStore(
      initialState: HoldingsEditorFeature.State(portfolioID: portfolioID)
    ) {
      HoldingsEditorFeature()
    }
    // `HoldingsDraft.addCategory()` generates a fresh `UUID()` directly
    // (no `@Dependency(\.uuid)` indirection), so the closure form would
    // diverge from the reducer's UUID. Disable exhaustivity and assert the
    // observable structure of the resulting state explicitly.
    store.exhaustivity = .off

    await store.send(.addCategoryTapped)

    XCTAssertEqual(store.state.draft.categories.count, 1)
    XCTAssertEqual(store.state.draft.categories[0].name, "")
    XCTAssertEqual(store.state.draft.categories[0].weightPercentText, "100")
    XCTAssertEqual(store.state.draft.categories[0].sortOrder, 0)
    XCTAssertTrue(store.state.draft.categories[0].tickers.isEmpty)
    XCTAssertEqual(store.state.issues, store.state.draft.issues())
  }

  func testDeleteCategoryRemovesCategoryAndRecomputesIssues() async {
    let portfolioID = UUID()
    let categoryID = UUID()
    let draft = HoldingsDraft(categories: [
      Self.makeValidCategory(id: categoryID)
    ])

    let store = TestStore(
      initialState: HoldingsEditorFeature.State(
        portfolioID: portfolioID, draft: draft)
    ) {
      HoldingsEditorFeature()
    }

    await store.send(.deleteCategory(id: categoryID)) {
      $0.draft.deleteCategory(id: categoryID)
      $0.issues = $0.draft.issues()
    }
  }

  func testMoveCategoryReordersCategoriesAndRecomputesIssues() async {
    let portfolioID = UUID()
    let firstID = UUID()
    let secondID = UUID()
    let draft = HoldingsDraft(categories: [
      CategoryDraft(
        id: firstID, name: "US",
        weightPercentText: "60", sortOrder: 0,
        tickers: [
          TickerDraft(
            symbol: "VTI",
            currentPrice: Decimal(300), movingAverage: Decimal(280),
            sortOrder: 0)
        ]),
      CategoryDraft(
        id: secondID, name: "Bonds",
        weightPercentText: "40", sortOrder: 1,
        tickers: [
          TickerDraft(
            symbol: "BND",
            currentPrice: Decimal(75), movingAverage: Decimal(72),
            sortOrder: 0)
        ]),
    ])

    let store = TestStore(
      initialState: HoldingsEditorFeature.State(
        portfolioID: portfolioID, draft: draft)
    ) {
      HoldingsEditorFeature()
    }

    await store.send(.moveCategory(id: secondID, direction: .up)) {
      $0.draft.moveCategory(id: secondID, direction: .up)
      $0.issues = $0.draft.issues()
    }
  }

  // MARK: - Mutations: addTicker / deleteTicker / moveTicker

  func testAddTickerInsertsTickerIntoNamedCategoryAndRecomputesIssues() async {
    let portfolioID = UUID()
    let categoryID = UUID()
    let draft = HoldingsDraft(categories: [
      CategoryDraft(
        id: categoryID, name: "US",
        weightPercentText: "100", sortOrder: 0, tickers: [])
    ])

    let store = TestStore(
      initialState: HoldingsEditorFeature.State(
        portfolioID: portfolioID, draft: draft)
    ) {
      HoldingsEditorFeature()
    }
    // `CategoryDraft.addTicker()` generates a fresh `UUID()` directly, so
    // the closure form would diverge from the reducer's UUID. Disable
    // exhaustivity and assert the observable structure of the resulting
    // ticker explicitly.
    store.exhaustivity = .off

    await store.send(.addTicker(categoryID: categoryID))

    XCTAssertEqual(store.state.draft.categories.count, 1)
    XCTAssertEqual(store.state.draft.categories[0].id, categoryID)
    XCTAssertEqual(store.state.draft.categories[0].tickers.count, 1)
    XCTAssertEqual(store.state.draft.categories[0].tickers[0].symbol, "")
    XCTAssertEqual(store.state.draft.categories[0].tickers[0].sortOrder, 0)
    XCTAssertEqual(store.state.issues, store.state.draft.issues())
  }

  func testAddTickerWithBogusCategoryIDIsNoOp() async {
    let portfolioID = UUID()
    let categoryID = UUID()
    let draft = HoldingsDraft(categories: [
      Self.makeValidCategory(id: categoryID)
    ])

    let store = TestStore(
      initialState: HoldingsEditorFeature.State(
        portfolioID: portfolioID, draft: draft)
    ) {
      HoldingsEditorFeature()
    }

    // Bogus id generated *after* the seed category so the
    // `firstIndex(where:)` guard returns nil and the reducer no-ops.
    let bogusID = UUID()
    await store.send(.addTicker(categoryID: bogusID))
  }

  func testDeleteTickerRemovesTickerAndRecomputesIssues() async {
    let portfolioID = UUID()
    let categoryID = UUID()
    let firstTickerID = UUID()
    let secondTickerID = UUID()
    let draft = HoldingsDraft(categories: [
      CategoryDraft(
        id: categoryID, name: "US",
        weightPercentText: "100", sortOrder: 0,
        tickers: [
          TickerDraft(
            id: firstTickerID, symbol: "VTI",
            currentPrice: Decimal(300), movingAverage: Decimal(280),
            sortOrder: 0),
          TickerDraft(
            id: secondTickerID, symbol: "VXUS",
            currentPrice: Decimal(60), movingAverage: Decimal(58),
            sortOrder: 1),
        ])
    ])

    let store = TestStore(
      initialState: HoldingsEditorFeature.State(
        portfolioID: portfolioID, draft: draft)
    ) {
      HoldingsEditorFeature()
    }

    await store.send(.deleteTicker(categoryID: categoryID, tickerID: secondTickerID)) {
      $0.draft.categories[0].deleteTicker(id: secondTickerID)
      $0.issues = $0.draft.issues()
    }
  }

  func testMoveTickerReordersTickersWithinCategoryAndRecomputesIssues() async {
    let portfolioID = UUID()
    let categoryID = UUID()
    let firstTickerID = UUID()
    let secondTickerID = UUID()
    let draft = HoldingsDraft(categories: [
      CategoryDraft(
        id: categoryID, name: "US",
        weightPercentText: "100", sortOrder: 0,
        tickers: [
          TickerDraft(
            id: firstTickerID, symbol: "VTI",
            currentPrice: Decimal(300), movingAverage: Decimal(280),
            sortOrder: 0),
          TickerDraft(
            id: secondTickerID, symbol: "VXUS",
            currentPrice: Decimal(60), movingAverage: Decimal(58),
            sortOrder: 1),
        ])
    ])

    let store = TestStore(
      initialState: HoldingsEditorFeature.State(
        portfolioID: portfolioID, draft: draft)
    ) {
      HoldingsEditorFeature()
    }

    await store.send(
      .moveTicker(categoryID: categoryID, tickerID: secondTickerID, direction: .up)
    ) {
      $0.draft.categories[0].moveTicker(id: secondTickerID, direction: .up)
      $0.issues = $0.draft.issues()
    }
  }

  // MARK: - .binding (per-row text edits)

  func testBindingRecomputesIssuesAfterDraftMutation() async {
    // Per-row text edits all funnel through the BindingReducer because every
    // editable field is bound via `@Bindable var store`. Drive a top-level
    // `\.draft` binding so we exercise both the BindingReducer write and
    // the reducer's recompute rule in a single step.
    let portfolioID = UUID()
    let store = TestStore(
      initialState: HoldingsEditorFeature.State(portfolioID: portfolioID)
    ) {
      HoldingsEditorFeature()
    }

    var newDraft = HoldingsDraft()
    newDraft.addCategory()
    let expectedIssues = newDraft.issues()

    await store.send(.binding(.set(\.draft, newDraft))) {
      $0.draft = newDraft
      $0.issues = expectedIssues
    }
  }

  // MARK: - .saveTapped / .saveSucceeded / .saveFailed / .saveErrorDismissed

  func testSaveTappedHappyPathPersistsAndDelegatesSaved() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    let categoryID = UUID()
    let tickerID = UUID()
    context.insert(
      Portfolio(
        id: portfolioID, name: "Growth",
        monthlyBudget: Decimal(500), maWindow: 50,
        createdAt: Date(timeIntervalSince1970: 1_000_000)))
    try context.save()

    let validDraft = HoldingsDraft(categories: [
      CategoryDraft(
        id: categoryID, name: "US Stocks",
        weightPercentText: "100", sortOrder: 0,
        tickers: [
          TickerDraft(
            id: tickerID, symbol: "VTI",
            currentPrice: Decimal(300), movingAverage: Decimal(280),
            sortOrder: 0)
        ])
    ])

    let store = TestStore(
      initialState: HoldingsEditorFeature.State(
        portfolioID: portfolioID, draft: validDraft)
    ) {
      HoldingsEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    await store.send(.saveTapped)
    // `.saveSucceeded` clears `state.saveError` (already nil) and chains
    // into `.delegate(.saved)` which the host listens for to dismiss.
    await store.receive(.saveSucceeded)
    await store.receive(\.delegate.saved)
  }

  func testSaveTappedFailurePathWritesSaveError() async {
    struct StubError: LocalizedError, Equatable {
      var errorDescription: String? { "save kaboom" }
    }

    let portfolioID = UUID()
    let categoryID = UUID()
    let validDraft = HoldingsDraft(categories: [
      Self.makeValidCategory(id: categoryID)
    ])

    let store = TestStore(
      initialState: HoldingsEditorFeature.State(
        portfolioID: portfolioID, draft: validDraft)
    ) {
      HoldingsEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubError() }
    }

    await store.send(.saveTapped)
    await store.receive(.saveFailed("save kaboom")) {
      $0.saveError = "save kaboom"
    }
  }

  func testSaveErrorDismissedClearsSaveError() async {
    let portfolioID = UUID()
    var state = HoldingsEditorFeature.State(portfolioID: portfolioID)
    state.saveError = "stale error"

    let store = TestStore(initialState: state) {
      HoldingsEditorFeature()
    }

    await store.send(.saveErrorDismissed) {
      $0.saveError = nil
    }
  }

  // MARK: - .revertTapped / .revertLoaded

  func testRevertTappedHappyPathReloadsDraftAndClearsSaveError() async throws {
    let container = try LocalPersistence.makeModelContainer(isStoredInMemoryOnly: true)
    let context = container.mainContext

    let portfolioID = UUID()
    let canonicalCategoryID = UUID()
    let canonicalTickerID = UUID()
    context.insert(
      Portfolio(
        id: portfolioID, name: "Growth",
        monthlyBudget: Decimal(500), maWindow: 50,
        createdAt: Date(timeIntervalSince1970: 1_000_000),
        categories: [
          Category(
            id: canonicalCategoryID, name: "Bonds",
            weight: Decimal(string: "1.0")!, sortOrder: 0,
            tickers: [
              Ticker(
                id: canonicalTickerID, symbol: "BND",
                currentPrice: Decimal(75), movingAverage: Decimal(72),
                sortOrder: 0)
            ])
        ]))
    try context.save()

    // Start with a divergent in-memory draft + a stale saveError so we can
    // assert the revert reload overwrites both.
    let dirtyDraft = HoldingsDraft(categories: [
      CategoryDraft(
        id: UUID(), name: "Stale",
        weightPercentText: "50", sortOrder: 0, tickers: [])
    ])
    let state = HoldingsEditorFeature.State(
      portfolioID: portfolioID, draft: dirtyDraft, saveError: "stale")

    let store = TestStore(initialState: state) {
      HoldingsEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { container }
    }

    let expectedDraft = HoldingsDraft(categories: [
      CategoryDraft(
        id: canonicalCategoryID,
        name: "Bonds",
        weightPercentText: "100",
        sortOrder: 0,
        tickers: [
          TickerDraft(
            id: canonicalTickerID,
            symbol: "BND",
            currentPrice: Decimal(75),
            movingAverage: Decimal(72),
            bandPosition: nil,
            sortOrder: 0)
        ])
    ])

    await store.send(.revertTapped)
    await store.receive(.revertLoaded(expectedDraft)) {
      $0.draft = expectedDraft
      $0.issues = expectedDraft.issues()
      $0.saveError = nil
    }
  }

  func testRevertTappedFailurePathWritesSaveError() async {
    struct StubError: LocalizedError, Equatable {
      var errorDescription: String? { "revert kaboom" }
    }

    let portfolioID = UUID()
    let categoryID = UUID()
    let store = TestStore(
      initialState: HoldingsEditorFeature.State(
        portfolioID: portfolioID,
        draft: HoldingsDraft(categories: [Self.makeValidCategory(id: categoryID)]))
    ) {
      HoldingsEditorFeature()
    } withDependencies: {
      $0.modelContainer.container = { throw StubError() }
    }

    await store.send(.revertTapped)
    await store.receive(.loadFailed("revert kaboom")) {
      $0.saveError = "revert kaboom"
    }
  }

  // MARK: - .delegate terminator

  func testDelegateActionsAreReducerNoOps() async {
    let portfolioID = UUID()
    let store = TestStore(
      initialState: HoldingsEditorFeature.State(portfolioID: portfolioID)
    ) {
      HoldingsEditorFeature()
    }

    // The reducer treats `.delegate` as a terminator (host listens). Both
    // `.saved` and `.canceled` must be reducer no-ops.
    await store.send(.delegate(.saved))
    await store.send(.delegate(.canceled))
  }

  // MARK: - Helpers

  /// Returns a single-category draft that produces zero `HoldingsDraftIssue`s
  /// (well-formed name, full 100% weight, one fully-priced ticker). Used by
  /// tests that need a non-empty `state.draft` but don't care about the
  /// underlying ticker symbol.
  private static func makeValidCategory(id: UUID) -> CategoryDraft {
    CategoryDraft(
      id: id,
      name: "US Stocks",
      weightPercentText: "100",
      sortOrder: 0,
      tickers: [
        TickerDraft(
          symbol: "VTI",
          currentPrice: Decimal(300),
          movingAverage: Decimal(280),
          sortOrder: 0)
      ])
  }
}
