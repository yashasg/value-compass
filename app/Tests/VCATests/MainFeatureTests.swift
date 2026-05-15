import ComposableArchitecture
import Foundation
import SwiftUI
import XCTest

@testable import VCA

/// `TestStore` coverage for `MainFeature` and `MainFeature+Shell` (issue #190,
/// part of #185).
///
/// Pins the post-onboarding adaptive shell: sidebar selection, iPad detail
/// routing, the path stack on top of compact / iPad detail roots, the size-
/// class → `NavigationShellKind` rule, and the child-delegate routing that
/// ties `PortfolioListFeature` / `PortfolioDetailFeature` /
/// `HoldingsEditorFeature` / `ContributionResultFeature` /
/// `ContributionHistoryFeature` together. `NavigationShellTests` already
/// exercises the static helpers (`shellKind(for:)`,
/// `selectPortfolioDetail(id:in:)`); this file drives the reducer through
/// `Action`s end-to-end.
///
/// `MainFeature.Action` is intentionally not `Equatable` because
/// `StackAction`'s push payload can carry non-`Equatable` values, so each
/// path send below uses the explicit `.path(.element(id:action:))`
/// constructor and asserts state diffs through the reducer mutation closure
/// rather than `await store.receive(_:)`.
@MainActor
final class MainFeatureTests: XCTestCase {
  // MARK: - Sidebar selection

  func testSidebarSelectedSettingsResetsDetailAndPath() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.sidebar = .portfolios
    initialState.detail = .portfolio(portfolioID)
    initialState.detailPortfolio = MainFeature.makeDetailState(id: portfolioID)
    initialState.path.append(
      .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID))
    )

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.sidebarSelected(.settings)) {
      $0.sidebar = .settings
      $0.detail = .settings
      $0.detailPortfolio = nil
      $0.path = StackState()
    }
  }

  func testSidebarSelectedPortfoliosWithNoSelectionShowsEmptyDetail() async {
    var initialState = MainFeature.State()
    initialState.sidebar = .settings
    initialState.detail = .settings

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.sidebarSelected(.portfolios)) {
      $0.sidebar = .portfolios
      $0.detail = .emptyPortfolioSelection
      $0.detailPortfolio = nil
      $0.path = StackState()
    }
  }

  func testSidebarSelectedPortfoliosWithSelectedIDPopulatesDetailPortfolio() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.sidebar = .settings
    initialState.detail = .settings
    initialState.portfolios.selectedPortfolioID = portfolioID

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.sidebarSelected(.portfolios)) {
      $0.sidebar = .portfolios
      $0.detail = .portfolio(portfolioID)
      $0.detailPortfolio = MainFeature.makeDetailState(id: portfolioID)
      $0.path = StackState()
    }
  }

  // MARK: - Detail selection

  func testDetailSelectedPortfolioPopulatesDetailPortfolio() async {
    let portfolioID = UUID()
    let store = TestStore(initialState: MainFeature.State()) { MainFeature() }

    await store.send(.detailSelected(.portfolio(portfolioID))) {
      $0.detail = .portfolio(portfolioID)
      $0.detailPortfolio = MainFeature.makeDetailState(id: portfolioID)
      $0.path = StackState()
    }
  }

  func testDetailSelectedSamePortfolioIsNoOpAndPreservesPath() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.detail = .portfolio(portfolioID)
    initialState.detailPortfolio = MainFeature.makeDetailState(id: portfolioID)
    initialState.path.append(
      .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID))
    )

    let store = TestStore(initialState: initialState) { MainFeature() }

    // Re-selecting the same portfolio is short-circuited by
    // `MainFeature.selectPortfolioDetail(id:in:)` so the existing path push
    // and `detailPortfolio` reducer state stay intact.
    await store.send(.detailSelected(.portfolio(portfolioID)))
  }

  func testDetailSelectedSettingsResetsDetailPortfolioAndPath() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.detail = .portfolio(portfolioID)
    initialState.detailPortfolio = MainFeature.makeDetailState(id: portfolioID)
    initialState.path.append(
      .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID))
    )

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.detailSelected(.settings)) {
      $0.detail = .settings
      $0.detailPortfolio = nil
      $0.path = StackState()
    }
  }

  // MARK: - Shell kind

  func testShellKindChangedStackEnablesPortfolioToolbarSettingsLink() async {
    var initialState = MainFeature.State()
    initialState.shellKind = .splitView
    initialState.portfolios.showsSettingsLink = false

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.shellKindChanged(.stack)) {
      $0.shellKind = .stack
      $0.portfolios.showsSettingsLink = true
    }
  }

  func testShellKindChangedSplitViewDisablesPortfolioToolbarSettingsLink() async {
    var initialState = MainFeature.State()
    initialState.shellKind = .stack
    initialState.portfolios.showsSettingsLink = true

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.shellKindChanged(.splitView)) {
      $0.shellKind = .splitView
      $0.portfolios.showsSettingsLink = false
    }
  }

  // MARK: - Portfolio list → main routing

  func testPortfolioOpenedDelegateOnStackAppendsPortfolioDetailToPath() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.shellKind = .stack

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.portfolios(.delegate(.portfolioOpened(portfolioID)))) {
      $0.path.append(.portfolioDetail(MainFeature.makeDetailState(id: portfolioID)))
    }
  }

  func testPortfolioOpenedDelegateOnSplitViewPopulatesDetailPortfolio() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.sidebar = .settings
    initialState.shellKind = .splitView

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.portfolios(.delegate(.portfolioOpened(portfolioID)))) {
      $0.sidebar = .portfolios
      $0.detail = .portfolio(portfolioID)
      $0.detailPortfolio = MainFeature.makeDetailState(id: portfolioID)
      $0.path = StackState()
    }
  }

  /// HIG → Launching → Quitting (#471): the compact iPhone toolbar
  /// pushes Settings through `MainFeature.path` so the Settings
  /// instance is scoped under `MainFeature` (and through it,
  /// `AppFeature.destination.main`). That scoping is what lets
  /// `SettingsFeature.delegate(.dataErased)` reach `AppFeature` from
  /// the iPhone toolbar entry point.
  func testSettingsOpenRequestedDelegateAppendsSettingsToPath() async {
    var initialState = MainFeature.State()
    initialState.shellKind = .stack

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.portfolios(.delegate(.settingsOpenRequested))) {
      $0.path.append(.settings(SettingsFeature.State()))
    }
  }

  // MARK: - PortfolioDetail delegates from path

  func testPortfolioDetailOpenCalculationResultFromPathAppendsContributionResult() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.shellKind = .stack
    initialState.path.append(.portfolioDetail(MainFeature.makeDetailState(id: portfolioID)))
    let elementID: StackElementID = 0
    let output = ContributionOutput(totalAmount: 1_000)

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(
      .path(
        .element(
          id: elementID,
          action: .portfolioDetail(.delegate(.openCalculationResult(output)))
        )
      )
    ) {
      $0.path.append(
        .contributionResult(
          ContributionResultFeature.State(portfolioID: portfolioID, output: output)
        )
      )
    }
  }

  func testPortfolioDetailOpenHistoryFromPathAppendsContributionHistory() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.shellKind = .stack
    initialState.path.append(.portfolioDetail(MainFeature.makeDetailState(id: portfolioID)))
    let elementID: StackElementID = 0

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(
      .path(
        .element(
          id: elementID,
          action: .portfolioDetail(.delegate(.openHistory(portfolioID: portfolioID)))
        )
      )
    ) {
      $0.path.append(
        .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID))
      )
    }
  }

  // MARK: - PortfolioDetail delegates from detailPortfolio (iPad detail column)

  func testPortfolioDetailOpenCalculationResultFromDetailPortfolioAppendsContributionResult()
    async
  {
    let portfolioID = UUID()
    let output = ContributionOutput(totalAmount: 4_200)
    var initialState = MainFeature.State()
    initialState.shellKind = .splitView
    initialState.detail = .portfolio(portfolioID)
    initialState.detailPortfolio = MainFeature.makeDetailState(id: portfolioID)

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.detailPortfolio(.delegate(.openCalculationResult(output)))) {
      $0.path.append(
        .contributionResult(
          ContributionResultFeature.State(portfolioID: portfolioID, output: output)
        )
      )
    }
  }

  func testPortfolioDetailOpenHistoryFromDetailPortfolioAppendsContributionHistory() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.shellKind = .splitView
    initialState.detail = .portfolio(portfolioID)
    initialState.detailPortfolio = MainFeature.makeDetailState(id: portfolioID)

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(.detailPortfolio(.delegate(.openHistory(portfolioID: portfolioID)))) {
      $0.path.append(
        .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID))
      )
    }
  }

  // MARK: - ContributionResult / ContributionHistory delegates

  func testContributionResultOpenHistoryFromPathAppendsContributionHistory() async {
    let portfolioID = UUID()
    let output = ContributionOutput(totalAmount: 50)
    var initialState = MainFeature.State()
    initialState.shellKind = .stack
    initialState.path.append(.portfolioDetail(MainFeature.makeDetailState(id: portfolioID)))
    initialState.path.append(
      .contributionResult(
        ContributionResultFeature.State(portfolioID: portfolioID, output: output)
      )
    )
    let resultID: StackElementID = 1

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(
      .path(
        .element(
          id: resultID,
          action: .contributionResult(.delegate(.openHistory(portfolioID: portfolioID)))
        )
      )
    ) {
      $0.path.append(
        .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID))
      )
    }
  }

  func testContributionHistoryOpenCalculatePopsBackToPortfolioDetail() async {
    let portfolioID = UUID()
    var initialState = MainFeature.State()
    initialState.shellKind = .stack
    initialState.path.append(.portfolioDetail(MainFeature.makeDetailState(id: portfolioID)))
    initialState.path.append(
      .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID))
    )
    let historyID: StackElementID = 1

    let store = TestStore(initialState: initialState) { MainFeature() }

    await store.send(
      .path(
        .element(
          id: historyID,
          action: .contributionHistory(.delegate(.openCalculate(portfolioID: portfolioID)))
        )
      )
    ) {
      $0.path.removeLast()
    }
  }

  func testContributionHistoryOpenCalculatePopsRepeatedlyUntilPortfolioDetail() async {
    let portfolioID = UUID()
    let output = ContributionOutput(totalAmount: 75)
    var initialState = MainFeature.State()
    initialState.shellKind = .stack
    initialState.path.append(.portfolioDetail(MainFeature.makeDetailState(id: portfolioID)))
    initialState.path.append(
      .contributionResult(
        ContributionResultFeature.State(portfolioID: portfolioID, output: output)
      )
    )
    initialState.path.append(
      .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID))
    )
    let historyID: StackElementID = 2

    let store = TestStore(initialState: initialState) { MainFeature() }

    // The reducer pops elements until the top is a `portfolioDetail`, so a
    // result→history sandwich must collapse all the way back to the detail
    // root in one action.
    await store.send(
      .path(
        .element(
          id: historyID,
          action: .contributionHistory(.delegate(.openCalculate(portfolioID: portfolioID)))
        )
      )
    ) {
      $0.path.removeLast()
      $0.path.removeLast()
    }
  }

  // MARK: - Helpers

  func testShellKindHelperMapsCompactToStack() {
    XCTAssertEqual(MainFeature.shellKind(for: .compact), .stack)
  }

  func testShellKindHelperMapsRegularToSplitView() {
    XCTAssertEqual(MainFeature.shellKind(for: .regular), .splitView)
  }

  func testShellKindHelperMapsNilToSplitView() {
    XCTAssertEqual(MainFeature.shellKind(for: nil), .splitView)
  }
}
