# Value Compass — v1 Database/Data Technical Specification

> **Status:** Draft  
> **Author:** Rusty (Backend Dev)  
> **Date:** 2026-05-12  
> **Infrastructure:** Supabase managed Postgres (v1 foundation); optional backend sync when configured  
> **Target:** iOS 17+ / iPadOS 17+, SwiftData offline-first storage with optional backend DB sync when available

---

## 1. Scope and Execution Model

V1 is **hybrid/offline-first**. The iOS app must execute entirely from local
SwiftData storage while offline, and should sync eligible portfolio state to the
backend DB (Supabase managed Postgres) when the backend is available. Supabase is
the **v1 infrastructure foundation** for optional backend sync and future market-data
caching. However, Supabase, the backend API, the poller, or any network-accessible
database must not be required for core app use.

This spec separates two data models that intentionally coexist:

1. **V1 local SwiftData model** — the required app runtime model for portfolios,
   categories, tickers, manual market inputs, and contribution history.
2. **V1 backend DB sync model** — the existing Postgres/SQLAlchemy model used
   when sync is available. It stores portfolios and flattened holdings only, not
   local categories, manual market inputs, or contribution history.

No backend schema changes are required for v1; sync must adapt to the existing
flat backend holdings schema.

---

## 2. V1 Local SwiftData Model

### 2.1 Entities

#### Portfolio

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | `UUID` | Yes | Stable local identifier |
| `name` | `String` | Yes | User-visible portfolio name |
| `monthlyBudget` | `Decimal` | Yes | Must be greater than zero |
| `maWindow` | `Int` | Yes | Allowed values: `50`, `200` |
| `createdAt` | `Date` | Yes | Set at creation |
| `categories` | `[Category]` | Yes | Ordered by `sortOrder` |

#### Category

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | `UUID` | Yes | Stable local identifier |
| `name` | `String` | Yes | Example: `US Large Cap` |
| `weight` | `Decimal` | Yes | Fractional share of budget: `0.00...1.00` |
| `sortOrder` | `Int` | Yes | Stable display order within portfolio |
| `portfolio` | `Portfolio` | Yes | Parent relationship |
| `tickers` | `[Ticker]` | Yes | Ordered by `sortOrder` |

#### Ticker

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | `UUID` | Yes | Stable local identifier |
| `symbol` | `String` | Yes | User-entered ticker symbol, normalized for comparisons |
| `currentPrice` | `Decimal?` | No | Manual/local market input; not synced in v1 |
| `movingAverage` | `Decimal?` | No | Manual/local market input for portfolio `maWindow`; not synced in v1 |
| `sortOrder` | `Int` | Yes | Stable display order within category |
| `category` | `Category` | Yes | Parent relationship |

#### ContributionRecord

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | `UUID` | Yes | Stable local identifier |
| `portfolioId` | `UUID` | Yes | Snapshot owner reference; local-only |
| `date` | `Date` | Yes | Calculation save time |
| `totalAmount` | `Decimal` | Yes | Saved contribution total |
| `breakdown` | `[TickerAllocation]` | Yes | Immutable snapshot of per-ticker output |

#### TickerAllocation

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `tickerSymbol` | `String` | Yes | Snapshot of ticker symbol at calculation time |
| `categoryName` | `String` | Yes | Snapshot of category name at calculation time |
| `amount` | `Decimal` | Yes | Rounded to cents |

`TickerAllocation` can be modeled either as a SwiftData child model owned by
`ContributionRecord` or as a Codable value embedded in the record, depending on
implementation ergonomics. The invariant is that history stores a snapshot and
does not depend on current ticker/category names.

### 2.2 Relationships

```text
Portfolio 1 ── * Category 1 ── * Ticker
Portfolio 1 ── * ContributionRecord 1 ── * TickerAllocation
```

- A `Category` cannot exist without a `Portfolio`.
- A `Ticker` cannot exist without a `Category`.
- A `ContributionRecord` belongs to one portfolio by `portfolioId`.
- `ContributionRecord.breakdown` captures immutable value snapshots; it must not
  be recomputed from current portfolio structure when displayed.

### 2.3 Constraints

| Constraint | Rule |
|------------|------|
| Portfolio budget | `monthlyBudget > 0` |
| MA window | `maWindow ∈ {50, 200}` |
| Category weights | Sum within a portfolio must equal `1.00` for calculation |
| Category weight range | Each category weight must be `>= 0` and `<= 1` |
| Ticker split | V1 splits each category weight equally across that category’s tickers |
| Ticker symbols | Trim whitespace; compare case-insensitively after normalization; no duplicate ticker may appear anywhere within one portfolio |
| Market data | Each included ticker needs `currentPrice` and `movingAverage` before calculation |
| Contribution amounts | Non-negative and rounded to cents |
| Contribution total | Saved allocation total must equal budget within cent-level tolerance |

### 2.4 Cascade, Delete, and History Rules

- Deleting a `Portfolio` deletes its local `Category`, `Ticker`, and
  `ContributionRecord` data; backend sync should delete the corresponding
  portfolio and flattened holdings if present.
- Deleting a `Category` deletes its child `Ticker` rows.
- Deleting a `Ticker` removes it from future calculations only.
- `ContributionRecord` is append-only after save. Do not edit saved records.
- Portfolio/category/ticker edits do not mutate prior history.
- Users may delete individual contribution records from history.
- History display should sort newest first and may group by month.
- Contribution history is strictly local-only in v1 and must never sync to the
  backend DB.

### 2.5 Category-vs-Holding Mapping

The v1 local model keeps `Category` as a first-class local-only entity. The
backend model has no category table and represents investable rows as
`Holding(ticker, weight)` directly under a portfolio.

V1 sync flattens local categories into backend holdings:

```text
backend_holding.weight = category.weight / category.tickers.count
```

Example:

```text
Category: US Equity, weight 0.60, tickers [VOO, VTI, SCHD]
Backend holdings:
  VOO  weight 0.20
  VTI  weight 0.20
  SCHD weight 0.20
```

This mapping is lossy because backend holdings do not preserve category name,
category sort order, or ticker grouping. Therefore, categories remain local-only
in v1 and the SwiftData category model remains the richer source of truth.
Inbound sync from backend holdings can reconstruct only flat ticker weights, not
original category grouping, unless future schema changes add category support.
Because duplicate tickers are disallowed anywhere within a portfolio, each
flattened backend holding maps to at most one local ticker symbol.

### 2.6 V1 Sync Eligibility

| Local data | Backend v1 sync behavior |
|------------|--------------------------|
| Portfolio metadata (`name`, `monthlyBudget`, `maWindow`) | Sync to `portfolios` when backend is available |
| Category identity, name, order, grouping | Do not sync; categories are local-only |
| Ticker symbol | Sync only as flattened `holdings.ticker` |
| Category/ticker weight | Sync as flattened `holdings.weight = category.weight / ticker_count` |
| Manual `currentPrice` / `movingAverage` | Do not sync; local/manual v1 inputs only |
| Contribution history and `TickerAllocation` snapshots | Never sync; local-only ledger |

The sync layer must validate portfolio-wide ticker uniqueness before writing
backend holdings. If local category grouping cannot be represented by the flat
backend model, local SwiftData remains authoritative and backend data must not
destructively overwrite local categories.

---

## 3. Existing Backend DB Model Alignment

The backend DB is a Supabase-hosted managed Postgres instance. It is modeled with
SQLAlchemy/Alembic in `backend/db`. In hybrid v1, its role is optional sync
persistence for eligible portfolio metadata and flattened holdings whenever the
backend is reachable; it is not required for offline app execution.

### 3.1 Backend Entities

#### `portfolios`

| Column | Type | Required | Notes |
|--------|------|----------|-------|
| `id` | UUID | Yes | Primary key |
| `device_uuid` | UUID | Yes | Device owner identifier; no user accounts |
| `name` | Text | Yes | Portfolio name |
| `monthly_budget` | Numeric | Yes | Budget amount |
| `ma_window` | Integer | Yes | Check constrained to `50` or `200` |
| `created_at` | Timestamptz | Yes | Creation timestamp |

#### `holdings`

| Column | Type | Required | Notes |
|--------|------|----------|-------|
| `id` | UUID | Yes | Primary key |
| `portfolio_id` | UUID | Yes | FK to `portfolios.id`, cascade delete |
| `ticker` | Text | Yes | Investable symbol |
| `weight` | Numeric | Yes | Fractional portfolio weight; equals local category weight divided equally across tickers during v1 sync |

#### `stock_cache`

| Column | Type | Required | Notes |
|--------|------|----------|-------|
| `ticker` | Text | Yes | Primary key |
| `current_price` | Numeric | Yes | Latest cached price |
| `sma_50` | Numeric | Yes | 50-day simple moving average |
| `sma_200` | Numeric | Yes | 200-day simple moving average |
| `last_modified` | Timestamptz | Yes | Last successful/attempted refresh timestamp |
| `next_modified` | Timestamptz | No | Only set after successful refresh |
| `job_status` | Text | Yes | Check constrained to `success` or `failed` |

### 3.2 Backend Relationships and Constraints

```text
portfolios 1 ── * holdings
stock_cache is keyed independently by ticker
```

- `holdings.portfolio_id` cascades on portfolio delete.
- `Portfolio.holdings` uses SQLAlchemy `cascade="all, delete-orphan"`.
- `portfolios.ma_window` is constrained by `ck_portfolios_ma_window`.
- `stock_cache.job_status` is constrained by `ck_stock_cache_job_status`.
- `stock_cache` is one row per ticker and update-only; it is not contribution
  history and does not store v1 manual/local market inputs.
- `next_modified` is only written when `job_status = 'success'`.

### 3.3 Backend Gaps vs V1 Local Model

| V1 Local Concept | Backend Status | V1 Impact |
|------------------|----------------|-----------|
| `Category` | Not represented | Local-only; flatten to holdings for sync |
| Category `sortOrder` | Not represented | Local-only; not recoverable from backend |
| Ticker `sortOrder` | Not represented | Local-only; not recoverable from backend |
| Manual `currentPrice` / `movingAverage` per ticker | Backend has shared `stock_cache`, not per-portfolio manual inputs | Local-only; never sync v1 manual inputs |
| `ContributionRecord` / history | Not represented | Local-only; never sync to backend |
| `TickerAllocation` snapshot | Not represented | Local-only; never sync to backend |
| Device-local SwiftData IDs | Backend uses UUID primary keys | V1 sync mapping needed for synced portfolios/holdings |

### 3.4 Deferred Backend Schema Changes

The following backend schema changes are **deferred** and not blockers for v1:

- Add category persistence (`categories` table) if backend sync must preserve
  user grouping.
- Add ordering columns for categories and holdings/tickers.
- Do not add contribution-history sync tables for v1; contribution history must
  remain local-only. Any future analytics must be explicitly separate from
  syncing user contribution ledgers.
- Add explicit constraints for positive budgets and holding weights if backend
  writes become user-facing.
- Add backend uniqueness/indexing support such as `(portfolio_id, ticker)` to
  mirror the v1 invariant that duplicate tickers are disallowed anywhere within
  a portfolio.
- Add migration support for category-to-holding round trips if categories become
  backend-owned.

No GitHub issues are required now because these are non-blocking schema evolution
questions; hybrid v1 sync must work within the existing flat backend model.

---

## 4. Migrations and Versioning

### 4.1 Local SwiftData

- V1 should ship with an explicit model version even if the initial migration is
  empty/trivial.
- Additive local schema changes are preferred: add optional fields or new models
  before requiring destructive migration.
- History snapshots must remain readable across local model versions.
- If a future migration changes how allocations are represented, preserve the
  rendered historical fields: date, total, ticker symbol, category name, amount.
- No local schema migration is required solely to support v1 backend sync.

### 4.2 Backend Postgres/Alembic

- Backend migrations are managed by Alembic under `backend/db/migrations`.
- Deploys run `alembic upgrade head` before restarting backend services.
- Existing backend policy is additive-only for deployed schema changes: add
  columns/tables rather than removing or renaming existing ones.
- Downgrades may exist for local development convenience but are not a deployment
  rollback mechanism.
- Backend DB versioning should not gate offline app releases because the app can
  run without the backend DB, but sync-enabled builds must remain compatible with
  the deployed flat portfolio/holding schema.

---

## 5. Validation Invariants

These invariants should be enforced at the app/domain boundary before
calculation and before persistence where applicable:

1. Portfolio name is non-empty after trimming.
2. Monthly budget is positive.
3. MA window is exactly `50` or `200`.
4. Category names are non-empty after trimming.
5. Category weights are in range and sum to `1.00` for calculation.
6. Empty categories may be edited/saved, but calculation must warn or exclude
   them consistently with the app spec.
7. Ticker symbols are non-empty after trimming.
8. Ticker symbol comparisons are normalized to avoid duplicates anywhere within
   the same portfolio, including across different categories.
9. Included tickers have both `currentPrice` and `movingAverage`.
10. Contribution outputs are non-negative.
11. Contribution output total equals `monthlyBudget` within ±$0.01 before final
    cent reconciliation.
12. Saved history is immutable and displays from stored snapshots, not current
    portfolio state.

Backend-only invariants remain aligned with existing schema constraints:

1. `portfolios.ma_window ∈ {50, 200}`.
2. `holdings.portfolio_id` must reference an existing portfolio.
3. Deleting a backend portfolio cascades to holdings.
4. `stock_cache.job_status ∈ {'success', 'failed'}`.
5. `stock_cache.next_modified` is only populated on successful refresh.

---

## 6. DB/Data Test Strategy

### 6.1 Local SwiftData Tests

Use XCTest with an in-memory SwiftData container.

| Area | Coverage |
|------|----------|
| CRUD | Create, fetch, update, and delete portfolios/categories/tickers |
| Relationships | Portfolio-category-ticker traversal and ordering |
| Cascades | Portfolio delete removes categories, tickers, and history |
| Category delete | Category delete removes child tickers |
| Validation | Budget, MA window, weight sum, missing market data, portfolio-wide ticker normalization/uniqueness |
| History | Save immutable contribution records with snapshot allocations |
| Rounding persistence | Stored allocation totals match budget after cent reconciliation |
| Migration smoke | Current model opens seeded v1 data without data loss |

### 6.2 Backend DB Tests

Backend DB tests remain focused on the existing Postgres model and Alembic
schema, independent of the offline v1 app runtime:

| Area | Coverage |
|------|----------|
| Model metadata | SQLAlchemy models match migration-created tables |
| Constraints | `ma_window` and `job_status` checks reject invalid values |
| Cascade | Deleting a backend portfolio removes holdings |
| Stock cache | Upsert/update behavior keeps one row per ticker |
| Migration | Fresh database upgrades from base to head |
| Additive policy | Future migrations avoid destructive deployed changes |

### 6.3 Contract Alignment Tests

For hybrid v1 sync, add focused tests for:

- Flattening categories into holdings with equal ticker splits.
- Detecting lossy fields that cannot round-trip through the current backend.
- Preserving local categories as the source of truth and avoiding destructive
  inbound overwrites when backend data cannot represent grouping.
- Ensuring contribution history and manual market inputs are never uploaded.

These tests cover the optional sync path; the offline local path must continue to
pass without a backend.

---

## 7. Non-Blocking Open Questions

| # | Question | Status |
|---|----------|--------|
| 1 | Should backend sync eventually preserve categories as first-class rows or flatten them permanently into holdings? | V1 flattens; first-class backend categories deferred |
| 2 | Should contribution history sync to backend or remain device-local indefinitely? | V1 decision: local-only and never synced |
| 3 | Should duplicate ticker symbols be allowed across different categories in one portfolio? | V1 decision: no duplicates anywhere within one portfolio |
| 4 | Should manual market data be stored as ticker fields only, or as dated observations later? | V1 decision: manual/local fields only; no backend sync |

No additional user-blocking DB decision is required for hybrid/offline-first v1 execution.
