import ComposableArchitecture
import XCTest

@testable import VCA

/// `TestStore` coverage for `OnboardingFeature` (issue #187, part of #185).
///
/// Pins the first-launch onboarding surface: the disclaimer toggle, the
/// "start setup" tap that now signals the parent directly (push-prompt
/// removal landed in #305), and the inert `.delegate` case the parent
/// reducer owns.
@MainActor
final class OnboardingFeatureTests: XCTestCase {
  func testAcknowledgeDisclaimerTappedFlipsState() async {
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }

    await store.send(.acknowledgeDisclaimerTapped) {
      $0.hasAcknowledgedDisclaimer = true
    }
  }

  // #305 regression guard: starting setup must NOT trigger any push
  // authorization or APNs registration in the MVP flow. The dependency is
  // overridden with a closure that fails the test if it is ever invoked, so
  // any future change that re-introduces a push-permission prompt in the
  // onboarding flow trips a deterministic XCTest failure (and not a real
  // simulator/device permission alert from the live client).
  func testStartSetupTappedCompletesWithoutRequestingPushAuthorization() async {
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    } withDependencies: {
      $0.pushNotifications.requestAuthorizationAndRegister = {
        XCTFail(
          "Onboarding must not request push authorization in v1 (issue #305)."
        )
      }
    }

    await store.send(.startSetupTapped)
    await store.receive(\.delegate.completed)
  }

  func testStartSetupTappedDoesNotMutateDisclaimerState() async {
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    } withDependencies: {
      $0.pushNotifications.requestAuthorizationAndRegister = {
        XCTFail(
          "Onboarding must not request push authorization in v1 (issue #305)."
        )
      }
    }

    await store.send(.startSetupTapped)
    await store.receive(\.delegate.completed)
  }

  func testDelegateCompletedIsNoOpOnState() async {
    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }

    await store.send(.delegate(.completed))
  }

  func testDelegateCompletedIsNoOpEvenAfterDisclaimerAcknowledged() async {
    let store = TestStore(
      initialState: OnboardingFeature.State(hasAcknowledgedDisclaimer: true)
    ) {
      OnboardingFeature()
    }

    await store.send(.delegate(.completed))
  }
}
