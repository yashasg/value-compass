import XCTest

@testable import VCA

/// Pins the canonical disclaimer surfaces required by #233.
///
/// The financial-advice disclaimer in `Disclaimer.text` is the
/// single source of truth surfaced on:
/// - the first-launch onboarding gate (`OnboardingView`),
/// - the Settings > Legal expanded disclosure (`SettingsView`,
///   `SettingsFeature.State.isDisclaimerExpanded` defaults to `true`),
/// - and — added in #233 — every calculation-output screen via
///   `CalculationOutputDisclaimerFooter`
///   (`ContributionResultView`, `PortfolioDetailView`,
///   `ContributionHistoryView` list + detail).
///
/// These assertions exist so future refactors that rename or relocate
/// any of those constants surface as test-time failures rather than
/// silently regressing the App Store §5.1.1 / §1.4 + FINRA Reg.
/// Notice 17-18 compliance posture.
final class DisclaimerSurfaceTests: XCTestCase {
  func testDisclaimerTextNamesInformationalPosture() {
    XCTAssertTrue(
      Disclaimer.text.contains("informational"),
      "Disclaimer.text must continue to declare the informational/educational framing required by Reuben's charter."
    )
  }

  func testDisclaimerTextDeniesInvestmentAdviceFraming() {
    XCTAssertTrue(
      Disclaimer.text.contains("not constitute investment advice"),
      "Disclaimer.text must explicitly deny investment-advice framing so the calculation-output surfaces ship the canonical denial copy."
    )
  }

  func testCalculationOutputDisclaimerIdentifierIsStable() {
    // Pinned constant — UI audits, snapshot tests, and downstream
    // tooling rely on this exact string to locate every
    // calculation-output disclaimer footer.
    XCTAssertEqual(
      CalculationOutputDisclaimer.accessibilityIdentifier,
      "calculation.output.disclaimer"
    )
  }
}
