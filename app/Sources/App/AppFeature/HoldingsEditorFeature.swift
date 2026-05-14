import ComposableArchitecture

/// Phase 0 placeholder for the holdings-editor reducer.
///
/// Issue #155 replaces this with the real reducer that owns
/// `HoldingsEditorView`. Until then the type exists only so `MainFeature`
/// (issue #149) can reference it as a `Path.holdingsEditor` destination.
@Reducer
struct HoldingsEditorFeature {
  @ObservableState
  struct State: Equatable, Sendable {}

  enum Action: Equatable, Sendable {
    case _placeholder
  }

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
