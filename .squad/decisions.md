# Squad Decisions

## Active Decisions

### 2026-05-14: Folder Rename — `frontend/` → `app/`
**By:** Squad loop | **Status:** Adopted | **Issue:** #138

The iOS/iPadOS app folder is renamed from `frontend/` to `app/`. "App" is less ambiguous (avoids collision with the generic web "frontend" classifier) and reads naturally next to `backend/`.

**Scope of change:**
1. **Folder Rename:** `frontend/` → `app/` (preserves `Sources/`, `Tests/`, `VCA.xcodeproj`, `build.sh`, `run.sh` layout — only the parent name changes).
2. **Build artifact path:** Default Xcode DerivedData moves from `build/frontend/xcode-derived-data` to `build/app/xcode-derived-data`. `DERIVED_DATA_PATH` env override unchanged.
3. **CI workflows:** `ios-ci.yml`, `codeql-ios.yml`, `ios-deploy.yml`, and `backend-ci.yml` updated for new path triggers, cache keys, working-directories, and script paths.
4. **OpenAPI mirror:** `backend/api/export_openapi.py` writes the iOS copy to `app/Sources/Backend/Networking/openapi.json`.
5. **Docs:** `README.md`, `app/README.md`, `backend/README.md`, `backend/api/README.md`, `docs/{tech-spec,app-tech-spec,services-tech-spec,design-system-colors,testflight-readiness}.md` updated. The `docs/tech-spec.md` directory table keeps a breadcrumb noting the rename history.
6. **Scripts:** `app/build.sh`/`app/run.sh` error messages refer to "app .xcodeproj" instead of "frontend app .xcodeproj"; `loop.md` validates `app/build.sh`/`app/run.sh`.
7. **`.gitignore`:** All `frontend/...` patterns rewritten to `app/...`.

**Out of scope (intentionally unchanged):**
- Historical entries in `.squad/decisions.md` (this file, below) and `.squad/agents/*/history.md` keep their original `frontend/` references — they record what was true at the time of the decision.
- Generic role keywords like "frontend dev" / "frontend/UI work" in `.squad/templates/*`, `.squad/routing.json`, and `.github/agents/squad.agent.md` describe a software role classification, not the app folder, and stay as-is.
- Xcode project `VCA.xcodeproj` paths are all relative to the project file, so no edits to `project.pbxproj` were needed.

**Validation:**
- `bash -n app/build.sh` and `bash -n app/run.sh` clean.
- `app/build.sh --help` and `app/run.sh --help` print usage successfully.
- `PYTHONPATH=backend python3 -m api.export_openapi --check` confirms the OpenAPI document is unchanged at the new mirror path.
- `.github/scripts/validate-secrets.sh` passes.

**Affected:** All — every developer command, CI workflow, and doc reference now uses `app/`.

---

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

7. **Frontend Folder Convention (19:57 UTC):** The iOS frontend app folder should be named `frontend`, and the iOS build/run scripts should live inside that folder instead of the repository root.

8. **Root Build Folder (20:05 UTC):** Build outputs should go to the repository root `/build`, with subfolders such as `/build/frontend` and `/build/backend`, so the repo can ignore the root `build/` folder and everything under it.

9. **Manual Apple Deployment (20:07 UTC):** App deployment to Apple should be a manual trigger only, similar to backend deployment. Do not automatically deploy the iOS app to Apple/App Store Connect from push or tag events.

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

### 2026-05-12T19:03:38.836-07:00: User Directive — Fonts for Scaffolding
**By:** yashasg (via Copilot) | **Status:** Active

Do not use SF-only fonts for scaffolding. Use the font set mentioned in the Stitch designs for now, and improve typography later if needed.

**Rationale:** Reflects user preference to leverage Stitch's existing typography (Manrope, Work Sans, IBM Plex Sans) as a starting point rather than defaulting to SF System Font only. Final typography system is a non-blocking design follow-up.

### 2026-05-12T19:05:12.285-07:00: User Directive — App Development Practices
**By:** yashasg (via Copilot) | **Status:** Active

App development GitHub issues should be small and incremental, and app implementation should follow test-driven development (TDD) from the start.

**Rationale:** Ensures issue granularity allows parallel work and independent merges. TDD enforces test coverage and reduces regression risk in core business logic.

### 2026-05-12T19:06:01.000-07:00: App Tech Spec — Reconciliation with Tess Approved Design
**By:** Danny (Lead/Architect) | **Status:** Adopted

App tech spec has been reviewed for conflicts with Tess-approved platform, layout, and flow decisions. No conflicting navigation or flow implementations were found.

**Key Clarifications:**
1. **Onboarding Flow:** Directs users to create their first real portfolio (not demo/sample). Disclaimer as first-run gate; empty-state prompt transitions directly to Portfolio Editor. First-run setup includes name, budget, MA window, and immediate holdings entry in one flow.
2. **TDD-First Practice:** Implementation should use test-driven development. Write tests before implementing view models, persistence, and service contracts. Use in-memory SwiftData for isolated unit tests; mock protocol seams; test behavior, not implementation details.
3. **Test Scope:** Do not test algorithm internals, backend API behavior, or SwiftUI layout pixel precision. Do test protocol contracts, validation rules, persistence, error handling, and happy-path flows.

**Files Updated:** `docs/app-tech-spec.md` (Sections 5 and 11 expanded with explicit onboarding and TDD guidance).

### 2026-05-12T19:05:12-07:00: iOS App TDD Backlog — 12 Incremental Issues
**By:** Basher (iOS Dev) | **Status:** Created

Created 12 incremental GitHub issues for Value Compass iOS/iPadOS v1 app development, following TDD-first methodology. All issues reference the accepted app tech spec and team decisions. No large umbrella issues; each issue builds on prior work and is testable independently.

**Issues Created (TDD-First App Implementation):**
- **#30:** App Test Harness & SwiftData Architecture Skeleton (Foundation)
- **#31:** SwiftData Domain Models & Local Persistence Tests (Portfolio/Category/Ticker/History models)
- **#32:** Portfolio List & Create/Edit Flow Tests (Portfolio CRUD UI, empty state, navigation)
- **#33:** Category & Ticker Editing Tests (Holdings editor, weights validation, ticker uniqueness)
- **#36:** Manual Market Data Input Tests (Ticker price/MA fields, decimal validation)
- **#39:** VCA Calculator Seam & Stub Tests (Protocol definition, proportional-split stub, seam contract)
- **#40:** Contribution Result Screen Tests (Result display, save to history, error handling)
- **#41:** Contribution History Tests (History list, detail view, swipe-to-delete, local-only)
- **#42:** iPhone/iPad Navigation Shell Tests (Adaptive layouts, NavigationStack/SplitView, shared view models)
- **#43:** Appearance & Accessibility Tests (Semantic color tokens, light/dark modes, Dynamic Type, WCAG AA, VoiceOver)
- **#44:** Settings & Disclaimer Tests (Disclaimer on first launch, settings UI, local preferences)
- **#45:** End-to-End Integration Tests (Complete workflow: create→edit→calculate→save→history, offline, multiple portfolios)

**Key Decisions:**
- TDD-first from the start: write tests before implementing
- Incremental boundaries: no issue covers more than one major feature area
- Offline-first validation: all data persists to local SwiftData
- User-owned algorithm: proportional-split stub for testing; real VCA remains user-owned (#15)

### 2026-05-12T19:05:12.285-07:00: Tess App Design Follow-Up Issues — Non-Blocking
**By:** Tess (iOS/iPadOS Designer) | **Status:** Created

Design follow-up issues created to refine visual system, color tokens, typography, and iPad layouts. All non-blocking; app scaffolding may proceed in parallel.

**Issues Created (Design Follow-Ups):**
- **#34:** Design System Refresh: Light/Dark Color Tokens (Replace Stitch palette with accessible, institutional light/dark system; WCAG AA compliance)
- **#35:** Typography System: Font Integration and Dynamic Type (Formalize three-font system, type scale, Dynamic Type support, SF System Font fallbacks)
- **#37:** Onboarding, Disclaimer, and Empty States Design (First-run onboarding flow, prominent legal disclaimer, graceful empty states)
- **#38:** iPad Layout Polish: Split-View Navigation and Adaptive Spacing (Ensure comfortable layouts across iPad sizes, touch targets, readable line lengths, balanced spacing)

**Approach:** Non-blocking follow-ups; Basher implements screens with semantic colors and adaptive layouts; Tess refines visual system later. Once functional MVP is walkable, design tokens are integrated and remaining polish follows.

**Status:** Basher may proceed with functional SwiftUI screen scaffolding using semantic system colors and adaptive layouts.

### 2026-05-13T03:45:16Z: CI/CD Secret Logging Validation
**By:** Livingston (DevOps Engineer) | **Status:** Implemented (PR #51)

Implement mandatory secret logging validation for all CI/CD workflow changes before PR creation.

**Decision:** GitHub secrets should never be echoed or printed to logs where they could be exposed in build artifacts, logs, or console output. The squad loop must enforce this check before PRs are created.

**Implementation:**
1. **Validation script:** `.github/scripts/validate-secrets.sh`
   - Detects unsafe patterns: echo/printf of SECRET, PASSWORD, API, KEY, TOKEN variables
   - Excludes safe patterns: piped commands, file redirects
   - Returns exit code 0 if all workflows pass, 1 if unsafe patterns found

2. **Loop enforcement:** Updated `loop.md` step 3
   - All squad members must run validation before creating PRs
   - Validation failure blocks PR creation

**Impact:**
- **Backend team:** No impact — backend-deploy uses secure SSH key handling (file-based, no echo)
- **iOS team:** No impact — ios-deploy uses secure certificate handling (piped base64 decode)
- **Future workflows:** Developers must avoid direct echo of secrets; pipe to commands or redirect to files

**Validation Status:**
- ✓ All current workflows (backend-ci, backend-deploy, ios-deploy, Azure workflows) pass validation
- ✓ Script correctly handles false positives (e.g., `echo | base64` is safe)

**Key Files:**
- `.github/scripts/validate-secrets.sh` — 60-line validation script (executable)
- `loop.md` — added mandatory pre-PR secret validation check (step 3)

**Next Steps:**
- Merge PR #51 to activate validation (✓ completed, merged to main)
- Squad loop enforces validation before each PR creation
- Update onboarding docs to mention this requirement for new developers

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

