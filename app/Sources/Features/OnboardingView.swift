import ComposableArchitecture
import SwiftUI

/// First-launch onboarding. The user acknowledges the disclaimer, reviews the
/// portfolio setup intro, then continues into the local-first app.
///
/// Reads from `OnboardingFeature` and routes the disclaimer / start-setup
/// taps through the reducer's effects (push authorization +
/// `.delegate(.completed)`) so behavior is fully testable.
///
/// Accessibility (#330): the disclaimer→setup-intro screen swap is a
/// SwiftUI `if`/`else` switch inside one `ScrollView`. The default
/// behavior — destroying the focused subtree and falling back to the
/// still-mounted `AppBrandHeader` — leaves VoiceOver, Switch Control,
/// and Full Keyboard Access users with no auditory or focus signal that
/// the screen changed on the very first interaction of the app. We
/// satisfy WCAG 2.2 SC 4.1.3 (Status Messages) and Apple HIG → Manage
/// focus by (1) routing an announcement through the central
/// `AccessibilityAnnouncer` seam (#293), and (2) using
/// `@AccessibilityFocusState` to move VoiceOver focus onto the new
/// step's header so the new screen reads from the top.
struct OnboardingView: View {
  let store: StoreOf<OnboardingFeature>

  /// VoiceOver/Switch-Control focus anchor for the active onboarding
  /// step header. Bound to both step headers so the
  /// `hasAcknowledgedDisclaimer` transition can move focus onto the
  /// header of the newly inserted subtree without depending on system
  /// auto-focus heuristics (#330).
  @AccessibilityFocusState private var focusedSection: OnboardingAccessibility.FocusTarget?

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
    .onChange(of: store.hasAcknowledgedDisclaimer) { _, acknowledged in
      // Move AT focus onto the header of the newly visible step. We do
      // this in addition to the announcement below because focus motion
      // and the post-focus auto-read are what restore the "I'm now on a
      // new screen" mental model — the announcement alone would still
      // leave focus orphaned on the destroyed "I Understand" button's
      // ancestor (the brand header) and trigger a redundant re-read of
      // the brand title (#330).
      focusedSection = OnboardingAccessibility.focusTarget(forAcknowledged: acknowledged)
    }
    .appAnnounceOnChange(of: store.hasAcknowledgedDisclaimer) { acknowledged in
      OnboardingAccessibility.transitionAnnouncement(forAcknowledged: acknowledged)
    }
  }

  private var disclaimerAcknowledgment: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label("Important Disclaimer", systemImage: "exclamationmark.shield")
        .valueCompassTextStyle(.headlineMedium)
        .foregroundStyle(Color.appContentPrimary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($focusedSection, equals: .disclaimerHeader)

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
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($focusedSection, equals: .setupIntroHeader)

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

/// Pure composer for the onboarding step-swap accessibility seam (#330).
///
/// Keeps the focus-target identity and the announcement string composer
/// out of the view body so `OnboardingAccessibilityTests` can pin them
/// without spinning up a SwiftUI host. WCAG 2.2 SC 4.1.3 (Status
/// Messages) requires that the disclaimer→setup-intro transition be
/// programmatically perceivable to assistive technologies; this enum
/// owns the contract for what is announced and where focus lands.
enum OnboardingAccessibility {
  /// VoiceOver/Switch-Control focus anchors for the two onboarding
  /// steps. Each value is bound to the corresponding step's header via
  /// `.accessibilityFocused($focusedSection, equals: ...)`.
  enum FocusTarget: Hashable {
    case disclaimerHeader
    case setupIntroHeader
  }

  /// Returns the focus target that should receive AT focus given the
  /// latest `hasAcknowledgedDisclaimer` flag. The fresh-install state
  /// (`acknowledged == false`) does not move focus on its own — system
  /// auto-focus already lands on the first focusable element of the
  /// disclaimer step at launch; we only override when the user crosses
  /// the transition.
  static func focusTarget(forAcknowledged acknowledged: Bool) -> FocusTarget {
    acknowledged ? .setupIntroHeader : .disclaimerHeader
  }

  /// Returns the announcement string for the disclaimer→setup-intro
  /// transition (or `nil` to skip the announcement in directions where
  /// it would be redundant). The reverse `true → false` direction is
  /// unreachable through the UI today (acknowledgement is one-way), so
  /// it produces no announcement to avoid surprise chatter if a future
  /// reset path is added.
  static func transitionAnnouncement(forAcknowledged acknowledged: Bool) -> String? {
    guard acknowledged else { return nil }
    return "Disclaimer acknowledged. Create your first portfolio."
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
