import SwiftUI

/// Top-level switch between forced-update, onboarding, and the main UI.
///
/// `MinAppVersionMonitor.requiresUpdate` takes precedence over everything —
/// once the backend says the app is unsupported, the user can't reach any
/// other screen.
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var minVersionMonitor: MinAppVersionMonitor

    var body: some View {
        Group {
            if minVersionMonitor.requiresUpdate {
                ForcedUpdateView(minimumVersion: minVersionMonitor.minimumVersion)
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainView()
            }
        }
    }
}
