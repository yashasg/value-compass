import SwiftUI

/// First-launch onboarding. Spec requirement: the disclaimer must be shown
/// here. Continuing to the main app is gated on the user tapping "Continue",
/// which after first dismissal also triggers the APNs permission prompt.
struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var pushManager: PushNotificationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Welcome to Value Compass")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                Text("Important Disclaimer")
                    .font(.headline)

                Text(Disclaimer.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        await pushManager.requestAuthorizationAndRegister()
                        appState.hasCompletedOnboarding = true
                    }
                } label: {
                    Text("I Understand — Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 640) // Comfortable reading width on iPad.
            .frame(maxWidth: .infinity)
        }
    }
}
