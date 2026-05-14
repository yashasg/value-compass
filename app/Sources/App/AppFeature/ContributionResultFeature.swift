import ComposableArchitecture

/// Phase 0 placeholder for the contribution-result reducer.
///
/// Issue #156 replaces this with the real reducer that owns the per-ticker
/// "required capital" result UI today rendered inline in `PortfolioDetailView`.
/// Until then the type exists only so `MainFeature` (issue #149) can
/// reference it as a `Path.contributionResult` destination.
@Reducer
struct ContributionResultFeature {
  @ObservableState
  struct State: Equatable, Sendable {}

  enum Action: Equatable, Sendable {
    case _placeholder
  }

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
