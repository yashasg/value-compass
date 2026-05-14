# Design System Color Tokens

Value Compass uses semantic color tokens instead of screen-specific colors. The
Swift API lives in `frontend/Sources/App/DesignSystem.swift`; the source values
live in `frontend/Sources/Assets/Assets.xcassets/App*.colorset`.

## Token catalog

| Token | Light | Dark | Use |
|---|---:|---:|---|
| `appBackground` | `#F8FAFC` | `#0B1120` | App chrome and root background |
| `appSurface` | `#FFFFFF` | `#111827` | Cards, grouped content, list surfaces |
| `appSurfaceElevated` | `#E2E8F0` | `#1E293B` | Elevated panels and high-density sections |
| `appContentPrimary` | `#0F172A` | `#F8FAFC` | Primary text and high-emphasis data |
| `appContentSecondary` | `#334155` | `#CBD5E1` | Secondary labels and supporting copy |
| `appContentTertiary` | `#475569` | `#94A3B8` | Low-emphasis helper text |
| `appPrimary` | `#0F62FE` | `#93C5FD` | Primary actions and focused affordances |
| `appSecondary` | `#7C3AED` | `#C4B5FD` | Secondary brand accents |
| `appTertiary` | `#0F766E` | `#5EEAD4` | Insight accents and calm emphasis |
| `appPositive` | `#166534` | `#86EFAC` | Positive financial movement |
| `appNegative` | `#B45309` | `#FCD34D` | Negative financial movement; pair with labels/icons |
| `appNeutral` | `#64748B` | `#94A3B8` | Neutral financial or metadata states |
| `appError` | `#B91C1C` | `#FCA5A5` | Blocking validation and calculation errors |
| `appWarning` | `#B45309` | `#FCD34D` | Non-blocking validation and stale/missing data |
| `appSuccess` | `#0F766E` | `#5EEAD4` | Successful validation or completion states |
| `appInfo` | `#0F62FE` | `#93C5FD` | Informational validation and guidance |
| `appInput` | `#FFFFFF` | `#1E293B` | Text fields and editable controls |
| `appDivider` | `#CBD5E1` | `#475569` | Separators and low-emphasis strokes |

## Accessibility checks

`frontend/Tests/VCATests/DesignSystemTests.swift` resolves every asset in light
and dark appearances and enforces WCAG AA contrast for text tokens across
background, surface, and elevated surface tokens. Minimum measured contrast:

| Text token | Light minimum | Dark minimum |
|---|---:|---:|
| `appContentPrimary` | 14.48:1 | 13.98:1 |
| `appContentSecondary` | 8.40:1 | 9.85:1 |
| `appContentTertiary` | 6.15:1 | 5.71:1 |

## Usage checklist

1. Use content tokens for text; do not place action, warning, or financial-state
   colors behind body text without adding a contrast test.
2. Use `appError` only for blocking validation or failed calculations; use
   `appWarning` for missing market data and non-blocking editor warnings.
3. Use `appPositive`, `appNegative`, and `appNeutral` for financial data, and
   include text labels or icons so meaning does not rely on color alone.
4. Use `appSuccess` and `appInfo` for validation feedback and guidance, not for
   financial performance.
5. Add new colors as asset-catalog tokens plus `AppColorToken` cases, then extend
   `DesignSystemTests` before using them in UI.
