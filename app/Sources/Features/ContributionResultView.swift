import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

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
    // WCAG 2.2 SC 4.1.3 (Status Messages) / #293: the initial arrival on
    // this screen is announced via the `navigationTitle` flip
    // ("Contribution Result" ↔ "Calculation Failed"), but tapping Retry
    // that lands on a *different* failure (e.g. transient network error
    // → missing market data) keeps the same title and only swaps the
    // inline error `Label`. SwiftUI fires no AT notification for that
    // text swap, so the AT user hears nothing and assumes Retry was
    // ignored. Post the new failure / success summary imperatively when
    // `output` changes after the screen has appeared. `onChange` does not
    // fire on first render, so the navigationTitle announcement and this
    // hook do not overlap.
    .onChange(of: store.output) { _, newValue in
      let message = ContributionResultAccessibility.announcement(for: newValue)
      UIAccessibility.post(notification: .announcement, argument: message)
    }
  }

  private var resultSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Total Monthly Contribution")
        .valueCompassTextStyle(.labelCaps)
        .foregroundStyle(Color.appContentSecondary)

      Text("$\(decimalText(store.output.totalAmount))")
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
            Text("$\(decimalText(category.amount))")
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
              Text("$\(decimalText(allocation.amount))")
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentPrimary)
              Text("\(percentText(allocation.allocatedWeight))%")
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

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  private func percentText(_ value: Decimal) -> String {
    decimalText(value * 100)
  }
}

/// Composes the VoiceOver announcement posted by `ContributionResultView`
/// when `ContributionResultFeature.State.output` changes after the screen
/// has appeared — typically after a Retry tap that produced a new failure
/// or finally succeeded (`#293`). The screen's first render is already
/// announced by the `navigationTitle` flip; this string covers the silent
/// gap when the title stays put and only the inline content swaps.
///
/// Exposed at file scope (not nested) so unit tests can pin every branch
/// without spinning up a SwiftUI host. Mirrors the on-screen copy so
/// screen-reader users hear what sighted users see.
enum ContributionResultAccessibility {
  static func announcement(for output: ContributionOutput) -> String {
    if let error = output.error {
      return error.localizedDescription
    }
    let amount = NSDecimalNumber(decimal: output.totalAmount).stringValue
    let count = output.allocations.count
    let allocationWord = count == 1 ? "allocation" : "allocations"
    return
      "Calculation complete. Monthly contribution $\(amount). \(count) ticker \(allocationWord) ready."
  }
}
