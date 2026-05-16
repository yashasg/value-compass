# Value Compass — v1 Services & Interfaces Technical Specification

> **Status:** Draft  
> **Owner:** Linus (Integration Engineering)  
> **Date:** 2026-05-12  
> **Scope:** Service seams, integration contracts, optional backend sync, OpenAPI/client sync expectations

---

## 1. Purpose

This document splits the services/interfaces concerns out of the combined v1 tech
spec. V1 is **hybrid/offline-first**: the app must complete the portfolio →
calculate → save flow from local data while optionally syncing eligible data to
the backend database when the backend is available. Backend availability can
improve portability and future service behavior, but it must not be required for
calculation, manual market inputs, or local contribution-history use.

The VCA/moving-average algorithm internals are deliberately out of scope. The app
only defines the interface and validation boundary. The real algorithm will live
in the iOS app codebase, but remains user-owned work tracked by [issue #15](https://github.com/yashasg/value-compass/issues/15).

---

## 2. V1 Service Principles

| Principle | Requirement |
|---|---|
| Offline-first core | V1 must complete portfolio editing, manual input, calculation, and local history without a backend. |
| Optional backend sync | When backend services are available, the app may sync eligible portfolio/config data; offline work remains authoritative locally until reconciliation succeeds. |
| Local-only contribution history | Saved contribution history and allocation snapshots stay on-device and must never sync to the backend. |
| Manual v1 market inputs | Current value and moving-average values are local user-correctable fields in v1. Missing values are validation issues, not backend failures. |
| Explicit seams | Calculation, market data, and sync are hidden behind protocols/adapters so later implementations can swap in. |
| Pure integration boundary | Services validate inputs/outputs but do not encode private algorithm internals. |
| Generated clients only | Future Swift networking code is generated from FastAPI/OpenAPI output and never hand-edited. |

---

## 3. In-Scope Service Seams for v1

### 3.1 `ContributionCalculating`

`ContributionCalculating` is the only app-facing seam for contribution allocation.
The app owns when this seam is called, input validation before the call, output
validation after the call, and persistence of accepted results. The algorithm
implementation behind the seam is not specified here.

```swift
protocol ContributionCalculating: Sendable {
    func calculate(input: ContributionInput) -> ContributionOutput
}
```

Expected contract:

- Input is a `ContributionInput` carrying a fully populated local `Portfolio`
  (categories, tickers, monthly budget) plus a `MarketDataSnapshot` of
  per-symbol current price, moving average, and optional band position.
- Return value is a `ContributionOutput` whose `allocations` enumerate
  per-ticker amounts and weights, plus a `categoryBreakdown` summary and an
  `error: LocalizedError?` channel.
- Returned allocations must be non-negative and must sum to
  `ContributionInput.monthlyBudget` within cent-level tolerance.
- The protocol method is **non-throwing**. The canonical error channel is
  `ContributionOutput.error`, populated by `ContributionOutput.failure(_:)`.
  Throws are not used because the seam is driven from TCA reducers that store
  errors as state.

`ContributionInputValidator` runs before the seam (inside
`ContributionCalculationService.calculate(input:calculator:)`) and rejects any
input that violates the contract above. Conformers therefore may rely on the
following invariants when invoked through the service: non-`nil` portfolio,
`monthlyBudget > 0`, non-empty categories whose weights sum to `1`, every
category contains at least one ticker, and every ticker has non-`nil`
`currentPrice` and `movingAverage` both strictly greater than `0`.

For invariants the validator already guarantees, conformers should still return
`ContributionOutput.failure(_:)` rather than calling `preconditionFailure`. The
seam is intended to be invoked directly from tests and user-authored harnesses;
a `preconditionFailure` for a validator-guaranteed invariant crashes those
direct-call paths even though the live orchestrator path never triggers it.

Calculator-private input dependencies live outside the validator. The notable
case today is `MarketDataQuote.bandPosition`, which is not checked by
`ContributionInputValidator`. Band-style conformers must guard for it locally
and return `ContributionCalculationError.missingBandPosition(symbol)` when
absent; this is what `BandAdjustedContributionCalculator` ships with.

V1 ships three conformers — `MovingAverageContributionCalculator` (default),
`BandAdjustedContributionCalculator`, and `ProportionalSplitContributionCalculator`
— so the app flow can be tested end-to-end. The full user-owned VCA algorithm
remains tracked by [issue #15](https://github.com/yashasg/value-compass/issues/15).

Current placeholder/local policy: the band-adjusted implementation computes
each ticker's raw multiplier as `1 + (0.5 - bandPosition)`. Because normalized
band position is expected to sit in the `0...1` range, the default clamp bounds
are `0.5` minimum and `1.5` maximum; out-of-range manual inputs are still
clamped to those bounds. These local policy values can change when the
user-owned VCA algorithm is finalized.

### 3.2 `MarketDataProviding`

`MarketDataProviding` isolates where ticker price and moving-average values come
from. In v1, it is backed by user-entered local values or deterministic stubs.

```swift
protocol MarketDataProviding {
    func currentPrice(for ticker: String) async throws -> Decimal
    func movingAverage(for ticker: String, window: Int) async throws -> Decimal
}
```

V1 behavior:

- Reads values already stored on the local ticker model.
- Performs no required HTTP requests for calculation.
- Treats missing values as user-correctable input errors.
- Does not cache independently from SwiftData; the local model is the source of
  truth for manual values.

Future behavior:

- A backend-backed implementation can read cached market data exposed by `vca-api`
  after the backend contract exists.
- The provider remains an adapter; it should not own calculation logic, overwrite
  user-entered manual values without consent, or mutate contribution history.

### 3.3 `PortfolioSyncing`

`PortfolioSyncing` is the optional hybrid/offline-first boundary for data that may
be mirrored to backend storage. It is intentionally separate from calculation and
history so sync availability cannot block core app behavior.

```swift
protocol PortfolioSyncing {
    func pushEligibleChanges() async throws -> SyncResult
    func pullRemoteChanges() async throws -> SyncResult
}
```

V1 sync contract:

- Sync is best-effort and availability-aware: failures surface as sync status, not
  calculation blockers.
- Eligible data includes portfolio structure/configuration that a backend schema
  can represent, such as portfolio metadata and holdings/tickers.
- Local-only data remains local even when sync is enabled: contribution history,
  saved allocation snapshots, and manual correction provenance must not be sent.
- Manual current value and moving-average fields remain app-local v1 inputs unless
  a later contract explicitly distinguishes user-entered overrides from backend
  market cache values.
- Conflicts should preserve local user work and avoid silent lossy category or
  ordering round trips.

---

## 4. V1 Local vs Sync vs Future Service Boundaries

| Area | V1 app-local behavior | V1/future sync boundary | Backend/service status |
|---|---|---|---|
| Portfolio metadata | Stored locally and usable offline. | Eligible for optional backend sync when representable. | Existing/future API may persist/read from Postgres. |
| Categories | First-class local grouping and ordering. | Sync only when backend can preserve semantics or explicitly handle lossy mapping. | Backend category support is deferred. |
| Tickers/holdings | Stored locally under categories. | Eligible for optional holdings sync; conflict handling must protect local edits. | Existing backend holdings are flatter than local model. |
| Manual current value / MA | User-entered local fields; missing data is user-correctable. | Remain app-local in v1; future contracts may separate manual overrides from cached market data. | Future API serves cached market data; poller refreshes cache. |
| Contribution calculation | Invoked locally through `ContributionCalculating`. | No backend calculation dependency in v1. | Real algorithm remains user-owned app code, not a service. |
| Contribution history | Local immutable ledger. | Never sync to backend. | No backend history table is required or expected for v1. |
| Generated Swift client | Not required for offline calculation. | Used only for backend-backed adapters once OpenAPI endpoints are active. | Must be generated from FastAPI/OpenAPI, never hand-edited. |
| Push notifications | Not required. | Future market-data completion/status signal only. | Optional future APNs path. |

---

## 5. Backend Availability in v1

The following must work without network access:

- Portfolio, category, ticker, and contribution-history storage.
- Manual market price/current value and moving-average entry.
- Contribution calculation invocation and result validation.
- Disclaimer and user-facing validation messages.

The following may be used when backend services are available, but must be
optional for the v1 app experience:

- Supabase/Postgres-backed sync for eligible portfolio/configuration data.
- `vca-api` health, schema/version, portfolio/status, portfolio/data, or holdings
  endpoints.
- Generated Swift OpenAPI client output used by sync or future market-data
  adapters.
- `vca-poller` stock-cache freshness and APNs notifications for future cached
  market-data flows.

FastAPI is the source of truth for backend contracts. `openapi.json` is a
generated artifact and should not be edited manually.

---

## 6. Future Backend Responsibilities

### 6.1 `backend/api` (`vca-api`)

When networking is introduced, the API is responsible for serving iOS clients and
reading from Postgres-backed state. It must not call Polygon directly on ordinary
read paths. Expected later responsibilities include:

- Health and schema/version endpoints.
- Portfolio/status metadata for cache freshness and sync status.
- Portfolio/configuration data once backend sync exists.
- Cached market-data reads sourced from `stock_cache`.
- A new-ticker request path that can enqueue or trigger market-data fetch work
  without blocking the client.
- Response headers such as `Cache-Control`, `Last-Modified`, and
  `X-Min-App-Version`.
- App Attest validation and rate-limit compatibility at the edge.

The API must not persist contribution history or saved allocation snapshots unless
a future explicit decision reverses the local-only history rule.

### 6.2 `backend/poller` (`vca-poller`)

The poller is the scheduled market-data writer. Expected later responsibilities
include:

- Fetching current prices and moving averages from Polygon on trading days.
- Writing successful snapshots to `stock_cache`.
- Updating `last_modified` / `next_modified` only after successful completion.
- Leaving clients on the last successful snapshot during poller failures.
- Emitting alerts for stale data rather than causing client retry storms.
- Sending APNs notifications when async market-data work completes.

The API and poller must share database/common code without drift. API reads and
poller writes should remain clearly separated except for explicitly documented
new-ticker background fetch behavior.

---

## 7. OpenAPI and Client Sync Expectations

Backend phases use OpenAPI as the backend/iOS contract:

1. FastAPI owns the schema exposed at `/openapi.json`.
2. The repo-root `openapi.json` is exported from FastAPI output, not edited by hand.
3. Regenerate checked-in contract artifacts with
   `PYTHONPATH=backend python3 -m api.export_openapi`; CI verifies them with the
   same command plus `--check`.
4. SwiftOpenAPIGenerator consumes `openapi.json` to produce code under
   `app/Sources/Backend/Networking/`.
5. Generated networking files are never manually modified.
6. Contract changes must be backward-compatible by default: newly added response
   fields are optional unless a versioned breaking change is intentionally planned.
7. Minimum app support is communicated with `X-Min-App-Version` and handled by the
   client with a forced-update path.
8. API schema versioning remains machine-readable through `/schema/version`.
9. **Content-model posture is asymmetric (issue #423): request bodies are
   closed (`additionalProperties: false` / Pydantic `extra="forbid"`),
   response bodies stay open.** A request that carries an unknown field
   must 422 with the `schemaUnsupported` envelope so a client-side typo
   (e.g. `displayName` vs `display_name`) or a stray field on a
   rectification PATCH cannot be silently dropped by Pydantic's default
   `extra="ignore"` while activity is stamped. Response models stay open
   so additive server-side schema evolution (e.g. a new optional
   indicator on `HoldingOut`) does not break older iOS builds. The
   closed list is `AddHoldingRequest`, `PatchPortfolioRequest`,
   `PatchHoldingRequest`; future request-body schemas must adopt the
   same posture, and the spec contract pin in
   `backend/tests/test_api.py::test_request_bodies_are_closed_content_and_responses_stay_open`
   fails the build if a model flips.

For v1 offline calculation, no OpenAPI client is required. For v1 hybrid sync or
future market-data adapters, OpenAPI-generated clients are the only supported
Swift networking surface.

---

## 8. Error Contracts

### 8.1 Calculation errors

Calculation-facing errors are narrow and user-actionable. The shipping enum is
`ContributionCalculationError` (`app/Sources/Backend/Services/ContributionCalculator.swift`)
and surfaces through `ContributionOutput.error: LocalizedError?` — never as a
thrown error. Cases group into pre-call invariants (caught by
`ContributionInputValidator`), calculator-private input checks (a conformer's
own guards), and post-call invariants (caught by `ContributionOutputValidator`).

| Error | Source | Meaning | User handling |
|---|---|---|---|
| `missingPortfolio` | input validator | `ContributionInput.portfolio` is `nil`. | Block calculation until a portfolio is selected. |
| `invalidBudget` | input validator | `ContributionInput.monthlyBudget` is non-positive. | Show inline budget validation. |
| `noCategories` | input validator | Portfolio has no categories. | Prompt user to add a category before calculating. |
| `categoryWeightsDoNotSumTo100` | input validator | Category weights do not sum to `1`. | Keep calculation disabled and focus the editor. |
| `categoryHasNoTickers(categoryName)` | input validator | A category has no tickers. | Show the category and prompt for at least one ticker. |
| `missingMarketData(symbol)` | input validator | `currentPrice` or `movingAverage` is absent for a ticker. | Show the ticker and prompt for manual entry. |
| `invalidMarketData(symbol)` | input validator | `currentPrice` or `movingAverage` is `≤ 0`. | Show the ticker and prompt for a corrected value. |
| `missingBandPosition(symbol)` | conformer guard (band-style) | `MarketDataQuote.bandPosition` is `nil` for a calculator that needs it. | Show the ticker and prompt for a manual band position (or switch calculators). |
| `negativeAllocation(symbol)` | output validator | A returned allocation is negative. | Block save and surface a generic calculation-contract error. |
| `allocationTotalMismatch(expected, actual)` | output validator | Allocations do not sum to the returned `totalAmount`. | Block save; treat as a calculator contract bug. |
| `outputTotalMismatch(expected, actual)` | output validator | Returned `totalAmount` does not match the input monthly budget. | Block save; treat as a calculator contract bug. |

The app should catch predictable input states before invoking
`ContributionCalculating`; the input validator is the backstop, not the primary
UI gate. Conformers must not call `preconditionFailure` for invariants the
validator already guarantees — return `.failure(_:)` instead so direct-call
paths (tests, user-authored harnesses) never crash the process.

### 8.2 Market-data errors

| Error | Meaning | User handling |
|---|---|---|
| `missingPrice(ticker)` | Current price was not entered or fetched. | Prompt for manual price entry. |
| `missingMovingAverage(ticker, window)` | Moving average for the selected window is absent. | Prompt for manual MA entry. |
| `unsupportedWindow(window)` | Requested MA window is outside the supported set. | Prevent selection; treat as developer/config error. |
| `staleData(ticker, asOf)` | Future backend cached data is older than freshness policy. | Warn but allow last-known/manual value if product allows. |
| `networkUnavailable` | Future backend provider cannot reach the API. | Fall back to cached/local values where available. |

V1 manual providers should only produce missing/unsupported local input errors;
network errors are reserved for backend-backed sync or market-data providers.

### 8.3 Sync errors

Sync errors should not block calculation or local history:

| Error | Meaning | User handling |
|---|---|---|
| `syncUnavailable` | API or network cannot be reached. | Keep local edits and show pending/offline sync status. |
| `schemaUnsupported` | Backend contract is older/newer than the app supports. | Disable sync and direct user to update when needed. |
| `conflictDetected` | Remote and local eligible data changed incompatibly. | Preserve local data and request user choice or safe merge. |
| `lossyMappingRejected` | Backend cannot represent local categories/order without loss. | Keep local data unsynced and explain limitation. |

### 8.4 Future HTTP errors

Future API errors should be structured and OpenAPI-described, with stable machine
codes and human-readable messages. The client should branch on codes, not raw
message text. Candidate shape:

```json
{
  "code": "stock_data_pending",
  "message": "Market data for this ticker is still being fetched.",
  "retry_after_seconds": 60
}
```

---

## 9. Deployment and DevOps

### v1 Deployment Model

V1 backend targets **Azure Container Apps** as the managed infrastructure foundation. The goal is to reduce operational overhead while supporting the hybrid/offline-first app model.

#### Deployment Triggers and Strategy

- **Manual deployment only via workflow_dispatch.** V1 has no shared backend environments until app MVP is ready. The team can trigger a deploy manually when a release is needed.
- **CI pipeline tests and publishes container images.** GitHub Actions builds and pushes a FastAPI container image for `vc-services` to the Azure Container Registry.
- **No automatic deployments on branch pushes.** Developers can test the FastAPI app locally before deciding to deploy.
- **Future: scheduled deployments after app MVP.** Once the app is widely deployed and backend sync is active, automated deployments for backend hotfixes may be considered.

#### Deployment Workflow

The `.github/workflows/vc-services-AutoDeployTrigger-*.yml` workflow:
1. Checks out the target ref.
2. Logs in to Azure using `AZURE_CREDENTIALS`.
3. Builds the FastAPI app from `backend/api` and pushes a container image to `AZURE_CONTAINER_REGISTRY_LOGIN_SERVER` with a tag matching the commit SHA.
4. Deploys the container to the Azure Container Apps resource group named by `AZURE_RESOURCE_GROUP` and container app named by `AZURE_CONTAINER_APP_NAME`.

All credentials and Azure resource identifiers are stored in GitHub Secrets. Required secrets for the Container Apps workflow are `AZURE_CREDENTIALS`, `AZURE_CONTAINER_REGISTRY_LOGIN_SERVER`, `AZURE_CONTAINER_REGISTRY_USERNAME`, `AZURE_CONTAINER_REGISTRY_PASSWORD`, `AZURE_CONTAINER_APP_NAME`, and `AZURE_RESOURCE_GROUP`. No secrets are committed to code.

### Future: Backend Responsibilities and API Contracts

| Boundary | Owner | In v1 | Later phase |
|---|---|---|---|
| UI → calculation | iOS app | Calls `ContributionCalculating` after local validation. | Same seam; implementation may change. |
| UI → market data | iOS app | Reads manual/stub values through `MarketDataProviding`. | Provider can call generated API client for cached market data. |
| UI → sync status | iOS app/integration | Shows offline/pending/synced state if sync is enabled. | Richer conflict resolution and multi-device sync. |
| iOS → backend API | Integration/API | Optional for eligible sync; never required for calculation/history. | Generated Swift client calls `vca-api`. |
| API → database | Backend | Optional sync persistence for representable data. | API reads portfolio/config/cache state. |
| Poller → database | Backend | Not needed by offline calculation. | Poller writes stock-cache snapshots. |
| API/poller → Polygon | Backend | Not used by app-local manual inputs. | Poller owns scheduled fetches; API only documented async new-ticker path. |
| Contribution history sync | iOS app | Prohibited; local-only. | Remains prohibited unless a future explicit decision changes it. |
| Algorithm internals | User | Placeholder only; real work blocked externally. | User-owned implementation from issue #15. |

Integration rule: each boundary gets one adapter and one contract test surface.
Do not let UI screens import backend details, do not let generated networking code
leak into domain models, and do not couple sync state to contribution-history
persistence.

---

## 10. Service-Level Test Strategy

V1 service tests should prove the seams work without proving the real algorithm:

- `ContributionCalculating` placeholder tests:
  - returns allocations for a valid local portfolio;
  - rejects missing market data, invalid weights, zero budget, and empty ticker
    sets;
  - never returns negative amounts;
  - output can be normalized to exactly the monthly budget at cent precision.
- Calculation-boundary tests:
  - app validation runs before the calculator is called;
  - invalid calculator output is rejected before persistence;
  - persistence receives only accepted `TickerAllocation` snapshots.
- `MarketDataProviding` manual-provider tests:
  - returns stored current price and moving average;
  - reports missing values with ticker-specific errors;
  - does not perform required network work.
- `PortfolioSyncing` optional-sync tests:
  - calculation and local history continue when sync is unavailable;
  - eligible portfolio/config changes can be queued and retried;
  - contribution history and allocation snapshots are never included in payloads;
  - lossy category/order mappings are detected instead of silently accepted.
- Future OpenAPI/client-sync tests:
  - generated Swift networking compiles from the exported schema;
  - schema changes preserve optional new fields or explicitly bump compatibility;
  - HTTP error envelopes decode into stable client error types;
  - API and poller behavior around stale cache/new ticker flows is covered by
    backend integration tests.

No service test should assert the VCA/moving-average formula until the user-owned
algorithm implementation lands.

---

## 11. Open Questions

| Question | Status |
|---|---|
| Real VCA/moving-average implementation | Blocked on user-owned [issue #15](https://github.com/yashasg/value-compass/issues/15). |
| Whether backend sync adds a first-class `Category` entity | Deferred to backend/db spec work. |
| Exact future HTTP error envelope | Proposed here; finalize when API endpoints are implemented. |
| Exact conflict policy for optional portfolio/config sync | Deferred to sync implementation design. |
| How to distinguish backend cached market data from user-entered manual overrides | Deferred to future market-data contract design. |
