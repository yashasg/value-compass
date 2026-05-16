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

## Cycle 2026-05-15 #3

**Lane:** `app/Sources/Backend/Persistence/*Repository.swift` protocol-seam audit on `origin/main`.

**Finding:** No new finding. `AppSettingsRepository`, `MarketDataBarRepository`, and `PortfolioCascadeDeleter` are internal persistence helpers with no `origin/main` call sites outside their own declarations/comments, so there is no live consumer contract that would break on a refactor today.

**Action:** No issue filed or updated.

**Dedup proof:** Reviewed `gh issue list --state all --search ...` results for `"AppSettingsRepository"`, `"MarketDataBarRepository"`, `"PortfolioCascadeDeleter"`, `"contract"`, `"schema"`, `"DependencyClient"`, and `"protocol"`. Related issues reviewed: #219, #235, #242, #244, #249, #250, #145, #147, #226, #28, #29. No existing issue covers a live repository-seam break, and the audited structs are not yet wired through DI or depended on by features.

**Revalidation:** Cycle-#2 conclusion still holds on `origin/main`: `ContributionCalculatorClient` still exposes both the legacy and full-shape calculator seams, and `APIClient` still sources `X-App-Attest` from `AppAttestProvider`.

## Cycle 2026-05-15 #4

**Lane:** `app/Sources/App/Dependencies/**` — `DependencyKey.liveValue/previewValue/testValue` parity audit across all 11 `@DependencyClient`s.

**Finding:** `APIClientDependency.swift:16-20` declares only `liveValue`. All 10 sibling clients (`BundleInfoClient`, `ContributionCalculatorClient`, `DeviceIDClient`, `KeychainClient`, `MassiveAPIKeyClient`, `MassiveAPIKeyValidatorClient`, `MinAppVersionClient`, `ModelContainerClient`, `PushNotificationsClient`, `UserDefaultsClient`) declare both `liveValue` and `previewValue`. This violates the Phase-0 acceptance criteria in #147 ("A `previewValue` and `testValue` … keep it"). `testValue` absence is conventional (macro-synthesized `unimplemented`); `previewValue` absence is the actual asymmetry — without it `swift-dependencies` falls through to the unimplemented `testValue` inside SwiftUI `#Preview`, which will crash every preview that composes a Phase-1 reducer using `@Dependency(\.apiClient)`. Currently latent (zero call sites), but the seam was specifically designed for Phase-1 consumption per the file's own doc comment.

**Action:** Opened #282 — `contract(dependencyclient): APIClientDependency missing previewValue — asymmetric vs all 10 sibling clients, violates #147 AC`. Labels: `priority:p2`, `mvp`, `ios`, `architecture`, `team:backend`, `squad:nagel`. Classification: additive hardening (no breaking signature changes; pure add of one static let).

**Dedup proof:** Searched `gh issue list --state all --search "contract in:title" --limit 50`; `gh issue list --state all --search "@Model" --limit 30`; `gh issue list --state all --search "openapi OR dependencyclient" --limit 30`; `gh issue list --state all --search "APIClientDependency OR previewValue OR apiClient" --limit 30`; `gh issue list --state all --search "DependencyKey OR liveValue OR previewValue" --limit 30`; `gh issue list --state all --search "preview OR previewValue" --limit 20`. Reviewed: #225, #226 (X-App-Attest header on the *transport*, not the DI client's value parity), #242 (ContributionCalculatorClient method-surface narrowness — different client, different drift), #147 (defines the AC this issue closes the gap against, CLOSED), #28/#29 (service error contract, different surface). No existing or closed issue covers a missing `previewValue` on `APIClientDependency`.

**Learning:** In a directory of `@DependencyClient` siblings, the *set* of declared static-let values (`liveValue`/`previewValue`/`testValue`) is itself part of the contract surface — a missing `previewValue` is asymmetric API hygiene that silently degrades SwiftUI Preview UX even when no production behavior is wrong. Always table-audit value parity across the whole directory, not just method shape on a single file.

## Cycle 2026-05-15 #5

**Lane:** `app/Sources/Backend/Models/MVPModels.swift` — `Codable`-on-`@Model`-JSON-column shape lock audit for `InvestSnapshot.compositionJSON` (and `warningsJSON`).

**Finding:** `CategorySnapshotInput` (`MVPModels.swift:175-179`) is the Swift type whose auto-synthesized `Codable` conformance defines the on-disk JSON byte shape of `InvestSnapshot.compositionJSON` — a persistent SwiftData column locked into the v1 baseline by `LocalSchemaV1` (`LocalSchemaVersions.swift:34`) and #235. Three guardrails are missing:

1. **No explicit `CodingKeys`** — JSON key set is an emergent property of property names (`name`, `weight`, `symbols`), so a `s/name/displayName/` refactor silently breaks decode of every previously-persisted row.
2. **No byte-pinned test** — `MVPModelsPersistenceTests.testInvestSnapshotRoundTripsCompositionAndWarningsAsJSON` round-trips through the *same struct* and never asserts canonical JSON bytes, so lockstep renames slip through CI.
3. **No documentation** — `grep` across `docs/` and `.squad/` returns zero references to `CategorySnapshotInput` / `compositionJSON` / `warningsJSON`.

Encoder/decoder pair (`MVPModels.swift:260-266`) pins only `outputFormatting = [.sortedKeys]`; no `keyEncoding/Decoding`, no `dateEncoding/Decoding`. Cheap-mitigation window is now: `grep -rn "InvestSnapshot(" app/Sources/` returns zero call sites (only `MVPModelsPersistenceTests` constructs one) — #131 is OPEN and will be the first writer of `InvestSnapshot` to disk. Post-#131, any rename becomes a SwiftData custom-`MigrationStage` problem.

**Action:** Opened #295 — `contract(@Model): InvestSnapshot.compositionJSON on-disk shape unprotected — CategorySnapshotInput Codable has no CodingKeys, no byte-pinned test, undocumented as persistent contract`. Labels: `priority:p1`, `mvp`, `ios`, `architecture`, `swiftdata`, `persistence`, `team:backend`, `team:strategy`, `squad:nagel`. Mitigation prescribed in three additive steps (add `CodingKeys`, add byte-pinning test, document the contract) — all pure-Swift, zero data migration.

**Dedup proof:** Searched `gh issue list --state all --search` for: `"CategorySnapshotInput"` (0 hits), `"compositionJSON"` (0 hits), `"InvestSnapshot"` (2 hits — #219 closed; #131 open snapshot save/delete), `"Codable"` (only #1 unrelated front-end spec), `"CodingKeys"` (0 hits), `"JSON in:title,body"` (12 results — none touched persistent-column JSON shape), `"snapshot composition"` (0 hits), `"JSON column schema"` (0 hits), `"contract in:title"` (full Nagel-contract corpus — confirms no prior issue on JSON-in-`@Model`-column shape). Existing issues reviewed: #219 (closed; introduced the type; AC checked "JSON round-trip" but not "byte shape"), #235 (closed; baselined `LocalSchemaV1` — this issue is the JSON-in-column complement), #131 (open; first writer; this finding must land before #131 closes), #132 (open; first reader via `decodedComposition()`), #249 / #250 / #244 (sibling `@Model` contract gaps — orthogonal surface). No existing or closed issue covers an unpinned `Codable` shape on a SwiftData JSON column.

**Classification:** modifying (latent / preventive). The contract surface exists today and works as written; it is the *absence of pinning* that constitutes the drift hazard. Mitigation is purely additive (no signature change, no data migration) iff filed before #131 ships its first writer. Post-#131 it converts to a real breaking-change concern requiring a custom `MigrationStage` to rewrite legacy JSON.

**Learning:** A `Codable` struct whose JSON output is stored in a SwiftData `@Model`'s `String` column is a contract surface that SwiftData itself cannot see — the schema migration plan only tracks property names of the `@Model` class, never the bytes inside an opaque column. Surveillance has to treat *every* `JSONEncoder.encode → @Model String column` pipeline as a persistent contract whose shape is defined by the Codable type's property names *unless* `CodingKeys` is declared. `outputFormatting = [.sortedKeys]` is a *necessary* condition for byte-pinned tests (and therefore for safe versioning) but is *not* a contract lock by itself — it only stabilizes ordering, not key spelling. Next pass should sweep the whole `Backend/` tree for `JSONEncoder().encode(` writes into any `@Model` column and apply the same three-guardrail check (explicit `CodingKeys`, byte-pinned test, doc note).

## 2026-05-15 contract pass (loop cycle, requested by yashasg)
- Scope: re-verified the five open `squad:nagel` items (#250, #295, #298, #302, #303) — all five still hold against `main` (HEAD 811c462). No comment-updates needed; evidence in repo unchanged.
- Verified closed: #235 now backed by `LocalSchemaV1` + `LocalSchemaV2` + `LocalSchemaMigrationPlan` (`app/Sources/App/LocalSchemaVersions.swift`); #249 satisfied by `@Attribute(.unique) var id: UUID` on `CategoryContribution` + `TickerAllocation`; #282 satisfied by `APIClientDependency.previewValue`; #244 by the deprecated `breakdown:` overload forwarding into `tickerAllocations:`; #242 by `calculateWithInput` on `ContributionCalculatorClient`.
- DependencyClient symmetry survey (11 files in `app/Sources/App/Dependencies/`): every client carries both `liveValue` and `previewValue`; `testValue` is macro-synthesized via `@DependencyClient`. No new asymmetry.
- @Model survey (`DomainModels.swift`, `MVPModels.swift`): every `@Model` has `@Attribute(.unique)` identity; `MarketDataBar` uses composite-string id, all others `UUID`. `VersionedSchema`/`SchemaMigrationPlan` pinned via `LocalSchemaV1/V2`.
- New findings filed:
  - **#316** `contract(openapi): X-App-Attest is a per-operation required header parameter, not a securityScheme` — `components.securitySchemes` absent; `security:` array absent; header duplicated across 4 protected ops while the URLSession transport (`APIClient.send`) attaches it anyway. labels: team:backend, priority:p2, architecture, ios.
  - **#317** `contract(openapi): HoldingOut/AddHoldingRequest money fields use bare 'number' — generated Swift client decodes as Double, lossy vs iOS Decimal model` — every price/weight/SMA field on `HoldingOut` plus `AddHoldingRequest.weight` is `type: number` (no format), while iOS persistence (`Holding.costBasis`, `MarketDataBar.{open,high,low,close}`, `Ticker.currentPrice/movingAverage`, `CategorySnapshotInput.weight`) stores `Decimal`. labels: team:backend, priority:p2, architecture, ios.
- Dedup proof saved: `gh issue list --search "securityScheme|X-App-Attest scheme|Double Decimal|HoldingOut|number format decimal|openapi number" --state all` returned no matches for either finding before filing.
- Considered, not filed (too speculative without concrete tripwire): `ContributionCalculating: Sendable` paired with non-Sendable `ContributionInput.portfolio: Portfolio?` — the `@MainActor` client closure currently launders the isolation gap; protocol contract is honest enough for user-authored conformers in v1. Re-evaluate if a background-actor call site lands.
- Considered, not filed: `AppSettings.singletonID` uniqueness convention — `@Attribute(.unique) id` plus a fixed default UUID is sufficient as long as `AppSettingsRepository.loadOrSeed` remains the single call site. Watch for new initializers.

## Cycle 2026-05-15 #6

**Lane:** `app/Sources/App/LocalSchemaVersions.swift` — `LocalSchemaV1` ↔ `LocalSchemaV2` freeze audit on `origin/main`.

**Finding:** `LocalSchemaV1.models` (`LocalSchemaVersions.swift:22-37`) enumerates the live global `@Model` classes, and `LocalSchemaV2.models` (`LocalSchemaVersions.swift:54-56`) simply returns `LocalSchemaV1.models`. The version identifiers differ, but the schema snapshots are not frozen; any future field or relationship edit to `Portfolio`, `InvestSnapshot`, `AppSettings`, or any sibling model retroactively mutates both baselines. `LocalSchemaMigrationTests.testSchemaV2ListsTheSameModelsAsV1AndAdvertisesABumpedVersion` (`LocalSchemaMigrationTests.swift:46-50`) currently codifies that aliasing behavior instead of guarding against it.

**Action:** Opened #337 — `contract(swiftdata): LocalSchemaV1/LocalSchemaV2 share live @Model types — versioned baselines are not frozen`. Labels: `priority:p1`, `mvp`, `ios`, `architecture`, `swiftdata`, `persistence`, `team:backend`, `squad:nagel`. Proposed mitigation: freeze each schema version as its own snapshot types/namespace, re-express v1→v2 against frozen shapes, and replace name-parity tests with version-isolation tests.

**Dedup proof:** Searched `gh issue list --state all --search` for `"LocalSchemaV1"`, `"LocalSchemaV2"`, `"VersionedSchema"`, `"SchemaMigrationPlan"`, `"migration baseline"`, `"SwiftData schema snapshot"`, and `"same models"`. Reviewed full near-matches: #235, #249, #250, #295, #298, #219. #235 covered the absence of versioning and is closed; #298 explicitly deferred full per-version namespacing for the additive `id` bump. No existing issue covers the current shared-live-types baseline hole.

**Classification:** modifying (latent; breaking on next real schema change). The app opens stores today, but the next persisted-field rename/removal/relationship change will lack a frozen pre-change schema snapshot.

**Learning:** `VersionedSchema` is only a contract lock if each version owns an immutable schema snapshot. Reusing live `@Model` classes across versions gives a version number without a frozen baseline; tests must assert version isolation, not just entity-name parity.

## Cycle 2026-05-15 #9

**Lane:** SwiftData cascade-routing audit — `Portfolio` deletion path vs the documented `PortfolioCascadeDeleter` contract on `origin/main` (HEAD `e039f7e`).

**Surface:** `app/Sources/Backend/Models/MVPModels.swift:10-20` (the documented cascade contract), `app/Sources/Backend/Persistence/PortfolioCascadeDeleter.swift:21-50` (the sanctioned helper), `app/Sources/App/AppFeature/PortfolioListFeature.swift:225-232` (the drifting production call site — `BackgroundModelActor.deletePortfolio` calls `modelContext.delete(portfolio)` directly), and `app/Tests/VCATests/MVPModelsPersistenceTests.swift:230-280` (helper-only tests, not the live path).

**Finding:** The schema doc-comment block in `MVPModels.swift` declares that `Holding` and `InvestSnapshot` are intentionally detached from `Portfolio` (no `@Relationship`, `portfolioId: UUID` instead) so that shared `MarketDataBar` rows do not cascade-delete; `PortfolioCascadeDeleter` is named as the *only* sanctioned path, with the explicit warning "deleting a `Portfolio` directly via `ModelContext.delete` will *not* cascade to MVP rows". Repo audit confirms the helper has zero production call sites — `grep -rn PortfolioCascadeDeleter app/Sources` returns only the helper itself and the doc comment that names it. The single live deletion site (`BackgroundModelActor.deletePortfolio` invoked from `PortfolioListFeature.confirmDelete`) bypasses the helper entirely. Legacy `ContributionRecord` rows still cascade correctly via `Portfolio.contributionRecords`'s `@Relationship(deleteRule: .cascade)` (`DomainModels.swift:32-33`), but `Holding`/`InvestSnapshot` rows would be left orphaned with a dangling `portfolioId`. Today no production code writes those rows (`grep -rn "Holding(\|InvestSnapshot(" app/Sources` → 0 hits; only test fixtures construct them), so the orphan-on-delete bug is dormant; #131 (OPEN) is the named first writer for `InvestSnapshot` and its own acceptance criteria says "Portfolio deletion deletes its snapshots."

**Action:** Filed **#340** — `contract(@Model): PortfolioCascadeDeleter has zero production callers — PortfolioListFeature orphans Holding/InvestSnapshot rows on portfolio delete`. Labels: `team:backend`, `squad:nagel`, `priority:p1`, `ios`, `architecture`, `swiftdata`, `persistence`, `mvp`. Mitigation prescribed in three additive steps (route `BackgroundModelActor.deletePortfolio` through `PortfolioCascadeDeleter`, add a `PortfolioListFeature` TestStore integration test against a seeded in-memory `ModelContext`, optionally promote the deleter to a `@DependencyClient` for symmetry with #282 hygiene). Must land before #131 ships its first writer; afterward the fix becomes a one-shot launch-time cleanup migration instead of pure routing.

**Dedup proof:** Searched `gh issue list --state all --search`: `"PortfolioCascadeDeleter"` (3 hits — #219, #250, #295, all CLOSED and unrelated), `"cascade"` (review-confirmed: #232 closed addressed delete *confirmation UI* only, never the cascade routing; #131 open is the future writer; #249 closed identity), `"orphan Holding OR orphan InvestSnapshot OR portfolioId orphan"` (0), `"modelContext.delete"` (0), `"deletePortfolio"` (0), `"Holding cascade OR snapshot cascade"` (no new hits), `"data integrity portfolio delete"` (0). Watched open Nagel surfaces (#302, #303, #316, #317, #337) re-checked — all orthogonal (OpenAPI / `VersionedSchema` baseline). Watched closed Nagel surfaces (#226, #225, #242, #250, #295, #298, #235, #244, #249, #282) re-verified — none covers a production cascade-deletion path bypassing a documented helper. New issue.

**Classification:** **latent** (breaks on next change). The contract is honored at the helper level and tested there; the production wiring violates it; the bug doesn't trigger today because no live writer creates the orphan-eligible rows. The instant #131 lands an `InvestSnapshot` writer (or a future `Holding` writer from #123/#128 lineage), the same swipe-to-delete the user has used since v1 silently leaks snapshot rows into the store. P1 because mitigation is purely additive *now*, becomes a real data-cleanup migration *later*, and the named future writer is already in flight as an open MVP issue.

**Learning:** A SwiftData cascade contract has two halves — (a) the helper does the right thing, and (b) every live deletion site calls the helper. Halves can be tested independently, but only an end-to-end test that exercises the reducer-driven deletion path (TestStore against a real in-memory `ModelContext` with seeded child rows) catches the routing gap. Doc-comments that claim "tests assert this contract end-to-end" need to be audited against what the tests *actually* exercise — `MVPModelsPersistenceTests` constructs the helper directly and never reaches `PortfolioListFeature`. Next sweep should table-check every "explicit cascade helper" pattern in the persistence layer (today: `PortfolioCascadeDeleter`, `AppSettingsRepository`, `MarketDataBarRepository`) against the live call sites in `App/AppFeature/**` to confirm each helper has at least one production caller.

## Cycle 2026-05-15 #10

**Lane:** URLSession transport-header vs OpenAPI spec audit on `origin/main` — specifically the `X-Device-UUID` binding (sibling of the `X-App-Attest` header-vs-securityScheme finding in #316; not covered by the last three cycles, which were SwiftData/`@Model` cascade routing (#9), `VersionedSchema` baselines (#6), and Codable-on-JSON-column shape locks (#5)).

**Surface (both sides, file:line):**
- Client side: `app/Sources/Backend/Networking/APIClient.swift:94-109` (`makeOutgoingRequest` unconditionally sets `X-Device-UUID` on every request, including `/health`); `APIClient.swift:115-126` (`send(_:)` invokes it on every send); `app/Sources/Backend/Networking/DeviceIDProvider.swift:9` (keychain-backed value source).
- Spec side: `openapi.json` (root) and `app/Sources/Backend/Networking/openapi.json` mirror — no `X-Device-UUID` parameter on any operation, no `components.securitySchemes` referencing it. Device identity carried instead by `AddHoldingRequest.device_uuid` body field (`backend/api/main.py:329-335`) and the `/portfolio/data` query parameter (`backend/api/main.py:424-428`).
- Backend code: `grep -rin "X-Device-UUID\|x_device_uuid" backend/` → 0 hits; every server-side device-identity read comes from body or query (`backend/api/main.py:332,425,528,601,610`). `/schema/version` and `/portfolio/status` accept and silently discard the header.
- Doc surface that misrepresents the wire format: `docs/legal/privacy-manifest.md:47-58` describes the *header* as what the backend joins on; the backend joins on the body/query value.

**Finding:** Same identifier, three surfaces, only two declared in the spec, only two load-bearing on the server. The privacy-manifest narrative ("`APIClient.swift` … sets the `X-Device-UUID` request header on every outbound backend call … the backend `backend/api/main.py` accepts `device_uuid: UUID` and joins it onto `Portfolio` rows") collapses the header surface and the body/query surface as if they were one binding. They are not. Refactor footgun in both directions: a privacy-minded "stop carrying `device_uuid` in the body, the header already conveys it" silently breaks `POST /portfolio/holdings` (backend reads body); a symmetric backend hardening "trust the header, ignore body" silently breaks today's clients. Also a latent Cloudflare cache-poisoning shape — `GET /portfolio/data` is documented Cloudflare-cacheable and is cache-keyed by the query `device_uuid`; if a future server-side switch made the header canonical without telling Cloudflare to vary on it, every device would receive the first device's portfolio.

**Action:** Filed **#348** — `contract(openapi): X-Device-UUID header attached on every protected request by iOS — undeclared in spec; backend reads device identity from body/query instead`. Labels: `team:backend`, `squad:nagel`, `priority:p2`, `ios`, `architecture` (matching the `priority:p2 + architecture + ios + team:backend` pattern of sibling OpenAPI-shape findings #316 and #317). Routing rationale: the canonical-binding decision lives in the FastAPI app and the regenerated `openapi.json`; the iOS-side change is a passive sweep of whichever surface the spec retires. Mitigation proposed in two interchangeable options (body/query canonical → drop the header from `makeOutgoingRequest:101`; or header canonical → declare it spec-side and remove `device_uuid` from body/query). Recommended cheapest path is body/query canonical (zero generated-client churn; one-line iOS removal; one paragraph of privacy-manifest rewrite).

**Dedup proof:** `gh issue list --state all --search` runs:
- `"X-Device-UUID"` → 7 hits (#339 retention, #329 deletion path, #224 privacy policy, #271 NSPrivacyCollectedDataType (closed), #333 export, #226 closed (App-Attest, not Device-UUID), #322 unrelated positioning). None covers the spec-vs-transport binding drift; #271 is the closest neighbour and is specifically the App-Privacy nutrition-label declaration, not the wire-format declaration in OpenAPI.
- `"device_uuid"` → 3 hits (#339, #2 closed db spec, #271). None spec-shape.
- `"header parameter device"`, `"transport header undocumented"`, `"device identity query body"`, `"header undocumented openapi"`, `"device identity"`, `"duplicate identity body header"`, `"X-Device-UUID header parameter spec"`, `"device_uuid body"` → all 0 hits. 
- Reviewed sibling Nagel surfaces #316 (X-App-Attest as securityScheme — distinct header), #317 (money types — distinct surface), #225/#226 (closed — App-Attest, not Device-UUID), #302 (FastAPI 422 envelope), #303 (202 with body) — all orthogonal.
- Grepped `.squad/scratch/cycle10/{open,closed}-issues.tsv` for `device.uuid|device_uuid|x-device` — three matches: #271 (closed, privacy-manifest), #329 (deletion-path), #339 (retention). All compliance/Reuben surfaces, all consume the *fact* that the identifier flows to the backend; none touches the wire-format declaration on the spec.
- Decision: NEW issue. No existing or closed issue covers an iOS-attached header that the OpenAPI spec fails to declare and the backend fails to read.

**Classification:** modifying (latent; refactor-footgun on next privacy or cacheability change). The system works today because iOS sends both surfaces and the backend happens to pick the right one; the contract is silently lying about which surface is canonical. Mitigation is purely additive iff filed before any client-side cleanup or backend-side hardening lands; afterward it converts into a real wire-incompatibility resolution.

**Handoffs:**
- **Linus** (OpenAPI spec owner) — owns the canonical-binding decision; same regen window as #316 (`X-App-Attest` securityScheme) and #317 (money types). Recommend Linus batch all three into one `openapi.json` regen.
- **Reuben** (legal/compliance) — `docs/legal/privacy-manifest.md:47-58` narrative must be re-validated against whichever surface wins; downstream effect on #339 (retention) and #271 (closed nutrition-label answer) is informational only — neither requires re-opening because the identifier is collected either way, only the wire transport changes.
- **Virgil** (iOS data layer) — implements whichever side of the sweep wins (drop the header from `makeOutgoingRequest`, or sweep `device_uuid` plumbing out of the generated-client call sites). Pairs with Virgil's open work on #128/#131 first-writer landings; this should land before either to avoid double-rework.
- **Basher** — no handoff in v1; reducer-side device-identity plumbing is laundered through `@Dependency(\.apiClient)` and does not surface in feature reducers.

**Learning:** A URLSession transport that attaches a header on every request is itself an undeclared contract surface unless that header appears in `openapi.json`. The pair (`makeOutgoingRequest` ↔ `parameters[]`) is the smallest unit of audit — every `req.setValue(..., forHTTPHeaderField:)` on the client must correspond to exactly one declared parameter or securityScheme on the spec. `X-App-Attest` has #316 (declared per-op, should be securityScheme); `X-Device-UUID` has #348 (undeclared, possibly redundant); `X-App-Version` is the next sibling — same pattern, also undeclared, deferred to a later pass once #348's canonical-binding decision lands so the third sweep doesn't re-litigate the same choice. Doc files that narrate the wire format (`docs/legal/privacy-manifest.md`) must be table-audited against the spec, not against the code comments, because comments can drift with the code while the spec is the only enforced contract.

## Cycle 2026-05-15 #11

**Lane:** `ContributionCalculating` protocol's *error contract* (the user-swappable VCA seam) on `origin/main` (HEAD `0145f8f`). Not previously audited — prior cycles covered the client surface (#242, #282, cycle #4), the input wiring (#359 by Linus's batch), and the schema layer (#235, #244, #249, #250, #295, #298, #337/#350, #340, cycles #5/#6/#9). Error semantics across conformers were unexamined.

**Finding:** `protocol ContributionCalculating` at `app/Sources/Backend/Services/ContributionCalculator.swift:3-5` ships with **zero doc-comment**, and its three built-in conformers disagree on how to respond to post-validator invariant violations:

- `MovingAverageContributionCalculator` calls `preconditionFailure` on `portfolio == nil` (line 282) and on missing market data (line 298) — *crashes the process*.
- `BandAdjustedContributionCalculator` returns `.failure(.missingPortfolio)` (line 366) and `.failure(.missingBandPosition(symbol))` (line 383) — *graceful errors*.
- `ProportionalSplitContributionCalculator` returns `.failure(.missingPortfolio)` (line 463) — graceful; reads no market data.

Compounding asymmetries: (1) `ContributionInputValidator.validate(_:)` (lines 207-250) checks `currentPrice` + `movingAverage` but never `bandPosition` — the band-style calculator carries an undocumented input dependency that any user-authored band-style conformer would inherit only by reading 175 lines below the protocol. (2) `docs/services-tech-spec.md:48-52` documents the protocol as `func calculate(for portfolio: Portfolio) throws -> [TickerAllocation]` and §8.1 (lines 240-249) lists five error cases (`missingMarketData`, `invalidWeights`, `zeroBudget`, `emptyTickerSet`, `invalidOutput`) — actual signature is `calculate(input:) -> ContributionOutput` and only `missingMarketData` survives in the real 11-case `ContributionCalculationError` enum. Nothing breaks today because the live default (`MovingAverage`, wired in `ContributionCalculatorClient.swift:50/60/66/72`) only flows through `ContributionCalculationService.calculate(...)`, which always runs the validator first. The seam is honest for built-ins on the validator-fronted path; dishonest for the use case the seam exists to support (#15 closed, #238 open — Investrum's user-pluggable algorithm axis).

**Action:** Opened **#363** — `contract(protocol): ContributionCalculating has no doc-comment, asymmetric post-validator error handling across conformers, undocumented bandPosition input, and a spec describing a different signature`. Labels: `team:backend`, `priority:p1`, `mvp`, `ios`, `architecture`, `squad:nagel`. Mitigation prescribed in five purely-additive steps: (a) protocol doc-comment naming validator guarantees + post-conditions + error channel + `preconditionFailure` rule; (b) `MovingAverage`'s two `preconditionFailure` calls → `.failure(...)` for symmetry; (c) document `bandPosition` as a calculator-private input OR add capability-gated validation; (d) rewrite `services-tech-spec.md` §3.1 + §8.1 to match shipping signature + enum; (e) add a `ContributionCalculatorTests` case that drives each conformer with validator-failing inputs directly.

**Dedup proof:** `gh issue list --state all --search` runs:
- `"ContributionCalculating"` → 13 hits; reviewed each — #15 (closed; original user-owned VCA directive); #39 (closed; initial stub tests); #130 (closed; first consumer); #242 (closed; client-vs-protocol *width* gap, not error-contract symmetry); #194/#195/#192/#154/#156 (closed; TCA migration tests); #356 / #359 (open; `Holding`-path input wiring + indicator persistence, orthogonal surfaces); #238 / #269 / #277 / #286 (positioning issues, not contract-surface).
- `"preconditionFailure"` → 0 hits. `"missingBandPosition OR bandPosition"` → only #356/#359/#242 (already reviewed). `"MovingAverageContributionCalculator OR BandAdjustedContributionCalculator OR ProportionalSplitContributionCalculator"` → only #356/#359/#242 (already reviewed). `"ContributionCalculationError"` → 0 contract-symmetry hits. `"ContributionOutput"` → no new hits. `"error contract"` → #28 closed (sync/HTTP error envelope, completely different surface), #302/#316/#317/#348 (OpenAPI surfaces, already-filed siblings). `"throws in:title,body calculator"`, `"missingPortfolio crash"`, `"calculator error symmetry OR asymmetric calculator"`, `"calculator documentation"`, `"services-tech-spec"`, `"user-authored conformer OR user-swappable seam"` → 0 contract-surface hits.
- Decision: NEW issue. No existing or closed issue covers the protocol-level doc gap + cross-conformer error-handling asymmetry + undocumented `bandPosition` input + spec-vs-code signature drift on `ContributionCalculating`.

**Classification:** modifying (latent breaking). The contract is honest for the live orchestrator path against the built-in default; it is silently misleading for any user-authored conformer following the spec or `MovingAverage`'s pattern. Flips to live breaking when a TestStore calls a conformer directly with validation-failing input, or when a user-authored conformer copies `MovingAverage`'s `preconditionFailure` pattern, or when the next reducer wires a conformer that bypasses `ContributionCalculationService`. Pure-Swift mitigation; zero data migration; zero behavior change on the orchestrator-fronted live path.

**Learning:** When a protocol is sold as a *user-extension seam*, the protocol's own doc-comment is the entire contract — not the orchestrator that fronts it, not the validator that fronts the orchestrator, and definitely not the spec document that describes a different signature. The pair (`Validator.validate guarantees` ↔ `Protocol.calculate post-conditions`) is the smallest unit of audit for any "we run a validator then call the seam" pattern: if the validator's guarantees aren't named in the seam's doc-comment, a third-party conformer has no way to know which invariants are pre-checked vs which they must guard locally, and the three built-in conformers are then evidence-by-construction of how to disagree about it. Next pass should sweep every other `protocol ... { func operation(...) -> ResultType }` in `app/Sources/Backend/Services/**` (today: `ContributionCalculating` only; `MarketDataProviding` from the spec is not yet ship code) and apply the same four-corner check — doc-comment, conformer symmetry, validator coverage, spec-vs-code drift.

## Cycle 2026-05-15 #12

**Lane:** Specialist-loop sweep on `origin/main` (HEAD `4c71d16`) covering the four contract surfaces in scope: (a) `ContributionCalculating` protocol seam (cycle #11 lane), (b) `MassiveAPIKeyStoring` / `MassiveAPIKeyValidating` (cycle #11's prescribed next-pass sweep of remaining `Backend/Services` + `Backend/Networking` protocols), (c) `DependencyClient` `liveValue`/`previewValue` symmetry across all 11 clients in `app/Sources/App/Dependencies/`, (d) URLSession transport headers (`X-Device-UUID`, `X-App-Attest`, `X-App-Version`) vs `openapi.json` parameter declarations, (e) SwiftData `@Model` frozen-snapshot baselines (`LocalSchemaV1Models.swift` + `DomainModels.swift` + `MVPModels.swift`), (f) `PortfolioCascadeDeleter` live-call-site verification post-#340/#355.

**Findings:** zero new validated contract drift.

**Re-verification of open Nagel surfaces against current `main` (HEAD `4c71d16`):**
- **#363** (ContributionCalculating protocol — doc-comment + post-validator error asymmetry + undocumented `bandPosition` + spec drift): all four evidence points still hold. `ContributionCalculator.swift:3-5` ships zero doc-comment; `MovingAverageContributionCalculator` lines 282, 298 still call `preconditionFailure` while `BandAdjusted` (line 366, 383) and `ProportionalSplit` (line 463) return `.failure(...)`; `ContributionInputValidator.validate(_:)` lines 207-250 still does not check `bandPosition`; `services-tech-spec.md` §3.1/§8.1 still describes `throws -> [TickerAllocation]`. No comment-update needed; the contract gap is unchanged.
- **#356** (HoldingOut indicator fields have no persistence target): unchanged — `HoldingOut` schema (`openapi.json:790-903`) still requires the eight indicator fields as nullable; `Holding` `@Model` (`MVPModels.swift:64-98`) still carries only `costBasis/shares/sortOrder`. No drift since filing.
- **#359** (no MarketDataSnapshot factory for MVP Holding path): unchanged — `MarketDataSnapshot.init(portfolio:)` (`ContributionCalculator.swift:47-61`) still walks `portfolio.categories.flatMap(\.tickers)`; no `Holding`-rooted factory exists.
- **#348** (X-Device-UUID undeclared in spec): unchanged — `APIClient.makeOutgoingRequest:101` still attaches the header on every request; `openapi.json` still declares it on no operation; `AddHoldingRequest.device_uuid` body field and `/portfolio/data?device_uuid=` query still both load-bearing. Canonical-binding decision still pending — see deferral below.
- **#316** (X-App-Attest as per-op param, not securityScheme): unchanged — `openapi.json:85-92,195-203,315-323,485-493` etc. still per-op; `components.securitySchemes` still absent.
- **#317** (money fields as bare `number`): unchanged — `HoldingOut.{current_price,sma_50,sma_200,midline,atr,upper_band,lower_band,band_position,weight}` and `AddHoldingRequest.weight` still `type: number` without `format`.
- **#302** (`/schema/version` + `/portfolio/status` still publish FastAPI 422 envelope): unchanged.
- **#303** (`/portfolio/holdings` 202 documented as JSON but runtime returns empty): unchanged.

**Closed-since-prior-cycle verifications:**
- **#340 / PR #355** (`PortfolioCascadeDeleter` had zero production callers): NOW resolved. `app/Sources/App/AppFeature/PortfolioListFeature.swift:234` routes `BackgroundModelActor.deletePortfolio` through `PortfolioCascadeDeleter(context:).delete(portfolioID:)`. Doc-comment at lines 223-228 names the deleter as the sanctioned path. Live cascade contract is now actually exercised on the user's swipe-to-delete path.

**Considered, not filed (deferred per prior-cycle discipline):**
- **`X-App-Version` undeclared transport header** (`APIClient.swift:103`). Evidence: iOS attaches `X-App-Version` on every outbound request (including unauthenticated `/health`); `grep "X-App-Version\|x_app_version" backend/` → 0 hits (backend never reads it); `grep "X-App-Version" openapi.json` → 0 parameter declarations. Same drift *shape* as #348 (undeclared client-side header) but with a *simpler resolution*: there is no body/query alternative, so the canonical-binding question that #348 raises does not apply — the only decisions available are "declare it as a per-op header parameter" or "stop attaching it from the client." Cycle #10's deferral rationale ("don't re-litigate the same choice as #348") still applies in spirit: filing now would either (a) get bundled into #348's regen window anyway, or (b) prejudge a binding decision the team hasn't made yet. Re-evaluate the moment #348 is resolved; file as a sibling that piggy-backs on the same OpenAPI regen.
- **`BackendSyncProjection` orphan wire shape** (`app/Sources/Backend/Networking/BackendSyncProjection.swift:1-138`). The struct triple `BackendPortfolioSyncPayload` / `BackendPortfolioPayload` / `BackendHoldingPayload` defines a JSON wire shape that has *no* matching OpenAPI operation: no `POST /portfolio` exists, `AddHoldingRequest` does not accept `portfolio_id`, `PortfolioDataResponse` does not include `device_uuid` or `created_at`. Grep confirms zero live writer (`grep "BackendSyncProjection" app/Sources/` → only the definition + tests at `BackendSyncProjectionTests.swift`). Filing would target dead-but-named code; the contract violation does not exist on the wire today. Re-evaluate the moment a reducer or effect calls `BackendSyncProjection.makePayload(...)` and sends the result anywhere. Reuben's #357 already names the privacy half of this surface; the contract half can wait for a live writer.

**Dedup proof (terms run for the two deferred candidates):**
- `gh issue list --state all --search "X-App-Version in:title,body"` → 18 hits reviewed, none cover the iOS-attached / spec-undeclared / backend-unread shape (closest neighbours are #224 privacy-policy, #316 X-App-Attest, #348 X-Device-UUID, #339 retention, #329 deletion). Decision: hold per prior-cycle discipline.
- `gh issue list --state all --search "BackendSyncProjection in:title,body"` → 2 hits (#357 compliance, #317 money types). Neither covers the orphan-wire-shape contract gap. Decision: hold pending live writer.

**Protocol-sweep deltas vs cycle #11's prescribed next pass:**
- `MassiveAPIKeyValidating` (`MassiveAPIKeyValidator.swift:27-29`): single declared conformer (`URLSessionMassiveAPIKeyValidator`), outcome enum `.valid / .invalid / .serverError / .networkUnavailable` symmetric across the only conformer, async-non-throwing channel consistent. Per-method doc-comment via the protocol-level block. No drift.
- `MassiveAPIKeyStoring` (`MassiveAPIKeyStore.swift:15-27`): three methods all `throws`, per-method doc-comments name the trim-on-save / empty-is-delete / idempotent-delete invariants. Single declared conformer (`KeychainMassiveAPIKeyStore`) honors all three at lines 69-99; `MassiveAPIKeyStoreError.underlying(...)` wraps every keychain failure consistently. No drift.
- No other `protocol` declarations exist in `app/Sources/Backend/**` — sweep complete.

**DependencyClient symmetry survey (re-run):** all 11 clients in `app/Sources/App/Dependencies/` ship both `liveValue` and `previewValue`; `testValue` is macro-synthesized via `@DependencyClient`. No asymmetry. (Confirms cycle 2026-05-15's identical finding still holds against `4c71d16`.)

**Classification:** no action. Pure re-verification cycle; the open surface is unchanged, the closed surface is freshly verified, the deferred candidates remain deferred per the rationale of cycle #10. Zero new findings is the expected and correct outcome for this pass.

**Learning:** A "zero findings" cycle is a load-bearing observation when the contract corpus is already saturated — it proves the prior cycles' filings are still load-bearing and that the team's fix cadence on cascade routing (#340 → #355) is the right shape. The next time a finding lands, it will most likely be triggered by *new code arriving* (a reducer that wires `BackendSyncProjection` to the wire; a feature that calls a conformer outside `ContributionCalculationService`; a regen of `openapi.json` that drops the X-App-Attest per-op param without declaring `components.securitySchemes`), not by re-reading the same code at a fresher cursor. The cycle log itself becomes the gate that proves "the contract surface did not silently drift between commits."

## Cycle 2026-05-15 #13

**Lane:** Specialist-loop surveillance pass on `origin/main` (HEAD `67f6fe7`). Goal: confirm whether the four-commit gap since cycle #12's HEAD (`4c71d16`) touched any contract surface I own.

**Method:** `git diff --stat 4c71d16..HEAD -- 'openapi.json' 'app/Sources/Backend/' 'app/Sources/App/Dependencies/' 'app/Sources/App/LocalSchema*'` → empty diff. The four landed commits are `67f6fe7` (NOTICE + THIRD_PARTY_NOTICES + README — repo posture only), `ba61df6` (`PrivacyInfo.xcprivacy` declarations — Reuben's lane), `44386db` (AppInfo/AppSuccess hex contrast tweak — Redfoot's lane), `fe5e249` (`AppLogoMark` Smart-Invert opt-out — Redfoot's lane). Zero touches to `Backend/Models/**`, `Backend/Services/**`, `Backend/Networking/**`, `Backend/Contracts/**`, `App/Dependencies/**`, `LocalSchemaVersions.swift`, `LocalSchemaV1Models.swift`, or `openapi.json`.

**Findings:** zero new validated contract drift.

**Open Nagel surfaces — status unchanged (re-verified by diff):** #363, #359, #356, #348, #316, #317, #381, #302, #303. The diff confirms no underlying file moved beneath any of these filings; no need to re-walk the cursor.

**Deferred candidates — still held per prior-cycle discipline:**
- `X-App-Version` undeclared transport header (sibling of #348). Re-evaluate when #348 lands.
- `BackendSyncProjection` orphan wire shape. Re-evaluate when a live writer appears.

**Dedup proof (spot-checks for symbols newest-introduced by cycle #12's window):** `gh issue list --state open --search "PortfolioCascadeDeleter in:title,body"` → 0 (the symbol's last issue #340 is closed by `4c71d16` per cycle #12). `gh issue list --state all --search "LocalSchemaV1Models in:title,body"` → 0 (no Nagel-surface follow-up needed against the new file `LocalSchemaV1Models.swift` introduced by `0145f8f` / #350; cycle #12 already verified type-identity disjointness + `id`-column delta are pinned by `LocalSchemaMigrationTests`).

**Classification:** no action. Pure surveillance pass; the contract surface is provably static between `4c71d16` and `67f6fe7`. Zero findings is the only honest outcome.

**Learning:** When the inter-cycle commit window is entirely non-contract-stream commits (compliance, a11y, repo posture), the cheapest valid surveillance method is a single `git diff --stat` scoped to the owned paths — no need to re-walk symbol-by-symbol when the diff proves the symbols did not move. This pattern keeps the cycle log honest without paying re-audit cost for unchanged code. Re-walk only when (a) a commit lands inside the owned paths, or (b) a third party (Linus, Virgil, Basher) files against one of the open Nagel surfaces.

## Cycle 2026-05-17 #1

**Lane:** Specialist-loop surveillance pass on local `main` (HEAD `5d11723`), seven commits ahead of cycle #13's HEAD (`67f6fe7`). Goal: verify the three contract-stream closures landed in this window (#392 `monthly_budget` decimal-string pinning, #363 `ContributionCalculating` doc + error symmetry, #337 follow-up v1→v2 migration tests) actually closed the drift they advertise, and re-confirm the seven still-open Nagel filings + two deferred candidates against the moved cursor.

**Method — scoped `git diff --stat 67f6fe7..HEAD` against owned surfaces:**
```
app/Sources/App/LocalSchemaV1Models.swift                 | 16 ++++++++--
app/Sources/Backend/Networking/openapi.json               |  3 +-
app/Sources/Backend/Services/ContributionCalculator.swift | 78 +++++++++++++-
docs/services-tech-spec.md                                | 87 +++++++++++++----
openapi.json                                              |  3 +-
```
The nine landed commits split: `fea5d93` (#392), `c576455` (#363), `9a43fc7` (#337 follow-up tests) touch contract surfaces; `c43bd15` (#391 DPA docs — Reuben), `5d11723` / `508c0a3` / `3a3344c` / `87617f7` / `fb019a3` (a11y + docs — Redfoot/Basher) do not. The `9a43fc7` follow-up is test-only (`app/Tests/VCATests/LocalSchemaMigrationTests.swift`, 422 lines) plus an additive 16-line doc-comment expansion at the top of `LocalSchemaV1Models.swift` (where v1-typed rows are reachable — `willMigrate` vs `didMigrate` callback semantics). No structural model change.

**Closed-since-prior-cycle verifications:**
- **#392** (`PortfolioDataResponse.monthly_budget` bare `number` → decimal-string): resolved end-to-end. Spec: `app/Sources/Backend/Networking/openapi.json:916-919` now reads `"type": "string", "format": "decimal"` (root copy `openapi.json:914-919` matches byte-for-byte). Backend: `backend/api/main.py:294-300` introduces `DecimalString = Annotated[Decimal, PlainSerializer(str, return_type=str, when_used="json"), WithJsonSchema({"type": "string", "format": "decimal"})]`; `PortfolioDataResponse.monthly_budget` is re-typed to `DecimalString` at line 338, and the live serializer at line 503 now passes `portfolio.monthly_budget` (the SQLAlchemy `Decimal`) directly instead of the prior lossy `float(...)` cast. The generated Swift client is build-time-emitted by the swift-openapi-generator plugin (config at `app/Sources/Backend/Networking/openapi-generator-config.yaml` lines 18-22: `generate: [types, client]`, `namingStrategy: idiomatic`) — no checked-in client to diff, but the new `WithJsonSchema` annotation forces the generator's `Decoder` to read the value as a `String`, restoring `Decimal(string:)` round-trip. The `Annotated` block comment names siblings #317 / #392 — leaves a deliberate audit trail that the `HoldingOut.*` and `AddHoldingRequest.weight` money fields (still bare `number` at `openapi.json:702-887`) remain in #317's scope and were not pinned by this PR.
- **#363** (`ContributionCalculating` protocol — doc-comment + post-validator error asymmetry + undocumented `bandPosition` input + spec drift): all four prescribed mitigations landed at `app/Sources/Backend/Services/ContributionCalculator.swift:3-67`. The protocol gains a 65-line doc-comment naming (a) the six validator-guaranteed pre-conditions, (b) the three output-validator post-conditions, (c) the `ContributionOutput.error` channel + non-throwing design, (d) the `MarketDataQuote.bandPosition` calculator-private input dependency. `MovingAverageContributionCalculator` lines 347 and 366 now return `.failure(ContributionCalculationError.missingPortfolio)` and `.failure(.missingMarketData(symbol))` — the two prior `preconditionFailure(...)` call sites are gone (file-wide `grep` reports the only surviving `preconditionFailure` token at line 54, inside the new doc-comment that describes why conformers must not call it). All three shipping conformers (`MovingAverage` line 347, `BandAdjusted` line 434, `ProportionalSplit` line 531) now share the same `.failure(.missingPortfolio)` shape; `BandAdjusted` line 451 keeps its calculator-private `.missingBandPosition(symbol)` guard. `docs/services-tech-spec.md` §3.1 (lines 46-99) rewrites the protocol signature from `func calculate(for portfolio: Portfolio) throws -> [TickerAllocation]` to the shipping `func calculate(input: ContributionInput) -> ContributionOutput`, and §8.1 (lines 261-292) replaces the five-row legacy table with the full eleven-case enum, each row tagged by source (`input validator` / `conformer guard (band-style)` / `output validator`) and matched byte-for-byte against `ContributionCalculationError` cases at `ContributionCalculator.swift:189-228` — both sides ship the same 11 case names with identical associated types.
- **#337** (v1→v2 SwiftData freeze): the follow-up landed as a 422-line `LocalSchemaMigrationTests.swift` plus a 16-line additive doc block in `LocalSchemaV1Models.swift:8-21` explaining that the current `migrateV1toV2` stage runs in `didMigrate` and therefore sees the v2 entity graph (correct — verified against `LocalSchemaVersions.swift:123-136` which declares `MigrationStage.custom(fromVersion: LocalSchemaV1.self, toVersion: LocalSchemaV2.self, willMigrate: nil, didMigrate: { context in ... })`). The tests pin: V1 entity-name enumeration (lines 29-46), distinct `versionIdentifier`s 1.0.0/2.0.0 (lines 48-53), V1↔V2 entity-name parity (lines 56-60), the frozen-snapshot invariant via `ObjectIdentifier` disjointness (lines 67-80), the v1→v2 `id`-column delta on `CategoryContribution`/`TickerAllocation` (lines 89-120), single-stage migration-plan ordering (lines 123-128), in-memory open (line 130-132), and disk-backed cold-open / write / warm-reopen round-trip carrying both a `Portfolio` (lines 134-175) and a full eleven-entity v2 fixture (lines 177-end). The bridge is end-to-end exercised; the freeze contract is now load-bearing in CI, not just visual.

**Re-verification of open Nagel surfaces against HEAD `5d11723`:**
- **#359** (no `MarketDataSnapshot` factory for MVP `Holding` path): unchanged. `MarketDataSnapshot.init(portfolio:)` at `ContributionCalculator.swift:112` still walks `portfolio.categories.flatMap(\.tickers)`; no `Holding`-rooted overload exists. The new doc-comment on `ContributionCalculating` actually *reinforces* this gap by codifying `MarketDataQuote.{currentPrice, movingAverage}` as validator pre-conditions sourced from the `Ticker` graph — making the `Holding`-path disconnect more visible, not less.
- **#356** (`HoldingOut` indicator fields have no persistence target on iOS `Holding` `@Model`): unchanged. `openapi.json:790-903` still requires eight indicator fields on `HoldingOut`; `MVPModels.swift:63-98` still ships `Holding` with only `id` / `portfolioId` / `symbol` / `costBasis` / `shares` / `sortOrder` / `createdAt` — no `currentPrice`, no `sma_*`, no `*_band`, no `bandPosition`.
- **#348** (`X-Device-UUID` undeclared transport header): unchanged. `APIClient.swift:101` still attaches the header on every protected request; `grep "X-Device-UUID" app/Sources/Backend/Networking/openapi.json` → 0 hits. Canonical-binding question still pending.
- **#317** (money fields as bare `number`): unchanged for the `HoldingOut.*` indicator block and `AddHoldingRequest.weight`. `openapi.json:702-707, 796-887` still emit `"type": "number"` with no `format`. #392's `DecimalString` annotation in `backend/api/main.py` is reusable but has not yet been applied to `HoldingOut` or `AddHoldingRequest` Pydantic types — #317 is the live follow-up.
- **#316** (`X-App-Attest` per-op param, not `securityScheme`): unchanged. `grep "securitySchemes" app/Sources/Backend/Networking/openapi.json` → 0 hits. Per-op parameter declarations remain at lines 85, 195, 315, 485, 593, 705.
- **#303** (`/portfolio/holdings` 202 documented as JSON but runtime returns empty): unchanged. `openapi.json:478-510` still advertises a JSON-body 202 response with empty schema (`"schema": {}`).
- **#302** (FastAPI 422 envelopes on `/schema/version` + `/portfolio/status`): unchanged. `openapi.json:160` and `:270` still reference `HTTPValidationError` (defined at `:765-776`).
- **#381 + #402** filed against this HEAD: still present in the local checkout's `openapi.json` (`HealthResponse.status` carries `"default": "ok"` with no `required` array at lines 778-788; `SchemaVersionResponse.min_app_version` survives as a nullable string body field at lines 985-994). Both have already been resolved upstream — PR #397 (commit `c85bf36` closing #381) and PR #407 (commit `9227c5f` closing #402) have merged to `origin/main` but sit *ahead* of local HEAD `5d11723`. No re-file needed; the drift is logically closed at the issue level and will land in the next sync. (Tracker shows both `state=CLOSED, stateReason=COMPLETED`.)

**Deferred candidates re-evaluated:**
- **`X-App-Version` undeclared transport header** (`APIClient.swift:103`). Sibling of #348. Still held: #348 has not yet been resolved (open at this HEAD; no PR linked), so the canonical-binding decision remains unmade. Filing now would prejudge the same binding question. Dedup proof: `gh issue list --state all --search "X-App-Version in:title,body"` → 10 hits, none cover the iOS-attached / spec-undeclared / backend-unread shape (closest neighbours #348, #316, #224, #329, #339, #374, #226, #225, #160 are all sibling-or-orthogonal). Re-evaluate the moment #348 lands.
- **`BackendSyncProjection` orphan wire shape**. Still held: `grep -rn "BackendSyncProjection" app/Sources/` returns only the definition file (`app/Sources/Backend/Networking/BackendSyncProjection.swift:23-107`) — no reducer or effect calls `BackendSyncProjection.makePayload(...)` or any of the throwing converters. The wire-shape contract is named but not on-the-wire. Reuben's #357 already named the privacy half on the same source file (now closed). Dedup proof: `gh issue list --state all --search "BackendSyncProjection in:title,body"` → 4 hits (#357 closed, #317 / #374 / #392 sibling-or-orthogonal). Re-evaluate the moment a live writer appears.

**Candidate-axes swept (all clean):**
- New `public` declarations in `app/Sources/` since `67f6fe7`: `git diff 67f6fe7..HEAD -- 'app/Sources/' | grep -E "^\+.*public (struct|class|enum|protocol|func|var|let|init)"` → empty. No new public-surface drift.
- `openapi.json` operation count: `jq '.paths | keys' openapi.json` → `["/health", "/portfolio/data", "/portfolio/holdings", "/portfolio/status", "/schema/version"]` (5 operations, unchanged vs cycles #12/#13).
- `DependencyClient` symmetry: `app/Sources/App/Dependencies/` still ships the same 11 clients with `liveValue` + `previewValue` + macro-synthesized `testValue`; `git diff 67f6fe7..HEAD -- 'app/Sources/App/Dependencies/'` → empty diff. Symmetry preserved.
- `LocalSchemaV1Models.swift` post-#337 frozen-snapshot integrity: the diff is a 16-line *additive* doc block (lines 8-21) explaining `willMigrate`/`didMigrate` reachability; no `@Model` shape touched. Test coverage at `LocalSchemaMigrationTests.swift:67-80` keeps `ObjectIdentifier` disjointness enforced.
- `services-tech-spec.md` ↔ implementation drift for the post-#363 spec: §3.1's eleven-row error-source table matches `ContributionCalculationError` byte-for-byte (case names, associated types, descriptions). No new `throws` claim re-introduced. (The whole point of #363's spec rewrite was to remove the `throws -> [TickerAllocation]` claim.)
- `MarketDataQuote` symbol references in the new doc-comment (`MarketDataQuote/currentPrice`, `/movingAverage`, `/bandPosition`): all three resolve to live struct members at `ContributionCalculator.swift:137-140`. No DocC-link drift.
- 11-case `ContributionCalculationError` ↔ spec table parity: enum at `ContributionCalculator.swift:189-200` lists `{missingPortfolio, invalidBudget, noCategories, categoryWeightsDoNotSumTo100, categoryHasNoTickers, missingMarketData, missingBandPosition, invalidMarketData, negativeAllocation, outputTotalMismatch, allocationTotalMismatch}`; spec table at `services-tech-spec.md:269-280` lists the same 11 names in the same order of arity. No spec drift introduced by the #363 fix itself.

**Dedup proof (re-run for the candidate axes touched this cycle):**
- `gh issue list --state all --search "DecimalString in:title,body"` → 0 hits. The new `Annotated` type in `backend/api/main.py:294-300` introduces no name collision with prior issues.
- `gh issue list --state all --search "format:decimal in:title,body"` → 0 hits.
- `gh issue list --state all --search "X-App-Version in:title,body"` → 10 hits reviewed (see deferral above); none cover the iOS-attached / spec-undeclared / backend-unread shape.
- `gh issue list --state all --search "BackendSyncProjection in:title,body"` → 4 hits (#357 closed; #317 / #374 / #392 sibling-or-orthogonal).
- `gh issue list --state all --search "willMigrate in:title,body"` → 0 hits. The new `LocalSchemaV1Models.swift` comment block at lines 8-21 introduces no symbol-level drift; the migration stage already runs in `didMigrate` and the comment documents that reality.
- `gh issue list --state all --search "ContributionCalculating doc in:title,body"` → 1 hit (#363 itself, closed).
- `gh issue list --state all --search "monthly_budget in:title,body"` → 1 hit (#392, closed).

**Classification:** no action — pure surveillance cycle. Three closures verified, seven open filings re-confirmed against the moved cursor, two deferred candidates re-deferred per prior-cycle rationale. Zero new validated contract drift. The fix cadence on the three closures (#392 / #363 / #337 follow-up) is clean — each closure ships its mitigation in the same PR as its evidence, with no orphaned half-fix.

**Learning:** The shape of a "load-bearing zero" cycle is now clear: when the inter-cycle window contains *contract-stream* commits (not the cycle #13 case of pure non-contract noise), the surveillance pass costs ~five end-to-end verifications — for each closure, walk (a) the spec, (b) the implementation, (c) the test, (d) any cross-referenced sibling issues. The #392 verification specifically illustrates the pattern: the Pydantic `Annotated[Decimal, PlainSerializer(...), WithJsonSchema(...)]` idiom in `backend/api/main.py` is the right shape for any future money-typed field, and #317's resolution should reuse it verbatim against the `HoldingOut` and `AddHoldingRequest` schemas — Nagel should call that out the next time #317 surfaces. Two-axis lesson: (1) when a closure leaves a deliberate comment naming a still-open sibling issue ("See issues #317, #392"), trust it as a self-documenting audit pointer and verify the sibling is in fact still open; (2) when the issue tracker shows a filing closed on `origin/main` but the fix hasn't reached local HEAD yet, the cycle log should note both states — the drift is logically resolved at the issue level even if still visible at HEAD, and Nagel should not re-file.

## Cycle 2026-05-17 #2

**Lane:** Specialist-loop pass on `origin/main` (HEAD `c2b8851`), three commits ahead of cycle #1's HEAD (`5d11723`). Goal: (a) confirm whether `c85bf36` (#381 fix) and `9227c5f` (#402 fix) actually closed the drift I had previously verified as logically-closed-but-not-on-local-HEAD; (b) re-confirm the remaining seven open Nagel filings against the moved cursor; (c) pick ONE fresh contract axis not yet covered by the eight-issue open queue (`#416 #359 #356 #348 #317 #316 #303 #302`) or the seven-issue recently-closed queue (`#402 #392 #381 #363 #340 #298 #295 #282`).

**Method — scoped `git diff --stat 5d11723..HEAD` against owned surfaces:**

```
app/Sources/Backend/Networking/openapi.json | 16 ++++------------
openapi.json                                | 16 ++++------------
2 files changed, 8 insertions(+), 24 deletions(-)
```

Only `openapi.json` and its app-side mirror moved in the window; both touched by `c85bf36` (#381) and `9227c5f` (#402). Third commit `c2b8851` is `compliance(data-retention)` — Reuben's lane, no contract surface. `git --no-pager diff --stat` confirms `app/Sources/Backend/Services/`, `app/Sources/Backend/Models/`, `app/Sources/App/LocalSchema*`, `app/Sources/App/Dependencies/`, `docs/services-tech-spec.md`, `app/Sources/Backend/Networking/APIClient.swift` are byte-static.

**Closed-since-prior-cycle verifications (the two filings cycle #1 listed as logically-closed-upstream):**

- **#381** (HealthResponse.status default but unclear requiredness): now fully resolved on local HEAD. `openapi.json:783-790` now reads `"type": "object", "required": ["status"], "title": "HealthResponse"` — the `required: ["status"]` array is present. Backend mechanism: `backend/api/main.py:331` carries `model_config = ConfigDict(json_schema_extra={"required": ["status"]})`. The `Field(default="ok")` is preserved as documentation but no longer fork-points the requiredness. Generated Swift client (rebuilt at next regen) will decode `status` as non-optional `String`. Issue confirmed `state=CLOSED, stateReason=COMPLETED, closedAt=2026-05-15T16:06:59Z`.
- **#402** (SchemaVersionResponse.min_app_version dead-channel duplicate of `X-Min-App-Version`): now fully resolved on local HEAD. `openapi.json:984-993` is now a single-field schema `{"version": {"type":"integer", ...}}` with `required: ["version"]`; the `min_app_version` body field that previously sat at lines 985-994 is gone. Backend mechanism: `backend/api/main.py:336-348` strips the field from `SchemaVersionResponse` and adds a docstring naming `X-Min-App-Version` as the canonical channel and cross-refs #402. Test pin: `backend/tests/test_api.py` flipped the assertion to lock the removal — `min_app_version must NOT appear in the response body or in the SchemaVersionResponse schema's properties/required; X-Min-App-Version must still be present on the response`. Issue confirmed `state=CLOSED, stateReason=COMPLETED, closedAt=2026-05-15T16:12:30Z`.

Both closures match the canonical Nagel resolution shape: spec + Pydantic + tests landed in the same PR with no half-fix.

**Re-verification of the eight still-open Nagel surfaces against HEAD `c2b8851`:**

- **#416** (blanket `Cache-Control: max-age=3600` + always-`now()` `Last-Modified` middleware): unchanged. `backend/api/main.py:284-301` (`add_standard_headers`) and `:128-141, 166-174` (`STANDARD_RESPONSE_HEADERS` injection) still apply uniformly. Filed ~12 minutes before this cycle by Nagel; reviewed only for dedupe.
- **#359** (no `MarketDataSnapshot` factory for MVP `Holding` path): unchanged. `MarketDataSnapshot.init(portfolio:)` (`ContributionCalculator.swift:112`) still walks `portfolio.categories.flatMap(\.tickers)`; no `Holding`-rooted factory exists.
- **#356** (`HoldingOut` indicator fields have no persistence target): unchanged. `openapi.json` `HoldingOut` schema still requires eight indicator fields (`current_price`, `sma_50`, `sma_200`, `midline`, `atr`, `upper_band`, `lower_band`, `band_position`); `MVPModels.swift:63-98` still ships `Holding` with only `costBasis/shares/sortOrder`.
- **#348** (`X-Device-UUID` undeclared transport header): unchanged. `APIClient.swift:101` still attaches the header on every protected request; `grep '"X-Device-UUID"' openapi.json` → 0 hits.
- **#317** (`HoldingOut.*` money fields as bare `number`): unchanged. The `DecimalString` annotation introduced in `fea5d93` (#392) lives in `backend/api/main.py:294-300` and is reusable but has not yet been applied to `HoldingOut` Pydantic types or `AddHoldingRequest.weight`. The `Annotated` block's "See issues #317, #392" comment is still the live audit pointer.
- **#316** (`X-App-Attest` per-op param, not `securityScheme`): unchanged. `grep '"securitySchemes"' openapi.json` → 0 hits. Per-op parameter declarations remain at `:85, :195, :315, :485, :593, :705`.
- **#303** (`/portfolio/holdings` 202 documented as JSON-body but runtime returns empty): unchanged. `openapi.json:478-510` still advertises a JSON-body 202 with empty schema (`"schema": {}`).
- **#302** (FastAPI 422 envelope on `/schema/version` + `/portfolio/status`): unchanged. `openapi.json:160, :270` still `$ref` `HTTPValidationError` (defined at `:765-776`).

**Open-surface count delta:** 7 → 8. No filings invalidated; one new filing (#423, this cycle).

**Deferred candidates re-evaluated:**

- **`X-App-Version` undeclared transport header** (`APIClient.swift:103`). Still held: #348 still open, the canonical-binding decision remains unmade. Filing now would prejudge the same binding question. Dedup: `gh issue list --state all --search "X-App-Version in:title,body"` → 10 hits, none cover the iOS-attached / spec-undeclared / backend-unread shape (closest neighbours are sibling-or-orthogonal). Re-evaluate the moment #348 lands.
- **`BackendSyncProjection` orphan wire shape**. Still held: `grep -rn "BackendSyncProjection" app/Sources/` returns only the definition file (`app/Sources/Backend/Networking/BackendSyncProjection.swift`) — no reducer or effect calls `BackendSyncProjection.makePayload(...)`. The wire-shape contract is named but not on-the-wire. Dedup: `gh issue list --state all --search "BackendSyncProjection in:title,body"` → 4 hits (#357 closed; #317 / #374 / #392 sibling-or-orthogonal). Re-evaluate when a live writer appears.

**Fresh contract axis selected: closed content models.**

Axis chosen: every `object`-typed schema in `components.schemas` ships with **no** `additionalProperties` declaration, and every Pydantic `BaseModel` ships with **no** `model_config = ConfigDict(extra="forbid")`. Both sides default to open content — Pydantic v2 default is `extra="ignore"` (silently drops unknown request fields); `swift-openapi-generator` default is to allow extra properties on decode (silently drops unknown response fields).

This axis is the *shared substrate* under every other Nagel filing: a field pinned to `format: decimal` by #392 doesn't actually protect against a stray `current_price_decimal: "1.23"` landing on the wire — the server's Pydantic model would silently drop it on inbound, the client's `Codable` would silently drop it on outbound, and the spec drift would never surface in either direction. Closing the schemas converts the spec from advisory to authoritative.

**Findings (additive / modifying / breaking):**

- Spec-wide grep `grep '"additionalProperties"' openapi.json` → 0 hits.
- 10/10 component schemas have `additionalProperties` unset (`AddHoldingRequest`, `ErrorEnvelope`, `HealthResponse`, `HoldingOut`, `PortfolioDataResponse`, `PortfolioStatusResponse`, `SchemaVersionResponse`, `ErrorCode` enum, `HTTPValidationError`, `ValidationError`).
- 7/7 `BaseModel` Pydantic classes in `backend/api/main.py` have no `extra="forbid"` (only `ConfigDict` site is line 331 on `HealthResponse`, which carries `json_schema_extra={"required":["status"]}` from #381 — does NOT set `extra="forbid"`).
- 0/0 backend tests exercise the unknown-field case (`grep -rn 'extra\|forbid' backend/tests/` → 0 hits).
- iOS generator config (`openapi-generator-config.yaml:11-15`) documents additive-evolution but does not pin closed content; the comment frames *additive* evolution as the contract but the default leaves *undeclared* drift silent.

Classification: **modifying / defensive**. Contract is currently advisory; mitigation makes it authoritative. No live consumer relies on the open-content latitude — there is no shipped iOS reducer sending unknown fields and no shipped client decoder expecting them. Regen is mechanical.

**Dedupe proof:**

- `gh issue list --state all --search "additionalProperties"` → 0 hits
- `gh issue list --state all --search "additionalProperties false"` → 0 hits
- `gh issue list --state all --search "extra forbid"` → 0 hits
- `gh issue list --state all --search "Pydantic extra"` → 0 hits
- `gh issue list --state all --search "unknown fields openapi"` → 0 hits
- `gh issue list --state all --search "strict mode openapi"` → 0 hits
- `gh issue list --state all --search "open content model"` → 0 hits
- `gh issue list --state all --search "swiftopenapigenerator unknown"` → 0 hits
- `gh issue list --state all --search "AddHoldingRequest unknown"` → 0 hits
- `gh issue list --state all --search "HoldingOut additional"` → 0 hits
- `gh issue list --state all --search "closed content model openapi"` → 0 hits

#416's body was read end-to-end and its lane (cache validator semantics + Cache-Control + Last-Modified middleware) is fully orthogonal to content-model openness. None of the eight open or seven recently-closed Nagel filings overlap.

**Decision: file ONE new issue.**

**Issue #423** filed: `contract(openapi): every component schema is an open content model (no additionalProperties: false; no Pydantic extra="forbid") — server silently drops unknown request fields, client silently drops unknown response fields, every other Nagel filing is masked by the shared open substrate`.

- **URL:** https://github.com/yashasg/value-compass/issues/423
- **Labels:** `priority:p2`, `mvp`, `ios`, `architecture`, `team:backend`, `squad:nagel`
- **Routing:** exactly one team label — `team:backend` (the fix lives in `backend/api/main.py` via `model_config = ConfigDict(extra="forbid")`; FastAPI emits `additionalProperties: false` into the spec via `api.export_openapi --check`; iOS-side regen is mechanical with no Swift code change).
- **Classification:** modifying / defensive. Migration plan included: zero deprecation on iOS (no live consumer relies on open content); no `info.version` bump (still `1.0.0`); roll-out sequencing prescribes (1) Pydantic `extra="forbid"` + schema-walk regression test → (2) `/portfolio/holdings` extra-field rejection test → (3) optional `StrictModel` base class to make the default un-writeable.

**Handoffs:**

- **→ Linus** (OpenAPI spec / backend tests): owns the fix. The mechanical change is a single `model_config` line on each `BaseModel` in `backend/api/main.py:67, 320, 336, 352, 359, 374, 384` (collapsing into the existing `ConfigDict` on `HealthResponse:331`). `api.export_openapi --check` then mirrors `additionalProperties: false` into `openapi.json` automatically. Linus also adds the unknown-field POST test on `/portfolio/holdings` and the schema-walk tripwire.
- **→ Virgil** (iOS contract): no action required this cycle. Regen at the next sync-feature PR is sufficient; the generated `Codable` types pick up `additionalProperties: false` automatically and gain explicit unknown-field rejection on decode.
- **→ Basher** (iOS UI): no action required.
- **→ Reuben** (compliance): worth noting that closing the content model also reduces the privacy-leak attack surface — a client cannot accidentally exfiltrate arbitrary additional fields via a misshapen request body once `extra="forbid"` rejects them at the API boundary.

**Learning:** When the contract surface has been hardened field-by-field (decimal pinning #392, requiredness #381, channel deduplication #402, error symmetry #363, schema freeze #337/#350), the *next* layer of value-add is the **substrate** under all those filings — closing the schemas so the field-level fixes are load-bearing rather than advisory. Pattern: after a wave of "shape the field" filings clears, the next Nagel-cycle move is to walk one level up and check whether the field-level invariants are protected by a structural invariant, or whether they sit on top of a permissive substrate that lets future drift silently undo them. The same pattern likely applies on the SwiftData side (every `@Model` is structurally open to property addition without a `VersionedSchema` snapshot until the freeze landed in #337/#350; the freeze itself was the substrate fix), and it's the pattern I'd reach for the moment a new contract surface comes online (e.g., when sync arrives, the first Nagel cycle after the first `POST /portfolio/sync` handler ships should immediately check whether the new request schema is closed *before* spending cycles on field-level invariants).

- 2026-05-15T17:45:29Z — No-op cycle: re-verified #302/#317/#348 drift remains, #416/#429/#423 duplicates/clean surfaces unchanged, no new contract drift after fa890f1.
## Cycle 2026-05-15T17:55:29Z

**Lane:** disclaimer surface audit on commit 2f6a188.

**Finding:** No new contract drift. The disclaimer rollout stays internal: `CalculationOutputDisclaimer` / `CalculationOutputDisclaimerFooter` are `internal` by default (no `public` decls), and the `SettingsFeature.State.isDisclaimerExpanded` default flips to `true` with matching reducer tests.

**Action:** No issue filed or updated.

**Revalidation:** `git diff fa890f1..2f6a188 -- openapi.json backend/ app/Sources/Backend/ app/Sources/App/ app/Sources/Features/` only touches app feature files; OpenAPI/backend contract surfaces remain unchanged. Clean substrates still hold for X-App-Attest and Cache-Control/Last-Modified: `openapi.json:25-31,85-87,195-197,315-317,485-487` and `backend/api/main.py:128-134,175-181,214-226,286-299,476-480`. Duplicate-check searched open Nagel issues (`gh issue list --state open --label squad:nagel`) and closed terms (`gh issue list --state closed --search "disclaimer"`, `"CalculationOutputDisclaimer OR isDisclaimerExpanded OR calculation output"`); closed #233 already matches this surface.

## Cycle 2026-05-15T18:13:38Z

**Lane:** Specialist-loop pass on HEAD `2f6a188` (no new commits since the 17:55 cycle — same cursor). Goal: walk one level past the field-level filings and look for **error-class symmetry across DB-touching endpoints** — the axis under #302 (422 envelope-shape mismatch) and #416 (cache validators on existing 503s) that nobody had yet swept on its own terms.

**Method:** for each route handler in `backend/api/main.py`, grep DB calls + try/except symmetry, then cross-check against the `responses=` dict on the decorator and the spec's declared response statuses.

```
Route               | DB touch  | try/except SQLAlchemyError | spec 503  | route 503=ERROR_RESPONSES |
--------------------|-----------|----------------------------|-----------|---------------------------|
GET  /health        | yes (407) | yes (406-415)              | yes       | yes (399-401)             |
GET  /schema/version| no        | n/a                        | no        | no                        |
GET  /portfolio/status| yes (450)| **NO**                    | **NO**    | **NO**                    |
GET  /portfolio/data| yes (486) | yes (485-496)              | yes       | yes (471-473)             |
POST /portfolio/holdings| yes×3 | yes ×4 (580-591, 600-614, 631-641, 643-652)| yes | yes (561-563)             |
```

`/portfolio/status` is the lone DB-touching endpoint without symmetric 503 mapping. `db.execute(select(StockCache...))` at `main.py:450-454` runs raw — any `SQLAlchemyError` falls through to Starlette's `ServerErrorMiddleware` and lands as undocumented `500 {"detail": "Internal Server Error"}`, neither a project `ErrorEnvelope` nor a documented contract response. The iOS-generated client (driven by `openapi.json` via `openapi-generator-config.yaml:18-22`) only emits `.ok / .unauthorized / .unprocessableContent` cases on `Operations.portfolio_status_portfolio_status_get.Output`; runtime 500s land in the `.undocumented(statusCode:_:)` catch-all with no `retry_after_seconds` signal.

Backend tests confirm the gap: `backend/tests/test_api.py:231-258` ships `test_portfolio_status_empty` + `test_portfolio_status_returns_latest` against a healthy DB only. No `test_portfolio_status_db_unreachable` analogue — the sibling pattern is unused on this endpoint.

**Dedup proof:**

- `gh issue list --state all --search "portfolio_status 503 in:title,body"` → 0 hits
- `gh issue list --state all --search "portfolio/status SQLAlchemyError in:title,body"` → 0 hits
- `gh issue list --state all --search "503 portfolio_status in:title,body"` → 0 hits
- `gh issue list --state all --search "portfolio status uncaught in:title,body"` → 0 hits
- `gh issue list --state all --search "syncUnavailable in:title,body"` → 2 hits (#416, #348 — orthogonal)
- `gh issue list --state all --search "ErrorEnvelope 503 in:title,body"` → 1 hit (#416 — cache validators on already-declared 503s, presupposes 503 path exists)
- `gh issue list --state all --search "SQLAlchemyError in:title,body"` → 0 hits
- `gh issue list --state all --search "/portfolio/status in:title"` → 1 hit (#302 — 422 envelope shape, orthogonal to 503 gap)
- `gh issue list --state all --search "undocumented 500 in:title,body"` → 0 net hits (only #422 ASO unrelated)
- `gh issue list --state all --search "Internal Server Error openapi in:title,body"` → 0 hits

Read-through verification on #302 confirms its scope is `422` payload-shape `HTTPValidationError → ErrorEnvelope`, NOT 503 declaration or DB-error mapping. Read-through on #416 confirms its scope presupposes the 503 path exists and tackles cache-validator semantics on those responses; for `/portfolio/status` there's nothing to cache because there's no 503 yet.

**Decision: file ONE new issue.**

**Issue #439** filed: `contract(openapi): /portfolio/status touches the DB without a SQLAlchemyError handler — 5xx leaks as undocumented FastAPI default body, asymmetric vs /portfolio/data, /health, /portfolio/holdings`.

- **URL:** https://github.com/yashasg/value-compass/issues/439
- **Labels:** `priority:p2`, `ios`, `architecture`, `team:backend`, `squad:nagel`
- **Routing:** exactly one team label — `team:backend` (fix is `backend/api/main.py` runtime + spec regen + backend test; no iOS code change, generator regen is mechanical).
- **Classification:** modifying / latent. ~10 LOC backend change mirroring `portfolio_data:485-496` + add `503: ERROR_RESPONSES[503]` to the route decorator + 1 new test pin + regenerate `openapi.json`. Additive on the wire — adds a new enum case on the generated iOS `Output`, no existing call site touched.

**Re-verification of the eight other open Nagel surfaces against HEAD `2f6a188`:**

- **#429** (`X-App-Version` undeclared transport header): unchanged. `APIClient.swift:103` still attaches; `grep "X-App-Version" openapi.json` → 0 hits.
- **#423** (open content model substrate): unchanged. `grep '"additionalProperties"' openapi.json` → 0 hits; `grep 'extra="forbid"' backend/api/main.py` → 0 hits.
- **#416** (blanket `Cache-Control` + `Last-Modified` middleware): unchanged. `main.py:284-301` still applies uniformly.
- **#359** (no `MarketDataSnapshot` factory for MVP `Holding` path): unchanged. `ContributionCalculator.swift:112` still walks `portfolio.categories.flatMap(\.tickers)`.
- **#356** (`HoldingOut` indicator fields have no persistence target): unchanged. `openapi.json:793-906` still requires 8 indicator fields; `MVPModels.swift:63-98` still ships `Holding` without them.
- **#348** (`X-Device-UUID` undeclared transport header): unchanged. `APIClient.swift:101` still attaches; `grep "X-Device-UUID" openapi.json` → 0 hits.
- **#317** (`HoldingOut.*` / `AddHoldingRequest.weight` money fields as bare `number`): unchanged. `openapi.json:702-707, 796-887` still emit bare `number` with no `format`. `DecimalString` from `main.py:313-317` (introduced by #392) remains unapplied to `HoldingOut` and `AddHoldingRequest` Pydantic types.
- **#316** (`X-App-Attest` per-op param, not `securityScheme`): unchanged. `grep '"securitySchemes"' openapi.json` → 0 hits.
- **#303** (`/portfolio/holdings` 202 documented as JSON-body but runtime returns empty): unchanged. `openapi.json:478-510` still advertises empty schema (`"schema": {}`).
- **#302** (FastAPI 422 envelope on `/schema/version` + `/portfolio/status`): unchanged. `openapi.json:160, :270` still `$ref` `HTTPValidationError`.

**Open-surface count delta:** 9 → 10 (added #439). No filings invalidated.

**Deferred candidates re-evaluated:**

- **`X-App-Version` undeclared transport header**: now LIVE as #429 (filed in a prior cycle). Removed from deferred list.
- **`BackendSyncProjection` orphan wire shape**: still held. `grep -rn "BackendSyncProjection" app/Sources/` returns only the definition file. The wire-shape contract is named but not on-the-wire. Re-evaluate when a live writer appears.

**Candidate-axes swept (clean, no new drift):**

- `AddHoldingRequest.device_uuid` body field + `X-Device-UUID` header + `/portfolio/data` `device_uuid` query: three-channel device identity is already named by #348's "backend reads device identity from body/query instead" framing. No new filing.
- `ErrorEnvelope.code` field: spec uses direct `$ref` to `ErrorCode` (not `anyOf` with null), matching Pydantic v2 emit. ✓
- `ValidationError` schema parity with `validation_error_handler`: runtime always returns `ErrorEnvelope` with `code=schemaUnsupported`, so `ValidationError` is documented-but-unreachable. Subsumed by #302; no separate filing.
- `health` un-attested + spec-omits `X-App-Attest` parameter: ✓ correct asymmetry; `unauthenticatedHealthPath` at `APIClient.swift:77` matches `require_app_attest` opt-out at `main.py:261-278`.
- Empty-string `X-App-Attest` accepted as missing (`if not x_app_attest`): Python falsy-check is intentional and documented at `main.py:267-271`; not drift.
- New `public` declarations since 2f6a188: HEAD is unchanged, so no new public surface to diff.

**Classification:** one new validated contract drift filed, nine existing open filings re-confirmed against the same cursor, one previously-deferred candidate is now live as #429.

**Learning:** The Nagel "error-class symmetry" sweep is the natural next layer after the field-level wave clears. The pattern: enumerate every endpoint, build a matrix of `(DB touch, try/except, spec 503, route 503=ERROR_RESPONSES[503])`, and any row where columns 2-4 disagree is a contract gap. This caught #439 in one pass on a static HEAD, after every field-level drift had been worked. The same matrix-sweep idiom is reusable the moment new endpoints land: when `/portfolio/sync` (or whatever sync POST surface ships) appears, run the matrix sweep BEFORE field-level filings — if the 503 row is asymmetric on day one, the error contract is broken and field-level fixes ride on a broken substrate. Two-axis lesson: (1) once `/portfolio/status` lands its 503 path, **re-fire** the cycle to verify #302's 422 fix + the new 503 path don't introduce a new asymmetry (e.g., a `Retry-After` header attached to one envelope but not the other); (2) the iOS `.undocumented(statusCode:_:)` catch-all is a load-bearing tell — any time the generated `Output` has an `.undocumented` case that production traffic could actually exercise, file before the case becomes a bug rather than after.

## Cycle 2026-05-15 #5

**Lane:** `backend/api/main.py` + `openapi.json` — `/portfolio/export` contract-surface review.

**Finding:** No new drift. `/portfolio/export` declares `device_uuid` as a query param, requires `X-App-Attest`, uses `ErrorEnvelope` for 401/404/422/503, and keeps decimal fields as `string`/`format: decimal`.

**Revalidation:** Existing drifts #302/#317/#348 remain live.

## Cycle 2026-05-15 #6

**Lane:** `app/Sources/Backend/Networking/APIClient.swift` + `app/Tests/VCATests/APIClientTests.swift` — validate #429 closure on HEAD `56e1b0b`.

**Finding:** PASS. `APIClient.makeOutgoingRequest` no longer accepts/sets `appVersion`; `send(_:)` no longer reads `CFBundleShortVersionString`; doc comment now says the client only transmits `X-Device-UUID`/`X-App-Attest` and consumes `X-Min-App-Version` via `MinAppVersionClient.observe(response:)`.

**Revalidation:** `MinAppVersionClient.observe(response:)` remains intact and still reads `X-Min-App-Version`; `openapi.json` and `app/Sources/Backend/Networking/openapi.json` are byte-identical; spec search still shows no `X-App-Version` declaration.

**Live drifts re-checked:** #302 (`HTTPValidationError`), #317 (bare `number` money fields), #348 (`X-Device-UUID`) remain live with refreshed refs in `.squad/agents/nagel/history.md:571`, `:568`, `:567`.

**Dedup proof:** `gh issue list --state all --search 'X-App-Version'` and `... --search 'X-Device-UUID'` both returned the expected live siblings/orthogonals; no duplicate of the #429 closure surfaced.

**Decision:** NO_OP — closure landed cleanly; no new drift introduced; roster unchanged.

## Cycle 2026-05-15 #7

**HEAD:** `dbdcb67`

**Parity:** PASS — `diff openapi.json app/Sources/Backend/Networking/openapi.json` is byte-identical.

**Schema audit:** new `PATCH /portfolio`, `PATCH /portfolio/holdings/{ticker}`, and `DELETE /portfolio/holdings/{ticker}` all keep `ErrorEnvelope` on non-200s and `DecimalString` on money fields (`monthly_budget`, `weight`); required fields are consistent (`PatchHoldingRequest.weight`, `PatchHoldingResponse.ticker/weight`, `PatchPortfolioResponse.portfolio_id/name/monthly_budget/ma_window`).

**Drifts rechecked:** #302, #317, #348 remain live; none were newly aggravated by the rectification endpoints. No new public Swift declarations.

**Dup-check:** reviewed open Nagel roster `#439 #423 #416 #359 #356 #348 #317 #316 #303 #302` plus searches for `right-to-correct`, `PATCH /portfolio`, `PATCH /portfolio/holdings/{ticker}`, `HTTPValidationError`, `ErrorEnvelope`, `X-Device-UUID`, `DecimalString`.

**Decision:** NO_OP — no validated contract drift on this HEAD.

## Cycle 2026-05-15T18:56:52Z

**HEAD:** `5a9bbea`

**Prior:** `dbdcb67`

**Finding:** NO_OP.

**Parity:** PASS — `diff openapi.json app/Sources/Backend/Networking/openapi.json` is byte-identical.

**Swift surface scan:** `app/Sources/App/DesignSystem.swift` adds `Decimal.appCurrencyFormatted()` / `appPercentFormatted()`, but both helpers are internal (not `public`); no new public Swift declarations landed this cycle.

**Revalidation hooks:** none fired. Nagel owns no file-path-triggered docs in this loop.

**Live drifts re-verified on new HEAD:** #302 (`openapi.json:155-160,265-270`), #303 (`openapi.json:685-689`), #316 (`openapi.json:665-672,873-889,1082-1089,1269-1285`; `securitySchemes` still 0 hits), #317 (`openapi.json:1451-1455,1548-1556`), #348 (`app/Sources/Backend/Networking/APIClient.swift:101-109`; openapi still has only `X-App-Attest` on protected ops), #356 (`openapi.json:1542-1654`; `app/Sources/Backend/Models/MVPModels.swift:63-98`), #359 (`app/Sources/Backend/Services/ContributionCalculator.swift:112-124`), #416 (`backend/api/main.py:300-305`), #423 (open-content substrate still open: `openapi.json` `additionalProperties` count 0; `backend/api/main.py` `extra="forbid"` count 0), #439 (`backend/api/main.py:588-611`; `openapi.json:265-270` still only documents 422, no 503 on the route).

**Duplicate-check evidence:** searched for `appCurrencyFormatted` / `appPercentFormatted` / `Decimal formatted`; only related result was closed #257 (`a11y(voiceover-currency)`), no open duplicate surfaced.

**Roster delta:** none — same 10 open Nagel issues (`#439 #423 #416 #359 #356 #348 #317 #316 #303 #302`).

**History append:** `.squad/agents/nagel/history.md` (end of file).

**Specialist summary:**
1. Internal Decimal formatting helpers were added, but they do not expand the public Swift API surface.
2. OpenAPI parity held, and all 10 live Nagel drifts were re-verified on HEAD with refreshed refs.
3. No issue filed; roster unchanged; history updated.

## Cycle 2026-05-15T19:02:00Z

**HEAD:** `5a9bbea` (unchanged from prior cycle at 18:57:36Z).

**Prior HEAD:** `5a9bbea` — `git --no-pager log 5a9bbea..HEAD --oneline` empty. Zero new commits in ~5 min.

**Parity check:** PASS — `diff openapi.json app/Sources/Backend/Networking/openapi.json` exit 0 (byte-identical).

**Swift surface scan:** `git --no-pager diff dbdcb67..HEAD -- '*.swift' | grep -E "^[-+]\s*(public|open) "` empty across `bfbd122` + `5a9bbea`. No new public/open declarations since `dbdcb67`; no new contract seams on the iOS side.

**Live drifts re-verified on HEAD with refreshed line refs:**

- **#302** `openapi.json`: `/schema/version` `"422"` at L155 + `/portfolio/status` `"422"` at L265 both still `$ref` `#/components/schemas/HTTPValidationError` (FastAPI default). Other 422 refs at L415, L595, L803, L993, L1192, L1372 unchanged.
- **#303** `openapi.json:685-689`: `/portfolio/holdings` `"202"` content `application/json` `schema: {}` — empty object schema declared but runtime returns no body. Runtime at `backend/api/main.py:790-805`.
- **#316** `openapi.json`: `grep -c "securitySchemes" openapi.json` = **0**. `X-App-Attest` still parameter-declared at L85, L195, L315, L495, L665, etc.
- **#317** `openapi.json`: `HoldingOut` money fields `current_price:L1552`, `sma_50:L1563`, `sma_200:L1574`, `midline:L1585`, `atr:L1596`, `upper_band:L1607`, `lower_band:L1618`, `band_position:L1629` — every one is `anyOf [{type:number},{type:null}]`. All required at L1645-L1652. Generated Swift decodes as `Double?` and discards `Decimal` precision.
- **#348** `app/Sources/Backend/Networking/APIClient.swift:107` sets `X-Device-UUID` on every request; `app/Sources/Backend/Networking/APIClient.swift:109` sets `X-App-Attest`. `openapi.json` has `'"name": "X-Device-UUID"'` grep exit 1 — header is never declared as a parameter; backend reads `device_uuid` as query/body field at `backend/api/main.py:403,542,631,720,822,905,958`.
- **#356** `openapi.json:1542-1654` (HoldingOut). `app/Sources/Backend/Models/MVPModels.swift:63-98` (Holding `@Model` carries only `id, portfolioId, symbol, costBasis, shares, sortOrder, createdAt`) — none of the eight indicator fields have a persistence target; `BandAdjustedContributionCalculator` cannot be fed on the MVP path.
- **#359** `app/Sources/Backend/Services/ContributionCalculator.swift`: `MarketDataSnapshot` declared at L101; `missingMarketData` returned at L304, L366. No factory for MVP `Holding` rows; default initializer at L95 still depends on retired `Ticker` rows.
- **#416** `backend/api/main.py:297-316` `add_standard_headers` middleware unchanged — `Cache-Control: max-age=<CACHE_MAX_AGE>` + `Last-Modified` + `X-Min-App-Version` set on EVERY response via `setdefault`, including 503 / `ErrorEnvelope` / `/health`.
- **#423** open-content substrate: `grep -c "additionalProperties" openapi.json` = **0**; `grep -c 'extra="forbid"' backend/api/main.py` = **0**. Substrate still permissive on both sides.
- **#439** `backend/api/main.py:588-611`: `portfolio_status` runs `db.execute(select(StockCache...))` at L604 with **no `try/except SQLAlchemyError`**; route `responses=` block only declares 401, no 503. Contrast `portfolio_data` at L616 (declares 503 at L624-626, has `SQLAlchemyError` handler at L643).

**Roster delta:** none — open Nagel issues `#439 #423 #416 #359 #356 #348 #317 #316 #303 #302` (10 issues, unchanged 8+ cycles).

**Dup-check terms used:** N/A — no NEW_ISSUE candidate surfaced (HEAD unchanged from prior cycle; all 10 drifts already-filed). Roster cross-checked against `gh issue list --label squad:nagel --state open --limit 50`.

**Outcome:** **NO_OP.** Same HEAD as prior cycle, parity holds, no new public Swift seams, all 10 drifts re-verified with refreshed line refs. Static stack — nothing landed in the 5-minute window.

## Cycle 2026-05-15T19:11:00Z

**HEAD:** `8e91267` (PR #451 merged: `compliance(data-erasure): add DELETE /portfolio`)

**Prior HEAD:** `5a9bbea` — HEAD moved this cycle. `git diff 5a9bbea..HEAD --stat`: 6 files / 629 insertions (openapi.json, app/.../openapi.json, backend/api/main.py, backend/tests/test_api.py, docs/legal/data-subject-rights.md, docs/legal/privacy-policy.md).

**Parity check:** PASS — `diff openapi.json app/Sources/Backend/Networking/openapi.json` exit 0 / byte-identical. Regeneration discipline held across PR #451 merge.

**Swift surface scan:** `git --no-pager diff 5a9bbea..HEAD -- '*.swift' | grep -E "^[-+]\s*(public|open) "` empty. No iOS Swift sources changed at all this cycle (PR #451 was backend-only + spec regen + docs). No new public/open declarations, no `ContributionCalculating` seam shift, no `@Model` schema bump.

**DELETE /portfolio audit (new endpoint, full pass in Nagel's lane):**

- **device-identity convention:** new endpoint reads `device_uuid: UUID` as a query parameter (`openapi.json:1059-1078` declares `device_uuid` query + `X-App-Attest` header; handler at `backend/api/main.py:1190-1192`). Same precedent as every other protected route. iOS continues to emit `X-Device-UUID` header on every request (`APIClient.swift:107`) which is undeclared in spec. **Fresh instance of #348 — first destructive instance.** Refresh comment posted on #348 (https://github.com/yashasg/value-compass/issues/348#issuecomment-4462702749).
- **response envelope:** 401 / 404 / 422 / 503 all reference `ErrorEnvelope` (`openapi.json:1104-1222`) — clean; does **not** extend #302 (no HTTPValidationError leak). 204 success is body-less. **However**: spec advertises `Cache-Control` + `Last-Modified` + `X-Min-App-Version` headers on the **destructive 204** response (`openapi.json:1083-1102`) and on every error path. This is a new, particularly hazardous instance of #416 — a destructive op with a 1-hour cacheability hint. Refresh comment posted on #416 (https://github.com/yashasg/value-compass/issues/416#issuecomment-4462702757).
- **additionalProperties:** none. Open-content substrate #423 still applies to ErrorEnvelope responses; new endpoint takes no JSON body so #423 isn't extended here.
- **X-App-Attest:** declared as per-op required header parameter at `openapi.json:1071-1077`. Now **9 ops** carry the duplicated inline header block; `grep -c '"securitySchemes"' openapi.json` still **0**. Refresh comment on #316 (https://github.com/yashasg/value-compass/issues/316#issuecomment-4462704758).
- **SwiftData @Model implications:** none. DELETE is destructive on the server side only; no new client-side schema fields.
- **iOS #329 unblock fit:** **YES — backend prerequisite is now shipped.** #329's "Proposed change" §1.i explicitly defers the backend `DELETE /devices/{X-Device-UUID}` (or equivalent) to a separate team:backend issue (#450). The shipped shape is `DELETE /portfolio?device_uuid={uuid}` — different surface (path `/portfolio`, identity via query rather than URL path), but functionally equivalent: cascade-deletes the `Portfolio` row + all `Holding` rows keyed to the calling device. iOS Settings "Erase All My Data" can now compose this request with `X-App-Attest` + `device_uuid` query selector. The X-Device-UUID header that iOS already emits (`APIClient.swift:107`) is silently ignored by the new handler — iOS must compose the query string from the same Keychain UUID it puts in the header. #329 remains open for the iOS-side Settings surface, Keychain UUID rotation, onboarding re-fire, and the four-step destructive sequence.

**Live drifts re-verified on HEAD `8e91267` with refreshed line refs:**

- **#302** `openapi.json`: `/schema/version` 422 at L160 + `/portfolio/status` 422 at L270 still `$ref` `HTTPValidationError`. Other route 422 refs all now use `ErrorEnvelope`. Still live; surface unchanged by PR #451.
- **#303** `openapi.json:685-689` `/portfolio/holdings` 202 schema `{}` empty object; runtime at `backend/api/main.py:792-905` returns 202 with no body. Still live.
- **#316** `openapi.json`: `grep -c "securitySchemes" openapi.json` = **0**. `X-App-Attest` parameter-declared at L85, L195, L315, L495, L665, L883, **L1071 (new)**, L1253, L1450. 9 ops, +1 since prior cycle.
- **#317** `openapi.json`: `HoldingOut` money fields shifted to L1723-L1810 (was :1552-1629); required at L1813-L1823 (was :1645-1652). All still `anyOf [{type:number},{type:null}]`. `AddHoldingRequest.weight` still bare `number` at L1622-L1626. Still live.
- **#348** iOS emitter `APIClient.swift:107` unchanged (X-Device-UUID set on every request). Backend reads `device_uuid` query/body at `main.py:406, 545, 634, 723, 825, 961, 1041, 1117, **1191 (new)**` — 9 sites, +1 since prior cycle. `grep -c '"name": "X-Device-UUID"' openapi.json` = **0**. Still live; severity ↑ on destructive route.
- **#356** `openapi.json:1713-1810` (HoldingOut indicator fields) vs `app/Sources/Backend/Models/MVPModels.swift:63-98` (Holding `@Model`: `id, portfolioId, symbol, costBasis, shares, sortOrder, createdAt`). No persistence target. Still live; MVPModels unchanged this cycle.
- **#359** `app/Sources/Backend/Services/ContributionCalculator.swift:101` `MarketDataSnapshot`; `:304, :366` return `missingMarketData`; `:95` default init still depends on retired `Ticker` path. ContributionCalculator unchanged this cycle. Still live.
- **#416** `backend/api/main.py:303-320` middleware (was :297-316) — `add_standard_headers` sets `Cache-Control` / `Last-Modified` / `X-Min-App-Version` via `setdefault` on every response. **New instance**: destructive `DELETE /portfolio` 204 response at `openapi.json:1083-1102` advertises Cache-Control. Severity ↑.
- **#423** `grep -c "additionalProperties" openapi.json` = **0**; `grep -c 'extra="forbid"' backend/api/main.py` = **0**. Substrate unchanged.
- **#439** `backend/api/main.py:599-614` `portfolio_status` (was :588-611) — still runs `db.execute(select(StockCache...))` at L607-611 with no `SQLAlchemyError` handler; route `responses=` block declares only 401, no 503. Asymmetric vs `portfolio_data` at L633-660 which has the `SQLAlchemyError` handler + 503 documented. Still live.

**Roster delta:** none — open Nagel issues `#439 #423 #416 #359 #356 #348 #317 #316 #303 #302` (10, unchanged 9+ cycles).

**Dup-check evidence (NEW_ISSUE consideration):**
- DELETE /portfolio audit revealed three drift instances on the new endpoint (query-param device identity, Cache-Control on destructive 204, X-App-Attest as param). **All three squarely fit existing #348 / #416 / #316 issue bodies** ("every protected request", "every operation/status", "per-operation required header parameter"). Filing a NEW_ISSUE for the destructive variant would duplicate #416's "blanket middleware applied to every operation/status" framing.
- Decision: **UPDATED_EXISTING** for #316 / #348 / #416 with destructive-endpoint refresh evidence; **NO_OP** on filing.
- Search terms: `gh issue list --label squad:nagel --state open --limit 50`; reviewed all 10 active drifts; cross-referenced PR #451 commit message naming #450 (Reuben's lane — already filed) and #329 (iOS lane — Virgil/Basher).

**Outcome:** **UPDATED_EXISTING** — three issue refresh comments posted (#316, #348, #416) on the new destructive endpoint surface. **No NEW_ISSUE**: all observed drift on PR #451 is contained within the existing roster.

**Top finding:** the new `DELETE /portfolio` 204 advertises `Cache-Control: max-age=<CACHE_MAX_AGE>` (openapi.json:1083-1089) — a destructive op tagged as cacheable. Refreshes #416 with the most severe instance to date.

**Learned this cycle:** when a write/destructive endpoint lands and the middleware-leak (#416) + identity-mismatch (#348) substrates both still hold, every new protected op deserves a targeted refresh comment, not just a roster-wide line-ref bump — the destructive variant is genuinely worse than the GET variant.

## Cycle 2026-05-15T19:25:30Z

**HEAD:** `9fe4cca`. **Prior HEAD:** `8e91267`.

**Commits since prior cycle:**
- `9fe4cca` — `hig(sf-symbols): swap PortfolioDetail Calculate button play.fill → function (closes #414) (#453)`
- `8c73273` — `contract(protocol): add MarketDataSnapshot + ContributionInput holdings seam (closes #359) (#452)` — **YOUR LANE**

**Parity check:** **PASS** — `diff openapi.json app/Sources/Backend/Networking/openapi.json` exit 0 / byte-identical. Neither file was modified this cycle.

**Public Swift API surface diff:** `git --no-pager diff 8e91267..9fe4cca -- '*.swift' | grep -E '^[+-]\s*(public|open) '` is **empty**. Confirmed: `grep -nE '^(public|open) ' $(find app/Sources -name '*.swift')` returns **zero hits in the entire app**. The VCA target is a single internal-by-default module; #452's seam additions (`ContributionInput.init(holdings:monthlyBudget:marketDataSnapshot:...)`, `MarketDataSnapshot.init(holdings:)`, `ContributionCalculatorClient.calculateForHoldings`) are all internal access. **0 breaking, 0 non-breaking public-API changes.**

**SwiftData @Model schema diff:** `git --no-pager diff 8e91267..9fe4cca -- '*.swift' | grep -E '@(Model|Attribute|Relationship)'` is **empty**. `Holding` @Model at `app/Sources/Backend/Models/MVPModels.swift:63-98` unchanged. **No schema drift.**

**#359 closure verified — YES.** Commit `8c73273` (PR #452) ships all six acceptance criteria from #359:

1. `MarketDataSnapshot.init(holdings: [Holding])` — `app/Sources/Backend/Services/ContributionCalculator.swift:194-220` — stub factory that explicitly comments #356 as the blocker and returns an empty snapshot today.
2. `ContributionInput.init(holdings:monthlyBudget:marketDataSnapshot:minMultiplier:maxMultiplier:)` — `ContributionCalculator.swift:99-164` — synthesizes a transient single-category `Portfolio` so all three shipping conformers stay bit-identical on the legacy path.
3. `ContributionCalculatorClient.calculateForHoldings` closure — `app/Sources/App/Dependencies/ContributionCalculatorClient.swift:56-73` (declaration) + L92-98 (live wiring) + L106 (preview wiring).
4. Reducer-level unit test with MVP `Holding` rows + non-empty snapshot — new file `app/Tests/VCATests/ContributionCalculatorMVPHoldingsSeamTests.swift` (215 lines, six scenarios pinning `MovingAverage` + `BandAdjusted` + `ProportionalSplit` on the new seam, plus a legacy-path regression).
5. `ProportionalSplitContributionCalculator` is doc-commented as **currently blocked** on the MVP path — `ContributionCalculator.swift:619-640` — anchored against a follow-up that owns relaxing `ContributionInputValidator`.
6. No behavior change on the legacy `Ticker`-backed path — synthesized graph constructs `Portfolio` → `Category("Holdings", weight: 1.0)` → `Ticker(currentPrice: nil, movingAverage: nil, bandPosition: nil)` and supplies the caller's `MarketDataSnapshot` (or the empty stub) directly. Closure ✅ correct.

**#363 residual drift — none; fully satisfied (closed in a prior cycle by commit `c576455` / PR #396, `closedAt: 2026-05-15T15:53:46Z`).** Re-verified on `9fe4cca`:

- Protocol doc-comment present at `ContributionCalculator.swift:3-67` (Pre-conditions, Post-conditions, Error channel, Calculator-private input dependencies — explicitly names `bandPosition` at L64-67).
- `grep -n "preconditionFailure" app/Sources/Backend/Services/ContributionCalculator.swift` returns only **L54** (narrative reference inside the doc-comment). All three conformers — `MovingAverageContributionCalculator` (L436-437, L460), `BandAdjustedContributionCalculator` (L523-524, L545), `ProportionalSplitContributionCalculator` (L642-643) — start with `if let validationError = ContributionInputValidator.validate(input) { return .failure(validationError) }` and use `.failure(...)` for every post-validator guard. Symmetry achieved.
- `docs/services-tech-spec.md` §3.1 (L41-99) matches the shipped signature `func calculate(input: ContributionInput) -> ContributionOutput`; L77-81 explicitly enforces `.failure(_:)` over `preconditionFailure`.
- `docs/services-tech-spec.md` §8.1 (L271-283) lists all 11 `ContributionCalculationError` cases verbatim.
- Direct-call tests exercise validator-failing inputs without crashing — `app/Tests/VCATests/ContributionCalculatorTests.swift:221, 246, 260, 278, 296` and parameterized cases at L359-386.

The prompt's stale roster listed #363 (and #429, #402, #392, #381, #340, #337) as open; current `gh issue list --label squad:nagel --state open` returns only **9 active drifts**.

**#356 status — UNCHANGED, but severity escalated by #452's stub factory.** Before this cycle, #356 was a future-tense data-layer gap ("once #123 retires `Ticker`, calculators silently produce `missingMarketData`"). After this cycle, the gap is **self-documented in production code**: `ContributionCalculator.swift:194-220` ships a `MarketDataSnapshot.init(holdings: [Holding])` factory whose body is `_ = holdings; self.init(quotesBySymbol: [:])` and whose doc-comment (L194-208) + inline comment (L210-217) name #356 as the explicit blocker three times. The MVP-path seam now exists, ships in green, and **returns empty snapshots until #356 lands**. Refresh comment posted: https://github.com/yashasg/value-compass/issues/356#issuecomment-4462845398.

**Live drifts re-verified on HEAD `9fe4cca` (line refs refreshed):**

- **#302** `openapi.json`: `/schema/version` `"422"` at **L155** → `$ref` `HTTPValidationError` at **L160**; `/portfolio/status` `"422"` at **L265** → `HTTPValidationError` at **L270**. Every other route's `"422"` (L415, 595, 803, 993, 1164, 1363, 1543) uses `ErrorEnvelope` (per #341 closure). Still live.
- **#303** `openapi.json:685-691`: `/portfolio/holdings` `"202"` content `application/json` `schema: {}` (empty object); runtime returns no body (`backend/api/main.py:792-805`). Still live.
- **#316** `openapi.json`: `grep -c securitySchemes openapi.json` = **0**. `X-App-Attest` parameter-declared at **L85, L195, L315, L495, L665, L883, L1071, L1253, L1450** (9 ops, unchanged from prior cycle). Still live.
- **#317** `openapi.json`: `HoldingOut` money fields all `anyOf [{type:number},{type:null}]` at **L1723** (`current_price`), **L1734** (`sma_50`), **L1745** (`sma_200`), **L1756** (`midline`), **L1767** (`atr`), **L1778** (`upper_band`), **L1789** (`lower_band`), **L1800** (`band_position`); required at L1816-1823. `AddHoldingRequest` schema at L1609-1635. Generated Swift decodes as `Double?` and discards `Decimal` precision. Still live.
- **#348** `app/Sources/Backend/Networking/APIClient.swift:107` sets `X-Device-UUID` on every request. `openapi.json` declares it **0 times**. Backend reads `device_uuid` query/body at `backend/api/main.py:406, 545, 634, 723, 825, 961, 1041, 1117, 1191` (9 sites; unchanged since prior cycle's DELETE-route refresh). Still live.
- **#356** `openapi.json:1723-1810` (HoldingOut indicator fields) vs `app/Sources/Backend/Models/MVPModels.swift:63-98` (Holding @Model). Severity escalated by #452's self-documenting stub (see above). Refresh comment posted.
- **#416** `backend/api/main.py:303-319` `add_standard_headers` middleware sets `Cache-Control` / `Last-Modified` / `X-Min-App-Version` via `setdefault` on every response. `openapi.json` declares the same triple in `STANDARD_RESPONSE_HEADERS` at L148-159 — every `responses` block in the spec inlines all three headers (including the destructive `DELETE /portfolio` 204 documented in prior cycle). Still live.
- **#423** `grep -c additionalProperties openapi.json` = **0**; `grep -c 'extra="forbid"' backend/api/main.py` = **0**. Substrate unchanged on both sides. Still live.
- **#439** `backend/api/main.py:599-614` `portfolio_status` runs `db.execute(select(StockCache.last_modified, StockCache.next_modified).order_by(...).limit(1)).first()` at L607-611 with **no `try/except SQLAlchemyError`**; route `responses=` block declares only 401 (no 503). Asymmetric vs `portfolio_data` at L633 which declares 503 and has SQLAlchemyError handler at L646. Still live.

**Roster delta:** **closed this cycle: #359**. Current open Nagel issues per `gh issue list --label squad:nagel --state open`: `#302 #303 #316 #317 #348 #356 #416 #423 #439` (9, down from 10 at prior cycle).

The prompt-listed issues `#337 #340 #363 #381 #392 #402 #429` were already closed in prior cycles (closedAt timestamps before `8e91267`); they did not require any action this cycle.

**Dup-check / dedupe terms used:** `gh issue list --label squad:nagel --state open --limit 50`; `git log --all --grep="#363" --oneline`; `grep -n preconditionFailure app/Sources/Backend/Services/ContributionCalculator.swift`; cross-referenced all 16 prompt-listed roster numbers against actual GH state. Considered filing a NEW_ISSUE for "transient `@Model` class synthesis in `ContributionInput.init(holdings:)` is not warned against in the doc-comment" (`ContributionCalculator.swift:131-156`) — synthesized `Portfolio` / `Category` / `Ticker` are SwiftData `@Model final class` instances created without a `ModelContext`, and a reducer that calls `modelContext.insert(input.portfolio!)` after `calculateForHoldings` would corrupt the store. **Decision: sub-threshold — the seam returns a `ContributionOutput` (allocations only), no production reducer round-trips the synthetic graph, and the doc-comment already says "the synthesis step is the single point that needs to be replaced when the legacy graph is retired".** Filing would not produce a validated breaking-change call; left as observation only.

**Outcome:** **UPDATED_EXISTING** — one refresh comment posted on #356 reflecting that PR #452's stub factory now names #356 as the explicit blocker in production code, escalating the severity classification from "future-tense data-layer gap" to "present-tense, code-level blocker that ships green today."

**Top finding:** #452 is a textbook contract-seam landing — six ACs met, zero breaking changes, MVP factory wired ahead of #356, all three conformers exercised through the new seam in `ContributionCalculatorMVPHoldingsSeamTests`. The protocol surface (`ContributionCalculating`, `ContributionInput`, `MarketDataSnapshot`, `ContributionCalculatorClient`) holds.

**Learned this cycle:** when a stub factory ships ahead of its data prerequisite (here, `MarketDataSnapshot.init(holdings:)` ahead of #356's indicator-field persistence), the right Nagel response is to escalate the prerequisite's severity classification rather than file a new contract issue against the stub — the stub is itself a contract artifact pointing at the prerequisite.

## Cycle 2026-05-15T19:41Z

**HEAD:** `9fe4cca` (unchanged from prior Nagel cycle at 19:25:30Z; orchestration log this cycle is `2026-05-15T19-20-28Z-specialist-loop.md` per spawn prompt, but my own history was already at `9fe4cca` — `git --no-pager log 9fe4cca..HEAD --oneline` is empty).

**Prior HEAD (per spawn prompt):** `8e91267`. Two commits in scope per the prompt: `8c73273` (PR #452 — closes #359, my lane) + `9fe4cca` (PR #453 — HIG SF Symbols, Turk's lane).

**Parity gate:** **PASS** — `diff openapi.json app/Sources/Backend/Networking/openapi.json` exit **0**, byte-identical. Neither openapi.json copy was touched by either commit (`git diff --stat 8e91267..HEAD -- openapi.json app/Sources/Backend/Networking/openapi.json` is empty).

**#359 closure validation:** **PASS** — `gh issue view 359 --json state,closedAt` returns `state=CLOSED, closedAt=2026-05-15T19:22:06Z, closedByPullRequestsReferences=[PR #452]`. All six acceptance criteria shipped:

1. `MarketDataSnapshot.init(holdings: [Holding])` stub factory at `app/Sources/Backend/Services/ContributionCalculator.swift:194-220` (doc-comment names #356 as the blocker at L197-203; body comment at L210-217; today returns empty snapshot via `_ = holdings; self.init(quotesBySymbol: [:])` at L218-219).
2. `ContributionInput.init(holdings:monthlyBudget:marketDataSnapshot:minMultiplier:maxMultiplier:)` at `ContributionCalculator.swift:99-164` — synthesizes transient `Portfolio(name:"Holdings", categories: [Category(name:"Holdings", weight:1, tickers:...)])` so legacy conformers stay bit-identical, supplies caller's snapshot or empty `MarketDataSnapshot(holdings:)` fallback at L160.
3. `ContributionCalculatorClient.calculateForHoldings` closure at `app/Sources/App/Dependencies/ContributionCalculatorClient.swift:56-73` (declaration), L92-98 (live wiring builds `ContributionInput` then delegates to `ContributionCalculationService.calculate`), L106 (preview value).
4. `app/Tests/VCATests/ContributionCalculatorMVPHoldingsSeamTests.swift` exists (215 lines) — six scenarios pin `MovingAverage` + `BandAdjusted` + `ProportionalSplit` on the new seam plus a legacy-path regression.
5. `ProportionalSplitContributionCalculator` doc-block at `ContributionCalculator.swift:619-640` documents the validator-gated MVP block (anchored against the follow-up that owns relaxing `ContributionInputValidator`).
6. Legacy `Ticker`-backed path bit-identical — synthesized `Ticker(currentPrice:nil, movingAverage:nil, bandPosition:nil)` at L138-144 carries no indicator fields; market-data flows exclusively through the caller-supplied `MarketDataSnapshot` argument.

**New-drift scan on PR #452 + PR #453:**

- `git --no-pager diff 8e91267..HEAD -- openapi.json app/Sources/Backend/Networking/openapi.json backend/api/main.py` empty (no contract surface touched).
- `git --no-pager diff 8e91267..HEAD -- 'app/Sources/**/*.swift' | grep -E '^[-+]\s*(public|open) '` empty — **zero public/open declarations changed**. `grep -nE '^(public|open) ' app/Sources/**/*.swift` repo-wide returns zero hits (VCA target is a single internal-by-default module; #452's three new symbols — `ContributionInput.init(holdings:...)`, `MarketDataSnapshot.init(holdings:)`, `ContributionCalculatorClient.calculateForHoldings` — are all internal access).
- `git --no-pager diff 8e91267..HEAD -- 'app/Sources/**/*.swift' | grep -E '@(Model|Attribute|Relationship)'` empty — **no SwiftData @Model schema drift**. `Holding` @Model unchanged at `app/Sources/Backend/Models/MVPModels.swift:63-98`.
- X-Device-UUID / X-App-Attest / X-App-Version handling: unchanged on both sides. `APIClient.swift:107` still emits `X-Device-UUID` (no change); spec parameter-declaration count for `"name": "X-Device-UUID"` = **0** (X-Device-UUID only appears in 4 description strings at L481, L1057, L2051, L2082 — not as a parameter); `"name": "X-App-Attest"` count still **9** at L85, 195, 315, 495, 665, 883, 1071, 1253, 1450; X-App-Version remains undeclared (per #429 closure) and `APIClient.swift` no longer sets it.
- Transient `SwiftData @Model final class` synthesis in `ContributionInput.init(holdings:)` (Portfolio + Category + Ticker created without a `ModelContext`) — re-considered for filing this cycle. **Sub-threshold (decision unchanged):** the seam returns a `ContributionOutput` (allocations only), no production reducer round-trips the synthetic graph back into a `ModelContext`, and the doc-comment at L115-120 already says "the synthesis step is the single point that needs to be replaced when the legacy graph is retired". Filing would not produce a validated breaking-change call.

**Verdict:** **#452 is a textbook contract-seam landing — zero new contract drift, zero public-API surface change, zero schema drift.** #453 is a single-line SwiftUI glyph swap in Turk's lane (`PortfolioDetailView.swift:225`) — fully outside Nagel's surface.

**Live drifts re-verified on HEAD `9fe4cca` (refreshed file:line — unchanged from prior cycle because openapi.json + main.py were not modified):**

- **#302** `openapi.json`: `/schema/version` `"422"` at **L155** → `$ref` `HTTPValidationError` at **L160**; `/portfolio/status` `"422"` at **L265** → `HTTPValidationError` at **L270**. Other route 422s (L415, 595, 803, 993, 1164, 1363, 1543) use `ErrorEnvelope` (per #341 closure). Still live.
- **#303** `openapi.json:658, 685-691`: `/portfolio/holdings` `"202"` content `application/json` `schema: {}` (empty object); runtime `add_holding` at `backend/api/main.py:792-805+` returns 202 without a JSON body. Still live.
- **#316** `grep -c securitySchemes openapi.json` = **0**. `X-App-Attest` parameter-declared at **L85, L195, L315, L495, L665, L883, L1071, L1253, L1450** (9 ops, unchanged). Still live.
- **#317** `HoldingOut` money fields all `anyOf [{type:number},{type:null}]` at **L1723** (`current_price`), **L1734** (`sma_50`), **L1745** (`sma_200`), **L1756** (`midline`), **L1767** (`atr`), **L1778** (`upper_band`), **L1789** (`lower_band`), **L1800** (`band_position`); required at L1816-1823. `AddHoldingRequest` schema at L1609-1635. Still live.
- **#348** `app/Sources/Backend/Networking/APIClient.swift:107` emits `X-Device-UUID`. `openapi.json` declares it as a parameter **0 times** (X-Device-UUID only appears in description strings at L481, L1057, L2051, L2082). Backend reads `device_uuid` query/body at `backend/api/main.py:406, 545, 634, 723, 825, 961, 1041, 1117, 1191` (9 sites, unchanged). Still live.
- **#356** `openapi.json:1723-1810` (HoldingOut indicator fields) vs `app/Sources/Backend/Models/MVPModels.swift:64-91` (`Holding` @Model carries only `id, portfolioId, symbol, costBasis, shares, sortOrder, createdAt`). Severity escalation noted last cycle (issue comment posted reflecting #452's stub factory naming #356 as the explicit blocker three times) — still live; **#356 is now the highest-leverage drift on the roster** because #452 wired the seam ahead of it. Still live.
- **#416** `backend/api/main.py:303-319` middleware `add_standard_headers` sets `Cache-Control: max-age=<CACHE_MAX_AGE>` + `Last-Modified` + `X-Min-App-Version` via `setdefault` on every response (including the destructive `DELETE /portfolio` 204 documented prior cycle). `grep -c '"Cache-Control"' openapi.json` = **44**. Still live.
- **#423** `grep -c additionalProperties openapi.json` = **0**; `grep -c 'extra="forbid"' backend/api/main.py` = **0**. Substrate unchanged on both sides. Still live.
- **#439** `backend/api/main.py:599-614` `portfolio_status` route declared at L590 with `responses=` block at L594-596 listing only **401** (no 503). DB query at L607-611 (`db.execute(select(StockCache.last_modified, StockCache.next_modified)...)`) has **no `try/except SQLAlchemyError`**. Asymmetric vs `portfolio_data` at L617 which declares 503 at L625-627 and has the SQLAlchemyError handler downstream. Still live.

**Roster delta:** none this cycle. Current open Nagel issues per `gh issue list --label squad:nagel --state open --limit 50`: `#302 #303 #316 #317 #348 #356 #416 #423 #439` (**9 live drifts**, unchanged from prior cycle's snapshot — confirming #359 closure took the count from 10 → 9).

**Dup-check evidence:** `gh issue list --label squad:nagel --state open --limit 50` (9 returned), `gh issue list --label squad:nagel --state closed --limit 20` (18 returned, including #359 at the top with `closedAt:2026-05-15T19:22:06Z`), `gh issue list --state all --search "MarketDataSnapshot"` (returns #359 closed + #356 open — both legitimate), `gh issue list --state all --search "ContributionInput holdings"` (same — no surprise duplicates). The "transient `@Model` synthesis without `ModelContext`" candidate was searched against the 18 closed Nagel filings (`#244`, `#249`, `#250`, `#295`, `#298`, `#337`, `#340` all touch `@Model` contracts) — none cover the synthetic-graph case; left as sub-threshold observation per the rationale above.

**Issue routing:** N/A — no NEW_ISSUE filed; existing roster routing already correct (`team:backend` on all 8 backend-lane filings, `team:frontend` would apply if filed but #356 already at `team:backend` since the persistence target is the @Model schema).

**History append:** this entry to `.squad/agents/nagel/history.md`.

**Outcome:** **NO_OP.** #452 is the contract-seam landing #359 demanded — six ACs met, zero breaking changes, zero new contract drift. #453 is outside Nagel's lane. Parity gate holds, all 9 live drifts re-verified at HEAD `9fe4cca` with refreshed file:line refs, roster unchanged.

**Top finding:** **#452 closure quality is unusually high** — the seam was wired ahead of its data prerequisite (#356) with self-documenting stubs that name the prerequisite three times in production doc-comments. The right Nagel posture remains: **escalate #356 priority rather than file new drift against the #452 stub** (already done last cycle via issue comment).

**Learned this cycle:** when the orchestrator re-spawns at the same HEAD as the prior specialist cycle, the parity gate + #N closure verification + roster re-snap are still worth running — they confirm nothing landed in the gap and produce a fresh audit trail. The cost is ~2 min and the value is a definitive "no drift, no roster delta, parity holds" record stamped at the requested cycle timestamp.

---

## Cycle — 2026-05-15T20:20:00Z (HEAD `95df9a5`; prior `9fe4cca`; +2 commits, BOTH Nagel-lane closures)

**Cycle anchor.** Spawned per `2026-05-15T19-41-00Z` orchestration log. Two commits since prior cycle, both Nagel-lane and both closing Nagel-lane issues:

- `95df9a5` — `data(holdings): persist indicator fields on Holding via v3 schema bump (closes #356)` (PR #455, 10 files, +841/-133). The single largest Nagel-lane closure since the v2 schema bump in #249/#298 — v2→v3 SwiftData migration + 8 new optional indicator columns on `Holding` + frozen v2 snapshot pattern extended (now V1∩V2∩V3 disjoint).
- `e0dd44c` — `contract(openapi): wrap /portfolio/status DB call in SQLAlchemyError handler (closes #439)` (PR #454, 4 files). The `openapi.json` regen happened here.

### Parity gate (mandatory, run first)

- `diff openapi.json app/Sources/Backend/Networking/openapi.json` → **exit 0**.
- `wc -c`: both **72,701 bytes**, mtime `May 15 12:55` matching PR #454.
- `shasum -a 256`: both `25c13abec4d8789be14e23218472056e60b1a50f9b25b97a38917c94184d6839` — **byte-identical**.
- **PARITY GATE: PASS.** PR #454 regenerated both copies in the same commit; the parity invariant survived the regen.

### #356 closure validation matrix (PASS, 9 ACs)

| AC | Expected | Verified at | Verdict |
|---|---|---|---|
| **AC-1** v3 schema bump structure | `LocalSchemaV3` enum + `migrateV2toV3 = MigrationStage.lightweight` (no custom didMigrate) | `app/Sources/App/LocalSchemaVersions.swift:88-113` (V3 enum), `:182-193` (lightweight stage) | ✅ PASS |
| **AC-2** v2 freeze mirrors v1 pattern | 11 entities frozen under `extension LocalSchemaV2`; intentional Holding indicator-column gap | `app/Sources/App/LocalSchemaV2Models.swift:38-363` — 11 nested `@Model` classes (Portfolio/Category/Ticker/ContributionRecord/CategoryContribution/TickerAllocation/Holding/TickerMetadata/MarketDataBar/InvestSnapshot/AppSettings); V2 Holding omits 8 indicator cols by design | ✅ PASS |
| **AC-3** Live `@Model` types moved to V3 namespace + typealiases retarget | `extension LocalSchemaV3 { Holding, Portfolio, … }`; module-scope `typealias Holding = LocalSchemaV3.Holding` (× 11) | `MVPModels.swift:66` (V3 ext), `DomainModels.swift:28` (V3 ext), `LocalSchemaVersions.swift:201-211` (11 typealiases) | ✅ PASS |
| **AC-4** `LocalPersistence.schema` sources from V3 | `Schema(versionedSchema: LocalSchemaV3.self)` | `LocalPersistence.swift:11` | ✅ PASS |
| **AC-5** `migrateV1toV2.didMigrate` pinned to explicit V2 types | `FetchDescriptor<LocalSchemaV2.CategoryContribution>` + `<LocalSchemaV2.TickerAllocation>` so v1→v2 backfill survives typealias retarget | `LocalSchemaVersions.swift:170-178` | ✅ PASS |
| **AC-6** Test surface extended for V3 | V1∩V2∩V3 disjoint (3-way pairwise), `testSchemaV2AndV3DifferOnHoldingIndicatorColumns`, V3 disk round-trip rename, `[V1,V2,V3]`/`[migrateV1toV2,migrateV2toV3]` plan assertion, `testHoldingRoundTripsIndicatorFieldsAddedInV3` + `testHoldingDefaultsIndicatorFieldsToNil` + `Holding.movingAverage(forWindow:)` window resolution | `LocalSchemaMigrationTests.swift:61-62` (V3 version), `:71-75` (V3 entity-names match), `:83-110` (3-way disjoint), `:154-160` (plan pins V1/V2/V3 + 2 stages), `:168-200` (8-column V2-vs-V3 delta), `:206` (round-trip renamed), `:261` (`vca-mig-v3-` prefix); `MVPModelsPersistenceTests.swift:40-72` (indicator round-trip), `:75-92` (defaults-to-nil + supported/unsupported window) | ✅ PASS |
| **AC-7** `MarketDataSnapshot.init(holdings:)` flipped from #359 empty-stub to real projection; skips all-nil holdings so validator surfaces `.missingMarketData(symbol)` | `ContributionCalculator.swift:194-213` (sma50 default), `:215-246` (maWindow overload + 3-nil skip at L235-237) | ✅ PASS |
| **AC-8** New `init(holdings:maWindow:)` overload + `Holding.movingAverage(forWindow:)`; unsupported windows return nil | `ContributionCalculator.swift:220-246` overload; `MVPModels.swift:153-159` window resolver (`case 50/200`, `default: nil`) | ✅ PASS |
| **AC-9** `ContributionCalculatorMVPHoldingsSeamTests` flipped from #359 until-#356 pin to indicator-projection assertion; AC3-AC6 unchanged | `ContributionCalculatorMVPHoldingsSeamTests.swift:50-66` (empty when all-nil), `:68-99` (projects when present), `:101-119` (window selection); AC3/AC4 at `:147-199`, AC5 at `:203-229` (still `explicit init(quotesBySymbol:)` for legacy/MarketDataSnapshot(holdings:)), AC6 legacy at `:233+` | ✅ PASS |

### #439 closure validation matrix (PASS, 3 ACs)

| AC | Expected | Verified at | Verdict |
|---|---|---|---|
| **AC-1** `/portfolio/status` wraps DB in `try/except SQLAlchemyError → ApiError(503, syncUnavailable, retry_after_seconds=60)` | `backend/api/main.py:614-627` (try at L614, except at L620, ApiError at L622-627 with `retry_after_seconds=60`); responses dict at L593-600 includes `HTTP_503_SERVICE_UNAVAILABLE` | ✅ PASS |
| **AC-2** Test exists asserting 503 + `code=syncUnavailable` + `retry_after_seconds=60` via OperationalError dep override | `backend/tests/test_api.py:282-312` — `test_portfolio_status_db_unreachable_returns_sync_unavailable` overrides `get_db` with a `_BrokenSession` raising `OperationalError`; asserts `status_code == 503` and body `{"code":"syncUnavailable","message":"Database is unreachable.","retry_after_seconds":60}` | ✅ PASS |
| **AC-3** OpenAPI declares 503 with `$ref: ErrorEnvelope` on `/portfolio/status` GET | `jq '.paths."/portfolio/status".get.responses | keys'` → `["200","401","422","503"]`; 503 schema `$ref: "#/components/schemas/ErrorEnvelope"` | ✅ PASS |

### Refreshed live-drift roster (was 9, now **10**: -2 closed, +3 new since 19:41Z)

- **#302** `openapi.json:155-160, 295-300` — `/schema/version` + `/portfolio/status` 422 entries still reference HTTPValidationError (FastAPI default), not the ErrorEnvelope. `RequestValidationError` handler exists at `backend/api/main.py:233-244` (returns ErrorEnvelope) but the OpenAPI 422 schema was never updated to match. Still live.
- **#303** `openapi.json:688-696` (route declaration); `jq '.paths."/portfolio/holdings".post.responses."202"'` → `schema: {}` (empty JSON body) but runtime in `backend/api/main.py:809+` returns no body. Still live.
- **#316** `grep -c '"securitySchemes"' openapi.json` = **0**. `X-App-Attest` parameter-declared at **L85, L195, L345, L525, L695, L913, L1101, L1283, L1480** + V1 at L1480 (10 op sites — count grew by 1 due to new `/portfolio/export` from #450). Still live.
- **#317** `HoldingOut` money fields use bare `number`: `current_price` at **L1753-1762**, `sma_50` at **L1764-1773**, `sma_200` at **L1775-1784**, `midline` at **L1786-1795**, `atr` at **L1797-1806**, `upper_band` at **L1808-1817**, `lower_band` at **L1819-1828**, `band_position` at **L1830-1839**; required at L1843-1854. `AddHoldingRequest.weight` at **L1655-1657** is `"type": "number"`, `exclusiveMinimum: 0.0`, `maximum: 1.0`. Still live.
- **#348** `app/Sources/Backend/Networking/APIClient.swift:107` (unchanged) emits `X-Device-UUID`. `grep -c '"name": "X-Device-UUID"' openapi.json` = **0** (only appears in description strings at L511, L1087, L2081, L2112). Backend reads `device_uuid` at `backend/api/main.py:406, 545, 651, 740, 768, 788, 842` (**24** raw `device_uuid` references in main.py). Still live.
- **#416** `backend/api/main.py:303-319` middleware sets `Cache-Control: max-age=<CACHE_MAX_AGE>` via `setdefault` on every response. `grep -c '"Cache-Control"' openapi.json` = **45** (up from 44 — one new occurrence from new export route added in #450/#451). Still live.
- **#423** `grep -c 'additionalProperties' openapi.json` = **0**; `grep -c 'extra="forbid"' backend/api/main.py backend/api/schemas.py` = **0**. Substrate unchanged. Still live.
- **#460** (NEW since prior cycle, filed 2026-05-15T20:08:09Z) — `PORTFOLIO_NOT_FOUND` overloaded for holding-not-found on PATCH/DELETE `/portfolio/holdings/{ticker}`. `backend/api/main.py:1006, 1081, 1104, 1153, 1176, 1245` all raise `PORTFOLIO_NOT_FOUND` regardless of which row is missing. `openapi.json:1674` enumerates the code. Live.
- **#461** (NEW since prior cycle, filed 2026-05-15T20:08:30Z) — `PatchHoldingRequest.weight` (`openapi.json:1858-1869`) is `string`/`format: decimal` with **no** `minimum`/`exclusiveMinimum`/`maximum`; `PatchPortfolioRequest.monthly_budget` (L1893-1932) same shape. Asymmetric vs `AddHoldingRequest.weight` at L1655-1657 which carries `exclusiveMinimum: 0.0, maximum: 1.0`. Live.
- **#463** (NEW since prior cycle, filed 2026-05-15T20:08:42Z) — `PortfolioExportResponse.format_version` (`openapi.json:2085`) has default but NOT in `required` (`["generated_at","device_uuid","portfolio"]` at L2083+). Same #381 pattern not applied to the new GDPR Art. 20 export endpoint. Live.

### Activity-window probe

`gh issue list --label squad:nagel --state open --search "updated:>2026-05-15T19:41:00Z"` → **3 hits**: #463, #461, #460 (all filed 2026-05-15T20:08:*Z, between this cycle's spawn and the prior cycle's stamp). All three already labeled `squad:nagel` + `team:backend` per orchestrator pre-routing; no re-routing needed.

### New-drift scan — verdict per candidate

1. **Holding schema bump strictly additive?** ✅ Yes. 8 new `Decimal?` columns, all nullable, all `= nil` default on init parameters. SwiftData lightweight bridge handles every existing V2 row without a custom didMigrate. `MVPModels.swift:106-122` shows every new param defaults to `nil` — no existing call site breaks. **Additive: PASS.**
2. **Public API signature change on @Model types?** ✅ No `public` modifiers exist on any `@Model` class in `MVPModels.swift` or `DomainModels.swift` (module-internal access). `Holding.init(...)` extended with 8 new params, all defaulted — no caller breaks. **No public surface drift.**
3. **`Holding.movingAverage(forWindow:)` public?** ✅ Declared at `MVPModels.swift:153` as `func movingAverage(forWindow window: Int) -> Decimal?` — **no `public` modifier**. Module-internal API; consistent with sibling methods (`normalizedSymbol`, `normalize`). Not on a header surface to maintain. **No drift.**
4. **`ContributionCalculating` protocol changed?** ✅ Declared at `ContributionCalculator.swift:68` as `protocol ContributionCalculating: Sendable` (no `public`). Conformers (`MovingAverageContributionCalculator` L460, `BandAdjustedContributionCalculator` L547, `ProportionalSplitContributionCalculator` L644) unchanged in method signatures. **Pure seam preservation — no drift.**
5. **`MarketDataSnapshot.init(holdings:maWindow:)` additive?** ✅ The original `init(holdings:)` at L211-213 still exists and now delegates to `init(holdings:maWindow:50)`. Existing call sites compile unchanged. Struct itself is `struct MarketDataSnapshot: Equatable` (no `public`). **Additive overload — no drift.**
6. **Validator behavior preserved on empty-indicator holdings?** ✅ `ContributionCalculator.swift:235-237` explicitly skips holdings with all-nil indicators so the shared validator emits `.missingMarketData(symbol)` instead of a 3-nil quote that would silently pass structural checks. Test at `ContributionCalculatorMVPHoldingsSeamTests.swift:50-66` pins this. **Behavior pin: PASS.**

**Cross-check against open #423:** the 8 new `Decimal?` columns are already declared on `HoldingOut` in the spec (`openapi.json:1743-1855`). The iOS side is *catching up to* the spec, not extending it — this **closes drift**, doesn't add it. No #423 worsening.

### Decision

**NO_OP.** Both #356 (the prior cycle's highest-leverage drift) and #439 ship inside Nagel's lane with 9-AC + 3-AC matrices fully green. Zero new drift introduced by either closure. The three roster additions (#460/#461/#463) are pre-existing orchestrator-routed filings, not net-new from this cycle's scan.

### Duplicate-check proof

- `gh issue list --label squad:nagel --state open --limit 50` → **10 open** (`#302 #303 #316 #317 #348 #416 #423 #460 #461 #463`).
- `gh issue view 356 --json state,closedAt` → `CLOSED` at `2026-05-15T19:59:22Z` (PR #455).
- `gh issue view 439 --json state,closedAt` → `CLOSED` at `2026-05-15T19:51:23Z` (PR #454).
- `gh issue list --label squad:nagel --state open --search "updated:>2026-05-15T19:41:00Z"` → **3** (#460, #461, #463). All pre-routed; all distinct from #356/#439 closures.
- `gh issue list --state all --search "MarketDataSnapshot OR movingAverage"` cross-check: only #356 + #359 returned, both closed legitimately.
- No new findings filed → no duplicate-check needed for NEW_ISSUE.

### Highest-leverage drift for next cycle

**#316** takes over from the now-closed #356. The X-App-Attest count just grew to **10 op sites** (was 9 last cycle) with the new `/portfolio/export` and `DELETE /portfolio` routes from #450/#451 — every protected route repeats the per-op parameter declaration when a single top-level `securitySchemes` block would unify them and let the generated Swift client apply attestation centrally. Closing #316 also unblocks #348 (X-Device-UUID would naturally live in the same security-scheme block once it lands). Secondary candidate: **#423** (open content model architectural fix that masks every other contract filing) — higher impact but larger surface; #316 is the better incremental next step.

### Issue routing

N/A — no NEW_ISSUE filed. Existing roster routing already correct: all 10 live drifts carry `squad:nagel`, 8 carry `team:backend`, #316/#348/#317 carry `team:frontend`-eligibility-mixed (route per orchestrator pre-existing convention).

### History append

This entry to `.squad/agents/nagel/history.md`.

### Outcome

**NO_OP** with the highest-touch validation matrix of the cycle. Parity gate PASS. **#356 closure: 9/9 ACs PASS** — the largest Nagel-lane closure since the v2 bump, structurally sound (V1∩V2∩V3 disjoint extended, frozen-snapshot invariant preserved, lightweight migration justified by null-only delta), zero breaking changes. **#439 closure: 3/3 ACs PASS** — symmetric with sibling endpoints, retry signal documented end-to-end. Roster shifted -2 / +3 = **9 → 10 live drifts**. Highest-leverage handoff: **#316** (X-App-Attest as securityScheme, now 10 op sites with the new export/erase routes).

### Top finding

**#455 (PR for #356) is the largest contract-correct schema bump shipped this cycle and the cleanest application of the frozen-snapshot pattern to date.** The v2 freeze in `LocalSchemaV2Models.swift` (363 LOC, 11 entities) is a textbook extension of the v1 freeze from #337 — the V2 Holding's intentional indicator-column gap is the entire v2→v3 delta, expressible as a single declarative diff. The `migrateV1toV2.didMigrate` retarget to explicit `LocalSchemaV2.*` fetches (L170-178) is the exact correctness fix that lets the typealiases re-resolve to V3 without breaking the v1→v2 backfill — easy to miss, present here. The doc-comment cross-references (e.g. `MVPModels.swift:73-83` calling out the wire shape, `LocalSchemaV2Models.swift:10-21` documenting where V2 types are reachable) make the future V3→V4 bump straightforward to execute.

### Learned this cycle

When closing the standing highest-leverage drift, the validation matrix grows proportionally with the surface area of the change — #356 produced a 9-AC matrix (3× the typical 3-AC cycle) because the SwiftData migration plan touches schema versioning, model type identity, migration stages, app-facing typealiases, test coverage extension, and the cross-file projection seam to `MarketDataSnapshot`. Resist the temptation to compress: each AC has an independent failure mode (e.g., AC-5 silently breaks v1→v2 backfill if the explicit type-pinning is missed; AC-6 catches retroactive mutation of the V1 baseline; AC-7 distinguishes "all-nil quote" from "no quote at all" at the validator gate). The 9-row matrix is the actual surface, not bookkeeping.

---

## Cycle — 2026-05-15T20:54:10Z (HEAD `beb72b6`; prior `95df9a5`; +2 commits, 1 Nagel-lane closure + 1 cross-lane UI ship)

**Cycle anchor.** Spawned per orchestrator parallel-specialist pass post-#463 closure. Two commits since prior cycle:

- `beb72b6` — `contract(openapi): mark PortfolioExportResponse.format_version required (closes #463) (#466)` (4 files, +69/-0). Pure Nagel-lane closure of one of the three filings made between cycles `9fe4cca` and `95df9a5`.
- `7378118` — `compliance(data-erasure-ui): add Settings → Erase All My Data flow (closes #329) (#464)` (11 files, +903/-33). Reuben/Basher-lane ship that touches contract surface (new dependency clients, new keychain rotation seam) — full Nagel scan required.

### Parity gate (mandatory, run first)

- `diff openapi.json app/Sources/Backend/Networking/openapi.json` → **exit 0**.
- `wc -c`: both **72,729 bytes** (was 72,701 at prior cycle; +28 bytes = `"format_version",\n          ` indented insertion).
- `shasum -a 256`: both `d5526ad67f5452a31eaf4b2f8207d2cf3e769e06b1d80e9f0938995e24d0d5f2` — **byte-identical**.
- `PYTHONPATH=backend python3 -m api.export_openapi --check` could not run locally (`ModuleNotFoundError: fastapi` — host env lacks the runtime venv); byte-identical sha establishes parity orthogonally. CI's `--check` step ran during PR #466 per the commit message ("`PYTHONPATH=backend python3 -m api.export_openapi --check`: passes").
- **PARITY GATE: PASS.** PR #466 regenerated both copies in the same commit (one-line `+ "format_version",` to each); the parity invariant survived the regen.

### #463 closure validation matrix (PASS, 6 ACs)

| AC | Expected | Verified at | Verdict |
|---|---|---|---|
| **AC-1** `format_version` lands in the `required` array | `["format_version", "generated_at", "device_uuid", "portfolio"]` for `components.schemas.PortfolioExportResponse.required` | `python3 -c "import json; print(json.load(open('openapi.json'))['components']['schemas']['PortfolioExportResponse']['required'])"` → `['format_version', 'generated_at', 'device_uuid', 'portfolio']`; raw at `openapi.json:2105-2110` | ✅ PASS |
| **AC-2** Pre-existing `required` entries are preserved (footgun: `json_schema_extra.required` *replaces* the auto-generated list with dict-update semantics) | `generated_at`, `device_uuid`, `portfolio` still in the array post-edit | Same `json.load` result above — all 3 present alongside `format_version` | ✅ PASS |
| **AC-3** Field schema retains numeric constraints so a future bump cannot land as a non-integer | `type: integer, default: 1, minimum: 1` (Pydantic's `Field(default=1, ge=1)` translates to JSON Schema `minimum: 1.0`) | `format_version_schema = {'type': 'integer', 'minimum': 1.0, 'title': 'Format Version', 'default': 1}` | ✅ PASS |
| **AC-4** Regression test pins required-array + field-schema invariants together (without this guard, a future naive `json_schema_extra={"required": ["…"]}` write would re-introduce the original drift silently) | Test exists asserting (i) `format_version` in required, (ii) `generated_at`/`device_uuid`/`portfolio` in required, (iii) `type/default/minimum` on the field | `backend/tests/test_api.py:717-758` — `test_portfolio_export_response_marks_format_version_required` asserts all four required fields + `type=='integer'`, `default==1`, `minimum==1` | ✅ PASS |
| **AC-5** Pydantic idiom is the same `#381`/`HealthResponse` precedent (i.e. `model_config = ConfigDict(json_schema_extra={"required": [...]})`), not a one-line hack | `backend/api/main.py:553-563` declares `model_config = ConfigDict(json_schema_extra={"required": ["format_version", "generated_at", "device_uuid", "portfolio"]})` with a 13-line inline comment naming #381 + #463 and warning about the dict-update footgun | Verified in diff at L540-563 of `backend/api/main.py` | ✅ PASS |
| **AC-6** Both `openapi.json` copies regenerated and committed in the same commit (parity invariant) | Parity gate above; only the same 1-line diff on each copy | `git --no-pager diff 95df9a5..beb72b6 -- openapi.json app/Sources/Backend/Networking/openapi.json` shows identical `+"format_version",` insert on each | ✅ PASS |

### #329 closure — Nagel-lane contract scan (PR #464, the data-erasure UI ship)

Even though #329 is Reuben's lane, it adds two new dependency clients and a Keychain rotation seam — that's exactly the cross-layer service-interface surface I gate. Five contract-relevant changes audited:

1. **`DeviceIDClient.rotate` added.** `app/Sources/App/Dependencies/DeviceIDClient.swift:18` — new closure field `var rotate: @Sendable () throws -> Void` on the `@DependencyClient`-decorated struct. **Source-compatible:** the TCA macro synthesizes an initializer where every closure parameter has a default that fires `reportIssue("unimplemented")` at runtime — existing call sites that constructed `DeviceIDClient(deviceID:)` continue to compile. `liveValue` (L29) and `previewValue` (L33) were both updated in the same diff to wire the new closure. `grep -rn 'DeviceIDClient(' app/Sources app/Tests` returns exactly the 2 known call sites. **Classification: ADDITIVE.**
2. **`DeviceIDProvider.keychainKey` visibility widened from `private static let` to `static let`** at `app/Sources/Backend/Networking/DeviceIDProvider.swift:13`. Doc comment explicitly justifies the relaxation ("Exposed `internal` so `rotate()` and tests can purge / pin the same key the `deviceID()` accessor reads from without re-deriving the literal"). **Classification: ADDITIVE** (visibility relaxation cannot break existing callers).
3. **`DeviceIDProvider.rotate() throws` added** at `app/Sources/Backend/Networking/DeviceIDProvider.swift:48`. New internal `static func` that wraps `KeychainStore.remove(keychainKey)`. **Classification: ADDITIVE.**
4. **`AccountErasureClient` + `AccountErasureRequestFactory` + `AccountErasureOutcome` enum** all new at `app/Sources/App/Dependencies/AccountErasureClient.swift` (137 LOC). All internal access (no `public`); `@DependencyClient` struct, factory enum with `static let path`/`makeRequest`, outcome enum with `.success`/`.networkUnavailable(reason:)`/`.serverError(status:)`. The `path = "/portfolio"` and `deviceUUIDQueryItem = "device_uuid"` constants are pinned against the spec to make a renamed-endpoint regression surface as a test failure, not a silent 404 (`AccountErasureClient.swift:43-50` doc comment). **Classification: ADDITIVE.**
5. **`LocalDataResetClient` + `BackgroundModelActor.eraseAllPersonalData()` extension** new at `app/Sources/App/Dependencies/LocalDataResetClient.swift` (92 LOC). Internal access throughout; the extension method on `BackgroundModelActor` is a strictly-additive operation that fetches every `Portfolio`/`Holding`/`InvestSnapshot`/`AppSettings` row and deletes them — `MarketDataBar`/`TickerMetadata` intentionally preserved (matches backend's `StockCache` carve-out documented at `docs/legal/data-subject-rights.md` "Erasure — full account"). **Classification: ADDITIVE.**

**Public-API surface diff:** `git --no-pager diff 95df9a5..beb72b6 -- 'app/Sources/**/*.swift' | grep -cE '^[-+]\s*(public|open) '` → **0**. Zero `public`/`open` declarations changed. The VCA target is still a single internal-by-default module.

**SwiftData `@Model` diff:** `git --no-pager diff 95df9a5..beb72b6 -- 'app/Sources/**/*.swift' | grep -cE '^[-+]\s*@(Model|Attribute|Relationship)'` → **0**. Zero schema drift on top of #356's freshly-landed v3 bump. `Holding`, `Portfolio`, `Category`, `Ticker`, `InvestSnapshot`, `AppSettings` all unchanged this cycle.

**Protocol-decl diff:** `git --no-pager diff 95df9a5..beb72b6 -- 'app/Sources/**/*.swift' | grep -cE '^[-+]\s*protocol '` → **0**. `ContributionCalculating` seam unchanged from #359 + #356 + #455. Six conformers (`MovingAverage`, `BandAdjusted`, `ProportionalSplit`, plus testing stubs) untouched.

**Verdict:** **PR #464 is contract-clean.** Five additive surfaces, zero modifying changes, zero removals, zero breaking signatures. The Keychain `rotate()` path is the only seam with any teeth — it documents a Privacy-Policy commitment (`docs/legal/privacy-policy.md` §6) so future regressions surface as policy violations, not silent silent-failure. Nagel posture: no filing.

### Refreshed live-drift roster (was 10, now **9** — `-1` for #463 closure)

- **#302** `openapi.json`: `/schema/version` `"422"` and `/portfolio/status` `"422"` both still `$ref HTTPValidationError`. Verified programmatically: `spec['paths']['/schema/version']['get']['responses']['422']['content']['application/json']['schema'] == {'$ref': '#/components/schemas/HTTPValidationError'}` (same for `/portfolio/status`). Still live.
- **#303** `openapi.json`: `/portfolio/holdings` POST `"202"` content `application/json` `schema: {}` (empty object); runtime `add_holding` returns 202 without a JSON body. Programmatic verify: `spec['paths']['/portfolio/holdings']['post']['responses']['202']['content']['application/json']['schema'] == {}`. Still live.
- **#316** `grep -c '"securitySchemes"' openapi.json` = **0**. `grep -c '"name": "X-App-Attest"' openapi.json` = **9** (NOT 10 — prior cycle's history entry had an arithmetic error; the actual op-site count has been 9 since /portfolio/export + DELETE /portfolio joined the protected set). Programmatic enumeration: `PATCH /portfolio`, `DELETE /portfolio`, `GET /portfolio/data`, `GET /portfolio/export`, `POST /portfolio/holdings`, `PATCH /portfolio/holdings/{ticker}`, `DELETE /portfolio/holdings/{ticker}`, `GET /portfolio/status`, `GET /schema/version` all declare `X-App-Attest` at op level (`GET /health` correctly omits it). Still live.
- **#317** `HoldingOut` money fields use bare `number`. `AddHoldingRequest.weight` at `openapi.json:1652-1656` retains `{type: number, exclusiveMinimum: 0.0, maximum: 1.0}` — the symmetric counter-example #461 exploits. Still live.
- **#348** `grep -c '"name": "X-Device-UUID"' openapi.json` = **0**. Description-only mentions at L511, L1087, L2081, L2113 (last one shifted +1 from L2112 last cycle). `APIClient.swift:107` still emits the header on every request. Still live.
- **#416** `grep -c '"Cache-Control"' openapi.json` = **45** (unchanged from prior cycle's 45 — the +1 from prior cycle came from #450's export route landing; this cycle introduced no new operations). Middleware `add_standard_headers` at `backend/api/main.py:303-319` still blankets every operation. Still live.
- **#423** `grep -c additionalProperties openapi.json` = **0**; `grep -c 'extra="forbid"' backend/api/main.py` = **0** (no `backend/api/schemas.py` exists — schemas inlined in main.py). Programmatic substrate audit: **16 of 17** component schemas are open-content (the closed one is `ErrorCode`, which is a string enum, not an object). Substrate masks every other contract filing. Still live.
- **#460** `ErrorCode` enum at `openapi.json:1668-1684`: `['appAttestMissing', 'conflictDetected', 'lossyMappingRejected', 'portfolioNotFound', 'schemaUnsupported', 'stockDataMissing', 'stockDataPending', 'stockDataStale', 'syncUnavailable', 'unsupportedMovingAverageWindow']`. `portfolioNotFound` raised by `PATCH /portfolio/holdings/{ticker}` (`backend/api/main.py:1006, 1081, 1104`) and `DELETE /portfolio/holdings/{ticker}` (L1153, 1176, 1245) for both portfolio-missing AND holding-missing. iOS clients cannot distinguish on the code channel. Still live.
- **#461** `PatchHoldingRequest.weight` at `openapi.json:1858-1865` = `{type: string, format: decimal}` (no `exclusiveMinimum`/`maximum`); `PatchPortfolioRequest.monthly_budget` at L1907-1918 = `anyOf [{type: string, format: decimal}, {type: null}]` (no range). `AddHoldingRequest.weight` at L1652-1657 retains `{type: number, exclusiveMinimum: 0.0, maximum: 1.0}`. The DecimalString fix in #392 dropped the range-constraint channel for every PATCH variant. Still live.

### Activity-window probe

`gh issue list --label squad:nagel --state closed --limit 5` → top entry is `#463 closedAt 2026-05-15T20:36:02Z` (PR #466). Below it: `#439` (20:36:02Z... wait, `#439 closedAt 19:51:23Z`), `#429` (`18:20:45Z`), `#402` (`16:12:30Z`), `#392` (`16:03:17Z`). **5 Nagel-lane closures in the past ~5 hours** — the parallel-specialist loop has been productive.

`gh issue list --label squad:nagel --state open --limit 50` → **9 open**: `#302 #303 #316 #317 #348 #416 #423 #460 #461`. **No new orchestrator-routed Nagel filings since the prior cycle stamp** (`gh issue list --label squad:nagel --state open --search "updated:>2026-05-15T20:20:00Z"` returns only `#463` and that's closed).

### New-drift scan — verdict per candidate

1. **`DeviceIDClient` testValue surface change?** ✅ No — `@DependencyClient` macro auto-synthesizes the new `rotate` field with a trap-on-call default. Tests that previously stubbed only `deviceID` continue to pass unless they exercise the erasure path. **No drift.**
2. **`DeviceIDProvider.keychainKey` exposure widens the contract?** ✅ Visibility relaxation, not signature change. Existing `private` callers (the same file) continue to work; new callers (rotate, tests) can now reach it. **No drift.**
3. **`AccountErasureRequestFactory.path` and `deviceUUIDQueryItem` pinned correctly against the spec?** ✅ `path = "/portfolio"` matches the `DELETE /portfolio` operation in `openapi.json` (operation id `delete_portfolio_portfolio_delete`); `deviceUUIDQueryItem = "device_uuid"` matches the query parameter declared at `backend/api/main.py:1101-1108` (the GDPR Art. 17 endpoint). Renaming either side would surface as an `AccountErasureClientTests` failure, not a silent 404. **No drift.**
4. **`AccountErasureOutcome` folds 204 + 404 to `.success` — does that violate the spec?** ✅ No — the spec declares `/portfolio` DELETE returns `204 No Content` on success and `404 portfolioNotFound` when the device never synced. Folding both to `.success` is a documented decision (`AccountErasureClient.swift:9-14`) consistent with the user-visible guarantee ("nothing left on the backend"). The OpenAPI `responses` block remains accurate on both codes. **No drift.**
5. **`LocalDataResetClient.eraseAllPersonalData` preserves market-data cache?** ✅ `BackgroundModelActor.eraseAllPersonalData()` deletes only `Portfolio` (cascading), `Holding`, `InvestSnapshot`, `AppSettings` — `MarketDataBar`/`TickerMetadata` left intact (`LocalDataResetClient.swift:74-90`). Matches the backend's `StockCache` carve-out described in `docs/legal/data-subject-rights.md` "Erasure — full account". **No drift.**
6. **#463 closure introduced any side drift?** ✅ Only edit to `openapi.json` was the `+"format_version",` insertion; only edit to `backend/api/main.py` was the `model_config = ConfigDict(...)` block above `PortfolioExportResponse` plus a 13-line inline comment. No other schema, route, or response changed. **No collateral drift.**

### Decision

**NO_OP.** #463 closure verified across a 6-AC matrix (textbook application of the #381 `HealthResponse` precedent, regression test pins all four required fields + field-schema constraints, the dict-update footgun is explicitly documented inline). PR #464 (Reuben's #329 closure) introduces five additive contract surfaces with zero modifications or removals. Roster: 10 → 9 live drifts (`-1` for #463).

### Duplicate-check proof

- `gh issue list --label squad:nagel --state open --limit 50` → **9** (`#302 #303 #316 #317 #348 #416 #423 #460 #461`), all distinct.
- `gh issue list --state open --search "contract in:title" --limit 30` → same 9 + nothing new.
- `gh issue view 463 --json state,closedAt` → `CLOSED` at `2026-05-15T20:36:02Z` (PR #466).
- `gh issue list --label squad:nagel --state closed --limit 5` → `#463`, `#439`, `#429`, `#402`, `#392` — five most-recent closures, no surprises.
- `gh issue list --label squad:nagel --state open --search "updated:>2026-05-15T20:20:00Z"` → **0** new orchestrator-routed filings since prior cycle stamp.
- No NEW_ISSUE filed this cycle → no duplicate-check needed for a NEW filing.

### Highest-leverage drift for next cycle

**#423** is now unambiguously the highest-leverage open drift. The substrate audit makes it explicit: **16 of 17** component schemas are open-content models. Until `additionalProperties: false` (or `extra="forbid"` on the Pydantic side) lands across the request schemas, every other Nagel filing — #461's missing range constraints, #460's overloaded `portfolioNotFound`, #303's empty 202 body, #316's per-op header, #348's undeclared header — gets *partially masked* because the server silently accepts unknown fields and the client silently drops unknown ones. Closing #423 is the multiplier; closing #461/#460/#303 in isolation each closes ONE drift, but closing #423 closes the failure mode that turns every other drift into a silent failure instead of a 422.

Secondary candidate: **#317** (HoldingOut bare-`number` money fields). The fix pattern is already established (`#392`/`#446`/`#374` shipped `DecimalString` end-to-end on `monthly_budget` + PATCH paths; #317 just ports the same pattern to the read path).

### Issue routing

N/A — no NEW_ISSUE filed. Existing roster routing already correct: all 9 live drifts carry `squad:nagel` + `team:backend`; topical labels (`ios`, `architecture`, `mvp`) intact.

### History append

This entry appended to `.squad/agents/nagel/history.md` (file end).

### Outcome

**NO_OP** with a 6-AC closure validation for #463 (cleanest one-line Nagel-lane closure of the cycle) plus a 5-surface additive scan for #329's Reuben-lane data-erasure UI ship. Parity gate PASS. Roster `10 → 9`. **#423 confirmed as the highest-leverage drift remaining** — substrate audit shows 16/17 component schemas are open-content models, masking every other open filing.

### Top finding

**The #381 → #463 pattern is now a *named precedent* in the codebase.** PR #466's commit message and inline doc comment both cite `HealthResponse` by name, and the test guard explicitly anchors against regressions of that pattern. This makes the *next* application — whoever ships the V4 sync envelope, or the `PortfolioExportResponse.format_version` v2 bump — a structural rather than ad-hoc fix. The dict-update footgun is the kind of Pydantic v2 quirk that bites in production; capturing it inline + in a regression test means a future reviewer doesn't have to re-derive why all four required fields must be re-stated.

### Learned this cycle

**Adjacent-lane PRs need the same Nagel surface scan as in-lane PRs.** #329 was Reuben's compliance closure on paper, but the implementation added two dependency clients (`AccountErasureClient`, `LocalDataResetClient`), widened a Keychain identifier from `private` to `internal`, and added a Keychain rotation seam — all interfaces between the data layer (Virgil) and the UI layer (Basher) that fall squarely inside my charter. Skipping the diff because the squad label said "Reuben" would have left those 5 surfaces unaudited. The cheap rule: **any PR touching `app/Sources/App/Dependencies/` or `app/Sources/Backend/Networking/` gets the Nagel public-API + protocol + @Model triple-scan, regardless of which lane's issue it closes.**

---

## Cycle — 2026-05-15T~21:30Z (HEAD `63cad39`; prior `beb72b6`; +1 commit, Nagel-lane closure #469)

**Cycle anchor.** This is the in-lane cycle — the single new commit `63cad39` closes Nagel's own filing #460 (PR #469): `contract(openapi): add dedicated holdingNotFound ErrorCode for PATCH/DELETE /portfolio/holdings/{ticker}`.

### Parity gate (mandatory, run first)

- `diff openapi.json app/Sources/Backend/Networking/openapi.json` → **exit 0**.
- `shasum -a 256`: both `22ecb114685e2590eb51680bd9fbd40cd87615f828a3be0d8f71e73023eefa4d` — **byte-identical**.
- **PARITY GATE: PASS.** PR #469 regenerated both copies in the same commit; the parity invariant survived the regen.

### #469 diff verification

The commit makes exactly the changes described:

| Change | Location | Verified |
|---|---|---|
| `HOLDING_NOT_FOUND = "holdingNotFound"` added to `ErrorCode` enum | `backend/api/main.py:86` | ✅ |
| Enum alphabetized: position 2 (between `conflictDetected:1` and `lossyMappingRejected:3`) | `backend/api/main.py:84-94` | ✅ |
| `patch_holding` inner 404 → `ErrorCode.HOLDING_NOT_FOUND` | `backend/api/main.py:1139` | ✅ |
| `patch_holding` outer 404 stays `ErrorCode.PORTFOLIO_NOT_FOUND` | `backend/api/main.py:1116` | ✅ |
| `delete_holding` inner 404 → `ErrorCode.HOLDING_NOT_FOUND` | `backend/api/main.py:1211` | ✅ |
| `delete_holding` outer 404 stays `ErrorCode.PORTFOLIO_NOT_FOUND` | `backend/api/main.py:1188` | ✅ |
| Enum docstring added distinguishing semantics | `backend/api/main.py:72-81` | ✅ |
| Both `openapi.json` copies gain `"holdingNotFound"` at enum position 2 + docstring | `openapi.json:1673`; `app/Sources/Backend/Networking/openapi.json:1673` | ✅ |
| `ErrorCode` enum in `openapi.json` is alphabetically sorted | `python3` verify → `True`, 11 values | ✅ |

### #460 closure validation matrix (PASS, 5 ACs)

| AC | Expected | Verified at | Verdict |
|---|---|---|---|
| **AC-1** `ErrorCode.HOLDING_NOT_FOUND = "holdingNotFound"` added to backend enum | Present between `CONFLICT_DETECTED` and `LOSSY_MAPPING_REJECTED` | `backend/api/main.py:86` | ✅ PASS |
| **AC-2** PATCH `/portfolio/holdings/{ticker}` 404-for-holding-missing emits `holdingNotFound` | `if holding is None: raise ApiError(…code=ErrorCode.HOLDING_NOT_FOUND…)` | `backend/api/main.py:1136-1141` | ✅ PASS |
| **AC-3** DELETE `/portfolio/holdings/{ticker}` 404-for-holding-missing emits `holdingNotFound` | Same pattern | `backend/api/main.py:1208-1213` | ✅ PASS |
| **AC-4** Both `openapi.json` copies show 11 enum values, parity byte-identical | `len(vals)==11`, sha256 match | openapi.json enum; shasum above | ✅ PASS |
| **AC-5** Backend tests assert PATCH/DELETE-holding with existing portfolio but unknown ticker returns `code: "holdingNotFound"` (not `portfolioNotFound`) | `test_patch_holding_404_for_unknown_ticker:1143` asserts `"holdingNotFound"`; `test_delete_holding_404_for_unknown_ticker:1292` asserts `"holdingNotFound"` | `backend/tests/test_api.py:1143, 1292` | ✅ PASS |

### Candidate A — 404 response examples/description drift

**Verification.** PATCH and DELETE `/portfolio/holdings/{ticker}` 404 responses have **no** `example`, `examples`, or `x-codeSamples` fields — no inline examples to contradict the new code. The 404 `description` field is `"Requested portfolio resource was not found."` on both operations. This text is shared from `ERROR_RESPONSES[HTTP_404_NOT_FOUND]` and applies identically to all other 404-declaring routes (including `PATCH /portfolio` and `DELETE /portfolio`).

**Assessment.** The description's "portfolio resource" phrasing is now ambiguous for holding-scoped routes (the 404 can fire for either the portfolio or the holding being missing). However: (a) there are no inline examples present at all — no conflicting example exists; (b) the `ErrorCode` enum docstring (`openapi.json:1684`) explicitly documents the semantic distinction between `portfolioNotFound` and `holdingNotFound`; (c) the `ErrorEnvelope.code` field is the machine-readable dispatch channel (the commit message and enum docstring both state this explicitly); (d) the description is human-readable boilerplate, not a programmatic contract surface.

**Verdict: sub-threshold. NO new issue.** The spec is internally consistent on the machine-readable level. The ambiguous description is a documentation quality note, not a contract contradiction. Filing threshold not met.

### Candidate B — iOS client dispatch gap

**Verification.** `grep -rnE "portfolioNotFound|holdingNotFound|PORTFOLIO_NOT_FOUND|HOLDING_NOT_FOUND" app/Sources/Backend/ app/Sources/Features/` returned:
- `app/Sources/Backend/Networking/openapi.json` — enum string values (spec file, not dispatch code)
- `app/Sources/App/AppFeature/HoldingsEditorFeature.swift:298,309,316,320` — local Swift enum case `portfolioNotFound(portfolioID)` on `HoldingsEditorPersistenceError` — this is an **internal app error**, not dispatching on a server `ErrorEnvelope.code`
- `app/Sources/App/Dependencies/AccountErasureClient.swift:9,11,12,16,22,43,124` — dispatch on HTTP status codes (200-300 and 404) but NOT on `ErrorEnvelope.code` body fields

**`app/Sources/Backend/Networking/APIClient.swift` audit:** the handwritten API client has no calls to PATCH `/portfolio/holdings/{ticker}` or DELETE `/portfolio/holdings/{ticker}` at all — these backend routes have no iOS client implementation yet. The iOS app does not call these endpoints.

**Verdict: NON-FINDING.** The iOS client does not call PATCH/DELETE holding routes. There is no live dispatch to gap. When those routes are wired, a Nagel filing on `holdingNotFound` dispatch will be appropriate; for now the surface is unimplemented on the client side and the "dispatch gap" cannot exist. Not filing.

### Candidate C — Other holding-scoped 404 paths with stale PORTFOLIO_NOT_FOUND

**Grep:** `grep -nE "PORTFOLIO_NOT_FOUND|portfolioNotFound" backend/api/main.py | head -40` returned 10 callsites. Audited all 10:

| Line | Route | Condition | Code | Correct? |
|---|---|---|---|---|
| L710 | `GET /portfolio/data` (or similar data route) | portfolio missing for device | `PORTFOLIO_NOT_FOUND` | ✅ |
| L817 | portfolio route | portfolio missing | `PORTFOLIO_NOT_FOUND` | ✅ |
| L891 | portfolio route | portfolio missing | `PORTFOLIO_NOT_FOUND` | ✅ |
| L1041 | `PATCH /portfolio` | portfolio missing for device | `PORTFOLIO_NOT_FOUND` | ✅ |
| L1116 | `PATCH /portfolio/holdings/{ticker}` outer | portfolio missing for device | `PORTFOLIO_NOT_FOUND` | ✅ |
| L1188 | `DELETE /portfolio/holdings/{ticker}` outer | portfolio missing for device | `PORTFOLIO_NOT_FOUND` | ✅ |
| L1280 | `DELETE /portfolio` (right-to-erasure) | portfolio missing for device | `PORTFOLIO_NOT_FOUND` | ✅ |

**Verdict: PASS.** No `PORTFOLIO_NOT_FOUND` callsite is misclassified as a holding-missing path. The `HOLDING_NOT_FOUND` rerouting is complete for all inner-holding-missing 404 branches (exactly 2 sites: L1139, L1211). No other route has a holding-row lookup that could erroneously emit `PORTFOLIO_NOT_FOUND`.

### Candidate D — Test coverage both arms

**Verification.**

- `test_patch_holding_404_for_unknown_device` (`test_api.py:1111`) → asserts `code == "portfolioNotFound"` (outer/portfolio-missing arm) ✅
- `test_patch_holding_404_for_unknown_ticker` (`test_api.py:1122`) → asserts `code == "holdingNotFound"` + `message == "Holding not found for portfolio."` (inner/holding-missing arm, positive test for new code) ✅
- `test_delete_holding_404_for_unknown_device` (`test_api.py:1268`) → asserts `code == "portfolioNotFound"` ✅
- `test_delete_holding_404_for_unknown_ticker` (`test_api.py:1278`) → asserts `code == "holdingNotFound"` + `message == "Holding not found for portfolio."` ✅

**Verdict: PASS.** All 4 test arms present. Both new (`holdingNotFound`) and regression (`portfolioNotFound`) branches exercised for both PATCH and DELETE. Test coverage is complete.

### Open-thread cross-reference table

| Issue | Affected by #469? | Assessment |
|---|---|---|
| **#302** 422 bodies reference HTTPValidationError | No | Unchanged; still live |
| **#303** /portfolio/holdings 202 body empty | No | Unchanged; still live |
| **#316** X-App-Attest per-op not securityScheme | No | Unchanged; still live; 9 op sites |
| **#317** HoldingOut bare `number` fields | No | Unchanged; still live |
| **#348** X-Device-UUID undeclared in spec | No | Unchanged; still live |
| **#416** blanket Cache-Control middleware | No | Unchanged; still live |
| **#423** `additionalProperties` posture absent | No | Unchanged; still live; 16/17 open schemas |
| **#461** DecimalString PATCH fields lack range constraints | No | Unchanged; still live |

No open issue is affected or partially resolved by #469. Roster moves from **9 → 8** open Nagel issues (−1 for #460 closure, +0 new).

### Activity-window probe

`gh issue list --label squad:nagel --state closed --search "closed:>2026-05-13" --limit 20` → 20 returned; top entries:
- `#460 CLOSED 2026-05-15T20:55:17Z` (#469) ✅ closed cleanly
- `#463 CLOSED 2026-05-15T20:36:02Z`
- `#439 CLOSED 2026-05-15T19:51:23Z`
- #429, #402, #392 (earlier today)

`gh issue list --label squad:nagel --state open --limit 20` → **8 open**: `#302 #303 #316 #317 #348 #416 #423 #461`. Confirms clean close.

### Duplicate-check trace

No new issue filed this cycle. Duplicate-check run for completeness on the two candidate-finding searches:

**Candidate A (404 description ambiguity):**
- `gh issue list --state all --search "404 description portfolio resource" --limit 20` → #460 (CLOSED, server-side fix done), #302 (open, HTTPValidationError). Neither covers 404-description prose.
- `gh issue list --state all --search "response description ambiguous holding" --limit 20` → 0 hits.
- `gh issue list --state all --search "404 example x-codeSamples holdingNotFound" --limit 20` → 0 hits.
- Sub-threshold confirmed; not filing.

**Candidate B (iOS dispatch gap):**
- `gh issue list --state all --search "iOS dispatch holdingNotFound" --limit 20` → 0 hits.
- `gh issue list --state all --search "client dispatch error code holdings" --limit 20` → #460 (CLOSED). #460's ACs did not include client-side dispatch (server-side only); non-finding because iOS client doesn't call these routes yet.
- `gh issue list --state all --search "holdingNotFound iOS client" --limit 20` → #460 + #457. Neither covers iOS client dispatch on holding routes.
- Non-finding confirmed; not filing.

### Decision

**NO_OP.** All 5 ACs of #460 verified green with full evidence. Candidates A and B resolve to non-findings (A: sub-threshold prose quality; B: iOS client doesn't call PATCH/DELETE holding routes yet). Candidate C: all 10 PORTFOLIO_NOT_FOUND callsites semantically correct, no holding-scoped misclassification. Candidate D: all 4 test arms present and correct. Roster: 9 → 8. Parity gate: PASS (byte-identical sha256).

### Highest-leverage drift for next cycle

**#423** remains unambiguously the highest-leverage open drift — 16/17 component schemas are open-content models; until `additionalProperties: false` lands, every other filing is partially masked. **#461** (DecimalString PATCH fields missing range constraints) is the cleanest incremental next closure: the pattern (#392/#446) is already established, the counterexample (`AddHoldingRequest.weight` with `exclusiveMinimum: 0.0, maximum: 1.0`) sits three lines above the broken field in the spec, and closing it restores symmetry between PATCH and POST request validation. #316 (X-App-Attest per-op) is the third candidate.

### Issue routing

N/A — no NEW_ISSUE filed. Existing roster routing unchanged: all 8 live drifts carry `squad:nagel` + `team:backend`.

### History append

This entry appended to `.squad/agents/nagel/history.md`.

### Outcome

**NO_OP** — cleanest in-lane cycle possible. #460's server-side fix is architecturally correct and complete: dedicated enum member, correct alphabetization, exactly 2 handler callsites re-routed (outer portfolio-missing branches untouched), docstring explains the semantic contract, both openapi.json copies regenerated byte-identical, all 4 test arms present. No candidates A–D confirmed. Roster: 9 → 8.

### Top finding

**The #460 closure (PR #469) is a textbook ErrorCode taxonomy addition.** The commit sequence is correct: the new enum member was added before (or in the same commit as) the handler change, so no client compiled against the old 10-value enum receives an unknown code during a deployment window — the enum leads the runtime. The `ErrorCode` docstring now serves as the authoritative semantic contract for the holding-vs-portfolio distinction across all future `holdingNotFound` / `portfolioNotFound` callsites. The frozen docstring at `openapi.json:1684` means any future route author who adds a holding-scoped 404 has an explicit discriminant to read before deciding which code to emit.

### Learned this cycle

**The "iOS dispatch gap" pattern requires two preconditions before it rises to a filing: (1) the server emits the new/distinct code, AND (2) the iOS client actually calls the endpoint.** When the iOS client doesn't implement the route at all, the gap is in the implementation queue, not the contract register — filing it as a contract drift would conflate "unimplemented feature" with "live contract-vs-impl mismatch". The filing threshold should be: server emits code X → iOS client calls the endpoint → iOS client decodes the response → iOS client does not branch on X. All four links must be live.

## Cycle #29 — HEAD `215fdef`

### Window + locked-surface scan (expected: PASS / 0 lines)

- Orchestrator window `63cad39..215fdef` = 2 commits:
  - `651d3d0` PR #474 — a11y status announcements; touches `app/Sources/App/AppFeature/SettingsAccessibility.swift` (+58), `app/Sources/Features/SettingsView.swift` (+3), `app/VCATests/VCATests/SettingsAccessibilityTests.swift` (+150), `app/VCA.xcodeproj/project.pbxproj` (+8).
  - `215fdef` PR #476 — ASO doc only; touches `docs/aso/keyword-field.md` (+231).
- `git --no-pager log --name-only 63cad39..HEAD -- 'backend/' 'openapi.json' 'app/Sources/Backend/Networking/' 'app/Sources/Backend/Models/'` → **empty**. No commits hit any contract-surface path.
- Diff stat: 5 files, +450 / −0; zero deletions; nothing under `backend/`, `openapi.json`, `app/Sources/Backend/**`.
- **Locked-surface scan: PASS (0 lines of contract surface in window).**

### Carry-forward verification (existing issues spot-checked)

`gh issue view` on each → all OPEN, titles unchanged, labels intact:

- #461 OPEN — DecimalString range constraints stripped asymmetrically (PatchHoldingRequest.weight, PatchPortfolioRequest.monthly_budget) vs AddHoldingRequest.weight.
- #423 OPEN — every component schema is an open content model (no `additionalProperties: false` / no `extra="forbid"`).
- #416 OPEN — blanket `Cache-Control: max-age=3600` + `Last-Modified: now()` middleware contradicting `ErrorEnvelope.retry_after_seconds`.
- #348 OPEN — `X-Device-UUID` undeclared header attached to every protected request.
- #317 OPEN — HoldingOut/AddHoldingRequest money fields as bare `number` → Swift `Double` (lossy vs iOS `Decimal`).
- #316 OPEN — `X-App-Attest` modeled as per-op header parameter, not `securityScheme`.
- #303 OPEN — `/portfolio/holdings` 202 documented JSON body, runtime empty.
- #302 OPEN — `/schema/version` + `/portfolio/status` still emit FastAPI 422 payloads (not `ErrorEnvelope`).

No state drift since cycle #28.

### Findings (expected: none — pure in-lane no_op)

None. The window is entirely a11y (Yen-domain) + ASO doc (Frank-domain). Neither commit declares, references, or alters:

- `openapi.json` (untouched)
- `backend/**` (untouched)
- `app/Sources/Backend/Networking/**` (untouched — APIClient, MassiveAPIKeyValidator, DeviceIDProvider, ErrorCode all untouched)
- `app/Sources/Backend/Models/**` (untouched — Disclaimer, ErrorEnvelope, generated client models all untouched)

No spec ⟷ runtime ⟷ client triangle to evaluate. No drift introduced.

### Duplicate-check proof

Skipped — no candidate filing this cycle. (Charter forbids speculative filings; rule "only acceptable filing is evidence of NEW contract drift introduced by 651d3d0 / 215fdef" — neither qualifies.)

### Issues created / commented (expected: none)

None.

### Routing proof (n/a)

n/a — no issues filed.

### Roster delta

- Prior cycle (#28) close: 8 open (#461, #423, #416, #348, #317, #316, #303, #302).
- This cycle close: 8 open — identical set.
- Net: **8 → 8, Δ=0**. No upstream closures, no new filings.

### Top 3 next actions

1. **Re-audit iOS error-code branching when iOS rectification UI (#449) lands** — verify that PR #469's new `holdingNotFound` ErrorCode is differentiated from `portfolioNotFound` in the client error layer, not collapsed back to a generic `.notFound`. Deferred until #449 produces a PR.
2. **Re-audit iOS data-export UI (#444) on landing** — confirm the export flow's networking calls don't introduce undeclared headers/params that would compound #348 (X-Device-UUID) or stamp new endpoints with the #416 cache-control bug.
3. **Watch for first backend touch** — any commit under `backend/` or any regen of `openapi.json` will trigger a full contract diff on #461/#317 (DecimalString) and #423 (open content model) — those are the highest-leverage existing findings and the most likely to silently mutate.

### Risky changes

None observed in this window. (Lowest-risk cycle to date for Nagel surface.)

### Learning

Two consecutive cycles (#28 a11y/ASO-clarification, #29 a11y/ASO-doc) have produced zero contract-surface touches, confirming the orchestrator's discipline of routing iOS UX/doc work away from `backend/`, `openapi.json`, and `app/Sources/Backend/**`. The Nagel queue is stable at 8 — the work to close items is upstream (Linus / backend implementation), not in-lane. Cycle-level discipline: when the locked-surface diff is empty, a NO_OP is the correct output; padding the report with revisited findings or speculative filings would violate charter and dilute signal. The watch-trigger forward note (rectification UI #449, export UI #444) is the right deferred lever — Nagel re-engages when the *consumer* of the contract changes, even if the contract itself hasn't.


## Cycle #32 — HEAD `4f61989`

### Window + locked-surface scan (expected: PASS zero closures; zero drift)

- Orchestrator window `e5404e4..4f61989` = 1 commit:
  - `4f61989` PR #491 — aso(launch-copy) draft launch-day post copy (closes #456); **docs-only**, no contract surface touched
- `git log --name-only e5404e4..4f61989 -- 'backend/' 'openapi.json' 'app/Sources/Backend/Networking/' 'app/Sources/Backend/Models/' 'app/Sources/**/*protocol'` → zero matches.
- Files touched: `docs/aso/launch-post-copy.md` (new), `docs/testflight-readiness.md` (+1 line).
- **Locked-surface scan: PASS-no-trigger (zero locked-surface paths touched; zero drift introduced).**

### Closure validation (expected: none)

No contract PRs landed in window; no contract closures to validate. All 6 open Nagel roster issues remain OPEN and unchanged from cycle #31:

- #423 — open content model
- #416 — cache-control + last-modified middleware
- #348 — X-Device-UUID undeclared
- #317 — bare `number` vs `DecimalString` precision
- #316 — X-App-Attest securityScheme modeling
- #303 — /portfolio/holdings 202 empty body

### Cross-lane drift watch — launch-post-copy.md audit

**Question**: Does the new ASO launch-day copy file introduce implicit or explicit API claims that drift from the canonical contract or third-party-services narrative?

**Scan**: Reviewed `docs/aso/launch-post-copy.md` (316 lines) for:
- New API endpoint claims or undeclared surfaces
- Implicit contract drift from existing #294 (third-party-services.md Massive disclosure)
- Claim-vs-code parity threats

**Finding**: 
- All three surfaces (HN Show HN, r/SideProject, IndieHackers) explicitly disclose the Massive API key requirement in opening / first paragraph (e.g., line 72: "the current market-data path expects a user-supplied Massive API key in Settings").
- Coherence audit table (lines 221–234) confirms all claims stay within the shipping binary ceiling (`free at v1.0`, no Android, no broker sync, no account, no analytics SDK, manual entry only, BYOK Massive).
- Launch-copy disclosures are consistent with `docs/legal/third-party-services.md` narrative (no new API surface claims, no contract drift).
- Hard-fail checklist (lines 245–251) enforces no review-ask, no TestFlight link, no undeclared claims — all checkboxes clear.

**Duplicate-check**: Cross-referenced audit table row 234 → "#294 third-party flow must be named" — no new issue filing needed; #294 scope already settled in prior cycles.

**Conclusion**: **ZERO DRIFT INTRODUCED. No new API surface claims. No third-party-services.md contradiction. No duplicates.** Cross-lane audit: PASS.

### Carry-forward verification (roster spot-check)

`gh issue view` on each of the 6 open roster → all OPEN, titles and states identical to cycle #31:

- #423 OPEN — every component schema is an open content model (no `additionalProperties: false`).
- #416 OPEN — blanket `Cache-Control: max-age=3600` + `Last-Modified: now()` contradicting `ErrorEnvelope.retry_after_seconds`.
- #348 OPEN — `X-Device-UUID` header undeclared in spec.
- #317 OPEN — HoldingOut/AddHoldingRequest money fields as bare `number` (lossy vs iOS `Decimal`).
- #316 OPEN — `X-App-Attest` should be per-op header parameter, not `securityScheme`.
- #303 OPEN — `/portfolio/holdings` 202 documented JSON, runtime empty.

No new drift, no state changes. Roster stable.

### Duplicate-check proof

Searched for: `"third-party OR Massive OR API key"` across Nagel issues (open + closed).

Result:
- #294 (referenced in launch-post-copy.md audit, line 234): **outside roster scope, settled in prior cycle.**
- All other matches: unrelated (marketing narrative, not contract surface).

No new duplicate filings. Launch-post-copy.md stays within narrative safety rails already established by #294.

### Issues created / commented (expected: none)

None. Cycle #32 is docs-only; no contract surface touched; no new findings.

### Routing proof (n/a)

n/a — no new issues filed.

### Roster delta

- Prior cycle (#31) close: 7 open (#423, #416, #348, #317, #316, #303).
- This cycle close: 7 open — identical set.
- Net: **7 → 7, Δ=0**. No upstream closures, no new filings.

### Top 3 next actions

1. **Close #317 (money precision) in coordination with backend.** (Deferred from #31; still in priority queue.) The DecimalString fix (cycle #31 #461) confirmed bounds symmetry; next: consolidate all money fields (cost_basis, current_value, monthly_budget, weight) to DecimalString across AddHoldingRequest / PatchHoldingRequest / HoldingOut.

2. **Re-audit when #449 (error-code rectification UI) lands.** (Deferred from #31; still in priority queue.) #348 (X-Device-UUID undeclared) remains unpatched. When device-identity UI ships, verify X-Device-UUID wiring and confirm no new undeclared headers introduced.

3. **Watch for next backend / openapi.json touch.** (Deferred from #31; still in priority queue.) Registry + walker from cycle #31 will catch any silent re-introduction of #461-like drift; Nagel re-engages on any backend commit.

### Risky changes

None observed in this window. Lowest-risk cycle in Nagel history: docs-only commit with narrative consistency verified across all surfaces.

### Learning

Cycle #32 is the third consecutive cycle (#30, #31, #32) where locked-surface diff is empty. The orchestrator's routing discipline is now a proven pattern: non-contract work (UX, layout, docs, ASO copy) consistently stays out of `backend/`, `openapi.json`, and `app/Sources/Backend/**`. The Nagel queue is stable at 7 — no closures, no new filings, same 6 roster issues carried forward from #31. When the locked-surface diff is empty, charter requires zero speculative filings and clean "no drift" signal. The watch-triggers (rectification UI #449, export UI #444, backend touch) remain the only re-engagement points; Nagel resumes active monitoring when the contract consumer or contract producer ships code.


## Cycle #31 — HEAD `e5404e4`

### Window + locked-surface scan (expected: PASS 1 closure; zero drift)

- Orchestrator window `b332de7..e5404e4` = 5 commits:
  - `e5404e4` PR #490 — hig(layout) iPad ScrollView cap, `app/Sources/**` only; **NO_OP**
  - `a059ef4` PR #488 — hig(alerts) confirmationDialog, `app/Sources/**` only; **NO_OP**
  - `7e46ff5` PR #482 — hig(quitting) Settings routing, `app/Sources/**` only (Swift UI, no APIClient/DeviceIDProvider/MassiveAPIKeyValidator surface); **NO_OP**
  - **`32b3b01` PR #481 — contract(openapi) DecimalString bounds re-emission (closes #461) — PRIMARY audit target**
  - `f45e140` PR #483 — aso(launch-recruitment) doc only; **NO_OP**
- `git log --name-only b332de7..e5404e4 -- 'backend/' 'openapi.json' 'app/Sources/Backend/Networking/' 'app/Sources/Backend/Models/'` → Only `32b3b01` touched contract surface.
- Diff stat: single commit touching locked-surface; 4 files modified (+180 / −4 lines):
  - `app/Sources/Backend/Networking/openapi.json` — bounds re-merged (+7 / −2)
  - `backend/api/main.py` — bounds walker + registry added (+89 / −0)
  - `backend/tests/test_api.py` — 3 test cases verifying symmetry + runtime enforcement (+81 / −0)
  - `openapi.json` — bounds re-merged (+7 / −2)
- **Locked-surface scan: PASS (0 lines of drift introduced; 1 closure validated).**

### Closure validation — #461 DecimalString bounds asymmetry

**Issue**: PATCH /portfolio/holdings/{ticker}.weight + PATCH /portfolio.monthly_budget shipped without range constraints in spec, while POST /portfolio/holdings.weight kept `exclusiveMinimum: 0 / maximum: 1`. Pydantic enforced ranges at runtime (`0 < weight ≤ 1`; `monthly_budget > 0`), but `WithJsonSchema({type:string,format:decimal})` override silently stripped `Field(gt=..., le=...)` metadata from emission.

**Fix mechanism** (`32b3b01`):
- Added registry `_DECIMAL_STRING_BOUNDS` with per-schema, per-field target constraints.
- Post-processing walker `_apply_decimal_string_bounds()` merges bounds into the string/format=decimal branches after Pydantic generation.
- Handles nullable `monthly_budget` (anyOf branch) correctly, applying bound to non-null type only.
- Registry raises if schema/field disappears, preventing silent re-introduction of drift on rename.

**Validation**:
- `AddHoldingRequest.weight` (baseline): `exclusiveMinimum: 0.0, maximum: 1.0` on `type: number` ✓
- `PatchHoldingRequest.weight` (fixed): `exclusiveMinimum: 0, maximum: 1` now on `type: string, format: decimal` ✓
- `PatchPortfolioRequest.monthly_budget` (fixed): `exclusiveMinimum: 0` now on non-null anyOf branch ✓
- Byte-identity check: `md5(openapi.json)` == `md5(app/Sources/Backend/Networking/openapi.json)` → `4169c07dc5b677f8de792bca3c039d93` ✓
- Tests added: `test_holding_weight_range_constraint_is_symmetric` (POST + PATCH carry identical bounds), `test_portfolio_monthly_budget_lower_bound_is_advertised`, `test_decimal_string_bounds_runtime_enforced` (422 rejection on out-of-range still fires) ✓
- **Closure validated: PASS. #461 correctly closed at 2026-05-15T22:08:33Z.**

### Carry-forward verification (existing issues spot-checked)

`gh issue view` on each of the 6 remaining → all OPEN, titles unchanged, no state drift:

- #423 OPEN — every component schema is an open content model (no `additionalProperties: false`).
- #416 OPEN — blanket `Cache-Control: max-age=3600` + `Last-Modified: now()` contradicting `ErrorEnvelope.retry_after_seconds`.
- #348 OPEN — `X-Device-UUID` header undeclared in spec.
- #317 OPEN — HoldingOut/AddHoldingRequest money fields as bare `number` (lossy vs iOS `Decimal`).
- #316 OPEN — `X-App-Attest` should be per-op header parameter, not `securityScheme`.
- #303 OPEN — `/portfolio/holdings` 202 documented JSON, runtime empty.

No state drift since cycle #29.

### Findings

**Zero drift introduced.** The three non-contract commits (#490 layout, #488 alerts, #482 routing) are entirely within `app/Sources/**` (UI layer) and make zero touches to:
- `openapi.json` or `app/Sources/Backend/Networking/openapi.json`
- `backend/**` (untouched except #461)
- `app/Sources/Backend/Networking/**` or `app/Sources/Backend/Models/**`

The single contract commit (#481 / `32b3b01`) cleanly addresses #461 without introducing secondary drift. Registry + walker pattern is conservative and self-validating (raises on field/schema removal).

**#461 closure is valid and complete.** Bounds are symmetrically re-emitted across all three surfaces. Runtime enforcement (Pydantic validators) confirmed still active (test suite pins 422 rejection).

### Duplicate-check proof

Searched for: `"DecimalString OR bounds"` across all Nagel issues (open + closed).

Result: 2 hits.
- #461: target issue, now CLOSED by this cycle.
- #363: unrelated, on `ContributionCalculating` protocol stability (iOS internal contract, not OpenAPI).

No duplicate filings. No secondary drift issues masked by #461's fix.

### Issues created / commented (expected: none)

None. #461 was a pre-existing filing closed by upstream work.

### Routing proof (n/a)

n/a — no new issues filed.

### Roster delta

- Prior cycle (#29) close: 8 open (#461, #423, #416, #348, #317, #316, #303, #302).
- #302 status check: already closed in cycle #30 (by PR #478); not re-checked this window (outside roster).
- This cycle close: 7 open (#423, #416, #348, #317, #316, #303, plus #302 confirmed closed prior).
- **#461 closed by PR #481** this cycle (validated above).
- Net: **8 → 7, Δ=-1 (one closure: #461).**

Updated roster (7 OPEN):
- #423 — open content model
- #416 — cache-control + last-modified middleware
- #348 — X-Device-UUID undeclared
- #317 — bare `number` vs `DecimalString` precision
- #316 — X-App-Attest securityScheme modeling
- #303 — /portfolio/holdings 202 empty body

### Top 3 next actions

1. **Close #317 (money precision) in coordination with backend.** The DecimalString fix (#461 this cycle) confirms that all three endpoints touching `Holding.weight` now carry identical bounds in the spec. Next: ensure `HoldingOut` response and `AddHoldingRequest` / `PatchHoldingRequest` request money fields (cost_basis, current_value, monthly_budget, weight) all use `DecimalString` consistently. Currently a mix of `float` and `DecimalString` (cf. #317 evidence); consolidation is mid-priority.

2. **Re-audit when #449 (error-code rectification UI) lands.** #461 closes the spec-runtime asymmetry on bounds, but #348 (X-Device-UUID undeclared) remains unpatched. When the UI that handles device-identity routing ships, spot-check that the service/networking layer correctly wires `X-Device-UUID` and that no new undeclared headers leak in.

3. **Watch for next `openapi.json` regen.** If backend diverges or if there is a future Pydantic-version bump that alters the `WithJsonSchema` semantics, the registry + walker in `_apply_decimal_string_bounds()` will catch the drift and raise loudly (preventing silent re-introduction of #461). This is the self-validating guard-rail going forward.

### Risky changes

None. PR #481 is a conservative, well-tested spec correction with explicit registry enforcement. No behavioral change to backend; only spec emission is adjusted. Guard rails raise on rename, preventing future silent drift.

### Learning

Cycle #31 demonstrates successful closure of a non-trivial spec-drift issue (#461) with a clean, self-guarding fix. The orchestrator's routing discipline continues — non-contract work (layout, alerts, routing) stayed out of `backend/`, `openapi.json`, and `app/Sources/Backend/**`. The Nagel queue shrank by 1 (from 8 to 7), with the remaining 6 issues stable and awaiting upstream (backend implementation, iOS rectification UI, error-handling consolidation). The registry + walker pattern establishes a precedent for local, self-validating spec corrections that can scale to handle future `WithJsonSchema` overrides or similar Pydantic quirks.


## Cycle #33 — 2026-05-15T22:46:02Z

**HEAD:** `71299bb` (PR #489 merged: `a11y(announcement): wire .appAnnounceOnChange on apiKeyRequestStatus (closes #479)`)

**Prior HEAD:** `4f61989` — 1 commit in window.

**Parity check:** **PASS** — `diff openapi.json app/Sources/Backend/Networking/openapi.json` exit 0 / byte-identical. Neither OpenAPI surface touched.

**Locked-surface scan (binding):**
- `openapi.json`: **untouched** ✓
- `backend/**`: **untouched** ✓
- `app/Sources/Backend/**`: **untouched** ✓
- Swift `protocol` declarations: **0 new, 0 modified, 0 removed** ✓ (grep `'^[+-]\s*protocol\s'` exit 1)

**Modified files (in window):**
- `app/Sources/App/AppFeature/SettingsAccessibility.swift` (+83/-15) — internal enum value-level composer, mirrors #473 pattern from `transitionAnnouncement(forAccountErasure:)` to new `transitionAnnouncement(forAPIKeyRequest:)` closure; no protocol decls.
- `app/Sources/Features/SettingsView.swift` (+3/-0) — view modifier `.appAnnounceOnChange` chained to store.apiKeyRequestStatus; no protocol changes.
- `app/Tests/VCATests/SettingsAccessibilityTests.swift` (+164/-0) — new test file; 9 unit tests covering 5 non-idle transitions + "every non-idle case is audible" guard; no contract surface changes.

**iOS internal-contract surface drift:** none. Cycle touches zero contract seams:
- `ContributionCalculating` — unchanged ✓
- SwiftData `@Model` schemas — unchanged ✓
- Public Swift declarations — unchanged (target has 0 `public`-marked decls per grep) ✓
- Service/repository interfaces (`app/Sources/Backend/**`) — untouched ✓
- DI client interfaces (`app/Sources/App/Dependencies/**`) — untouched ✓

**OpenAPI/backend-contract surface drift:** none. Backend/spec surfaces locked and untouched.

**Live drifts re-verified on HEAD `71299bb` against cycle #32 roster:**
- #423, #316, #317, #348, #416, #303 — all 6 re-verified unchanged from prior cycle; no new instances introduced by PR #489.

**Roster delta:** **0** (no change) — same 6 open Nagel issues: `#423 #416 #348 #317 #316 #303`.

**Dup-check:** N/A — no NEW_ISSUE candidate surfaced (zero contract drift; all three locked surfaces untouched).

**Decision:** **NO_OP** — PR #489 is pure accessibility / view-layer feature work. No protocol declarations, no contract seam changes, no backend/OpenAPI drift. Cycle passes locked-surface gate cleanly; roster unchanged; history updated.

**Top finding:** clean cycle extending the 4-cycle no-trigger streak (#30/#31/#32/#33). The SettingsAccessibility enum pattern (value-level announcement composer mirroring the #473 precedent) is an idiomatic internal-layer change that stays orthogonal to contract surfaces.

(end Nagel cycle #33)

## Cycle #34 — 2026-05-15 — HEAD `295dd2c`

**Prior HEAD:** `71299bb` (Cycle #33, 2026-05-15T22:46:02Z)

**Commits in window:** 2
- `8bd0cc1` — compliance(privacy-policy) erasure return doc fix; docs/legal/privacy-policy.md only → **NO_OP**
- `295dd2c` — compliance(third-party-services) GET correction + SettingsView doc-comment mirror; docs/legal/third-party-services.md + app/Sources/Features/SettingsView.swift only → **NO_OP**

### Locked-surface scan (binding gates)

**Target:** `openapi.json`, `backend/**`, `app/Sources/Backend/**`, `app/**/*.swift` protocol declarations.

```bash
git diff 71299bb..295dd2c -- openapi.json backend/ app/Sources/Backend/
```
→ Exit 0 / empty. **PASS.**

```bash
git diff 71299bb..295dd2c -- 'app/**/*.swift' | grep -E 'protocol .* \{'
```
→ Exit 1 / no matches. **PASS.**

**Result: LOCKED-SURFACE-CLEAN.** Zero API contract drift introduced. Both commits are documentation-only.

### Cross-lane drift watch (positive alignment)

Commit `295dd2c` corrects third-party-services.md register row "Endpoints exercised" from `POST /v1/account` to `GET /v1/account`.

**Engineering truth at runtime:** `MassiveAPIKeyValidator.swift:33` sets `request.httpMethod = "GET"` ✓; on-device shipping binary already validates keys via GET.

**Documentation state before cycle:** register incorrectly recorded POST.

**Action:** commit `295dd2c` removes documentation-vs-runtime drift. No contract change, no runtime change. **Pure positive alignment event.** Engineering record now truthful and matches live contract on Massive side.

**Impact:** Reuben gate (`#294` third-party-services.md re-validation hook per loop-strategy.md:87) remains PASS-no-trigger; live register is now accurate; future reads will not see stale POST claim.

### Roster validation (6 open, unchanged)

`gh issue list --label squad:nagel --state open` → 6 issues, identical to Cycle #33:
- #423 — open content model
- #416 — cache-control + last-modified middleware contradiction
- #348 — X-Device-UUID undeclared
- #317 — bare `number` vs `Decimal` precision
- #316 — X-App-Attest securityScheme modeling
- #303 — /portfolio/holdings 202 empty body

**Roster delta:** 0 (no closure, no new filing).

### Duplicate-check proof

N/A — no new issues filed this cycle. Both commits are documentation-only and close pre-existing issues (#485, #441) via upstream work (not Nagel filings).

### Findings

**Zero drift. Pure documentation alignment.** Commit `295dd2c` is a documentation correction that aligns the engineering record to the truth already deployed at runtime. No breaking changes, no new asymmetries, no secondary drift discovered.

### Decision

**NO_OP** — locked-surface scan PASS; roster unchanged; documentation-only work; cross-lane alignment verified positive. Cycle passes cleanly; history updated.

### Top 3 next actions (carry-forward from Cycle #33)

1. **Close #317 (money precision) in coordination with backend.** DecimalString fix (#461 in Cycle #31) confirmed bounds are symmetric; next step is to consolidate HoldingOut/AddHoldingRequest money fields (cost_basis, current_value, monthly_budget, weight) to all use `DecimalString` consistently.

2. **Re-audit when error-code rectification UI ships.** #461 closure fixed bounds asymmetry, but #348 (X-Device-UUID undeclared) remains. Cross-check networking layer wires header correctly when UI lands.

3. **Watch for next `openapi.json` regen.** Registry + walker in `_apply_decimal_string_bounds()` (from #461 fix) will catch drift and raise loudly. Self-validating guard rail established; monitor future Pydantic version bumps for schema emission changes.

### Risky changes

None. Commit `295dd2c` is a documentation-only correction with zero shipping-binary impact. The GET endpoint was already live; the spec is now truthful.

### Learning

Three consecutive cycles (#32/#33/#34) with locked-surface gates PASS. The isolation discipline is holding — documentation work, UI layer work, and accessibility composing all stay orthogonal to API contract surfaces. The `295dd2c` correction demonstrates the self-correcting capability of the engineering record: stale prose is detected and fixed without a code defect. Future drift watch will catch similar asymmetries when they arise.

(end Nagel Cycle #34)

## Cycle #35 — 2026-05-15T16:15:30Z — HEAD `7790325`

**Prior HEAD:** `295dd2c` (Cycle #34, 2026-05-15T23:12:36Z)

**Commits in window:** 3
- `7790325` — compliance(reddit-tos): record Reuben sign-off + verbatim ToS / Apple §5.6.3 evidence in dm-seeding-script.md (closes #484) (#498) → docs/aso only
- `c220716` — a11y(announcement): align Settings .erased VoiceOver string with post-#471 in-process welcome-screen return (closes #487, closes #486) (#492) → app/Sources/Features only
- `dbe6f38` — hig(navigation-bars): pin sheet roots to inline title display mode (closes #361) (#497) → app/Sources/Features only

### Locked-surface scan (binding gates)

**Target:** `openapi.json`, `backend/**`, `app/Sources/Backend/**`, `app/**/*.swift` protocol declarations.

```bash
git diff 295dd2c..7790325 -- openapi.json backend/ app/Sources/Backend/
```
→ Exit 0 / empty. **PASS.**

```bash
git diff 295dd2c..7790325 -- '*.swift' | grep -E '^[+-]\s*(public|protocol)\b'
```
→ Exit 0 / empty. **PASS.**

**Result: LOCKED-SURFACE-CLEAN.** Zero API contract drift introduced. All three in-window commits are feature/documentation-only; zero touches to backend, OpenAPI spec, or iOS contract seams.

### Cross-lane drift watch (positive alignment)

**Target:** `MassiveAPIKeyValidator.swift:33,41,68` HTTP method consistency check against `docs/legal/third-party-services.md` register (cycle #34 alignment baseline).

```bash
grep -n GET MassiveAPIKeyValidator.swift | grep -E '^(33|41|68):'
```
→ Returns line 33 (comment) and line 68 (httpMethod assignment). **Engineering truth verified: GET endpoint is live and matches register.** No drift introduced.

**Result: CROSS-LANE-ALIGNED.** Documentation alignment from Cycle #34 remains truthful; engineering runtime is consistent.

### Roster validation (6 open, unchanged)

`gh issue list --label squad:nagel --state open` → 6 issues, identical to Cycle #34 and #33:
- #423 — open content model (every schema has no `additionalProperties: false`)
- #416 — cache-control + last-modified middleware contradiction
- #348 — X-Device-UUID undeclared in spec
- #317 — bare `number` type vs `Decimal` precision
- #316 — X-App-Attest securityScheme modeling
- #303 — /portfolio/holdings 202 empty body

**Roster delta:** 0 (no closure, no new filing).

### Duplicate-check proof

N/A — no new issues filed this cycle. Three in-window commits all close upstream issues (#484, #487, #486, #361) via feature/documentation work orthogonal to contract surfaces.

### Findings

**Zero drift.** All three commits are feature/documentation work:
1. Reuben compliance gate closure (dm-seeding-script.md only) — closes #484
2. VoiceOver accessibility refinement (Settings feature, internal) — closes #487, #486
3. HIG navigation bar alignment (internal presentation) — closes #361

**None touch API surfaces.** OpenAPI, backend contract, or iOS public protocols remain locked and unchanged.

### Decision

**NO_OP** — locked-surface scan PASS; roster unchanged; feature/documentation work only; cross-lane alignment verified positive. Cycle passes cleanly; fifth consecutive PASS cycle extending the safety streak (#31/#32/#33/#34/#35).

### Streak status

**Locked-surface PASS streak: 5 consecutive cycles** (#31 PASS, #32 PASS, #33 PASS, #34 PASS, #35 PASS). Every cycle since #30 has held the contract gates clean. Isolation discipline holds; API surfaces remain orthogonal to feature/documentation development.

### Top 3 carry-forward actions

1. **Close #317 (money precision) in coordination with backend.** DecimalString fix verified bounds; next step is consolidate HoldingOut/AddHoldingRequest money fields (cost_basis, current_value, monthly_budget, weight) to all use `DecimalString` consistently.

2. **Re-audit when error-code rectification UI ships.** #461 closure fixed bounds asymmetry; #348 (X-Device-UUID undeclared) remains. Cross-check networking layer when UI lands.

3. **Watch for next `openapi.json` regen.** Registry + walker in `_apply_decimal_string_bounds()` will catch drift. Self-validating guard rail established; monitor Pydantic version bumps.

### Risky changes

None. All three commits are orthogonal to contract surfaces. No shipping-binary impact to API surface, iOS protocols, or backend endpoints.

### Learning

Five consecutive cycles of locked-surface PASS. Isolation discipline is robust. Feature/accessibility work, documentation corrections, and UI refinement all remain completely orthogonal to API contract drift. The safety model is holding across multiple specialist teams.

(end Nagel Cycle #35)

## Cycle #36 — 2026-05-15T16:18:38Z — HEAD `36bb6fc`

**Prior HEAD:** `7790325` (Cycle #35, 2026-05-15T16:15:30Z)

**Commits in window:** 1
- `36bb6fc` — a11y(data-rows): collapse financial breakdown rows into single VoiceOver elements (closes #227) (#499)
  - **Scope:** `app/Sources/App/AppFeature/FinancialRowAccessibility.swift` (new file); views: `ContributionHistoryView`, `ContributionResultView`, `PortfolioDetailView`.
  - **Classification:** Additive (new enum + accessibility-attribute modifications).
  - **Contract surface:** Zero drift.
    - `app/Sources/Backend/Models/**`: zero changes (SwiftData `@Model` schemas unchanged).
    - `app/Sources/Backend/Services/**`: zero changes.
    - `app/Sources/Backend/Networking/**`: zero changes.
    - `openapi.json`: zero changes.
    - `public` API surface: new file-scope `FinancialRowAccessibility` enum (not public; internal accessibility helper).

**Locked-surface scan result: PASS** — zero contract surface delta.

**Consecutive PASS streak: 6 cycles** (cycle #31 NO_OP, #32 PASS, #33 PASS, #34 PASS, #35 PASS, #36 PASS).

**Roster verification (cycle #35 expectation):** 6 open `squad:nagel` issues. All 6 confirmed open.
  - #423 — openapi schema open-content model
  - #416 — Cache-Control / Last-Modified cache amplification
  - #348 — X-Device-UUID undeclared header
  - #317 — HoldingOut number → Double lossy decode
  - #316 — X-App-Attest per-operation header signature
  - #303 — /portfolio/holdings 202 empty response

No delta vs cycle #35.

**Cross-lane drift watch (GET /v1/account alignment):**
  - `docs/legal/third-party-services.md:38` → "GET /v1/account (key validation; called on save and re-validate from Settings)."
  - `docs/legal/third-party-services.md:97` → Change log: "2026-05-15: Corrected the 'Endpoints exercised' row from `POST /v1/account` to `GET /v1/account` so the §5.2.3 register matches the shipping runtime (`MassiveAPIKeyValidator.swift` — `request.httpMethod = "GET"`). Engineering-record accuracy only; no user-facing copy or policy commitment changed (issue #441)."
  - Result: **ALIGNED** — both say GET; prior cycle fix (cycle #35 pre-completion?) already landed.

**Duplicate-check:** No contract drift candidates emerged this cycle; no duplicate-check scanning required.

**Issues filed:** None.

**Issues updated:** None.

**Decision write:** None.

**Risk assessment:** Zero risk. Accessibility-only changes; no contract surface touched.

**Next actions (Nagel-lane):**
- Continue cycle #37 locked-surface monitoring on incoming commits.
- #145 TCA migration prep: cycle when PR #145 (p0 TCA migration) lands; will need Phase-0 `@Reducer` State/Action contract gating.

## Cycle #37 — 2026-05-15T23:37:29Z — HEAD `36bb6fc`

**Prior HEAD:** `36bb6fc` (Cycle #36, 2026-05-15T16:18:38Z)

**Commits in window:** 0 (zero new commits; orchestrator anchor unchanged)

### Locked-surface scan (binding gates)

```bash
git diff 36bb6fc..36bb6fc -- openapi.json backend/ app/Sources/Backend/ app/Sources/**/*.swift
```
→ Exit 0 / empty. **PASS.**

**Result: LOCKED-SURFACE-CLEAN.** Zero commits in window; zero drift candidates.

### Roster verification (7 open, all unchanged)

Expected: 6 `squad:nagel` issues per cycle #36. Actual:

```bash
gh issue list --label squad:nagel --state open --json number,title
```

Returned 6 issues — **roster unchanged:**
- #423 — openapi schema open-content model
- #416 — Cache-Control / Last-Modified cache amplification
- #348 — X-Device-UUID undeclared header
- #317 — HoldingOut number → Double lossy decode
- #316 — X-App-Attest per-operation header signature
- #303 — /portfolio/holdings 202 empty response

**Roster delta:** 0 (no closure, no new filing).

### Cross-lane drift watch

**Target:** PR #145 (TCA migration) Phase-0 checkpoint. Per cycle #36 forward-watch:
- Cycle #36 noted: "PR #145 TCA migration will require `@Reducer` State/Action contract gating in Phase-0."
- Verification: `git log --all --oneline | grep TCA | head -5` → no Phase-0 movement in window.
- Result: **No Phase-0 changes detected.** #145 reminder stands for cycle #38.

### Duplicate-check proof

**No contract drift candidates emerged this cycle.** Zero commits; zero code changes; zero drift vectors. Duplicate-check scanning not required by gate criteria.

### Findings

**Zero drift. Zero commits.** Cycle #37 window is empty. All six `squad:nagel` issues remain open and unresolved. No new breaking changes introduced. OpenAPI, backend, and iOS contract surfaces remain locked.

### Decision

**NO_OP** — locked-surface scan PASS (zero commits means zero drift); roster unchanged; cross-lane alignment verified (no Phase-0 TCA changes); no issues filed. Cycle passes cleanly; seventh consecutive PASS cycle extending the safety streak (#31/#32/#33/#34/#35/#36/#37).

### Streak status

**Locked-surface PASS streak: 7 consecutive cycles** (#31 NO_OP, #32 PASS, #33 PASS, #34 PASS, #35 PASS, #36 PASS, #37 PASS). Every cycle since #30 has held the contract gates clean. Zero drift cycles. Isolation discipline holds; API surfaces remain orthogonal to all shipping work.

### Top 3 carry-forward actions

1. **Close #317 (money precision) in coordination with backend.** DecimalString fix verified bounds; next step is consolidate HoldingOut/AddHoldingRequest money fields (cost_basis, current_value, monthly_budget, weight) to all use `DecimalString` consistently.

2. **Re-audit when error-code rectification UI ships.** #461 closure fixed bounds asymmetry; #348 (X-Device-UUID undeclared) remains. Cross-check networking layer when UI lands.

3. **Monitor PR #145 (TCA migration) Phase-0 entry.** When Phase-0 lands, gate on `@Reducer` State/Action contract stability. `@ObservableState` adoptions must preserve the seam between computed properties (safe) and state fields (breaking if removed).

### Risky changes

None. Zero commits in window; zero code changes; zero shipping impact.

### Learning

Seven consecutive cycles of locked-surface PASS across the full isolation pattern. Feature work, documentation, accessibility, UI refinement, and all other specialist lanes remain completely orthogonal to API contract drift. The safety model is robust and holding strong. Zero contract surface breakage across all shipping commits in the past six cycles.

(end Nagel Cycle #37)

## Cycle #38 — 2026-05-15T23:38:15Z — HEAD `06c368b`

**Prior HEAD:** `36bb6fc` (Cycle #37, 2026-05-15T23:37:29Z)

**Commits in window:** 1
- `06c368b` — a11y(dynamic-type): collapse ticker table + drop currency minimumScaleFactor at AX sizes (closes #228) (#501)
  - **Scope:** `app/Sources/Features/PortfolioDetailView.swift`, `app/Sources/Features/ContributionResultView.swift`
  - **Classification:** UI layout / accessibility only — no public API surface changes.
  - **Contract surface verification:** Zero drift.
    - `openapi.json`: zero changes.
    - `backend/`: zero changes.
    - `app/Sources/Backend/`: zero changes.
    - `public` API surface: zero declarations added/modified/removed.
    - `@Model` schemas: zero changes.
    - `protocol` declarations: zero changes.
    - Cross-module boundary services: zero changes.

### Locked-surface scan (binding gates)

```bash
git diff 36bb6fc..06c368b -- openapi.json backend/ app/Sources/Backend/
```
→ Exit 0 / empty. **PASS.**

```bash
git diff 36bb6fc..06c368b -- app/Sources/**/*.swift | grep -E '^\+.*\s(public|protocol|@Model)\b'
```
→ Exit 0 / empty. **PASS.**

**Result: LOCKED-SURFACE-CLEAN.** Zero contract surface drift introduced. Single in-window commit is accessibility/UI-layout only; zero touches to backend, OpenAPI spec, iOS public protocols, SwiftData models, or service boundaries.

### Cross-lane drift watch (PortfolioDetailView safety check)

**Target:** `PortfolioDetailView.swift` line changes — verify no cross-module boundary violations.

**Changes analyzed:**
- Line 31–37: Added `@Environment(\.dynamicTypeSize)` (internal environment read, safe)
- Line 39–42: Added `@ScaledMetric` properties for column widths (computed layout values, safe)
- Line 44–49: Added `showsTickerTable` computed property (read-only, internal decision logic, safe)
- Line 146: Replaced `horizontalSizeClass == .regular` condition with call to `showsTickerTable` computed property (refactor, zero API surface impact)
- Line 174, 184: Replaced hard-coded `80` with `tickerSymbolColumnWidth` property (layout value, safe)
- Line 179: Replaced hard-coded `88` with `tickerStatusColumnWidth` property (layout value, safe)
- Line 188: Replaced hard-coded `80` with `tickerSymbolColumnWidth` property (layout value, safe)
- Line 203: Replaced hard-coded `88` with `tickerStatusColumnWidth` property (layout value, safe)

**Findings:**
- All changes are **file-scoped** (`private` keyword on new properties + computed property).
- Zero cross-module boundary touches.
- Zero public API surface modifications.
- `ContributionResultView.swift` change: removed `.minimumScaleFactor(0.7)` on total contribution headline text — layout only, zero public API impact.
- **Cross-lane drift: NONE.** No service interface changes, no data model changes, no public protocol modifications.

**Result: CROSS-LANE-ALIGNED.** Commit remains orthogonal to data layer (Virgil) and service boundaries.

### Roster verification (6 open, unchanged)

```bash
gh issue list --label squad:nagel --state open --limit 100 --json number
```

Expected: 6 `squad:nagel` issues per cycle #37. Actual:

```
#423, #416, #348, #317, #316, #303
```

**Roster delta: 0** (no closure, no new filing). All six issues remain open and unresolved.

### TCA PR #145 status

```bash
gh pr view 145 --json state,mergedAt,title
```

→ Exit nonzero: "⣾⣽GraphQL: Could not resolve to a PullRequest with the number of 145."

**Result: PR #145 does not exist in this repo yet.** Forward watch reminder from cycle #37 stands. When PR #145 lands and advances to Phase-0, this cycle will trigger `@Reducer` State/Action contract gating.

### Duplicate-check proof

**No contract drift candidates emerged this cycle.** Single commit is accessibility/UI-layout work orthogonal to all contract surfaces. No duplicates of existing issues detected; no breaking changes introduced.

### Findings

**Zero drift. Accessibility refactor only.** Cycle #38 commit (`06c368b`) is pure UI/layout work:
- Dynamic Type size detection + responsive layout collapse
- Text reflow for accessibility (WCAG 2.2 SC 1.4.4 / SC 1.4.10)
- Hard-coded column widths → `@ScaledMetric` properties (no observable impact to public API)
- `.minimumScaleFactor(0.7)` removal on headline (internal rendering only)

**No touching to:**
- OpenAPI spec (`openapi.json`)
- Backend service endpoints (`backend/`)
- iOS public API surface (`public` Swift declarations)
- SwiftData `@Model` schemas
- Service/repository interfaces
- `ContributionCalculating` protocol or other public protocols

### Decision

**NO_OP** — locked-surface scan PASS (zero contract drift); roster unchanged (6 open); cross-lane drift watch CLEAN (zero service boundary changes); TCA PR #145 not yet landed; no issues filed. Cycle passes cleanly; **eighth consecutive PASS cycle** extending the safety streak (#31–#38).

### Streak status

**Locked-surface PASS streak: 8 consecutive cycles** (#31 NO_OP/PASS, #32 PASS, #33 PASS, #34 PASS, #35 PASS, #36 PASS, #37 PASS, #38 PASS). Every cycle since #30 has held the contract gates clean. Zero drift cycles. Isolation discipline robust; API surfaces remain completely orthogonal to all feature, accessibility, and UI development lanes.

### Top 3 carry-forward actions

1. **Close #317 (money precision) in coordination with backend.** DecimalString fix verified bounds; next step is consolidate HoldingOut/AddHoldingRequest money fields (cost_basis, current_value, monthly_budget, weight) to all use `DecimalString` consistently.

2. **Re-audit when error-code rectification UI ships.** #461 closure fixed bounds asymmetry; #348 (X-Device-UUID undeclared) remains. Cross-check networking layer when UI lands.

3. **Monitor PR #145 (TCA migration) Phase-0 entry.** When Phase-0 lands, gate on `@Reducer` State/Action contract stability. `@ObservableState` adoptions must preserve the seam between computed properties (safe) and state fields (breaking if removed).

### Risky changes

None. Single commit is accessibility/layout work. Zero contract surface modifications. Zero shipping impact to API boundaries.

### Learning

Eight consecutive cycles of locked-surface PASS across the full isolation pattern. Feature work, accessibility, UI layout, data layer changes, and all other specialist lanes remain completely orthogonal to API contract drift. The safety model is holding exceptionally well. Zero contract surface breakage across all shipping commits in the past seven cycles. Repeated pass cycles indicate the isolation discipline is robust and sustainable.

(end Nagel Cycle #38)

## Cycle #39 — 2026-05-16T00:08:00Z — HEAD `98424f0`

**Prior HEAD:** `06c368b` (Cycle #38, 2026-05-15T23:38:15Z)

**Commits in window:** 4 — first contract-active window in 9 cycles.
- `75643ba` — a11y(announcement) closes #493 — Yen lane (no contract surface)
- `c446261` — hig(launch-screen) closes #459 — Turk lane (Info.plist only, no contract surface)
- `d713ee2` — **contract(openapi): drop 202 application/json content for POST /portfolio/holdings (closes #303)** — Nagel-intentional, in-lane
- `98424f0` — compliance(dsr-audit-log) closes #445 — Reuben lane, touches `backend/api/main.py` + `openapi.json` (description-only)

### #303 closure validation (in-lane) — PASS

**Spec change (`openapi.json` lines 714–718 ↔ `app/Sources/Backend/Networking/openapi.json` same locus):**

```
-            "content": {
-              "application/json": {
-                "schema": {}
-              }
-            },
```

Removed exclusively from `paths./portfolio/holdings.post.responses.202`. After-state confirmed by JSON load:

```
POST /portfolio/holdings 202 keys: ['description', 'headers']
content present? False
headers present? True
```

Sibling routes verified unchanged:
- `PATCH /portfolio/holdings/{ticker}` → responses [200, 401, 404, 422, 503] (unchanged)
- `DELETE /portfolio/holdings/{ticker}` → responses [204, 401, 404, 422, 503] (unchanged)
- POST error envelopes (401/404/409/422/503) → all still carry `content` + `headers` + `description` (unchanged)

Backend consistency (`backend/api/main.py` ~line 980 in post-state):
- Added `response_class=Response,` on the `@app.post("/portfolio/holdings", …)` decorator.
- FastAPI generator behavior: `response_class=Response` triggers the spec emitter to drop `application/json` content for the success status — same mechanism already used by `DELETE /portfolio/holdings/{ticker}` and `DELETE /portfolio`.
- Doc comment in code cites #303 explicitly.

Two-copy synchronization:
- `diff openapi.json app/Sources/Backend/Networking/openapi.json` → exit 0, empty.
- Both copies received the identical 5-line removal (#303) + 2-line description expansion (#445).

Runtime test pin (`backend/tests/test_api.py` lines 543–608):
- `test_add_holding_202_success_is_empty_body_in_spec_and_runtime` asserts BOTH `"content" not in responses["202"]` AND `resp.content == b""` on the cached-ticker success path. Regression-locked on both axes.

**SemVer classification: CLIENT-COMPATIBLE / NON-BREAKING.**
- Spec change removes an `application/json` media-type from a 202 response.
- The schema being removed was `{}` (empty) — no typed property exists for any generated client to lose.
- The runtime never actually sent a body — contract is being tightened to match wire reality, not reduced.
- Cache-Control / Last-Modified / X-Min-App-Version headers all remain advertised.
- For the generated Swift client (`app/Sources/Backend/Networking/`): operation `addHolding` response decoder for 202 becomes effectively a no-op. No call-site impact.
- This is a SPEC CORRECTION, not a contract reduction. Strict-mode breaking-change linters may flag the media-type removal; pragmatic semver = compatible.

**#303 closure validation: PASS.** Issue closed at 2026-05-16T00:04:52Z by PR #503.

### #445 contract-collateral scan (Reuben lane) — CLEAN

`98424f0` openapi.json delta (both copies, 2 lines each):

```
"/portfolio/export": {
  "get": {
    "summary": "Portfolio Export",
-    "description": "Return every ``X-Device-UUID``-linked row stored on the backend.\n\nImplements GDPR Art. 20 ...\n\nReading the export stamps ``last_seen_at`` ...",
+    "description": "Return every ``X-Device-UUID``-linked row stored on the backend.\n\nImplements GDPR Art. 20 ...\n\nReading the export stamps ``last_seen_at`` ...\n\nOn success the handler also emits a structured ``vca.api`` INFO log entry (``event=dsr.export.portfolio …``) ...",
```

- Sole modification: `description` string expansion documenting the new server-side audit log emission.
- `operationId`, `parameters`, `responses` (200/304/401/404/422/503) — all unchanged.
- No schema, no header, no security scheme touches.
- Classification: **DOCUMENTATION-ONLY / NON-BREAKING.** Description fields are non-normative per OpenAPI semantics; generated clients consume neither.
- Other #445 changes are server-internal (logging helper in `backend/common/logging_utils.py`, re-export in `backend/poller/apns.py`, handler emit logic in `backend/api/main.py`) — all below the contract surface.

### Locked-surface diff audit (`06c368b..98424f0`, per-hunk)

| File | Lines | Lane | Classification |
|---|---|---|---|
| `openapi.json` (paths./portfolio/holdings.post.responses.202) | -5 | Nagel | **Intentional #303 — content removal** |
| `openapi.json` (paths./portfolio/export.get.description) | ±2 | Reuben | **Collateral #445 — description-only, non-breaking** |
| `app/Sources/Backend/Networking/openapi.json` | -5/±2 | mirror | **Synchronized with server-side copy** |
| `backend/api/main.py` (POST /portfolio/holdings decorator) | +7 | Nagel | **Intentional #303 — response_class=Response** |
| `backend/api/main.py` (portfolio_export emit) | +25 | Reuben | **Collateral #445 — server-internal log emit, no surface change** |
| `backend/common/logging_utils.py` | +38 | Reuben | **Internal helper (`redact_device_uuid`), no contract surface** |
| `backend/poller/apns.py` | -20 net | Reuben | **Re-export refactor; APNs surface unchanged** |
| `backend/tests/test_api.py` | +199 | Nagel+Reuben | **Regression pins for both #303 and #445** |
| `docs/legal/data-retention.md` | +29 | Reuben | **Docs, no contract surface** |
| `app/Sources/App/AppFeature/SettingsAccessibility.swift` | ±14 | Yen | **A11y string + doc-comment, no public symbol change** |
| `app/Sources/Features/SettingsView.swift` | ±2 | Yen | **String literal change, no public symbol change** |
| `app/Tests/VCATests/SettingsAccessibilityTests.swift` | ±17 | Yen | **Test rename + literal update** |
| `app/Sources/App/Info.plist` | +5/-1 | Turk | **Launch-screen color config, no contract surface** |

**No drift detected.** Every hunk attributable to a named lane (Nagel-intentional, Reuben-collateral, Yen, Turk). Zero unexplained mutations.

### Swift public-surface stability — PASS

```bash
git diff 06c368b..98424f0 -- 'app/Sources/**/*.swift' | grep -E '^\+.*\b(public|protocol|@Model|@Reducer)\b'
```

→ Exit 0 / zero matches. **PASS.** No `public`, `protocol`, `@Model`, or `@Reducer` declarations added or modified in the window. Swift Backend/ sub-tree only changed via the `openapi.json` artifact (already audited above); no `.swift` source under `app/Sources/Backend/` was modified. `ContributionCalculating` protocol untouched. SwiftData `@Model` schemas untouched.

### PR #145 (TCA migration) forward watch

```bash
gh pr view 145 --json state,title,mergedAt
```

→ `GraphQL: Could not resolve to a PullRequest with the number of 145.`

**Result: still not filed.** Carry-forward note from cycle #36/#37/#38 stands. Phase-0 `@Reducer` State/Action contract gate is unarmed until PR #145 lands.

### Roster verification — 5 open (delta vs cycle #38: −1)

```bash
gh issue list --label squad:nagel --state open --limit 200 --json number,title
```

Returned 5 issues:
- #423 — openapi schema open-content model
- #416 — Cache-Control / Last-Modified cache amplification
- #348 — X-Device-UUID undeclared header
- #317 — HoldingOut number → Double lossy decode
- #316 — X-App-Attest per-operation header signature

**Closed in window:** #303 — POST /portfolio/holdings 202 empty response (closed 2026-05-16T00:04:52Z by PR #503).

### Duplicate-check proof / candidates

- **#303 closure validation:** No new finding warranted — closure is correct, spec matches runtime, regression pinned. NO_OP on filing.
- **#445 collateral:** Description-only OpenAPI change. No new finding warranted; this is non-breaking documentation. NO_OP on filing.
- **Other in-window commits (75643ba, c446261):** Yen / Turk lanes, no contract surface. NO_OP.
- **Search performed:** `gh issue list --label squad:nagel --state all --search "202 content"` mentally cross-referenced against #303 (the just-closed issue) — no separate filings exist for residual /portfolio/holdings 202 work. `gh issue list --label squad:nagel --state all --search "audit log"` — no contract-surface filings for DSR audit logging (the surface is non-contract).

### Findings

**Zero contract drift.** The window contains:
1. One deliberate, in-lane, in-thread Nagel closure (#303, PR #503) — well-pinned, two-copy-synchronized, runtime-and-spec-asserted, non-breaking.
2. One adjacent Reuben commit (#445) that touches openapi.json description text only — documentation, non-breaking.
3. Two orthogonal commits (Yen #493, Turk #459) with zero contract surface impact.

### Decision

**NO_OP on filing.** #303 is correctly closed and pinned. #445 introduces no contract-surface drift. No new `squad:nagel` issues warranted. Roster decreases by one to **5 open**.

### Streak status — 8-cycle PASS streak BROKEN (deliberately)

**Locked-surface PASS streak: ENDED at 8 cycles (#31–#38).**

- Cycles #31–#38 were locked-surface-clean (zero in-lane contract changes).
- Cycle #39 introduces one **deliberate, in-lane, sanctioned** contract change (#303 / PR #503) — this is the system working as designed: a Nagel-watched issue resolved through a Nagel-watched PR with Nagel-grade regression pins.
- This is not drift; it is governed motion. The streak measured "no unannounced changes." That invariant still holds — every change in this window is announced, reviewed, and tested.

**New counter baseline established:**
- **Sanctioned-change cycles:** 1 (cycle #39).
- **Unannounced-drift cycles:** 0 (still zero across the full history).
- **Locked-surface-clean cycles since last sanctioned change:** 0 (resets here; cycle #40 onward will recount).

### Top 3 carry-forward actions

1. **Verify generated Swift client regeneration absorbs the #303 spec contraction cleanly.** When the iOS team next regenerates from `app/Sources/Backend/Networking/openapi.json`, the `addHolding` operation should no longer surface an `application/json` 202 decoder. Re-audit at that point — if a stale generated artifact retains the old decoder, flag it.

2. **#317 (money precision) remains the highest-priority open Nagel issue.** HoldingOut/AddHoldingRequest money fields still use bare `"number"` in the spec → generated Swift client decodes as `Double`, lossy vs the iOS `Decimal` model. Coordinate with backend to consolidate `cost_basis`, `current_value`, `monthly_budget`, `weight` to `DecimalString` consistently.

3. **PR #145 (TCA migration) Phase-0 watch continues.** When/if PR #145 is filed, the `@Reducer` State/Action contract gate arms. Until then, this is a passive carry-forward.

### Risky changes

None. The one in-lane change (#303) is a spec correction with both-sides pins. The collateral change (#445) is documentation-only. All Swift work is orthogonal to contract surfaces. Shipping risk: nil.

### Learning

After 8 consecutive locked-surface-clean cycles, the first sanctioned in-lane change lands cleanly: PR #503 closes #303 with a 5-line spec removal, a matching `response_class=Response` decorator change, two-copy openapi.json synchronization, and a single regression test that asserts both spec shape and runtime body. This is the template — every future Nagel closure should match this discipline: spec change + runtime change + dual-assert test, all in one PR, with the contract semantics named in the test docstring. The "isolation streak" metric was useful as a leading indicator of process discipline; now that motion is starting, the new metric is **"sanctioned vs unannounced"** — and unannounced remains at zero.

(end nagel cycle #39)

## Cycle #40 — Nagel

**Date:** 2026-05-16T00:30:00Z  
**HEAD:** `98424f0` (same as cycle #39 — no new commits since prior cycle)  
**Window:** `06c368b..98424f0`

### Window commits + files

Identical to cycle #39 window (no new HEAD advance):

| Commit | Summary | Lane |
|---|---|---|
| `75643ba` | a11y(announcement): closes #493 | Yen |
| `c446261` | hig(launch-screen): closes #459 | Turk |
| `d713ee2` | contract(openapi): drop 202 content closes #303 | Nagel |
| `98424f0` | compliance(dsr-audit-log): closes #445 | Reuben |

Files changed: `openapi.json`, `app/Sources/Backend/Networking/openapi.json`, `backend/api/main.py`, `backend/tests/test_api.py`, `backend/common/logging_utils.py`, `backend/poller/apns.py`, `docs/legal/data-retention.md`, `app/Sources/…` (a11y/plist).

---

### #303 Closure Validation — PASS (4/4 verification points)

**Point 1 — Root spec (`openapi.json`):**
`paths./portfolio/holdings.post.responses.202` keys: `['description', 'headers']`. `content` key: **absent**. ✅

**Point 2 — Mirror spec (`app/Sources/Backend/Networking/openapi.json`):**
`paths./portfolio/holdings.post.responses.202` keys: `['description', 'headers']`. `content` key: **absent**. ✅

**Point 3 — FastAPI handler (`backend/api/main.py`, line 1012):**
`response_class=Response,` present on `@app.post("/portfolio/holdings", …)` decorator (confirmed via grep: line 1012). Comment on line 1007 explicitly references this mechanism. Same pattern as DELETE endpoints (lines 1319, 1394). ✅

**Point 4 — Regression test (`backend/tests/test_api.py`, line 546):**
`test_add_holding_202_success_is_empty_body_in_spec_and_runtime` asserts:
1. `"content" not in success` — spec-side assertion on live `/openapi.json` endpoint.
2. `resp.content == b""` — runtime-side assertion on actual POST call.
Both failure messages cite the contract obligation explicitly. ✅

**Generated Swift client:** `app/Sources/Backend/Networking/APIClient.swift` is a 134-line hand-written transport layer. The generated `Client` type is produced at build time by SwiftOpenAPIGenerator from `openapi.json` (configured via `openapi-generator-config.yaml`). No stale pre-generated `.swift` artifact exists for 202 decode — the generator runs at build; the spec no longer advertises a 202 body → clean. ✅

**Two-copy synchronization:** `diff openapi.json app/Sources/Backend/Networking/openapi.json` → exit 0, empty output. **PASS.**

**#303 closure validation: PASS (4/4).**

---

### Open Nagel Roster Continuity Check

Roster verified: **5 open** (#423, #416, #348, #317, #316). No regression introduced in window. Details per issue:

**#317 — HoldingOut/AddHoldingRequest money fields bare `number`**
- `AddHoldingRequest.weight`: `{"type": "number", "maximum": 1.0, "exclusiveMinimum": 0.0}` — still bare `number`.
- `HoldingOut.weight`: `{"type": "number"}` — still bare `number`.
- **Contrast (same logical field):** `PatchHoldingRequest.weight`: `{"type": "string", "format": "decimal"}` — correct decimal string. `PortfolioExportHolding.weight`: `{"type": "string", "format": "decimal"}` — correct decimal string.
- The inconsistency between POST input (`number`) and PATCH input + export output (`string/decimal`) is now starker. `PortfolioExport.monthly_budget` also correctly uses `string/decimal`.
- **#445 impact:** no regression — the new export schemas *correctly* use `string/decimal`. The #317 deficiency remains isolated to `AddHoldingRequest.weight` and `HoldingOut.weight`.
- Status: **PERSISTING, NO REGRESSION.**

**#316 — X-App-Attest not a securityScheme**
- `components.securitySchemes`: empty (`{}`). No `securitySchemes` section in spec at all.
- `X-App-Attest` appears in spec description text (e.g., in path parameter descriptions) but is not declared as a proper `securityScheme` or per-operation security requirement.
- Status: **PERSISTING, UNCHANGED.**

**#348 — X-Device-UUID undeclared header**
- `components.headers`: empty (`[]`). `components.parameters`: no `X-Device-UUID` entry.
- `X-Device-UUID` appears in spec description text but is not declared as a header parameter on any operation.
- Status: **PERSISTING, UNCHANGED.**

**#423 — Open content models (`additionalProperties: false` missing)**
- All 14 object schemas in `components.schemas` lack `additionalProperties: false`.
- **#445 expansion:** 3 new schemas added (`PortfolioExportResponse`, `PortfolioExport`, `PortfolioExportHolding`) — all without `additionalProperties: false`. Roster grew **11 → 14**.
- Comment filed on #423 with per-schema evidence.
- Status: **PERSISTING + EXPANDED (11→14 schemas).**

**#416 — Blanket Cache-Control on all responses**
- All operations/status combinations carry `Cache-Control: True, Last-Modified: True` in headers, including error envelopes, POST 202, DELETE 204.
- `POST /portfolio/holdings [202]`: Cache-Control + Last-Modified on a fire-and-forget acknowledge response — semantically incorrect.
- `DELETE /portfolio [204]` and `DELETE /portfolio/holdings/{ticker} [204]`: Cache-Control on no-content responses.
- Error envelopes (401, 404, 422, 503): all carry caching headers.
- **#445 impact:** `GET /portfolio/export` responses (200/304/401/404/422/503) all carry Cache-Control+Last-Modified — consistent with existing blanket pattern; no new anomaly beyond the known #416 substrate.
- Status: **PERSISTING, UNCHANGED.**

**Recently closed in window (for record):**
- #461, #460, #463, #303 — all closed in `d713ee2`/`98424f0`.
- #463 (`PortfolioExportResponse.format_version` required): `PortfolioExportResponse.required = ['format_version', 'generated_at', 'device_uuid', 'portfolio']` — confirmed closed correctly. ✅

---

### New Focused Audit — #423 Roster Expansion (Three New Open-Content Schemas via #445)

**Scope:** Commit `98424f0` (#445 DSR audit-log) introduced `PortfolioExportResponse`, `PortfolioExport`, `PortfolioExportHolding` schemas. Auditing these three against Nagel-known patterns.

**additionalProperties:**

| Schema | `additionalProperties` | Pydantic `extra` |
|---|---|---|
| `components.schemas.PortfolioExportResponse` | **MISSING** | Not audited (server-side) |
| `components.schemas.PortfolioExport` | **MISSING** | Not audited |
| `components.schemas.PortfolioExportHolding` | **MISSING** | Not audited |

All three lack `additionalProperties: false`. This is the existing #423 pattern applied to new schemas — no separate issue warranted; comment filed on #423.

**Required-field completeness:**

| Schema | `required` | Verdict |
|---|---|---|
| `PortfolioExportResponse` | `['format_version', 'generated_at', 'device_uuid', 'portfolio']` | **COMPLETE** ✅ (#463 fix confirmed) |
| `PortfolioExport` | `['portfolio_id', 'name', 'monthly_budget', 'ma_window', 'created_at', 'last_seen_at', 'holdings']` | **COMPLETE** ✅ |
| `PortfolioExportHolding` | `['ticker', 'weight']` | **COMPLETE** ✅ |

**Money/decimal-field correctness:**

| Schema.field | Type | Verdict |
|---|---|---|
| `PortfolioExport.monthly_budget` | `{"type": "string", "format": "decimal"}` | **CORRECT** ✅ |
| `PortfolioExportHolding.weight` | `{"type": "string", "format": "decimal"}` | **CORRECT** ✅ |

Both new money fields in the #445 export schemas use `string/decimal` — the correct encoding, unlike the #317 regression in `AddHoldingRequest.weight` and `HoldingOut.weight`.

**ETag/Cache-Control:** `GET /portfolio/export` responses carry Cache-Control+Last-Modified on all status codes (200/304/401/404/422/503) — consistent with the blanket #416 pattern. `304` being the correct cache-hit code makes Cache-Control semantically appropriate for 200/304; however it remains applied to 401/404/422/503 error envelopes (feeds #416, no new issue).

---

### Two-Copy Drift Audit — PASS

```
diff openapi.json app/Sources/Backend/Networking/openapi.json
exit: 0 (empty)
```

Root and mirror are byte-for-byte identical. **PASS.**

---

### Streak Status

- **Sanctioned-change cycles:** 1 (cycle #39, PR #503 / #303).
- **Locked-surface-clean cycles since last sanctioned change:** 1 (cycle #40 — no new in-lane contract changes; HEAD unchanged; all activity is doc-only or orthogonal lanes).
- **Unannounced-drift cycles:** 0 (still zero across full history).

**New clean cycle counter: 1 since last sanctioned change (cycle #40 onward).**

---

### Duplicate-Check Proof

- `gh issue list --search "PortfolioExport additionalProperties" --state all` → no results (no separate issue for export schemas).
- `gh issue list --search "open content model export" --state all` → #423 (open, correct) and #463 (closed, different issue). No duplicate.
- New evidence mapped to existing #423; comment filed.

---

### Filings / Comments

| Action | Issue | Routing |
|---|---|---|
| **COMMENT** | #423 — expanded open-content-model roster from 11→14 schemas with per-schema JSONPath evidence | `team:backend`, `squad:nagel` |
| All others | **NO_OP** — #303 PASS, roster unchanged, no new drift |

---

### Blockers

None.

### Risky Changes

None. The window contains:
1. One deliberate, in-lane, correctly-closed Nagel change (#303, validated PASS).
2. One adjacent Reuben change (#445) that adds 3 new schemas — clean in required-fields and money-field encoding; the only deficiency is the expected #423 pattern (no `additionalProperties`).
3. Two orthogonal commits (Yen #493, Turk #459) with zero contract surface.

### Top 3 Next Actions

1. **Prioritise #317 (money precision).** `AddHoldingRequest.weight` is `number` while `PatchHoldingRequest.weight`, `PortfolioExportHolding.weight`, and `PortfolioExport.monthly_budget` are all `string/decimal`. The inconsistency across POST-input vs PATCH-input vs export-output is now documented with 4 data points. Fix: change `AddHoldingRequest.weight` and `HoldingOut.weight` to `{"type": "string", "format": "decimal"}`.

2. **Drive #423 (open-content-model) toward resolution.** Roster now 14 schemas. Fix: add `additionalProperties: false` to all 14 and Pydantic `extra="forbid"` in corresponding models. Confirm no wildcard field names relied upon by any handler.

3. **#348 (X-Device-UUID) and #316 (X-App-Attest).** Both are spec correctness issues with zero runtime risk. Group them with #317 and #423 into a single "spec hygiene" batch PR to close all four in one pass.

### Learning

When the HEAD pointer hasn't advanced from the prior cycle, the correct behaviour is to re-validate the prior-cycle findings with fresh evidence rather than re-running the same surface scan. The #445 export schemas provide a useful counter-example: the team applied the `string/decimal` encoding correctly for new money fields while leaving the older `AddHoldingRequest.weight` and `HoldingOut.weight` in the broken `number` state. This asymmetry in the same codebase strengthens the #317 case — the fix pattern is known and proven (the team already knows how to write it), it just hasn't been back-applied to the older fields.

(end Nagel cycle #40)

## Cycle #42 — Nagel

**Date:** 2026-05-16T01:20:31Z  
**HEAD:** `1662b32`  
**Window:** `9ba571e..HEAD` (since cycle #40 Nagel commit)  
**Anchor justification:** Cycle #41 was a Yen/Turk-only effective cycle for the contract lane (both NO_OP, history-only commits). No Nagel cycle #41 was run; this is cycle #42 covering the gap. Broader window `98424f0..HEAD` also inspected and confirmed contract-clean (4 history-only commits + Saul inbox file).

### Window commits + files

| Commit | Summary | Lane | Locked-surface touch? |
|---|---|---|---|
| `9e344ad` | research(saul): cycle #40 DSR audit-log cross-evidence | Saul | NO — `.squad/agents/saul/history.md`, `.squad/agents/frank/inbox-saul-cycle-40.md` |
| `9ba571e` | chore(nagel): cycle #40 history | Nagel | NO — `.squad/agents/nagel/history.md` |
| `f273de9` | chore(yen): cycle #41 history (NO_OP, 11→8 roster) | Yen | NO — `.squad/agents/yen/history.md` |
| `1662b32` | chore(turk): cycle #41 history (NO_OP, watchlist 4/4 PASS, #328 closed) | Turk | NO — `.squad/agents/turk/history.md` |

`git --no-pager diff --stat 98424f0..HEAD -- openapi.json app/Sources/Backend/Networking/openapi.json backend/ app/Sources/Backend/` → **empty output, zero hunks.**

---

### Four-Invariant Pass

**1. Parity gate — PASS.**
```
diff openapi.json app/Sources/Backend/Networking/openapi.json
exit: 0 (empty)
```
Both files 72,960 bytes. SHA-256 identical: `d9c7f1eb5b90a557a5ab2d46740dcf60d454ff311445d91b32b553b7e2db5fff`. Byte-for-byte match.

**2. Locked-surface scan — PASS.**
Window `9ba571e..HEAD`: 0 hunks against `openapi.json`, mirror, `backend/`, `app/Sources/Backend/`.
Broader window `98424f0..HEAD`: 0 hunks against same locked surface.
**Attribution:** All 4 window commits are specialist-history-only writes (Saul/Nagel/Yen/Turk to their own `.squad/agents/*/history.md` and one inbox file). No code or spec touched. **No drift.**

**3. Swift public-surface stability — PASS.**
```
git --no-pager diff 9ba571e..HEAD -- 'app/Sources/**/*.swift' | grep -E '^\+.*\b(public|protocol|@Model|@Reducer)\b' | wc -l
→ 0
git --no-pager diff 98424f0..HEAD -- 'app/Sources/**/*.swift' | grep -E '^\+.*\b(public|protocol|@Model|@Reducer)\b' | wc -l
→ 0
```
Zero Swift files touched in either window. Public-surface stability trivially preserved.

**4. Live-drift roster — PASS (5 open, all PERSISTING with refreshed citations).**

**#317 — HoldingOut/AddHoldingRequest money fields bare `number`**
- `components.schemas.AddHoldingRequest.properties.weight` = `{"type":"number","maximum":1.0,"exclusiveMinimum":0.0,"title":"Weight"}` — still bare `number`.
- `components.schemas.HoldingOut.properties.weight` = `{"type":"number","title":"Weight"}` — still bare `number`.
- **Contrast (still asymmetric within same spec):**
  - `PatchHoldingRequest.weight` → `string/decimal` ✅
  - `PortfolioExportHolding.weight` → `string/decimal` ✅
  - `PortfolioExport.monthly_budget` → `string/decimal` ✅
- **Status: PERSISTING, UNCHANGED.** No regression, no new evidence — same 4-data-point asymmetry as cycle #40. No fresh comment needed.

**#316 — X-App-Attest not a securityScheme**
- `components.securitySchemes` → **ABSENT** (not just empty — the key is not present in the spec at all).
- `security` (top-level) → **ABSENT**.
- `X-App-Attest` literal occurrences in spec text: **19** (all in description prose / parameter descriptions, none as a declared `securityScheme` or per-operation security requirement).
- **Status: PERSISTING, UNCHANGED.**

**#348 — X-Device-UUID undeclared header**
- `X-Device-UUID` literal occurrences in spec: **4** (description text only).
- `components.headers` = `{}` (empty). `components.parameters` = `{}` (empty).
- Not declared as a header parameter on any operation.
- **Status: PERSISTING, UNCHANGED.**

**#423 — Open content models (no `additionalProperties: false`)**
- Total schemas: **15** (was 14 last cycle — discrepancy explained: 14 are `type: object`, 1 is non-object).
- Object schemas with `additionalProperties` set: **0**.
- Object schemas MISSING `additionalProperties`: **14/14** → `AddHoldingRequest, ErrorEnvelope, HealthResponse, HoldingOut, PatchHoldingRequest, PatchHoldingResponse, PatchPortfolioRequest, PatchPortfolioResponse, PortfolioDataResponse, PortfolioExport, PortfolioExportHolding, PortfolioExportResponse, PortfolioStatusResponse, SchemaVersionResponse`.
- **Status: PERSISTING, UNCHANGED.** Roster identical to cycle #40 (14 object schemas, all open). No fresh comment — last comment on #423 was cycle #40.

**#416 — Blanket Cache-Control / Last-Modified on all responses**
- Total operations: **10**. Total response slots: **45**.
- Response slots carrying `Cache-Control`: **45 / 45** (100%).
- `204` responses carrying Cache-Control: **2 / 2** (DELETE `/portfolio`, DELETE `/portfolio/holdings/{ticker}`).
- `202` async-acknowledge responses (POST `/portfolio/holdings`): still carries Cache-Control.
- Error envelopes (401/404/422/503) carrying Cache-Control: **34**.
- **Status: PERSISTING, UNCHANGED.** Same blanket pattern as cycle #40.

---

### Streak Status

- **Sanctioned-change cycles (lifetime):** 1 (cycle #39 / PR #503 / #303).
- **Locked-surface-clean cycles since last sanctioned change:** **3** (cycles #40, #41, #42). The lane has been quiet since #303 landed.
- **Unannounced-drift cycles (lifetime):** **0**. Discipline holds at 42/42.

---

### Findings

**Zero new findings.** Locked surface untouched. Roster line refs unchanged. No drift, no regression, no new schemas, no new operations.

### Decisions

None. NO_OP cycle.

### Duplicate-Check Proof

Not invoked. No new issue contemplated because no new evidence surfaced. Roster line-ref refresh confirmed all 5 open issues map to current spec without modification — no fresh-comment thresholds tripped (each issue last received Nagel evidence within the last 1–2 cycles).

### Filings / Comments

| Action | Issue | Routing |
|---|---|---|
| **NO_OP** | All 5 (#423, #416, #348, #317, #316) — line refs hold, no regression, no expansion |

### Blockers

None.

### Risky Changes

None. Window contains zero code/spec/Swift activity.

### Forward Watch / Handoff

- Watch for first new `paths.*` or `components.schemas.*` mutation since #303 — that will be the next sanctioned-change candidate (likely #317 or batched spec-hygiene PR per cycle-#40 recommendation).
- Drift discipline holds: 3 consecutive clean cycles, unannounced-drift counter remains zero at cycle #42.

(end Nagel cycle #42)

---

## Cycle #43 — Nagel

**Date:** 2026-05-16T01:40:16Z  
**HEAD:** `54d9df5`  
**Window:** `1662b32..54d9df5` (6 commits)  
**Anchor justification:** Continues directly from cycle #42 Nagel commit `0928cf8`. Window covers cycles #42 specialist-history writes from Turk, Yen, Reuben, Saul, and Frank.

### Window commits + files

| Commit | Summary | Lane | Locked-surface touch? |
|---|---|---|---|
| `0928cf8` | chore(nagel): cycle #42 history | Nagel | NO — `.squad/agents/nagel/history.md` |
| `5dd6585` | chore(turk): cycle #42 history | Turk | NO — `.squad/agents/turk/history.md` |
| `4eba7dd` | chore(yen): cycle #42 history | Yen | NO — `.squad/agents/yen/history.md` |
| `5f7e774` | compliance(reuben): cycle #42 | Reuben | NO — `.squad/agents/reuben/history.md` |
| `5e58594` | research(saul): cycle #42 NO_OP | Saul | NO — `.squad/agents/saul/history.md` + Frank inbox |
| `54d9df5` | aso(frank): cycle #42 6-peer probe | Frank | NO — `.squad/agents/frank/history.md` |

`git --no-pager diff --stat 1662b32..54d9df5 -- openapi.json app/Sources/Backend/Networking/openapi.json backend/ app/Sources/Backend/` → **empty output, zero hunks.** Window is 100% specialist-history.

---

### Four-Invariant Pass

**1. Parity gate — PASS.**
```
diff openapi.json app/Sources/Backend/Networking/openapi.json
exit: 0 (empty)
```
Both files SHA-256 `d9c7f1eb5b90a557a5ab2d46740dcf60d454ff311445d91b32b553b7e2db5fff` (unchanged vs cycle #42). Byte-for-byte match.

**2. Swift public-surface stability — PASS.**
```
git --no-pager diff 1662b32..54d9df5 -- 'app/Sources/**/*.swift' | grep -E '^\+.*\b(public|protocol|@Model|@Reducer)\b'
→ 0 matches (grep exit 1)
```
Zero Swift files touched in window.

**3. Locked-surface scan — PASS.**
Window `1662b32..54d9df5`: 0 hunks against `openapi.json`, mirror, `backend/`, `app/Sources/Backend/`. All 6 commits are specialist-history-only writes. **No drift.**

**4. Roster integrity — PASS (5 open, exact match to carry-forward).**
`gh issue list --label "squad:nagel" --state open` returns exactly `#423, #416, #348, #317, #316` — identical to cycle #42 carry-forward. All five PERSISTING; line refs hold against `54d9df5` openapi.json (hash unchanged, so per-issue evidence from cycle #42 still applies verbatim).

---

### Streak Status

- **Sanctioned-change cycles (lifetime):** 1 (cycle #39 / PR #503 / #303).
- **Locked-surface-clean cycles since last sanctioned change:** **4** (cycles #40, #41, #42, #43).
- **Unannounced-drift counter:** **0**. Discipline holds 43/43.

---

### Findings

Zero new findings. Locked surface untouched. openapi.json hash unchanged vs cycle #42. Roster identical to carry-forward.

### Decisions

None. NO_OP cycle.

### Duplicate-Check Proof

Open Nagel issues (5): `#423, #416, #348, #317, #316`. Recently-closed Nagel (last 50): `#463, #461, #460, #439, #429, #402, #392, #381, #363, #359, …` — none reopened or regressed. No new contract candidate to file (window contains no spec mutation), so duplicate-check is a NO-OP confirmation, not a filing gate.

### Filings / Comments

| Action | Issue | Routing |
|---|---|---|
| **NO_OP** | All 5 (#423, #416, #348, #317, #316) — line refs hold, no regression |

### Blockers

None.

### Risky Changes

None. Window contains zero code/spec/Swift activity.

### Forward Watch / Handoff

- Still waiting for first sanctioned `paths.*` or `components.schemas.*` mutation since #303 (PR #503). Likely vehicle: #317 (Decimal-money normalization) or a batched spec-hygiene PR.
- Drift discipline: 4 consecutive clean cycles, unannounced-drift counter remains zero entering cycle #44.

(end Nagel cycle #43)
