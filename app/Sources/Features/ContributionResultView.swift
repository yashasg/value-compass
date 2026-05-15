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
          resultSummary
          categoryBreakdown
          actions
        }
        // #233: render `Disclaimer.text` alongside every computed
        // dollar amount. Kept inside the same scroll container as the
        // result summary so the disclaimer travels with the output and
        // is not separated by a navigation push or a settings tap.
        CalculationOutputDisclaimerFooter()
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle(store.output.error == nil ? "Contribution Result" : "Calculation Failed")
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
    .alert(
      "Result Saved",
      isPresented: Binding(
        get: { store.saveConfirmation != nil },
        set: { if !$0 { store.send(.saveConfirmationDismissed) } }
      ),
      presenting: store.saveConfirmation
    ) { _ in
      Button("OK", role: .cancel) { store.send(.saveConfirmationDismissed) }
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
  }

  /// Snapshot of `store.output.error?.localizedDescription` so the
  /// announcement helper only fires when the error text actually changes.
  /// Returning `nil` on success suppresses the announce-on-success path,
  /// which the navigation title and result summary already cover for
  /// sighted and AT users alike.
  private var errorMessage: String? {
    store.output.error?.localizedDescription
  }

  private var resultSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Total Monthly Contribution")
        .valueCompassTextStyle(.labelCaps)
        .foregroundStyle(Color.appContentSecondary)

      Text(store.output.totalAmount.appCurrencyFormatted())
        .valueCompassTextStyle(.displayLarge)
        .minimumScaleFactor(0.7)
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
          }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("contribution.result.category")
      }
    }
  }

  private var actions: some View {
    HStack(spacing: 12) {
      Button {
        store.send(.saveTapped)
      } label: {
        Label("Save", systemImage: "tray.and.arrow.down")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("contribution.result.save")

      Button {
        store.send(.openHistoryTapped)
      } label: {
        Label("History", systemImage: "clock.arrow.circlepath")
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("contribution.result.history")
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
