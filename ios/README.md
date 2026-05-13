# ios

SwiftUI client for value-compass. One Xcode project (`VCA.xcodeproj`) building
a universal app for iPhone and iPad.

## Target

- iOS 17+ / iPadOS 17+
- Swift, SwiftUI
- iPhone and iPad layouts

## Layout

```
ios/
  VCA.xcodeproj
  Sources/
    App/           # Entry point, app lifecycle, AppDelegate (APNs)
    Features/      # SwiftUI screens (Onboarding, Settings, ForcedUpdate, Main)
    Networking/    # URLSession transport, Keychain, X-Min-App-Version monitor,
                   # SwiftOpenAPIGenerator config + openapi.json
    Models/        # Disclaimer text and other Swift data models
```

## Key Libraries

| Library                | Purpose                                        |
|------------------------|------------------------------------------------|
| URLSession             | Networking (HTTP/2 by default)                 |
| SwiftOpenAPIGenerator  | Generated API client from `openapi.json`       |
| Security (Keychain)    | Device UUID persistence                        |
| UserNotifications      | APNs push handling                             |

## API Contract

- The Swift client is generated from `openapi.json` via SwiftOpenAPIGenerator
  at build time. Generated sources land in the build directory and are
  never hand-edited. The generator config lives at
  `Sources/Networking/openapi-generator-config.yaml`, and a build-time copy
  of the repo-root `openapi.json` lives at `Sources/Networking/openapi.json`
  (kept in sync by CI — never edited manually).
- New server fields are optional (`Codable` with optionals) — old app
  versions never break. SwiftOpenAPIGenerator emits non-required schema
  properties as `Optional` automatically.
- The `X-Min-App-Version` response header triggers a forced-update screen
  if the running app is below the minimum supported version. This is
  implemented in `Networking/MinAppVersionMonitor.swift` and surfaced by
  `Features/ForcedUpdateView.swift`. Every response funneled through
  `APIClient.send` is inspected, regardless of HTTP status.

### Wiring SwiftOpenAPIGenerator

The `swift-openapi-generator` build plugin
(<https://github.com/apple/swift-openapi-generator>) must be added to the
Xcode project as a Swift Package dependency and attached to the `VCA` target
as a build-tool plugin. Once attached, `Sources/Networking/openapi.json` is
consumed at build time and a `Client` type is generated and made available
to `APIClient.swift`.

## Disclaimer

Displayed on onboarding (`Features/OnboardingView.swift`) and accessible
from Settings (`Features/SettingsView.swift`). The text lives in a single
constant (`Models/Disclaimer.swift`):

> This tool is for informational and educational purposes only. It does not
> constitute investment advice. Past price trends do not guarantee future
> performance. Consult a licensed financial advisor before making
> investment decisions.
