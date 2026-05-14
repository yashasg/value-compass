import ComposableArchitecture
import Foundation

/// Post-onboarding shell reducer that owns adaptive navigation: an iPhone
/// `NavigationStack` driven by `path`, and an iPad `NavigationSplitView` over
/// a sidebar (`Portfolios` / `Settings`), a content column scoped from
/// `portfolios` / `settings`, and a detail column rooted in `detailPortfolio`
/// (when a portfolio is selected) or `settings` (when the sidebar shows
/// settings).
///
/// Phase 0 (#149) introduced the reducer skeleton and navigation enums.
/// Phase 1 (#150–#157) replaced the placeholder child reducers with real
/// implementations. Phase 2 (#159) — this revision — wires Phase 1 child
/// delegates into `path` / `detailPortfolio` / `detail` so `MainView` is
/// driven entirely by the reducer (no `@Query` / navigation-`@State` needed)
/// and the iPhone stack and iPad split view share a single source of truth.
@Reducer
struct MainFeature {
  @ObservableState
  struct State: Equatable {
    /// iPad sidebar selection. Compact (iPhone) ignores this; the toolbar's
    /// own `NavigationLink { SettingsView() }` keeps powering the compact
    /// settings push because Phase 1 (#152) deliberately kept that
    /// presentation MVVM-style for the empty-detail case.
    var sidebar: Sidebar = .portfolios

    /// Source of truth for the iPad content column when sidebar = portfolios
    /// and for the compact stack root.
    var portfolios = PortfolioListFeature.State()

    /// Source of truth for the iPad content column when sidebar = settings
    /// and for the iPad detail column when sidebar = settings.
    var settings = SettingsFeature.State()

    /// Stack pushed on top of the compact root (iPhone) or on top of the
    /// iPad detail column root (`detailPortfolio` / settings). Reused for
    /// both shells so child delegate routing is shell-agnostic.
    var path = StackState<Path.State>()

    /// What the iPad detail column shows at the root. Compact mode ignores
    /// this — the same selection lives at the bottom of `path` instead.
    var detail: Detail = .emptyPortfolioSelection

    /// PortfolioDetailFeature scoped under the iPad detail column root when
    /// `detail == .portfolio(id)`. Compact mode keeps this `nil`; the same
    /// state lives inside `path[0]` (`.portfolioDetail(...)`) instead.
    var detailPortfolio: PortfolioDetailFeature.State?

    /// Adaptive shell currently rendered by `MainView`. The view sets this
    /// from `@Environment(\.horizontalSizeClass)` via `.shellKindChanged(_:)`
    /// so the reducer can route portfolio selection to the right surface
    /// (push onto `path` for compact, set `detailPortfolio` + `detail` for
    /// regular) without inspecting SwiftUI environment values itself.
    var shellKind: NavigationShellKind = .splitView
  }

  /// Sidebar slot in the iPad split view.
  enum Sidebar: String, Hashable, CaseIterable, Identifiable {
    case portfolios
    case settings
    var id: String { rawValue }
  }

  /// Currently shown detail pane in the iPad split view.
  @CasePathable
  enum Detail: Equatable {
    case portfolio(UUID)
    case settings
    case emptyPortfolioSelection
  }

  /// Pushable destinations rendered on top of the compact stack root or the
  /// iPad detail column root. The `@Reducer` macro generates `Path.State` /
  /// `Path.Action` automatically.
  @Reducer
  enum Path {
    case portfolioDetail(PortfolioDetailFeature)
    case holdingsEditor(HoldingsEditorFeature)
    case contributionResult(ContributionResultFeature)
    case contributionHistory(ContributionHistoryFeature)
    case settings(SettingsFeature)
  }

  /// Note: `Action` intentionally does not conform to `Equatable`. The
  /// `path(StackActionOf<Path>)` case wraps `StackAction`, which is not
  /// `Equatable` in TCA 1.x because its `.push` payload can carry non-
  /// `Equatable` presentation values. State remains `Equatable` so the
  /// reducer is testable.
  enum Action {
    case sidebarSelected(Sidebar)
    case detailSelected(Detail)
    case shellKindChanged(NavigationShellKind)
    case path(StackActionOf<Path>)
    case portfolios(PortfolioListFeature.Action)
    case settings(SettingsFeature.Action)
    case detailPortfolio(PortfolioDetailFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.portfolios, action: \.portfolios) {
      PortfolioListFeature()
    }
    Scope(state: \.settings, action: \.settings) {
      SettingsFeature()
    }
    Reduce { state, action in
      switch action {
      case .sidebarSelected(let sidebar):
        state.sidebar = sidebar
        switch sidebar {
        case .settings:
          state.detail = .settings
          state.detailPortfolio = nil
          state.path = StackState()
        case .portfolios:
          if let id = state.portfolios.selectedPortfolioID {
            MainFeature.selectPortfolioDetail(id: id, in: &state)
          } else {
            state.detail = .emptyPortfolioSelection
            state.detailPortfolio = nil
            state.path = StackState()
          }
        }
        return .none

      case .detailSelected(let detail):
        switch detail {
        case .portfolio(let id):
          MainFeature.selectPortfolioDetail(id: id, in: &state)
        case .settings, .emptyPortfolioSelection:
          state.detail = detail
          state.detailPortfolio = nil
          state.path = StackState()
        }
        return .none

      case .shellKindChanged(let kind):
        state.shellKind = kind
        // The PortfolioListView's toolbar settings link only renders in the
        // compact stack — on iPad the sidebar already exposes settings, so
        // the toolbar link would duplicate it.
        state.portfolios.showsSettingsLink = (kind == .stack)
        return .none

      case .portfolios(.delegate(.portfolioOpened(let id))):
        // Selecting a portfolio in the list routes to the right surface
        // depending on which shell the view layer is rendering.
        switch state.shellKind {
        case .stack:
          state.path.append(.portfolioDetail(MainFeature.makeDetailState(id: id)))
        case .splitView:
          state.sidebar = .portfolios
          MainFeature.selectPortfolioDetail(id: id, in: &state)
        }
        return .none

      // PortfolioDetailFeature delegates from inside the path stack
      // (compact mode and iPad pushes off the detail root).
      case .path(
        .element(let id, .portfolioDetail(.delegate(.openHoldingsEditor(let portfolioID))))):
        _ = id
        state.path.append(.holdingsEditor(HoldingsEditorFeature.State(portfolioID: portfolioID)))
        return .none

      case .path(
        .element(let id, .portfolioDetail(.delegate(.openCalculationResult(let output))))):
        if let element = state.path[id: id],
          case .portfolioDetail(let detailState) = element
        {
          state.path.append(
            .contributionResult(
              ContributionResultFeature.State(
                portfolioID: detailState.portfolioID, output: output)))
        }
        return .none

      case .path(.element(let id, .portfolioDetail(.delegate(.openHistory(let portfolioID))))):
        _ = id
        state.path.append(
          .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID)))
        return .none

      // PortfolioDetailFeature delegates from the iPad detail column root
      // (`detailPortfolio`, never reached on iPhone compact).
      case .detailPortfolio(.delegate(.openHoldingsEditor(let portfolioID))):
        state.path.append(.holdingsEditor(HoldingsEditorFeature.State(portfolioID: portfolioID)))
        return .none

      case .detailPortfolio(.delegate(.openCalculationResult(let output))):
        if let detailState = state.detailPortfolio {
          state.path.append(
            .contributionResult(
              ContributionResultFeature.State(
                portfolioID: detailState.portfolioID, output: output)))
        }
        return .none

      case .detailPortfolio(.delegate(.openHistory(let portfolioID))):
        state.path.append(
          .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID)))
        return .none

      case .detailPortfolio:
        return .none

      // ContributionResultFeature → push history.
      case .path(.element(_, .contributionResult(.delegate(.openHistory(let portfolioID))))):
        state.path.append(
          .contributionHistory(ContributionHistoryFeature.State(portfolioID: portfolioID)))
        return .none

      // ContributionHistoryFeature → pop back to the originating
      // PortfolioDetail so the user can run the calculator again.
      case .path(.element(_, .contributionHistory(.delegate(.openCalculate)))):
        while let last = state.path.last, !last.isPortfolioDetail {
          state.path.removeLast()
        }
        return .none

      // HoldingsEditorFeature → pop after save / cancel so the surrounding
      // PortfolioDetail picks up the refreshed snapshot via its `.task`.
      case .path(.element(_, .holdingsEditor(.delegate))):
        if state.path.last?.isHoldingsEditor == true {
          state.path.removeLast()
        }
        return .none

      case .path, .portfolios, .settings:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
    .ifLet(\.detailPortfolio, action: \.detailPortfolio) {
      PortfolioDetailFeature()
    }
  }

  /// Builds an empty `PortfolioDetailFeature.State` for `id`. The reducer
  /// then reloads the real snapshot via `PortfolioDetailFeature.task` so
  /// the compact stack and iPad detail column do not block on a synchronous
  /// SwiftData fetch at the call site.
  static func makeDetailState(id: UUID) -> PortfolioDetailFeature.State {
    PortfolioDetailFeature.State(
      portfolioID: id,
      snapshot: PortfolioDetailSnapshot(
        id: id,
        name: "",
        monthlyBudget: 0,
        maWindow: 0,
        categories: [],
        marketDataCompleteCount: 0,
        marketDataIncompleteCount: 0,
        canCalculate: false
      )
    )
  }

  /// Routes the iPad detail column to `id`, reusing the existing
  /// `detailPortfolio` reducer state (and any path push on top of it) when
  /// the same portfolio is re-selected. Without this guard, every sidebar /
  /// list re-selection would replace `detailPortfolio` with a freshly built
  /// empty stub — `PortfolioDetailFeature` would then have to reload the
  /// snapshot asynchronously, the user would see a flash of empty content,
  /// and any in-flight reducer state (e.g. an open holdings editor on top of
  /// the detail root) would be discarded.
  static func selectPortfolioDetail(id: UUID, in state: inout State) {
    if state.detailPortfolio?.portfolioID == id, state.detail == .portfolio(id) {
      return
    }
    state.detail = .portfolio(id)
    state.detailPortfolio = MainFeature.makeDetailState(id: id)
    state.path = StackState()
  }
}

/// `@Reducer` on an `enum` generates `Path.State` and `Path.Action` enums but
/// does not add `Equatable`/`Sendable` conformance automatically. We add both
/// here so `MainFeature.State` (which holds `StackState<Path.State>`) can
/// synthesize `Equatable` and so the macro-generated `CaseScope` closures do
/// not produce data-race warnings.
extension MainFeature.Path.State: Equatable {}
extension MainFeature.Path.State: Sendable {}
extension MainFeature.Path.Action: Sendable {}

extension MainFeature.Path.State {
  /// Helpers used by the path-pop logic in `MainFeature.body`. Kept here so
  /// the reducer body avoids long inline pattern matches and stays readable.
  fileprivate var isPortfolioDetail: Bool {
    if case .portfolioDetail = self { return true }
    return false
  }

  fileprivate var isHoldingsEditor: Bool {
    if case .holdingsEditor = self { return true }
    return false
  }
}
