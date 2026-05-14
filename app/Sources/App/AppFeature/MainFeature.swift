import ComposableArchitecture

/// Phase 0 placeholder for the post-onboarding shell reducer.
///
/// The sibling Phase 0 issue #149 replaces this stub with the real
/// `MainFeature` that owns the iPhone `NavigationStack` / iPad
/// `NavigationSplitView` shell. We keep an empty `@Reducer` here so this PR
/// compiles in isolation; if #149 lands first, this file is the only point
/// of conflict and should be deleted in that PR's merge resolution.
@Reducer
struct MainFeature {
  @ObservableState
  struct State: Equatable {}

  enum Action: Equatable {
    case _placeholder
  }

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
