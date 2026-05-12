import Foundation

/// Cross-cutting app state owned by `VCAApp` and injected as an
/// `@EnvironmentObject` into the view tree.
@MainActor
final class AppState: ObservableObject {
    /// `true` until the user dismisses the onboarding sheet (which contains
    /// the disclaimer). Persisted across launches via `UserDefaults`.
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingKey)
        }
    }

    private static let onboardingKey = "com.valuecompass.hasCompletedOnboarding"

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }
}
