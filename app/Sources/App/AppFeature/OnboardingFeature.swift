import ComposableArchitecture

/// Reducer that drives the first-launch onboarding flow shown by
/// `OnboardingView`.
///
/// The flow has two on-screen steps:
///
/// 1. Disclaimer acknowledgement — toggled by `acknowledgeDisclaimerTapped`.
/// 2. Portfolio setup intro — completed by `startSetupTapped`, which requests
///    push authorization and then signals the parent reducer to transition.
///
/// Persistence of `hasSeenDisclaimer` and the actual transition to the main
/// route are owned by `AppFeature` (Phase 2, #158) — this reducer only emits
/// `.delegate(.completed)` so the side-effect ordering matches the legacy
/// `OnboardingView`.
@Reducer
struct OnboardingFeature {
  @ObservableState
  struct State: Equatable {
    var hasAcknowledgedDisclaimer: Bool = false
  }

  enum Action: Equatable {
    case acknowledgeDisclaimerTapped
    case startSetupTapped
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      /// Onboarding finished — parent persists `hasSeenDisclaimer` and
      /// transitions to `.main(...)`.
      case completed
    }
  }

  @Dependency(\.pushNotifications) var pushNotifications

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .acknowledgeDisclaimerTapped:
        state.hasAcknowledgedDisclaimer = true
        return .none

      case .startSetupTapped:
        return .run { [pushNotifications] send in
          await pushNotifications.requestAuthorizationAndRegister()
          await send(.delegate(.completed))
        }

      case .delegate:
        return .none
      }
    }
  }
}
