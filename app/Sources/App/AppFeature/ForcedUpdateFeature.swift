import ComposableArchitecture

/// Phase 0 placeholder for the forced-update reducer.
///
/// Issue #150 replaces this with the real reducer that owns the
/// "update required" UI currently in `ForcedUpdateView`. Until then the
/// type exists only so `AppFeature.Destination.forcedUpdate` has a real
/// `State` to embed and so Phase 0 compiles in isolation.
@Reducer
struct ForcedUpdateFeature {
  @ObservableState
  struct State: Equatable {}

  enum Action: Equatable {
    case _placeholder
  }

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
