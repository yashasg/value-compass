# Value Compass — v1 Technical Specification

> **Status:** Draft
> **Author:** Danny (Lead/Architect)
> **Date:** 2026-05-12
> **Target:** iOS 17+ / iPadOS 17+, local-first, offline-capable

---

## 1. Product Goal

Value Compass helps users practice **value cost averaging** (VCA) by computing a
target contribution amount for each investment period. The user defines a
portfolio of categories and tickers, sets a monthly budget, and the app tells
them how much to invest in each ticker based on a moving-average signal.

**V1 is an offline-first iOS/iPadOS app.** No backend dependency. Market data is
entered manually or stubbed. The algorithm is owned by the user — the app
provides the scaffolding, UI, persistence, and a protocol seam the algorithm
plugs into.

---

## 2. Non-Goals (v1)

| # | Non-Goal | Rationale |
|---|----------|-----------|
| 1 | Implement the VCA/moving-average algorithm | User-owned; we define the seam only |
| 2 | Live market data | Stub/manual values; backend poller comes later |
| 3 | Backend sync / Supabase | Local-first; backend scaffolding exists but is not wired |
| 4 | Per-ticker weight customization | Equal split within category for v1 |
| 5 | Push notifications | Requires backend + APNs; deferred |
| 6 | Brokerage integration | Out of scope entirely |
| 7 | Multiple devices / cloud sync | Single-device, local data |

---

## 3. V1 Scope

- Create, edit, delete **portfolios**
- Each portfolio has a name, monthly budget, and MA window (50 or 200)
- Organize holdings into **categories** with a category weight (% of budget)
- Add/remove **tickers** within categories (equally split, no per-ticker weight)
- Manually enter or stub **current price** and **moving average** per ticker
- Run the **contribution calculation** → per-ticker target amounts
- View and persist **contribution history** locally
- Disclaimer screen (required; text already defined in iOS README)

---

## 4. Domain Model

```
Portfolio
├── id: UUID
├── name: String
├── monthlyBudget: Decimal
├── maWindow: Int            // 50 | 200
├── createdAt: Date
└── categories: [Category]

Category
├── id: UUID
├── name: String             // e.g. "US Large Cap", "International"
├── weight: Decimal          // 0.00–1.00, sum across categories = 1.00
├── sortOrder: Int
└── tickers: [Ticker]

Ticker
├── id: UUID
├── symbol: String           // e.g. "VOO"
├── currentPrice: Decimal?   // manual entry or stub; nil = not yet entered
├── movingAverage: Decimal?  // manual entry or stub; nil = not yet entered
└── sortOrder: Int

ContributionRecord
├── id: UUID
├── portfolioId: UUID
├── date: Date
├── totalAmount: Decimal
├── breakdown: [TickerAllocation]

TickerAllocation
├── tickerSymbol: String
├── categoryName: String
├── amount: Decimal          // rounded to cents
```

### Key Constraints

| Constraint | Rule |
|------------|------|
| Category weights | Must sum to 1.00 within a portfolio |
| Ticker split | Equal split: `categoryBudget / tickerCount` |
| Rounding | Round each ticker amount to 2 decimal places; assign remainder to the largest (or most-underweight) ticker |
| MA window | Constrained to `{50, 200}` (matches backend `ck_portfolios_ma_window`) |
| Budget | Must be > 0 |

### Relationship to Backend Model

The existing backend defines `Portfolio → Holding` with per-holding `weight`.
V1 introduces a `Category` layer. When backend sync is added later, the mapping
is:

- Each `Category` maps to a group of `Holding` rows sharing a computed weight
  (`category.weight / category.tickers.count`)
- The `Category` entity lives client-side only until the backend schema evolves

This is a **deliberate divergence** — the local model is richer than the backend
model, and the backend will be extended to match when sync is built.

---

## 5. Local Data / Storage

**Engine:** SwiftData (iOS 17+)

| Why SwiftData | Trade-off |
|---------------|-----------|
| Native Apple framework, zero dependencies | Newer than Core Data, smaller community |
| `@Model` macro reduces boilerplate | Migration tooling less mature than Core Data |
| CloudKit sync available later if needed | Ties to Apple ecosystem (acceptable for iOS-only v1) |

### Schema

SwiftData `@Model` classes mirror the domain model in §4. Stored in the app's
default container (`ModelContainer`). No encryption in v1 (no sensitive financial
data — just ticker symbols and target amounts).

### Persistence Rules

- All CRUD is synchronous on the main actor (small data set, simple queries)
- `ContributionRecord` is append-only — never edited, only deleted
- Cascade delete: deleting a Portfolio deletes its Categories, Tickers, and
  ContributionRecords

---

## 6. Screen / Flow Outline

```
App Launch
  │
  ▼
Portfolio List
  │  ├── [+] Create Portfolio → Portfolio Editor (name, budget, MA window)
  │  └── Tap portfolio →
  ▼
Portfolio Detail
  │  ├── Summary: name, budget, category breakdown
  │  ├── Categories listed with weights and ticker counts
  │  ├── [Edit] → Category/Ticker Editor
  │  └── [Calculate] → Contribution Result
  ▼
Category / Ticker Editor
  │  ├── Add/remove categories, set weights
  │  ├── Add/remove tickers within a category
  │  ├── Enter current price / moving average per ticker
  │  └── Validation: weights must sum to 100%, budget > 0
  ▼
Contribution Result
  │  ├── Total contribution amount
  │  ├── Per-ticker breakdown (amount, category)
  │  ├── [Save] → persists ContributionRecord
  │  └── [History] → Contribution History
  ▼
Contribution History
     ├── List of past calculations (date, total, expandable breakdown)
     └── Swipe to delete
```

### Navigation

- `NavigationStack` (iPhone) / `NavigationSplitView` (iPad)
- No tab bar in v1 — single navigation hierarchy rooted at Portfolio List

---

## 7. Service Seams & Stubs

### 7.1 Contribution Calculator Protocol

The algorithm is **not implemented by the team**. We define a Swift protocol and
ship a placeholder implementation. The user provides the real implementation.

```swift
/// The single seam for the VCA algorithm.
/// The app calls `calculate()`; the user owns the implementation.
protocol ContributionCalculating {
    /// Given a portfolio and its current market data, return per-ticker
    /// target contribution amounts.
    ///
    /// - Parameter portfolio: Fully populated portfolio with categories,
    ///   tickers, and their current price / moving average values.
    /// - Returns: An array of ticker allocations summing to
    ///   `portfolio.monthlyBudget`.
    /// - Throws: `CalculationError` if input data is incomplete.
    func calculate(for portfolio: Portfolio) throws -> [TickerAllocation]
}

enum CalculationError: Error {
    case missingMarketData(ticker: String)
    case invalidWeights            // category weights don't sum to 1.0
    case zeroBudget
}
```

**Placeholder behavior:** The stub implementation ignores moving averages and
splits the budget proportionally by category weight, then equally among tickers
within each category. This lets the full UI/UX flow work end-to-end before the
real algorithm is plugged in.

### 7.2 Market Data Provider Protocol

```swift
/// Seam for market data. V1: manual entry. Later: backend polling.
protocol MarketDataProviding {
    func currentPrice(for ticker: String) async throws -> Decimal
    func movingAverage(for ticker: String, window: Int) async throws -> Decimal
}
```

**V1 implementation:** Reads from the `Ticker.currentPrice` and
`Ticker.movingAverage` fields the user entered manually. No network calls.

**Later:** A `BackendMarketDataProvider` conformance will call the existing
`vca-api` which reads from `stock_cache` populated by `vca-poller`.

---

## 8. Contribution Calculation Boundary

```
User taps [Calculate]
        │
        ▼
  Validate inputs
  ├── All category weights sum to 1.0?
  ├── Budget > 0?
  ├── Every ticker has currentPrice and movingAverage?
  │   (if not → show error, list missing tickers)
        │
        ▼
  Call ContributionCalculating.calculate(for:)
  (user-owned algorithm — opaque to us)
        │
        ▼
  Receive [TickerAllocation]
  ├── Verify sum ≈ monthlyBudget (tolerance: ±$0.01)
  ├── Apply rounding to cents
  ├── Assign remainder to largest/most-underweight ticker
        │
        ▼
  Display Contribution Result screen
  ├── User can [Save] → persists ContributionRecord
```

**Key decision:** The app validates inputs *before* calling the algorithm and
validates outputs *after*. The algorithm is a pure function — it receives clean
data and returns allocations. Rounding is handled by the app, not the algorithm.

---

## 9. History Persistence

- `ContributionRecord` is saved to SwiftData when the user taps [Save]
- Each record captures a snapshot: date, total, and full per-ticker breakdown
- Records are **immutable** (append-only) — editing a portfolio does not
  retroactively change history
- Display: grouped by month, newest first
- Deletion: swipe-to-delete on individual records; cascade-delete when portfolio
  is deleted

---

## 10. Validation & Error States

| State | Behavior |
|-------|----------|
| Category weights ≠ 100% | Inline error on editor; [Calculate] disabled |
| Budget ≤ 0 | Inline error; [Calculate] disabled |
| Missing price/MA for any ticker | Alert listing missing tickers; [Calculate] disabled |
| Empty portfolio (no categories) | Empty state with prompt to add a category |
| Category with no tickers | Warning badge; excluded from calculation |
| Algorithm throws `CalculationError` | Alert with error description |
| Algorithm returns amounts not summing to budget | App-side rounding correction; log warning |

---

## 11. Implementation Phases

| Phase | Scope | Depends On |
|-------|-------|------------|
| **P0 — Domain & Storage** | SwiftData models, CRUD for Portfolio/Category/Ticker | — |
| **P1 — Core Screens** | Portfolio List, Portfolio Detail, Category/Ticker Editor | P0 |
| **P2 — Calculator Seam** | `ContributionCalculating` protocol, stub impl, result screen | P0, P1 |
| **P3 — History** | ContributionRecord persistence, history list screen | P2 |
| **P4 — Polish** | iPad layout, input validation UX, disclaimer, empty states | P1–P3 |

Each phase should be a mergeable PR. Estimated total: 2–3 weeks for the team,
assuming the user provides the real algorithm implementation in parallel with P2.

---

## 12. Test Strategy

| Layer | Tool | Coverage Target |
|-------|------|-----------------|
| **Domain model** | XCTest | Category weight validation, rounding logic, cascade rules |
| **SwiftData persistence** | XCTest + in-memory container | CRUD, cascade delete, history append-only |
| **Calculator protocol** | XCTest | Stub returns correct proportional split; error cases |
| **UI flows** | XCUITest | Happy path: create portfolio → add category/ticker → calculate → save |
| **Snapshot** | Optional (swift-snapshot-testing) | Key screens on iPhone SE, iPhone 15, iPad |

**Test principle:** The `ContributionCalculating` protocol is tested via the stub.
When the user provides the real implementation, they are responsible for its unit
tests. The app tests only validate that the protocol contract is honored (output
sums to budget, no negative amounts, etc.).

---

## 13. Open Questions & Blockers

| # | Question | Status | Tracking |
|---|----------|--------|----------|
| 1 | User to provide `ContributionCalculating` implementation (real VCA algorithm) | **Blocked on user** | [Issue #15](https://github.com/yashasg/value-compass/issues/15) |
| 2 | Should contribution history include a "notes" field for user annotations? | Open — not blocking v1, can add later | — |
| 3 | When backend sync is built, will the `Category` concept be added to the backend schema or remain client-only? | Deferred to v2 planning | — |

---

## Appendix A: Repository Layout

| Directory | Purpose |
|-----------|---------|
| `frontend/` | iOS/iPadOS universal app (moved from `ios/`) |
| `frontend/Sources/Models/` | SwiftData `@Model` classes |
| `frontend/Sources/Features/` | One subfolder per screen (PortfolioList, PortfolioDetail, etc.) |
| `frontend/Sources/App/` | App entry point, `ModelContainer` setup |
| `frontend/Sources/Networking/` | **Unused in v1** — no backend calls; later: generated OpenAPI client |
| `frontend/VCA.xcodeproj` | Build target for the universal iOS/iPadOS app |
| `frontend/build.sh` | Builds and tests on iPhone/iPad Simulator; env-configurable iOS/iPadOS version, device types, and platform mode |
| `frontend/run.sh` | Boots/creates simulator, builds, installs, and launches the app; env-configurable device and version |
| `backend/api` | FastAPI v1 API (vc-services); optional sync endpoint for eligible portfolio/holding state |
| `backend/poller` | Background market-data poller; writes to `stock_cache`; scheduled fetches only |
| `backend/db` | Supabase/Postgres schema and Alembic migrations; SQLAlchemy models for `portfolios`, `holdings`, `stock_cache` |
| `backend/common` | Shared utilities between API and poller |
| `docs/` | Technical specifications (app, services, database) |
| `infra/` | Azure Container Apps and deployment configuration |

## Appendix B: Rounding Example

Portfolio budget: $500.00
Categories: US Equity (60%), International (40%)
US Equity tickers: VOO, VTI, SCHD
International tickers: VXUS, VEA

```
US Equity budget:   $500 × 0.60 = $300.00
  VOO:  $300 / 3 = $100.00
  VTI:  $300 / 3 = $100.00
  SCHD: $300 / 3 = $100.00   (clean split)

International budget: $500 × 0.40 = $200.00
  VXUS: $200 / 2 = $100.00
  VEA:  $200 / 2 = $100.00   (clean split)

Total: $500.00 ✓
```

Uneven example — budget $500, category 70%/30%, 3 tickers in first:

```
Cat A budget:  $500 × 0.70 = $350.00
  T1: $350 / 3 = $116.67
  T2: $350 / 3 = $116.67
  T3: $350 / 3 = $116.66   (remainder $0.01 → assigned to T3 or largest)

Cat B budget:  $500 × 0.30 = $150.00
  T4: $150.00

Total: $500.00 ✓
```
