import ComposableArchitecture

/// Phase 0 placeholder for the portfolio-list reducer.
///
/// Issue #153 replaces this with the real reducer that owns the portfolio
/// list + editor UI currently in `PortfolioListView`. Until then the type
/// exists only so `MainFeature` (issue #149) can reference it via
/// `Scope(state: \.portfolios, …)`.
@Reducer
struct PortfolioListFeature {
  @ObservableState
  struct State: Equatable, Sendable {}

  enum Action: Equatable, Sendable {
    case _placeholder
  }

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
