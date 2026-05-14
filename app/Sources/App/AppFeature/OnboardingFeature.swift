import ComposableArchitecture

/// Phase 0 placeholder for the onboarding reducer.
///
/// Issue #151 replaces this with the real reducer that owns the
/// disclaimer-acceptance UI currently in `OnboardingView`. Until then the
/// type exists only so `AppFeature.Destination.onboarding` has a real
/// `State` to embed and so Phase 0 compiles in isolation.
@Reducer
struct OnboardingFeature {
  @ObservableState
  struct State: Equatable {}

  enum Action: Equatable {
    case _placeholder
  }

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
