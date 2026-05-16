import ComposableArchitecture
import Foundation
import SwiftUI

/// Per-portfolio contribution-result surface. Renders on top of
/// `ContributionResultFeature`. Replaces the MVVM definition that
/// previously lived in `MainView.swift`. Pure TCA: scope a
/// `StoreOf<ContributionResultFeature>` from the parent and pass it in.
struct ContributionResultView: View {
  let store: StoreOf<ContributionResultFeature>

  init(store: StoreOf<ContributionResultFeature>) {
    self.store = store
  }

  var body: some View {
    ContributionResultContent(store: store)
  }
}

/// TCA renderer for `ContributionResultFeature`. Used by the production app
/// via `MainFeature.path` (wired in #159) and by previews / tests.
struct ContributionResultContent: View {
  @Bindable var store: StoreOf<ContributionResultFeature>

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if let error = store.output.error {
          calculationErrorView(error)
        } else {
          if let savedSummary = store.saveConfirmation {
            savedBadge(savedSummary)
          }
          resultSummary
          categoryBreakdown
        }
        // #233: render `Disclaimer.text` alongside every computed
        // dollar amount. Kept inside the same scroll container as the
        // result summary so the disclaimer travels with the output and
        // is not separated by a navigation push or a settings tap.
        CalculationOutputDisclaimerFooter()
      }
      .padding(AppLayoutMetrics.mainMargin)
      .frame(maxWidth: AppLayoutMetrics.readableContentMaxWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .navigationTitle(store.output.error == nil ? "Contribution Result" : "Calculation Failed")
    // #358: HIG → Bars → Toolbars / Navigation Bars require the
    // screen's primary action to stay reachable regardless of scroll
    // position. The category-breakdown VStack inside the ScrollView is
    // unbounded for large portfolios, so the previous in-body
    // Save+History HStack scrolled off-screen on the first verification
    // pass. Save is .primaryAction (trailing nav-bar slot); History is
    // .secondaryAction (overflow menu on compact, visible on regular).
    // Both items are gated on the error-free output so the toolbar
    // collapses to the empty bar on the calculation-failure surface.
    .toolbar { resultToolbarContent }
    .alert(
      "Could Not Save Result",
      isPresented: Binding(
        get: { store.saveError != nil },
        set: { if !$0 { store.send(.saveErrorDismissed) } }
      ),
      presenting: store.saveError
    ) { _ in
      Button("OK", role: .cancel) { store.send(.saveErrorDismissed) }
    } message: { message in
      Text(message)
    }
    .accessibilityIdentifier("contribution.result")
    // WCAG 2.2 SC 4.1.3 — Status Messages. The Retry button keeps the
    // user on this screen; when calculation still fails, the inline
    // error `Label` is replaced silently, so AT users have no cue that
    // their retry was rejected. Announce on `output.error` transitions
    // so VoiceOver hears the message even when focus stays on Retry
    // (#293).
    .appAnnounceOnChange(of: errorMessage) { message in
      message
    }
    // #328: the routine "Result Saved" modal alert was retired (HIG →
    // Alerts forbids alerts for routine status confirmations). The
    // inline `savedBadge` covers the sighted-user signal; this modifier
    // restores VoiceOver / Voice Control / Switch Control parity by
    // announcing the confirmation summary when `store.saveConfirmation`
    // transitions from `nil` to a value (or from one summary to a
    // newer one after a second save round-trip). Same family as the
    // post-#352 `appAnnounceOnChange(of: store.calculationOutput)`
    // helper in `PortfolioDetailView`.
    .appAnnounceOnChange(of: store.saveConfirmation) { summary in
      summary
    }
  }

  /// Snapshot of `store.output.error?.localizedDescription` so the
  /// announcement helper only fires when the error text actually changes.
  /// Returning `nil` on success suppresses the announce-on-success path,
  /// which the navigation title and result summary already cover for
  /// sighted and AT users alike.
  private var errorMessage: String? {
    store.output.error?.localizedDescription
  }

  /// Inline confirmation pill rendered above the result summary after a
  /// successful `.saveTapped` round-trip. Replaces the routine "Result
  /// Saved" modal alert that previously forced an OK tap (#328) — HIG →
  /// Alerts forbids alerts for routine status confirmations. The badge
  /// stays visible until the next `.persistSucceeded` overwrites
  /// `store.saveConfirmation` with a newer summary, giving the user a
  /// persistent post-save UI cue without modal interruption.
  private func savedBadge(_ summary: String) -> some View {
    Label(summary, systemImage: "checkmark.circle.fill")
      .valueCompassTextStyle(.bodyLarge)
      .foregroundStyle(Color.appPositive)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        Color.appSurfaceElevated,
        in: RoundedRectangle(cornerRadius: 12)
      )
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(summary)
      .accessibilityIdentifier("contribution.result.savedBadge")
  }

  private var resultSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Total Monthly Contribution")
        .valueCompassTextStyle(.labelCaps)
        .foregroundStyle(Color.appContentSecondary)

      // WCAG 2.2 SC 1.4.4 (Resize Text) + SC 1.4.10 (Reflow) — allow
      // the headline currency value to wrap naturally at accessibility
      // Dynamic Type sizes instead of shrinking to 70% of its scaled
      // size (#228). The surrounding VStack already provides leading
      // alignment and full-width sizing for multi-line layout.
      Text(store.output.totalAmount.appCurrencyFormatted())
        .valueCompassTextStyle(.displayLarge)
        .foregroundStyle(Color.appContentPrimary)
        .accessibilityIdentifier("contribution.result.total")
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private var categoryBreakdown: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Breakdown")
        .valueCompassTextStyle(.headlineMedium)
        .foregroundStyle(Color.appContentPrimary)
        // #299: pin the per-screen section title as a VoiceOver
        // heading so the Headings rotor can jump to Breakdown without
        // a linear swipe through every category + ticker row.
        .accessibilityAddTraits(.isHeader)

      ForEach(Array(store.output.categoryBreakdown.enumerated()), id: \.offset) { _, category in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(category.categoryName)
              .valueCompassTextStyle(.bodyLarge)
              .foregroundStyle(Color.appContentPrimary)
            Spacer()
            Text(category.amount.appCurrencyFormatted())
              .valueCompassTextStyle(.data)
              .foregroundStyle(Color.appContentPrimary)
          }
          // #227: collapse the per-category header into a single
          // VoiceOver element so the category name and its dollar total
          // are spoken together instead of as two unrelated targets.
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(FinancialRowAccessibility.label(forResultCategory: category))
          .accessibilityValue(FinancialRowAccessibility.value(forResultCategory: category))

          ForEach(
            Array(
              store.output.allocations.filter { $0.categoryName == category.categoryName }
                .enumerated()),
            id: \.offset
          ) { _, allocation in
            HStack {
              Text(allocation.tickerSymbol)
                .valueCompassTextStyle(.labelCaps)
                .foregroundStyle(Color.appContentPrimary)
              Spacer()
              Text(allocation.amount.appCurrencyFormatted())
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentPrimary)
              Text(allocation.allocatedWeight.appPercentFormatted())
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentSecondary)
            }
            .accessibilityIdentifier("contribution.result.ticker")
            // #227: the per-ticker allocation row pairs a symbol with
            // its dollar amount and percentage weight. Without an
            // explicit grouping VoiceOver exposes those three texts as
            // independent focus targets; the ignore + label/value
            // combination collapses the row into one element whose
            // spoken value carries the financial breakdown verbatim
            // (composer pinned in `FinancialRowAccessibilityTests`).
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(FinancialRowAccessibility.label(forResultAllocation: allocation))
            .accessibilityValue(FinancialRowAccessibility.value(forResultAllocation: allocation))
          }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("contribution.result.category")
      }
    }
  }

  @ToolbarContentBuilder
  private var resultToolbarContent: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Button {
        store.send(.saveTapped)
      } label: {
        Label("Save", systemImage: "tray.and.arrow.down")
      }
      // The toolbar collapses Label to icon-only on iPhone / compact
      // widths, leaving the "Save" text exposed only to VoiceOver.
      // `.accessibilityShowsLargeContentViewer()` re-surfaces the
      // Label's title through iOS's long-press large-content tooltip
      // so users on AX text sizes who do not use VoiceOver can still
      // read what the glyph represents (matches the post-#401
      // PortfolioListView toolbar convention).
      .accessibilityShowsLargeContentViewer()
      .accessibilityIdentifier("contribution.result.save")
      .disabled(store.output.error != nil)
    }

    ToolbarItem(placement: .secondaryAction) {
      Button {
        store.send(.openHistoryTapped)
      } label: {
        Label("History", systemImage: "clock.arrow.circlepath")
      }
      // See `.primaryAction` block above — same icon-only collapse
      // rule, same Large Content Viewer rationale (#401).
      .accessibilityShowsLargeContentViewer()
      .accessibilityIdentifier("contribution.result.history")
      .disabled(store.output.error != nil)
    }
  }

  private func calculationErrorView(_ error: LocalizedError) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
        .valueCompassTextStyle(.bodyLarge)
        .foregroundStyle(Color.appError)
        .accessibilityIdentifier("contribution.result.error")

      Button {
        store.send(.retryTapped)
      } label: {
        Label("Retry", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("contribution.result.retry")
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }
}
