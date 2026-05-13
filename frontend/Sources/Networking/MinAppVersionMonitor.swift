import Foundation

/// Observes every backend response for the `X-Min-App-Version` header and
/// publishes a flag when the running app falls below the minimum supported
/// version. The root view observes this flag and presents `ForcedUpdateView`.
///
/// This is implemented as an `ObservableObject` with `@Published` so SwiftUI
/// re-renders automatically. Updates are dispatched to the main actor.
@MainActor
final class MinAppVersionMonitor: ObservableObject {
    static let shared = MinAppVersionMonitor()

    @Published private(set) var requiresUpdate: Bool = false
    @Published private(set) var minimumVersion: String?

    /// Current bundle short version, used as the baseline for comparison.
    /// Falls back to `"0.0.0"` if the bundle key is missing (which forces an
    /// update — fail-closed in unexpected configurations).
    private let currentVersion: String

    init(currentVersion: String? = nil) {
        if let explicit = currentVersion {
            self.currentVersion = explicit
        } else {
            self.currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
        }
    }

    /// Inspect a response and update `requiresUpdate` if needed.
    /// Header lookup is case-insensitive — `HTTPURLResponse.value(forHTTPHeaderField:)`
    /// already handles that on Apple platforms.
    func observe(response: HTTPURLResponse) {
        guard let header = response.value(forHTTPHeaderField: "X-Min-App-Version"),
              !header.isEmpty else {
            return
        }
        let below = AppVersion.isBelowMinimum(current: currentVersion, minimum: header)
        if minimumVersion != header {
            minimumVersion = header
        }
        if requiresUpdate != below {
            requiresUpdate = below
        }
    }
}
