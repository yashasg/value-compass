import ComposableArchitecture

/// Phase 0 placeholder for the settings reducer.
///
/// Issue #152 replaces this with the real reducer that owns `SettingsView`'s
/// preferences + reset UI. Until then the type exists only so `MainFeature`
/// (issue #149) can reference it via `Scope(state: \.settings, …)` and as a
/// stack destination.
@Reducer
struct SettingsFeature {
  @ObservableState
  struct State: Equatable, Sendable {}

  enum Action: Equatable, Sendable {
    case _placeholder
  }

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
