# Trademark clearance & freedom-to-operate posture

This document is the engineering record of the **name/logo intellectual-property
surface** that ships in the iOS app today and the gaps that still need a
qualified trademark attorney before any external TestFlight or App Store
submission.

> ⚠️ **Not legal advice.** Nothing in this file is a clearance opinion, a
> freedom-to-operate conclusion, or a representation that the marks below are
> available for use in any jurisdiction or class. It is a checklist of the
> public-record searches and decisions that licensed counsel must complete
> and sign off on **before** submission. Until that sign-off exists, the
> default-to-no posture documented in
> [`docs/legal/app-review-notes.md`](app-review-notes.md) applies: submission
> is gated.

## Marks in scope

The v1 build ships three distinct intellectual-property surfaces that any
clearance opinion must cover.

| Mark | Surface in code | First public exposure |
|---|---|---|
| Word mark **"Investrum"** | `app/Sources/App/Info.plist` (`CFBundleDisplayName`); `app/Sources/App/AppBrand.swift` (`AppBrand.displayName`); `app/Sources/App/AppFeature/ForcedUpdateFeature.swift` fallback App Store search URL | Home-screen label, App Store listing, marketing copy |
| Geometric logo (`UnevenInvestrumGlyph`) | `app/Sources/App/AppBrand.swift` (`UnevenInvestrumGlyph` shape, three-triangle composition); `app/Sources/Assets/Assets.xcassets/AppIcon.appiconset` (rendered icon) | App icon, splash header, settings header |
| Trigram **"VCA"** | `app/VCA.xcodeproj/` (product code, crash-report identity, App Store Connect submission metadata); `app/Sources/Features/PortfolioDetailView.swift:251` user-facing copy ("local moving-average VCA calculator") | Crash logs, App Store Connect dashboard, in-app copy |

The trigram exposure is the most acute: `VCA` shows up in user-facing copy
*and* in build identity, so a class-distance analysis or a rename decision
must land before submission.

## Required searches

Each of the four sub-sections below enumerates the public-record searches
that must exist on file (printouts, screenshots, or dated text dumps) before
counsel signs off. None of the searches has been performed by this
engineering record; this file is the **list of what to do**, not the record
of having done it.

### 1. Word mark "Investrum"

| Database | Query | Class(es) | Status |
|---|---|---|---|
| USPTO TESS direct hit | `Investrum` | 009 (downloadable software), 036 (financial services) | ☐ Not on file |
| USPTO TESS phonetic / similar | `Investrum`, `Investrium`, `Investorum`, `Investorum`, `Investrim`, `Investum`, prefix `INVEST*` with finance/software descriptors | 009, 036 | ☐ Not on file |
| EUIPO eSearch plus | `Investrum` and phonetic variants | 9, 36 (Nice) | ☐ Not on file |
| WIPO Madrid Monitor | `Investrum` | 9, 36 | ☐ Not on file |
| CIPO (Canada) TM database | `Investrum` | 9, 36 | ☐ Not on file |
| UKIPO TM search | `Investrum` | 9, 36 | ☐ Not on file (record only if UK is in launch scope) |

The launch-jurisdiction list itself is a decision counsel must confirm. The
defaults in the table reflect the App Store's global storefront posture; if
the operator decides to launch in U.S. + EU + Canada only, the UKIPO row
moves out of scope.

### 2. Storefront collision scan

| Storefront | Query | Notes |
|---|---|---|
| Apple App Store (US) | `Investrum`, `Investrium`, `Investorum` | Finance + Utilities shelves; pairs with #292 / #220 |
| Apple App Store (EU representative — DE, FR, NL) | Same | Storefront varies per region; counsel decides which storefronts are mandatory |
| Google Play (US) | Same | Cross-platform collision risk; record even if Android launch is not in scope |
| Web (Google + DuckDuckGo) | `"Investrum"`, `"Investrum" finance`, `"Investrum" investing` | Surfaces common-law users not in registries |

### 3. Geometric mark `UnevenInvestrumGlyph`

The logo is a composition of three asymmetric triangles defined in
`app/Sources/App/AppBrand.swift` (`UnevenInvestrumGlyph.path(in:)`).

| Database | Design-search code(s) | Status |
|---|---|---|
| USPTO design-search | `26.03.07` (triangles), `26.03.21` (plurality of triangles), `26.03.05` (triangles with one or more curved sides) | ☐ Not on file |
| EUIPO Vienna classification | `26.3.1` (triangles), `26.3.7` (plurality of triangles) | ☐ Not on file |

Counsel must also decide whether the geometric mark is being filed
defensively or relied on as common-law only. The codebase does not encode
that decision today.

### 4. Trigram "VCA"

The trigram is shipped in two distinct surfaces — internal build identity
and user-facing copy — and the clearance posture must be decided for each.

**Known senior registrant (knockout — not exhaustive):**

- **VCA Inc. — USPTO Reg. No. 2,196,632.** Class 44 (veterinary services).
  This is a class-distance posture, not a clearance: a financial-utility app
  is most plausibly Class 9 (downloadable software) / Class 36 (financial
  services), neither of which overlaps Class 44. Counsel must confirm that
  this class-distance argument holds across launch jurisdictions and against
  any other registered `VCA` marks (e.g., VCA = "Value Cost Averaging" or
  "Variable Cost Averaging" usages by financial educators or publishers
  that may have common-law claims even without registration).

The squad must take an explicit decision on the trigram. Three options:

| Option | What happens to `VCA` |
|---|---|
| **(a) Keep — class-distance defense** | `VCA.xcodeproj` and `PortfolioDetailView.swift:251` copy stay; counsel signs off on the Class 9 / 36 vs. Class 44 distance argument and documents any second-priority registrants discovered during the search. |
| **(b) Rename in user-facing copy only** | `PortfolioDetailView.swift:251` copy changes (e.g., "local moving-average value-averaging calculator"); `VCA.xcodeproj` and the bundle identifier stay because they are not user-facing. App Store Connect submission metadata still surfaces `VCA` indirectly via crash reports — counsel must confirm acceptable. |
| **(c) Keep `VCA` strictly internal** | `PortfolioDetailView.swift:251` copy changes; `VCA.xcodeproj` keeps for now (renaming the Xcode project is a multi-file refactor and a separate issue), but any future user-facing surface is forbidden from spelling `VCA`. Documented in this file as the operative rule. |

The default-to-no posture means option **(c)** is the safest absent counsel
sign-off on **(a)**. The squad has not yet decided.

## Submission gate

Until **all** of the following are true, no external TestFlight (TestFlight
external testing) or App Store submission may proceed:

1. The "Status" column in each search table above shows a dated, attached
   or referenced printout / screenshot / text dump for every row in scope.
2. The trigram decision (a) / (b) / (c) is recorded in
   [`.squad/decisions.md`](../../.squad/decisions.md) with the name of the
   licensed counsel who signed off.
3. The freedom-to-operate memo (signed by licensed counsel in each launch
   jurisdiction) is attached or referenced from this file.
4. This memo is cross-linked from the four other pre-submission sync
   surfaces so submission cannot proceed unless all five agree:
   [`docs/legal/app-review-notes.md`](app-review-notes.md) (#254),
   the Privacy Policy disclosure (#224), the App Privacy nutrition label
   (#271 closed), the Age-Rating Questionnaire (#287), and the Third-Party
   ToS surface (#294). After this issue lands the gate is **five** surfaces,
   not four.

## Why this matters

- **Apple App Store Review Guideline §5.2 (Intellectual Property).** Apple
  may remove any app that infringes another party's intellectual property
  ([guidelines](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)).
- **Apple App Store Review Guideline §5.2.5.** Apple may reject apps
  "intended to confuse or trick users."
- **Lanham Act §43(a) — 15 U.S.C. §1125(a).** Federal unfair-competition /
  false-designation-of-origin liability that does not require federal
  registration and survives against an unregistered prior user.
- **15 U.S.C. §1114.** Federal infringement liability for confusingly
  similar marks on related goods/services.

Indie publishers ship every quarter with takedown letters issued against an
uncleared name; once the listing exists in App Store Connect and the build
ships, the rename cost is materially larger than the pre-submission
clearance cost. Default-to-no on ambiguous IP exposure means: if the
clearance is not on file, do not submit.

## Tracking

- Originating issue: #314.
- Renames recorded in this file when they ship: trigram decision (option a / b / c).
- Related pre-submission gates: #254 (App Review notes), #224 (Privacy
  Policy), #287 (age-rating), #294 (third-party ToS surface), #338 (repo
  notices / MIT preservation — landed in PR #382).

## When this declaration must change

This memo must be re-reviewed by counsel and updated **before** any of the
following ship to App Store Connect or external TestFlight:

- The product is renamed (the cleared name is "Investrum" — any change
  re-opens every row in §1).
- The logo geometry in `UnevenInvestrumGlyph` is altered (the cleared mark
  is the specific three-triangle composition — geometry changes re-open
  §3).
- The trigram `VCA` is exposed in any new user-facing surface beyond
  `PortfolioDetailView.swift:251` (re-opens §4 and may invalidate any
  class-distance argument depending on the new context).
- The launch-jurisdiction list expands beyond what counsel signed off
  on (re-opens §1 and §2 for the new jurisdictions).
