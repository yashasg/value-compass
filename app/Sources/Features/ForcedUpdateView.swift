import ComposableArchitecture
import SwiftUI

/// Shown when the backend's `X-Min-App-Version` header indicates the running
/// app is below the minimum supported version. Blocks all further use until
/// the user updates via the App Store.
///
/// Reads its state from `ForcedUpdateFeature` and routes the "Open App Store"
/// tap through the reducer's `@Dependency(\.openURL)` effect so behavior is
/// fully testable.
struct ForcedUpdateView: View {
  let store: StoreOf<ForcedUpdateFeature>

  init(store: StoreOf<ForcedUpdateFeature>) {
    self.store = store
  }

  /// Phase 0 → Phase 2 bridge: `RootView` still constructs this view with a
  /// raw `minimumVersion` value supplied by `MinAppVersionMonitor`. Wrap that
  /// into a short-lived `Store` so the rendered hierarchy is identical until
  /// #158/#159 hand `RootView` the real store and this initializer is
  /// removed alongside `MinAppVersionMonitor`.
  init(minimumVersion: String?) {
    self.init(
      store: Store(
        initialState: ForcedUpdateFeature.State(minimumVersion: minimumVersion)
      ) {
        ForcedUpdateFeature()
      }
    )
  }

  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "arrow.up.circle.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 96, height: 96)
        .foregroundStyle(Color.appPrimary)
        .accessibilityHidden(true)

      Text("Update Required")
        .valueCompassTextStyle(.displayLarge)
        .foregroundStyle(Color.appContentPrimary)

      if let minimumVersion = store.minimumVersion {
        Text("\(AppBrand.displayName) \(minimumVersion) or later is required to continue.")
          .multilineTextAlignment(.center)
          .foregroundStyle(Color.appContentSecondary)
      } else {
        Text("A newer version of \(AppBrand.displayName) is required to continue.")
          .multilineTextAlignment(.center)
          .foregroundStyle(Color.appContentSecondary)
      }

      Button("Open App Store") {
        store.send(.openAppStoreTapped)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .appMinimumTouchTarget()
    }
    .padding(32)
    .frame(maxWidth: 640)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.appBackground)
  }
}

#Preview("ForcedUpdateView – with version") {
  ForcedUpdateView(
    store: Store(
      initialState: ForcedUpdateFeature.State(minimumVersion: "1.4.0")
    ) {
      ForcedUpdateFeature()
    }
  )
}

#Preview("ForcedUpdateView – no version") {
  ForcedUpdateView(
    store: Store(
      initialState: ForcedUpdateFeature.State(minimumVersion: nil)
    ) {
      ForcedUpdateFeature()
    }
  )
}
