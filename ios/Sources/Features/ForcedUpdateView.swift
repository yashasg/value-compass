import SwiftUI

/// Shown when the backend's `X-Min-App-Version` header indicates the running
/// app is below the minimum supported version. Blocks all further use until
/// the user updates via the App Store.
struct ForcedUpdateView: View {
    let minimumVersion: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Update Required")
                .font(.largeTitle.bold())

            if let minimumVersion {
                Text("Value Compass \(minimumVersion) or later is required to continue.")
                    .multilineTextAlignment(.center)
            } else {
                Text("A newer version of Value Compass is required to continue.")
                    .multilineTextAlignment(.center)
            }

            // Open the App Store. Prefer an explicit App Store ID when one
            // has been configured via Info.plist (`VCAAppStoreID`); otherwise
            // fall back to a search for "Value Compass" so the link always
            // resolves to a valid page.
            Link("Open App Store", destination: Self.appStoreURL)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static var appStoreURL: URL {
        if let id = Bundle.main.object(forInfoDictionaryKey: "VCAAppStoreID") as? String,
           !id.isEmpty,
           let url = URL(string: "itms-apps://itunes.apple.com/app/id\(id)") {
            return url
        }
        return URL(string: "https://apps.apple.com/")
            ?? URL(fileURLWithPath: "/")
    }
}
