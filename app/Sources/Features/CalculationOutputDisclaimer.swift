import SwiftUI

/// Canonical accessibility surface for the persistent investment-advice
/// disclaimer rendered on every calculation-output screen
/// (`ContributionResultView`, `PortfolioDetailView`, `ContributionHistoryView`
/// list + detail). Lifted to a shared enum so unit tests can pin the
/// identifier without re-deriving the string in each view file, and so
/// future audits can grep one symbol to locate every disclaimer surface.
///
/// Closes #233: the financial-advice disclaimer in
/// `Disclaimer.text` must be load-bearing and visible on every screen
/// that renders computed dollar amounts. The first-launch onboarding gate
/// and the Settings > Legal disclosure (now default-expanded; see
/// `SettingsFeature.State.isDisclaimerExpanded`) do not satisfy the
/// "contemporaneous with the output" requirement for App Review §5.1.1 /
/// §1.4 and the FINRA Reg. Notice 17-18 framing — the disclaimer has to
/// travel with the dollar amount, not just gate the first launch.
enum CalculationOutputDisclaimer {
  /// `.accessibilityIdentifier` applied to every footer instance. Stable
  /// identifier so UI audits, snapshot tests, and the
  /// `DisclaimerSurfaceTests` presence checks can pin one constant.
  static let accessibilityIdentifier = "calculation.output.disclaimer"
}

/// Persistent, always-rendered disclaimer footer placed at the bottom of
/// every calculation-output surface (#233). Renders `Disclaimer.text`
/// verbatim — no paraphrasing — so the in-view copy always matches the
/// onboarding-time acknowledgement and the Settings > Legal disclosure.
///
/// Uses `.bodySmall` typography + `Color.appContentSecondary` to match
/// the visual weight Settings already applies to the same string
/// (`SettingsView.swift` Legal section), and `fixedSize(vertical: true)`
/// so Dynamic Type can grow the disclaimer height without truncation.
struct CalculationOutputDisclaimerFooter: View {
  var body: some View {
    Text(Disclaimer.text)
      .valueCompassTextStyle(.bodySmall)
      .foregroundStyle(Color.appContentSecondary)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityIdentifier(CalculationOutputDisclaimer.accessibilityIdentifier)
  }
}

#Preview("CalculationOutputDisclaimerFooter") {
  CalculationOutputDisclaimerFooter()
    .padding()
}
