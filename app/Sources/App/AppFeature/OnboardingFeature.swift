import ComposableArchitecture

/// Reducer that drives the first-launch onboarding flow shown by
/// `OnboardingView`.
///
/// The flow has two on-screen steps:
///
/// 1. Disclaimer acknowledgement — toggled by `acknowledgeDisclaimerTapped`.
/// 2. Portfolio setup intro — completed by `startSetupTapped`, which signals
///    the parent reducer to transition. The MVP build does **not** ship a
///    user-facing push notification feature, so `startSetupTapped` no longer
///    requests `UNUserNotificationCenter` authorization or registers for
///    APNs (issue #305). `PushNotificationsClient` and the APNs
///    `AppDelegate` callbacks remain in the project intentionally dormant so
///    the future push-notification feature (whenever it ships under its own
///    issue) can rewire permission gating without re-introducing dead
///    infrastructure.
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

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .acknowledgeDisclaimerTapped:
        state.hasAcknowledgedDisclaimer = true
        return .none

      case .startSetupTapped:
        return .send(.delegate(.completed))

      case .delegate:
        return .none
      }
    }
  }
}
