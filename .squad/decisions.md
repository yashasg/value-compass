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

5. **Stitch Scope (16:56 UTC):** Hold off on Tess's standalone app design work. The user will provide Stitch designs; Tess should review and approve those designs before the team proceeds.

6. **Stitch as Functional Scaffolding (17:02 UTC):** Treat Stitch screen content as placeholder. Focus on building functionality first. User does not prefer the current color scheme and is mainly a starting point. Tess may propose a better color scheme and design system later.

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

### 2026-05-12: Stitch Screens as Functional Scaffolding, Not Visual Spec
**By:** Tess (iOS/iPadOS Designer) with user clarification | **Status:** Active

After user clarification, the Stitch `stitch_value_compass_vca_calculator` designs are reframed as functional scaffolding, not a final visual specification.

**Direction:**
1. **Stitch = functional scaffolding only.** Use to confirm screen inventory, navigation, and field-level intent. Do not treat its copy, iconography, or color palette as canonical.
2. **Functionality first.** Engineering should build against data model and flows, not pixel-match Stitch. SwiftUI views may use placeholder styling and system colors during MVP.
3. **New design system later.** Tess will propose a replacement color scheme, typography scale, and component tokens after functional MVP is walkable; this becomes a follow-up design pass, not a blocker.
4. **Review gating narrows.** Approval-blocking questions now limited to product/UX decisions affecting data model and implementation order (calculation methodology, persistence, watchlist scope, auth, units, offline). Visual-fidelity and content-copy questions deferred.

**Unblocks:** Engineering can start scaffolding screens and models in parallel without waiting for visual design finalization.

### 2026-05-12T17:02:11.019-07:00: Tess — Platform, layout, and appearance scope for v1
**By:** Tess (iOS/iPadOS Designer) | **Status:** Adopted

Value Compass v1 design scope is now concrete and approved.

**Scope:**
- **Platform:** Both iPhone and iPad with adaptive layouts: `NavigationStack` on iPhone (compact width), `NavigationSplitView` on iPad (regular width). No bottom tab bar in v1.
- **Appearance:** Both light and dark mode via semantic system colors and asset catalog color sets — no hard-coded hex in views. Stitch's coral-on-navy is provisional only.
- **Visual System:** Stitch screens are functional scaffolding (screen inventory, fields, navigation). Final palette, typography, iconography, spacing will be proposed by Tess after functional MVP is walkable.
- **Approved screens:** Onboarding/first-run, Portfolio list (iPad sidebar), Portfolio detail/dashboard, Create/Edit Portfolio, Category list/edit, Ticker add/edit (manual market value + per-ticker moving-average inputs), Contribution input/result/history, Settings (local-only, no account UI), Disclaimer.
- **Accessibility:** Dynamic Type, VoiceOver labels, WCAG AA contrast in both appearances, no color-only signaling (pair with arrows or +/− text).

**Why:** User directive (iPhone+iPad, light+dark) + v1 is local/offline-first, no auth, categories local-only. Aligns design scope with engineering scope.

**Impact:**
- **Basher:** unblocked to scaffold SwiftUI screens for both size classes and appearances using semantic colors. Report feasibility on adaptive navigation and contribution flows.
- **Rusty / Linus:** no change — SwiftData and services already account for this scope.

### 2026-05-12T17:02:11.019-07:00: SwiftUI Stitch Scaffold Feasibility — ADOPTED
**By:** Basher (iOS Dev) | **Status:** Adopted

SwiftUI scaffolding is feasible for universal iPhone/iPad support and light/dark mode without duplicating core screen logic.

**Key Findings:**
1. **Navigation:** `NavigationSplitView` on iPad and `NavigationStack` on iPhone share the same Portfolio→Category→Ticker view models using a shared route/selection model and screen components. Only the shell is adaptive: compact width drives stack pushes/sheets; regular width drives sidebar/content/detail selection. Core business logic is not forked by device class.

2. **Semantic colors:** Asset Catalog color sets support light/dark mode without per-view conditionals. Use `Color("TokenName")`/design-token wrappers with asset variants switching by appearance. Token categories include: app/background surfaces, elevated surfaces/cards, primary/secondary action, content primary/secondary/tertiary, borders/dividers, validation/status, financial positive/negative/neutral, input background/focus/disabled, selection/highlight, and chart/category accents.

3. **SwiftData observation:** Keep `@Query` at list/history boundaries and pass selected model IDs or references into focused screens. For create/edit forms, use draft form state and commit in one save to avoid live partial mutations. Contribution history queries immutable `ContributionRecord` snapshots by `portfolioId`, sorted newest-first. Calculation uses an explicit validated input snapshot so edits during navigation do not alter already-produced results.

4. **Scaffolding order:** (1) App shell with adaptive navigation, semantic tokens, disclaimer route, local settings. (2) Onboarding/disclaimer first-launch gate. (3) Portfolio list. (4) Create/edit portfolio. (5) Portfolio detail/dashboard. (6) Category edit. (7) Ticker edit with manual market inputs. (8) Contribution input/validation. (9) Contribution result. (10) Contribution history. (11) Settings/disclaimer.

5. **Blockers:** None. User clarification is not needed before implementation for navigation, dark/light mode, local settings, no account UI, no tabs, or manual market inputs. Open non-blocking items: final Tess palette/typography, final user-supplied VCA algorithm, future backend sync/category round-trip behavior.

**Why:** Preserves v1 decisions (universal iOS/iPadOS, SwiftData local-first, Portfolio→Category→Ticker, manual market inputs, local-only settings/history, no account UI, no tabs, semantic colors, provisional SF fonts) while treating Stitch as functional scaffolding only.

**Next:** Basher proceeds with SwiftUI scaffolding implementation.

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
