# Frontend

SwiftUI client for value-compass. One Xcode project (`VCA.xcodeproj`) building
a universal app for iPhone and iPad.

## Target

- iOS 17+ / iPadOS 17+
- Swift, SwiftUI
- iPhone and iPad layouts

## Layout

```
frontend/
  VCA.xcodeproj
  Sources/
    App/           # Entry point, app lifecycle
    Features/      # UI screens
    Networking/    # SwiftOpenAPIGenerator output — never edited manually
    Models/        # Swift data models
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
  at build time. Generated sources land in `Sources/Networking/` and are
  never hand-edited.
- New server fields are optional (`Codable` with optionals) — old app
  versions never break.
- The `X-Min-App-Version` response header triggers a forced-update screen
  if the running app is below the minimum supported version.

## Disclaimer

Displayed on onboarding and accessible from Settings:

> This tool is for informational and educational purposes only. It does not
> constitute investment advice. Past price trends do not guarantee future
> performance. Consult a licensed financial advisor before making
> investment decisions.
