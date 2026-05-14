import ComposableArchitecture

/// Phase 0 placeholder for the portfolio-detail reducer.
///
/// Issue #154 replaces this with the real reducer that owns
/// `PortfolioDetailView`. Until then the type exists only so `MainFeature`
/// (issue #149) can reference it as a `Path.portfolioDetail` destination.
@Reducer
struct PortfolioDetailFeature {
  @ObservableState
  struct State: Equatable, Sendable {}

  enum Action: Equatable, Sendable {
    case _placeholder
  }

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
