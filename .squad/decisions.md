# Squad Decisions

## Active Decisions

### 2026-05-12: V1 Architecture — Local-First iOS with Protocol Seams
**Author:** Danny (Lead/Architect) | **Status:** Proposed

V1 of Value Compass is an offline-first iOS/iPadOS app. The backend scaffolding exists but is not used in v1. The VCA algorithm is user-owned.

**Key Decisions:**
1. **SwiftData** for local persistence (iOS 17+ baseline). Trade-off: less mature migration tooling vs. simpler API and future CloudKit path.
2. **Category layer** added to the domain model (Portfolio → Category → Ticker). Diverges from backend's flat `Portfolio → Holding` model. Backend schema extended when sync is built.
3. **`ContributionCalculating` protocol** is the single algorithm seam. Proportional-split stub ships with the app. User provides the real VCA implementation.
4. **`MarketDataProviding` protocol** abstracts market data. V1 reads manually-entered values from local Ticker model. Later: calls the backend API.
5. **Input validation before, rounding after** the algorithm call. Algorithm receives clean data and returns raw allocations; app rounds to cents.

**Affected:** All — shapes v1 implementation surface.

### 2026-05-12: Tech Specs Split into App, Services, and Database
**By:** Coordinator (Danny, Basher, Rusty, Linus) | **Status:** Adopted

The combined v1 technical specification has been split into three focused documents:

**App Tech Spec** (`docs/app-tech-spec.md`) — Basher
- iOS/iPadOS concerns: SwiftUI/SwiftData app behavior, navigation, validation UX, app service seams
- Contribution-result flow, history UI, app/UI test strategy, implementation phases
- Algorithm internals, backend services, and database schema are intentional references only

**Services Tech Spec** (`docs/services-tech-spec.md`) — Linus
- V1 services defined as local protocol seams (`ContributionCalculating`, `MarketDataProviding`)
- No required backend/OpenAPI client consumption until later phases
- Stable seams now without coupling v1 delivery to API, poller, or generated networking work

**Database Tech Spec** (`docs/db-tech-spec.md`) — Rusty
- SwiftData model is the required runtime data model for v1
- Existing backend Postgres/SQLAlchemy schema documented for future sync (deferred)
- iOS can implement SwiftData without waiting on backend schema changes
- Future sync must handle lossy `Category → Holding` flattening

### 2026-05-12: User Directives
**By:** yashasg (via Copilot) | **Status:** Active

1. **Moving Average Algorithm (15:56 UTC):** For v1, target moving average for value cost averaging, but do NOT implement the algorithm yet. The user will handle the algorithm. Build on existing scaffolding. For anything needed from the user to unblock work, create GitHub issues and assign them to yashasg.

2. **Tech Spec Split (16:12 UTC):** The project should have separate technical specifications for app, services, and database rather than one combined tech spec.

3. **Tess UI/UX Design (16:30 UTC):** Tess should design the user flow, screens, color scheme, dark mode and light mode, and fonts for the app, using Swift and Apple design systems.

4. **Small Incremental Issues (16:34 UTC):** GitHub implementation issues for services and database work should be small, incremental issues that build on top of each other rather than one massive issue.

### 2026-05-12: App Implementation — Offline-First Backend Sync Alignment
**Author:** Basher (iOS Dev) | **Status:** Adopted

The app implements v1 as hybrid/offline-first: SwiftData is the primary runtime source of truth and all core UX works offline, while backend sync runs when configured and available.

**Key Constraints:**
- Manual/local market inputs are the v1 source for current value and moving-average fields.
- Categories remain local-only in v1.
- Backend sync flattens local category/ticker state into backend holdings without preserving names, order, or grouping.
- Contribution history is local-only and never syncs to backend storage.
- The real VCA algorithm remains user-owned and should not be implemented by the team yet.

### 2026-05-12: Tess Joins Squad as iOS/iPadOS Designer
**By:** Coordinator | **Status:** Active

Tess added to Squad with focus on iOS/iPadOS design. Priorities: smooth onboarding and app usage. User directive: prioritize smooth onboarding and app usage.

### 2026-05-12: Services Boundaries — Hybrid/Offline-First
**Author:** Linus (Integration Engineering) | **Status:** Adopted

V1 is hybrid/offline-first: the app runs fully offline from local data; optional backend availability syncs eligible portfolio/configuration data.

**Boundaries:**
- `ContributionCalculating` remains app-local; algorithm user-owned.
- `MarketDataProviding` uses manual local current value / moving-average fields in v1.
- `PortfolioSyncing` is optional and separate; sync failures do not block calculation.
- Future Swift networking is generated from FastAPI/OpenAPI; generated clients are not hand-edited.
- API serves cached market data; poller refreshes `stock_cache`; API may trigger async fetches for new tickers.

### 2026-05-12: Database Constraints — Hybrid/Offline-First V1
**Author:** Rusty (Backend Dev) | **Status:** Adopted

V1 backend is optional sync persistence for portfolios and flattened holdings.

**Constraints:**
- Categories remain local-only. Backend sync flattens: `holding.weight = category.weight / category.tickers.count`.
- Duplicate ticker symbols disallowed within one portfolio across all categories.
- Contribution history, snapshots, manual current values, manual moving-average inputs are local-only and never sync.
- Backend Postgres schema (flat holdings) is sufficient; v1 does not block offline app execution.
- iOS preserves local categories as the richer source of truth; backend holdings are a lossy sync projection.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction

## Backlog Issues — DB & Services Implementation

**Created 2026-05-12 from tech specs. Small incremental issues per user directive.**

**Database Issues (Rusty):**
- #16: Flatten SwiftData categories into backend holdings
- #17: Validate portfolio-wide ticker uniqueness/weights before sync
- #18: Test local-only fields never sync
- #19: Test backend DB model/migration invariants
- #20: Document/test hybrid DB boundary mapping

**Services Issues (Linus):**
- #21: FastAPI/OpenAPI source-of-truth workflow
- #22: Generated Swift OpenAPI client workflow
- #23: Optional offline-first PortfolioSyncing boundary
- #24: Category-to-holdings sync safeguards
- #25: Cached market-data API
- #26: Poller stock_cache refresh flow
- #27: Async new-ticker fetch trigger
- #28: Structured service error contract
- #29: Service integration/contract tests
