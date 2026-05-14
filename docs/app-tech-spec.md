# Value Compass — App Technical Specification

> **Status:** Draft  
> **Owner:** iOS  
> **Date:** 2026-05-12  
> **Target:** iOS 17+ / iPadOS 17+, local-first, offline-capable

This document is the app-only v1 technical specification for the Value Compass iOS/iPadOS client. It is split from the combined v1 tech spec and should be read alongside the dedicated services and database specs when those areas are needed.

---

## 1. App Goal

Value Compass helps users practice value cost averaging (VCA) from a native iPhone and iPad app. The app lets a user define a portfolio, organize holdings into categories and tickers, enter the data required for a contribution run, calculate target contribution amounts through an app-owned service seam, and persist contribution history locally.

V1 is a hybrid/offline-first app: local SwiftData remains the primary runtime source of truth and the complete portfolio → calculate → save-history flow must work without network access. When backend sync is configured and available, the app may sync portfolio/holding state in the background; sync must not block local UX or change the app-owned calculation boundary. Market data inputs for v1 are manual/local fields entered by the user or provided by local stubs.

---

## 2. App Non-Goals (v1)

| # | Non-Goal | Rationale |
|---|----------|-----------|
| 1 | Implement algorithm internals | The app defines the seam and UX around calculation; the VCA algorithm remains user-owned. |
| 2 | Live market data | Manual/local values keep the app offline-capable for v1. |
| 3 | Backend-required operation | Backend sync can be available when configured, but no core app flow may require network access. |
| 4 | Database schema design beyond app persistence | Backend/db concerns belong in the split database spec. |
| 5 | Service runtime design | API, poller, and market-data services belong in the split services spec. |
| 6 | Brokerage integration | Out of scope. |
| 7 | Push notifications | Deferred until backend and APNs flows are in scope. |
| 8 | Real-time multi-device cloud UX | Deferred; v1 sync, when configured, is a best-effort backend adapter over local SwiftData rather than a cloud-first experience. |

---

## 3. Platform and App Architecture

- **Platform:** Universal iOS/iPadOS app.
- **Minimum OS:** iOS 17+ / iPadOS 17+.
- **UI framework:** SwiftUI.
- **Local persistence:** SwiftData.
- **Primary layout:** Single navigation hierarchy rooted at the portfolio list.
- **iPhone navigation:** `NavigationStack`.
- **iPad navigation:** `NavigationSplitView` where screen width allows a master-detail experience.
- **No tab bar in v1** — all navigation flows through the portfolio hierarchy.
- **Networking:** Not required by the core v1 app flow. Generated networking/sync scaffolding may be used only as an optional backend adapter when configured and reachable.
- **Light and dark mode:** Both are required from v1 onward.

### Build and Run Scripts

**`app/build.sh`** — Builds and tests the app on explicit simulator destinations.

Defaults:
- iOS/iPadOS Simulator version: `26.4`
- iPhone device: `iPhone 17`
- iPad device: `iPad (A16)`
- Platform mode: `both` (build and test on both iPhone and iPad)

Env overrides: `IOS_VERSION`, `IPADOS_VERSION`, `IPHONE_DEVICE`, `IPAD_DEVICE`, `PLATFORM_MODE` (iphone|ipad|both), `SCHEME`, `PROJECT_PATH`, `WORKSPACE_PATH`.

**`app/run.sh`** — Boots or creates the selected simulator, builds, installs, and launches the app.

Env overrides: `DEVICE_KIND` (iphone|ipad), `IOS_VERSION`, `IPADOS_VERSION`, `IPHONE_DEVICE`, `IPAD_DEVICE`, `SCHEME`, `PROJECT_PATH`, `WORKSPACE_PATH`.

The app should prefer simple, testable seams: SwiftUI views render state, view models coordinate validation and actions, SwiftData repositories/persistence helpers own local storage, service protocols hide calculation and market-data sources, and any backend sync adapter observes local changes without becoming the source of truth.

### App Design Principles

The app technical specification and SwiftUI implementation are the canonical sources for v1 behavior and layout. Early generated Stitch exports were functional references only and should not remain as maintained source code or design assets in the repository.

- **Generated design exports are placeholder material.** Screen layouts, information hierarchy, and interaction patterns are captured in this spec and implemented in SwiftUI rather than maintained as generated HTML/images.
- **Tess owns final design.** Tess (iOS/iPadOS Designer) reviews the app implementation and approves or revises the design system (colors, typography, spacing, dark mode support, animations).
- **Prefer accessible system typography unless a design-system decision says otherwise.** Do not hardcode SF Pro Display or SF Mono without an explicit approved design requirement.
- **iPhone and iPad support from v1.** All screens must be functional on both iPhone (compact width, `NavigationStack`) and iPad (regular width, `NavigationSplitView`). Responsive layouts and adaptive navigation are required, not post-v1 additions.
- **Light and dark mode required.** Implement both light and dark color schemes from v1 to avoid rework.

---

## 4. App Data Model Perspective

SwiftData models mirror the app's local domain concepts:

- `Portfolio`: name, monthly budget, MA window, categories, creation date.
- `Category`: display name, category weight, sort order, tickers.
- `Ticker`: symbol, optional current price, optional moving average, sort order.
- `ContributionRecord`: immutable saved calculation result for a portfolio.
- `TickerAllocation`: saved/displayed per-ticker amount within a contribution result.

App-level constraints:

| Constraint | App Behavior |
|------------|--------------|
| Monthly budget | Must be greater than zero before calculation. |
| MA window | User chooses supported windows only: 50 or 200. |
| Category weights | Must sum to 100% for a portfolio before calculation. |
| Ticker membership | Tickers live inside categories; categories with no tickers are shown as warnings. |
| Market inputs | Each ticker needs the required price and moving-average values before calculation. |
| History records | Saved results are immutable snapshots; editing a portfolio does not rewrite history. |

Backend model mapping and database persistence rules are references only here. For app behavior, categories remain local-only in v1. When backend sync is configured, holdings are flattened from `Category → Ticker` into backend holdings and category names/order/grouping are not expected to round-trip. Contribution history is local-only and must never sync to the backend. See the split database spec for canonical backend/db decisions.

---

## 5. Screens and Navigation

### Navigation Architecture

- **iPhone (compact width):** `NavigationStack` rooted at Portfolio List. User navigates forward with push semantics (Portfolio → Detail → Holdings Editor → Calculate → Result).
- **iPad (regular width):** `NavigationSplitView` with a sidebar showing Portfolio List and a detail pane for the current portfolio. User selects a portfolio to populate the detail and sub-views.
- **No tab bar in v1.** All navigation flows through the portfolio hierarchy.

### Onboarding & First-Run Flow

On first app launch, guide the user through creating their first **real portfolio**—not a sample or demo portfolio. The onboarding sequence is:

1. **Disclaimer screen** (one-time at first launch): Display the required disclaimer and request acknowledgment before proceeding.
2. **Portfolio creation prompt** (on empty state): If no portfolios exist, show a clear empty state with a primary action "Create Your First Portfolio" that transitions to the Portfolio Editor.
3. **Guided setup:** Walk the user through naming their portfolio, setting a monthly budget, and choosing a moving-average window (50 or 200).
4. **First holdings:** After portfolio creation, offer to immediately enter the first category and ticker so the user builds a real portfolio structure in one sitting.

The onboarding design should feel like a natural part of app setup, not a separate tutorial or sample. Avoid placeholder portfolio names or demo data; the user should own their portfolio from the start.

### Screen Flows

```text
App Launch (iOS 17+ with SwiftData container)
  │
  ▼
Disclaimer (first-run gate)
  │
  ▼
Portfolio List (empty state on fresh install)
  │
  ├── [Create Your First Portfolio] → Portfolio Editor (new portfolio)
  │
  └── (after creation) Portfolio Detail
       ├── Summary: name, budget, MA window
       ├── Category breakdown: weights, ticker counts, validation status
       ├── [Edit Holdings] → Category / Ticker Editor
       ├── [Calculate] → Contribution Result
       └── [History] → Contribution History

Portfolio Editor (create or edit)
  ├── Name input
  ├── Monthly budget input
  ├── MA window selector (50 / 200)
  └── Save / Cancel

Category / Ticker Editor
  ├── Add/remove/reorder categories
  ├── Set category weights
  ├── Add/remove/reorder tickers inside a category
  ├── Enter current price and moving average per ticker
  └── Inline validation for editable fields

Contribution Result
  ├── Total contribution amount
  ├── Per-ticker breakdown by category
  ├── Error state if calculation fails
  ├── [Save] persists a ContributionRecord
  └── [History] opens saved records

Contribution History
  ├── Newest records first, grouped by month
  ├── Row summary: date and total amount
  ├── Expand/detail view: per-ticker breakdown
  └── Swipe-to-delete individual records

Settings / Info (optional in v1)
  ├── Disclaimer re-display
  └── App version / legal
```

**Navigation note:** Settings are only required if needed to expose the disclaimer after onboarding; otherwise, keep the hierarchy focused on portfolio work. If no Settings screen is needed, a persistent info button on Portfolio List suffices.

---

## 6. View Model and Service Seams

The app should keep algorithm and data-source details behind protocols so UI work can proceed without service/backend dependencies.

### View Model Responsibilities

- Load and mutate SwiftData-backed models for the current screen.
- Format money, percentages, dates, and validation messages for display.
- Expose simple view state such as `canCalculate`, `validationMessages`, `isSaving`, and `result`.
- Coordinate actions: create portfolio, update holdings, request calculation, save history, delete history.
- Convert thrown service errors into user-facing messages.

### Service Boundaries

- **Contribution calculating seam:** A protocol used by the app when the user taps Calculate. The app treats the implementation as opaque and does not encode algorithm internals in views.
- **Market data seam:** A protocol that supplies current price and moving-average values. V1 reads manual/local values already present in local ticker data.
- **Persistence seam:** SwiftData-backed access for portfolios and contribution records. Small v1 data sets may stay main-actor oriented unless implementation complexity requires separation.
- **Backend sync seam:** Optional, configuration-gated sync for portfolio/holding state. It must flatten local category/ticker data into backend holdings, avoid syncing category metadata, and never read or write contribution history.

Services/backend details are references only in this app spec. Network-backed providers and sync adapters should be described in the split services spec and consumed through the same app seams without making offline flows dependent on the backend.

---

## 7. Validation UX and Error States

Validation should be visible before the user commits an action whenever possible.

| State | UX |
|-------|----|
| Empty portfolio list | Friendly empty state with a clear Create Portfolio action. |
| Portfolio name missing | Inline editor error; Save disabled. |
| Budget ≤ 0 | Inline editor error; Save/Calculate disabled depending on context. |
| Category weights do not sum to 100% | Inline aggregate error near category weights; Calculate disabled. |
| Category has no tickers | Warning badge and explanatory text; user should fix before calculation. |
| Missing ticker price or moving average | Inline row error; Calculate disabled and detail list available. |
| Calculation service throws | Alert or result-screen error with a plain-language explanation and recovery action. |
| Save history fails | Non-destructive error; keep result visible so the user can retry. |

The app should avoid surprising modal errors for issues already visible inline. Alerts are appropriate for service failures, destructive actions, and unexpected persistence errors.

---

## 8. Contribution Result Flow

1. User taps **Calculate** from Portfolio Detail.
2. View model runs app validation: budget, weights, tickers, and required market inputs.
3. If validation fails, the app keeps the user on the current screen and points to fields needing attention.
4. If validation passes, the app calls the contribution calculation seam.
5. The app receives allocation results and performs app-level contract checks suitable for display and saving, such as non-negative amounts and total matching the portfolio budget within cent-level tolerance.
6. The app displays the Contribution Result screen with total amount and a category-grouped per-ticker breakdown.
7. User taps **Save** to persist an immutable `ContributionRecord` snapshot.
8. User can navigate to History after saving or return to adjust inputs and calculate again.

This spec intentionally does not define the calculation algorithm. The app only defines when calculation is requested, which inputs must be valid, and how returned results are displayed and saved.

---

## 9. Contribution History UI

History is a local-only ledger of saved contribution results. It must remain on device and must never be synced to backend storage.

- Show records newest first.
- Group records by month for scanning.
- Display date and total amount in each row.
- Provide a detail or expandable section showing the full per-ticker breakdown with category names.
- Allow swipe-to-delete for individual records.
- Do not mutate existing records when portfolio names, category names, or tickers are later edited.
- If no records exist, show an empty state that links back to calculation.

History should feel like a record of what the user saw at save time, not a live recalculation of current portfolio state.

---

## 10. Disclaimer UX

The disclaimer from `app/README.md` is required in the app:

> This tool is for informational and educational purposes only. It does not constitute investment advice. Past price trends do not guarantee future performance. Consult a licensed financial advisor before making investment decisions.

Display it during onboarding or first launch, and keep it accessible later from an app information/settings surface if that surface exists in v1.

---

## 11. App Test Strategy

### TDD-First Approach

**Implementation should follow test-driven development (TDD) practices** where appropriate:

- Write tests **before** implementing view model logic, persistence layer, and service protocol contracts.
- Use in-memory SwiftData containers for isolated unit tests without file I/O.
- Test protocol seams (e.g., `ContributionCalculating`, `MarketDataProviding`) as black boxes from the app's perspective.
- For SwiftUI views, prefer snapshot testing or lightweight UI tests over integration tests when possible.

This ensures implementation is tightly coupled to requirements and reduces refactor risk during integration phases. The benefit is clarity on expected behavior early, reducing rework when integrating with services or design review feedback.

### Coverage by Layer

| Layer | Tool | Coverage Target |
|-------|------|-----------------|
| View models | XCTest | **Write tests first.** Validation states, action enablement, error mapping, save/delete flows. |
| SwiftData app persistence | XCTest with in-memory container | **Use in-memory models for isolation.** Portfolio CRUD, category/ticker relationships, history snapshots, cascade behavior visible to the app. |
| Service seam integration | XCTest | **Mock protocol implementations; test the contract, not the implementation.** App calls calculator seam only after validation and handles success/failure responses. |
| SwiftUI screens | XCUITest | Happy path: create portfolio → add category/ticker data → calculate → save → view history. |
| iPad layout | XCUITest or targeted UI tests | Split-view navigation and detail selection on iPad-size destinations. |
| Onboarding flow | XCUITest | First-run disclaimer, empty-state prompt, first portfolio creation, and immediate holdings setup. |
| Snapshot testing | Optional | Key screens across compact iPhone, large iPhone, and iPad if the project adopts a snapshot tool. |

### Test Scope Boundaries

The app test suite should not test algorithm internals. It should test the protocol contract from the app's perspective: valid inputs are passed, invalid inputs are blocked, returned allocations render correctly, and saved history matches the displayed result.

**Test behavior, not implementation.** A SwiftUI view test should verify that errors are displayed, not that a specific `.alert()` modifier was used.

---

## 12. App Implementation Phases

| Phase | Scope | Depends On |
|-------|-------|------------|
| **P0 — App Shell & Local Models** | App entry point, SwiftData container, local models, disclaimer placement. | — |
| **P1 — Portfolio CRUD** | Portfolio List, Portfolio Editor, basic Portfolio Detail. | P0 |
| **P2 — Holdings Editor** | Category/ticker editing, ordering, manual market inputs, inline validation. | P1 |
| **P3 — Calculation Seam & Result UI** | Contribution calculator protocol integration, stub/manual market-data path, result screen, app-level contract checks. | P1, P2 |
| **P4 — History UI** | Save contribution records, grouped history list, detail/expandable breakdown, delete flow. | P3 |
| **P5 — Optional Backend Sync Adapter** | Configuration-gated sync for portfolio/flattened holding state only; categories remain local-only and contribution history never syncs. | P1–P2 |
| **P6 — Mobile UX Polish** | iPad split view, empty states, accessibility labels, keyboard/numeric input polish, final validation messages. | P1–P5 |
| **P7 — App Test Pass** | View-model tests, SwiftData in-memory tests, XCUITest happy path, iPad smoke coverage, offline/sync-unavailable smoke coverage. | P1–P6 |

Each phase should be mergeable independently. Local app progress must not couple to backend availability or algorithm implementation work; sync work should remain optional and configuration-gated from the user's perspective.

---

## 13. References to Split Specs

- **Services/backend spec:** Owns API, poller, networking provider behavior, market data service design, push notification service design, and backend sync transport behavior.
- **Database spec:** Owns backend schema, migrations, constraints, service persistence, flattened holdings mapping, and any future backend representation of categories.
- **This app spec:** Owns native mobile UX, SwiftUI/SwiftData app behavior, app validation, service seams from the client perspective, local-only category/history UX, and app/UI tests.

Treat `docs/tech-spec.md` as source history only and keep app decisions in this document.
