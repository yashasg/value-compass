import ComposableArchitecture
import SwiftUI

/// First-launch onboarding. The user acknowledges the disclaimer, reviews the
/// portfolio setup intro, then continues into the local-first app.
///
/// Reads from `OnboardingFeature` and routes the disclaimer / start-setup
/// taps through the reducer's effects (push authorization +
/// `.delegate(.completed)`) so behavior is fully testable.
struct OnboardingView: View {
  let store: StoreOf<OnboardingFeature>

  init(store: StoreOf<OnboardingFeature>) {
    self.store = store
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        AppBrandHeader(logoSize: 72, subtitle: "Personal contribution planning")
          .accessibilityAddTraits(.isHeader)

        if store.hasAcknowledgedDisclaimer {
          portfolioSetupIntro
        } else {
          disclaimerAcknowledgment
        }
      }
      .padding(24)
      .frame(maxWidth: 640)
      .frame(maxWidth: .infinity)
    }
    .background(Color.appBackground)
  }

  private var disclaimerAcknowledgment: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label("Important Disclaimer", systemImage: "exclamationmark.shield")
        .valueCompassTextStyle(.headlineMedium)
        .foregroundStyle(Color.appContentPrimary)

      Text(Disclaimer.text)
        .valueCompassTextStyle(.bodyLarge)
        .foregroundStyle(Color.appContentSecondary)
        .fixedSize(horizontal: false, vertical: true)

      Button {
        store.send(.acknowledgeDisclaimerTapped)
      } label: {
        Text("I Understand")
          .valueCompassTextStyle(.bodyLarge)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .appMinimumTouchTarget()
      .accessibilityIdentifier("onboarding.disclaimer.accept")
    }
    .padding()
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 20))
  }

  private var portfolioSetupIntro: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Create your first portfolio")
        .valueCompassTextStyle(.headlineMedium)
        .foregroundStyle(Color.appContentPrimary)

      Text(
        "Next you will create a local portfolio, choose a monthly budget, then add categories and tickers. Everything works offline, and you can edit details any time."
      )
      .valueCompassTextStyle(.bodyLarge)
      .foregroundStyle(Color.appContentSecondary)
      .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 12) {
        OnboardingSetupStep(
          systemImage: "briefcase",
          title: "Name a real portfolio",
          detail: "Start with your own account or strategy rather than demo data.")
        OnboardingSetupStep(
          systemImage: "dollarsign.circle",
          title: "Set the monthly contribution",
          detail: "Enter the budget the calculator should allocate.")
        OnboardingSetupStep(
          systemImage: "list.bullet.rectangle",
          title: "Add holdings",
          detail: "Organize categories and tickers before calculating.")
      }
      .accessibilityIdentifier("onboarding.setup.steps")

      Button {
        store.send(.startSetupTapped)
      } label: {
        Text("Start Portfolio Setup")
          .valueCompassTextStyle(.bodyLarge)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .appMinimumTouchTarget()
      .accessibilityIdentifier("onboarding.portfolio.start")
    }
    .padding()
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 20))
  }
}

private struct OnboardingSetupStep: View {
  let systemImage: String
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: systemImage)
        .foregroundStyle(Color.appPrimary)
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .valueCompassTextStyle(.bodyLarge)
          .foregroundStyle(Color.appContentPrimary)
        Text(detail)
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appContentSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview("OnboardingView – disclaimer step") {
  OnboardingView(
    store: Store(
      initialState: OnboardingFeature.State(hasAcknowledgedDisclaimer: false)
    ) {
      OnboardingFeature()
    }
  )
}

#Preview("OnboardingView – setup step") {
  OnboardingView(
    store: Store(
      initialState: OnboardingFeature.State(hasAcknowledgedDisclaimer: true)
    ) {
      OnboardingFeature()
    }
  )
}
