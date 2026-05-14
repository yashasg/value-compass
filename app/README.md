# App

SwiftUI client for the Investrum app. The Xcode project lives in
`app/VCA.xcodeproj` and builds a universal app for iPhone and iPad.

## Target

- iOS 17+ / iPadOS 17+
- Swift, SwiftUI
- iPhone and iPad layouts

## Layout

```
app/
  VCA.xcodeproj
  Sources/
    App/           # Entry point, app lifecycle
    Features/      # UI screens
    Backend/       # Backend boundary — only place active code may depend on
                   #   SwiftData, Keychain, Massive, indicators, or VCA engine
      Contracts/   # Protocols App/Features may depend on
      Models/      # Domain & SwiftData models
      Networking/  # API client, version monitor, Keychain glue, SwiftOpenAPIGenerator output
      Services/    # Local computation engines (e.g. ContributionCalculator)
    DesignSystem/  # Typography, semantic tokens
    Assets/        # App icon and asset catalog
  Tests/
    VCATests/
  build.sh
  run.sh
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
  at build time. Generated sources land in `Sources/Backend/Networking/` and are
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

## Design System

Color tokens are semantic SwiftUI colors backed by asset-catalog light/dark
variants. See `docs/design-system-colors.md` for the token catalog, WCAG contrast
evidence, and financial-data usage checklist.
