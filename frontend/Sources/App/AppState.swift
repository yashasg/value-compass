import Foundation

/// Cross-cutting app state owned by `VCAApp` and injected as an
/// `@EnvironmentObject` into the view tree.
@MainActor
final class AppState: ObservableObject {
    /// `true` until the user dismisses the onboarding sheet (which contains
    /// the disclaimer). Persisted across launches via `UserDefaults`.
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            userDefaults.set(hasCompletedOnboarding, forKey: Self.onboardingKey)
        }
    }

    static let onboardingKey = "com.valuecompass.hasCompletedOnboarding"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasCompletedOnboarding = userDefaults.bool(forKey: Self.onboardingKey)
    }
}
