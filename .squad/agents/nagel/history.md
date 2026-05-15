# Nagel — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** API Contract Monitor

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool. v1 ships **without** a server.
- **Backend:** Python/FastAPI exists in `backend/` but is unused in v1. Rusty (the backend dev) has been retired.
- **iOS internal contracts (the v1 surface I own):**
  - `ContributionCalculating` protocol — the seam that makes the VCA algorithm user-swappable. Hardened API stability target.
  - SwiftData `@Model` types — Portfolio, Category, Ticker. Schema versioning matters; a botched migration corrupts user data.
  - Service / repository interfaces between Virgil's data layer and Basher's UI layer.
  - Any `public` declaration in the app or future SPM modules.
- **OpenAPI surface:** `openapi.json` exists for the FastAPI backend. Generated Swift clients exist (Linus owns). Activates when sync work begins.

## Day-1 Scope (active)

I am ON from day 1 watching iOS-internal contracts:

1. **Every PR that touches a `public` declaration** — diff, classify, gate if breaking.
2. **Every change to `ContributionCalculating`** — presumed breaking until proven purely additive.
3. **Every SwiftData `@Model` schema change** — requires explicit schema-version bump and a migration plan I sign off on.
4. **Every change to data-layer ↔ UI-layer service interfaces** — coordinate with Virgil and Basher.

## Sync-Era Activation (post-MVP)

Additional responsibilities ramp up when **any** of the following are true:

1. The team decides to wire iOS sync to the existing backend.
2. The OpenAPI spec changes (server-side) for any reason — I diff and report.
3. The iOS client begins generating from a new version of the spec.
4. Linus needs a second pair of eyes on a contract decision.

## Coordination Map

- **Virgil** — owns the iOS-side contracts I watch every day: SwiftData schemas, `ContributionCalculating`, service interfaces. We are partners; he writes, I monitor and gate.
- **Basher** — consumes Virgil's contracts from the UI side. I alert him when a contract change requires UI updates.
- **Linus** — Dev QA. Writes tests across the iOS app. We coordinate when a contract change needs new test coverage; he authors the tests.
- **OpenAPI spec ownership** — currently unassigned (Linus stepped back from integration in v1). When sync work begins, this will need a re-assigned owner before the sync-era surface activates.
- **Danny** — final arbiter when a breaking change is unavoidable; he weighs migration cost.

## Useful Files

**iOS internal contracts (day-1 active):**

- `ios/Sources/Models/DomainModels.swift` — SwiftData `@Model` types (Portfolio, Category, Ticker). Schema lives here.
- `ContributionCalculating` protocol — the user-swap seam (Virgil knows the exact path; likely `ios/Sources/VCA/` or similar).
- Service / repository protocols in the data layer — Virgil owns the paths.

**Future sync surface (activates when sync work begins):**

- `backend/api/main.py` — FastAPI app; OpenAPI spec is generated from this.
- `openapi.json` (or wherever the snapshot lives) — the contract surface.
- iOS generated client output directory (Linus knows the path).

## Outputs the team expects from me

- Spec-diff reports (one per change)
- Breaking-change alerts with severity
- Versioning recommendations (semver bumps, deprecation timelines)
- Migration plans when a breaking change is unavoidable
- Periodic compatibility matrix

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.

## Onboarding — 2026-05-15

### 1. Product in one paragraph

Value Compass is a local-first iOS/iPadOS app (iOS 17+ / iPadOS 17+) that helps individual investors practice **value cost averaging (VCA)**: the user defines a portfolio (name, monthly budget, MA window of 50 or 200), organizes holdings into categories with weights and tickers, enters or fetches current price + moving-average data, then taps **Calculate** / **Invest** to get per-ticker contribution amounts that sum to the budget (`docs/tech-spec.md` §1–§3, `docs/app-tech-spec.md` §1, §5). Saved results land in an immutable, append-only local **ContributionRecord** history. The v1 MVP shape is offline-first SwiftUI + SwiftData, single-device, no user accounts, no cloud sync, no live brokerage data — the **VCA algorithm itself remains user-owned** and plugs in via a single protocol seam.

### 2. Technical architecture I need to know

- **Local-first iOS/iPadOS, SwiftUI + SwiftData.** SwiftData is the runtime source of truth; everything in `docs/db-tech-spec.md` §2 must run with the network unplugged.
- **THE critical contract — `ContributionCalculating` protocol** (`app/Sources/Backend/Services/ContributionCalculator.swift:3`, declared in `docs/tech-spec.md` §7.1 and `docs/app-tech-spec.md` §6). This is the single seam between the app shell and the user-owned VCA algorithm. Any signature change here cascades into every UI flow that triggers a calculation. Treat any non-additive change as breaking.
- **SwiftData `@Model` persistence schema** lives at `app/Sources/Backend/Models/DomainModels.swift`. The six `@Model final class` types I have to watch:
  - `Portfolio` (line 23)
  - `Category` (line 105)
  - `Ticker` (line 140)
  - `ContributionRecord` (line 178)
  - `CategoryContribution` (line 242)
  - `TickerAllocation` (line 262)
  Constraints/invariants enumerated in `docs/db-tech-spec.md` §2.3 and §5; cascade rules in §2.4. History rows are append-only snapshots — schema changes that break snapshot readability are a v1 data-loss event.
- **Folder map (Virgil's territory, where most contracts live):**
  - `app/Sources/Backend/Models/**` — `@Model` types (schema)
  - `app/Sources/Backend/Contracts/**` — currently `BackendContracts.swift` (namespace enum); future home for cross-layer protocol surfaces
  - `app/Sources/Backend/Services/**` — `ContributionCalculator.swift` and other service protocols
  - `app/Sources/Backend/Networking/**` — `APIClient`, `MassiveAPIKeyValidator`, `MassiveAPIKeyStore`, `KeychainStore`, `BackendSyncProjection`, `AppVersion`, `DeviceIDProvider`
  - `app/Sources/App/Dependencies/**` — DI composition root; today: `APIClientDependency.swift`, `ContributionCalculatorClient.swift`, `KeychainClient.swift`, `MassiveAPIKeyClient.swift`, `MassiveAPIKeyValidatorClient.swift`, `ModelContainerClient.swift`, `BundleInfoClient.swift`, `DeviceIDClient.swift`, `MinAppVersionClient.swift`, `PushNotificationsClient.swift`, `UserDefaultsClient.swift`. Every `Client` here is a contract a consumer depends on.
- **Stream routing:** `app/Sources/Backend/**` and `app/Sources/App/Dependencies/**` are exactly the folder scope of the `team:backend` workstream (`.squad/streams.json`). PRs labeled `team:backend` are the high-signal queue I diff first.

### 3. V1 roadmap & scope boundaries

**In-scope for v1 (open MVP issues, all `mvp` labeled, see `.squad/decisions.md` triage table):**

- #123 — Local SwiftData models for portfolios, market data, settings, snapshots
- #124 — Local-only app shell and onboarding gates
- #125 — Portfolio, category, and symbol-only holding editor
- #126 — Bundled NYSE equity/ETF metadata with typeahead
- #127 — Massive API key validation and Keychain storage
- #128 — Massive client and shared local EOD market-data refresh
- #129 — TA-Lib-backed `TechnicalIndicators` SPM package
- #130 — Invest action with required capital and local VCA result
- #131 — Explicit Portfolio Snapshot save and delete
- #132 — Snapshot review and per-ticker Swift Charts
- #133 — Settings, API key management, preferences, full local reset
- #134 — iPhone NavigationStack / iPad NavigationSplitView workspace
- #135 — Complete MVP integration and regression test pass
- **#145 — p0: migrate the app from MVVM to TCA** (the biggest contract risk in the queue — see §5)

**Mothballed / dormant in v1 (NOT my surveillance surface right now):**

- The Python `backend/**` directory (FastAPI app, SQLAlchemy models, Alembic migrations, poller). Confirmed mothballed by `.squad/decisions.md` (2026-05-15T01:54:01-07:00 streams.json drops `_mothballed`; `routing.json` keeps `integration` domain `status: "mothballed-v1"`).
- `openapi.json` and the generated Swift OpenAPI client (currently mirrored to `app/Sources/Backend/Networking/openapi.json` per the 2026-05-14 folder rename decision, but unused by app code in v1).
- **OpenAPI authorship is unassigned** (Linus stepped back from integration in v1; needs a re-assigned owner before sync-era surveillance activates).
- My server-contract role (semver on `openapi.json`, generated-client diffs, server↔client compatibility matrix) stays **dormant until sync work begins post-MVP** — confirmed by user directive 2026-05-15T01:13:56-07:00.

### 4. My active surveillance in v1

For every open PR I will diff for changes in:

1. **`ContributionCalculating` protocol** at `app/Sources/Backend/Services/ContributionCalculator.swift`. Any change presumed breaking until proven purely additive. The companion error type `ContributionCalculationError` (`docs/tech-spec.md` §7.1) is part of the same contract — adding/removing/renaming a case is breaking for any exhaustive `switch` consumer.
2. **SwiftData `@Model` schemas** under `app/Sources/Backend/Models/**` — specifically the six classes listed above. Any field add/remove/rename, type change, optionality change, relationship change, or cascade-rule change requires:
   - Explicit SwiftData model-version bump (per `docs/db-tech-spec.md` §4.1: "ship with an explicit model version even if the initial migration is empty/trivial")
   - Migration plan I sign off on
   - Confirmation that history snapshots remain readable (`§4.1`, `§2.4`)
3. **`public` declarations across `app/Sources/Backend/**`** — service/repository interfaces between Virgil's data layer and Basher's UI layer. Today this includes the protocols already documented (`ContributionCalculating`) and the protocols called out in the `team:backend` keyword signals (`.squad/decisions.md`): `MarketDataProviding`, `TickerMetadataProviding`, `MassiveAPIKeyStoring`. As Virgil lands #123/#127/#128, every new `protocol` or `public` type in this tree enters my watchlist.
4. **DI client interfaces under `app/Sources/App/Dependencies/**`** — each `*Client.swift` (10 today: `APIClientDependency`, `BundleInfoClient`, `ContributionCalculatorClient`, `DeviceIDClient`, `KeychainClient`, `MassiveAPIKeyClient`, `MassiveAPIKeyValidatorClient`, `MinAppVersionClient`, `ModelContainerClient`, `PushNotificationsClient`, `UserDefaultsClient`) is a wired-up contract; signature drift here breaks the composition root and every feature that resolves it.

### 5. Specific contract risks in the v1 work queue

- **#123 (SwiftData models — Virgil/backend)** — *direct hit on surveillance #2.* Body explicitly says "Replace legacy contribution-history model with local-only MVP models: Portfolio, Category, Holding, TickerMetadata, MarketDataBar, PortfolioSnapshot, AppSettings." That's a wholesale schema rewrite with new types (`Holding`, `TickerMetadata`, `MarketDataBar`, `PortfolioSnapshot`, `AppSettings`) replacing/augmenting the six `@Model` classes that exist today. This MUST land with an explicit SwiftData model version, a migration plan from the legacy schema to the MVP schema, and a story for any pre-existing `ContributionRecord` data on disk. **I will gate on the migration plan.**
- **#127 (Keychain / `MassiveAPIKeyStoring` — backend)** — *direct hit on surveillance #3.* Defines a new `MassiveAPIKeyStoring` protocol consumed by Settings UI and by the Massive client. The "saved key is masked in UI" + "tests use injectable stores" requirements imply consumers across both Backend/Networking and Features. Once this protocol ships, signature changes are breaking for both.
- **#128 (Massive client — backend)** — *surveillance #3 + #4.* Body says "No generated OpenAPI/value-compass backend client is used" — confirms my OpenAPI dormancy. But the new `URLSession`-based `MassiveClient` becomes a public seam consumed by #130 (Invest) and #132 (Charts). Mock-session test contract is part of the surface.
- **#129 (TechnicalIndicators SPM package — backend)** — *new public-API surface from day 1.* The body specifies a `TechnicalIndicating` Swift facade exposing ATR, SMA, EMA, Bollinger, RSI, Keltner, with the constraint "C/TA-Lib symbols do not leak above the package boundary." The package's public API becomes a versioned contract the moment another module imports it; the C-symbol-leak rule is itself a contract invariant I will check on every PR to that package.
- **#130 (Invest action — frontend+backend)** — *surveillance #1.* Acceptance criteria "Call `ContributionCalculating` locally" + "Output is non-negative and reconciles to entered capital" — confirms the algorithm seam is the calculation contract. Any drift in input/output types or pre/post-validation behavior is a breaking change for the user-owned algorithm implementation.
- **#145 (TCA migration — frontend+backend, p0)** — **biggest contract risk in the queue.** The migration takes a hard dependency on `swift-composable-architecture` 1.25.5 and rewrites every feature into `@Reducer`-macro modules. Implications for me:
  - Every **Reducer `State` struct** is a Swift API contract. Field add/remove/rename = breaking for any composing parent reducer or test that constructs that state.
  - Every **Reducer `Action` enum** is a Swift API contract. Case add/remove/rename = breaking for every `switch` and every parent `Action.feature(.foo)` callsite.
  - Every **`@Dependency` key** under `app/Sources/App/Dependencies/**` is rewritten into a TCA `DependencyKey`; the *interface* must stay stable across the migration or every feature that resolves it breaks.
  - The Phase-0 "Dependency interfaces, AppReducer skeleton, navigation structure" issues will define the new shared contract surface for the entire app — these are the ones I want to review FIRST and HARDEST. Phase-2 issues are forbidden from touching Phase-1 files (per #145 phase rules) — that's an in-spec contract-stability discipline I should help enforce on review.
  - The migration is a once-only opportunity to set semver discipline; everything that lands during it is effectively v0 of the post-migration contract.

### 6. Open questions

1. **`internal` vs `public` enforcement.** The repo currently ships as a single Xcode app target (`app/VCA.xcodeproj`), not an SPM-modularized workspace. With a single target, *every* Swift declaration is implicitly `internal` and there is no compiler-enforced public surface to gate on. Question: do we adopt a convention that "anything `public`-marked is a watched contract" *now* (anticipating #129's SPM package and the TCA migration's likely module split), or do we treat the whole `app/Sources/Backend/**` tree as the contract surface regardless of access modifier? Need a Danny call on this.
2. **Version-bump cadence pre-1.0.** No semver policy exists today (no released version, no `CHANGELOG.md`, no tag scheme for the iOS app I can find). Pre-1.0 SemVer technically allows breaking changes on every minor bump, which is too loose for a contract-monitor role. Recommend we agree on: (a) a marker file (e.g., `app/CONTRACT_VERSION` or a constant) that bumps when the SwiftData model version, `ContributionCalculating`, or any backend-stream public protocol changes, and (b) what "breaking" obliges — a required PR label, a deprecation cycle length, etc.
3. **SwiftData migration policy specifics.** `docs/db-tech-spec.md` §4.1 says "additive local schema changes are preferred" and "ship with an explicit model version even if the initial migration is empty/trivial" — but doesn't pin a `VersionedSchema`/`SchemaMigrationPlan` convention. Issue #123 will force this decision. I want to be in the loop when Virgil chooses the pattern.
4. **TCA Reducer interface change classification.** Pre-migration: changing a view-model property is internal refactor noise. Post-migration: changing a `Reducer.State` field is an API change visible to every composing parent and every test. Need an agreed rule for when a Reducer/State/Action change is "breaking" vs "internal" — proposed default: any change to a `Reducer` whose parent composes it via `Scope`/`ifLet`/`forEach` is breaking; root `AppFeature` changes are always breaking.
5. **OpenAPI authorship re-owner trigger.** When sync work begins, who owns `openapi.json`? Linus stepped back; the slot is empty. I should be informed the moment sync is scheduled so I can flag that the owner gap blocks my server-side activation.
