import ComposableArchitecture

/// Phase 0 placeholder for the contribution-history reducer.
///
/// Issue #157 replaces this with the real reducer that owns
/// `ContributionHistoryDetailView`. Until then the type exists only so
/// `MainFeature` (issue #149) can reference it as a `Path.contributionHistory`
/// destination.
@Reducer
struct ContributionHistoryFeature {
  @ObservableState
  struct State: Equatable, Sendable {}

  enum Action: Equatable, Sendable {
    case _placeholder
  }

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
