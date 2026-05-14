import ComposableArchitecture
import Foundation

/// Post-onboarding shell reducer that mirrors what `MainView` does today: an
/// iPhone `NavigationStack` and an iPad `NavigationSplitView` over a sidebar
/// (`Portfolios` / `Settings`) and a detail (`PortfolioDetail` or
/// `SettingsView`).
///
/// Phase 0 (issue #149): only the reducer skeleton + navigation enums. The
/// child feature reducers (`PortfolioListFeature`, `PortfolioDetailFeature`,
/// `SettingsFeature`, …) are Phase 1 issues and are referenced here as empty
/// `@Reducer` placeholders so this PR compiles in isolation. Phase 2 (#159)
/// wires this reducer into the actual navigation views.
@Reducer
struct MainFeature {
  @ObservableState
  struct State: Equatable {
    var sidebar: Sidebar = .portfolios
    var portfolios = PortfolioListFeature.State()
    var settings = SettingsFeature.State()
    var path = StackState<Path.State>()
    var detail: Detail = .emptyPortfolioSelection
  }

  /// Sidebar slot in the iPad split view; mirrors
  /// `MainView.SidebarSelection`.
  enum Sidebar: String, Hashable, CaseIterable, Identifiable {
    case portfolios
    case settings
    var id: String { rawValue }
  }

  /// Currently shown detail pane in the iPad split view; mirrors
  /// `MainView.DetailSelection`.
  @CasePathable
  enum Detail: Equatable {
    case portfolio(UUID)
    case settings
    case emptyPortfolioSelection
  }

  /// Pushable iPhone-stack destinations. Each case wraps a placeholder Phase 1
  /// reducer until #150–#157 land; the `@Reducer` macro generates `Path.State`
  /// and `Path.Action` automatically.
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
    case path(StackActionOf<Path>)
    case portfolios(PortfolioListFeature.Action)
    case settings(SettingsFeature.Action)
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
        return .none
      case .detailSelected(let detail):
        state.detail = detail
        return .none
      case .path, .portfolios, .settings:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
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
