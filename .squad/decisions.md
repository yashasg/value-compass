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

### 2026-05-12T19:22:02.523-07:00: DevOps Infrastructure & Deployment — User Directives
**By:** yashasg (via Copilot) | **Status:** Active

Infrastructure and deployment approach for Value Compass v1 backend and services.

**Decisions:**

1. **Database Foundation: Supabase Managed**  
   Use Supabase managed database as the v1 infrastructure foundation, prioritizing the fastest backend/sync path with minimal operations overhead.

2. **Backend Deployment: Azure Container Apps**  
   Deploy the v1 FastAPI backend service using Azure Container Apps.

3. **CI/CD Pipeline: Test, Build, Publish — No Auto-Deploy**  
   CI should run tests/builds and publish backend container images, but should not deploy before the app MVP is ready.

4. **Deployment Manual Trigger Only**  
   The Azure-generated GitHub Action may support deployment, but deployment must be manual via `workflow_dispatch`; do not auto-deploy before the app MVP is ready.

5. **No Shared Backend Environments Until MVP**  
   Do not create shared backend environments until the app MVP is ready.

**Why:** User selected these during DevOps discovery. Manual deployment and no shared environments ensure MVP readiness is a hard gate; single-environment constraint reduces operational complexity before v1 approval.

**Related Issue:** [#46 — Fix Azure Container Apps workflow: disable auto-deploy, validate config for MVP](https://github.com/yashasg/value-compass/issues/46)

### 2026-05-12T19:22:02.523-07:00: GitHub Issue #46 — Azure Container Apps Workflow Fix
**By:** Livingston (DevOps Engineer) | **Status:** Created

GitHub issue created to consolidate remediation of the Azure-generated GitHub Actions workflow for Azure Container Apps deployment.

**Issue:** [#46 — Fix Azure Container Apps workflow: disable auto-deploy, validate config for MVP](https://github.com/yashasg/value-compass/issues/46)

**Root Cause:** Workflow run #25774741652 failed due to:
- Auto-deployment on push (violating MVP manual-only policy)
- Invalid placeholder parameters (`_dockerfilePathKey_`, `_targetLabelKey_`)
- Malformed `appSourcePath` (missing `/` between `${{ github.workspace }}` and `backend/api`)
- Missing Azure/ACR secret configuration

**Fixes Applied:**
1. Removed automatic trigger; changed to `workflow_dispatch` only
2. Removed invalid placeholder parameters
3. Fixed `appSourcePath` to `${{ github.workspace }}/backend/api`
4. Updated workflow name for clarity

**Tracked Acceptance Criteria:**
1. Workflow triggers only manually via `workflow_dispatch` (no auto-deploy on push)
2. Azure-generated placeholder parameters removed/replaced
3. `appSourcePath` valid for FastAPI backend (`backend/api`)
4. Required secrets and Azure resources documented (no secret values committed)
5. YAML validation passes (no actual deployment until secrets exist)

**Next Steps (Required for Future Deployment):**
- Configure GitHub Repository Secrets: `VCSERVICES_AZURE_CREDENTIALS`, `VCSERVICES_REGISTRY_USERNAME`, `VCSERVICES_REGISTRY_PASSWORD`
- Verify Azure Resources: resource group `puzzlequest-value-compass-rg`, container registry `cae127fb809bacr.azurecr.io`, container app `vc-services`
- Manual deployment only (MVP): trigger workflow manually via GitHub UI or API using `workflow_dispatch`

**Aligns with MVP decision:** Deployment now requires manual trigger via `workflow_dispatch` only.

### 2026-05-12T19:57:36.350-07:00: Frontend Folder Convention and Build/Run Scripts
**By:** Basher (iOS Dev) | **Status:** Adopted

The iOS/iPadOS app folder is renamed from `ios/` to `frontend/`. Build and run scripts live inside that folder at `frontend/build.sh` and `frontend/run.sh`.

**Key Decisions:**
1. **Folder Rename:** `ios/` → `frontend/` as the primary app development directory
2. **Script Location:** App-local developer scripts live at `frontend/build.sh` and `frontend/run.sh`
3. **Script Defaults:** Environment-overridable defaults for iOS Simulator 26.4 (iPhone 17, iPad A16), matching currently installed Xcode runtime
4. **Root Resolution:** Scripts resolve their `ROOT_DIR` to `frontend/` and default `PROJECT_PATH` to `VCA.xcodeproj` relative to that directory
5. **Deployment Baseline:** Scripts preserve iOS/iPadOS 17+ minimum deployment target
6. **Environment Overrides:** All values customizable via environment variables: `IOS_VERSION`, `IPADOS_VERSION`, `IPHONE_DEVICE`, `IPAD_DEVICE`, `DEVICE_KIND`, `PLATFORM_MODE`, `SCHEME`, `PROJECT_PATH`, `WORKSPACE_PATH`
7. **Validation:** Scripts pass syntax validation (`bash -n`) and are executable

**Constraints:**
- Repo-root scripts should not be assumed for iOS app build/run flows; use `frontend/build.sh` and `frontend/run.sh` instead
- Actual xcodebuild build and test are blocked; `frontend/VCA.xcodeproj` missing `project.pbxproj` file until app project is scaffolded
- Scripts are ready for use once the Xcode project structure is in place

**Impact:** Folder rename consolidates app structure; build/run scripts colocate with app source. Local development setup ready pending Xcode project scaffolding.

### 2026-05-12T20:01:38.315-07:00: iOS Xcode Build Artifacts — .gitignore Patterns for Frontend Folder
**By:** Basher (iOS Dev) | **Status:** Adopted

Repository root `.gitignore` updated with focused iOS/Xcode build artifact patterns scoped to the `frontend/` directory. Build artifacts are ignored; source and project files remain trackable.

**Patterns Added:**

| Pattern | Purpose | Generated By |
|---------|---------|-------------|
| `frontend/.build/` | SPM and general build artifacts | Xcode build system, frontend/build.sh |
| `frontend/build/` | Xcode build output directory | xcodebuild |
| `frontend/.build/xcode-derived-data/` | Explicit derived data path from scripts | xcodebuild -derivedDataPath |
| `frontend/DerivedData/` | Standard Xcode derived data (fallback) | Xcode |
| `frontend/*.pbxuser` | User-specific Xcode project settings | Xcode IDE |
| `frontend/*.perspectivev3` | User-specific Xcode workspace perspectives | Xcode IDE |
| `frontend/*.xcworkspace/xcuserdata/` | Per-user xcworkspace settings | Xcode IDE |
| `frontend/*.xcodeproj/xcuserdata/` | Per-user xcodeproj settings | Xcode IDE |
| `frontend/.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | Workspace configuration | Xcode IDE |
| `frontend/.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | Workspace settings index | Xcode IDE |
| `frontend/Pods/` & `frontend/Podfile.lock` | CocoaPods dependencies (if adopted) | CocoaPods |
| `frontend/Carthage/Build/` | Carthage build artifacts (if adopted) | Carthage |
| `frontend/*.profdata` | Code coverage data | Xcode test/profiling |
| `frontend/*.app/` | Generated macOS app bundles | Xcode |
| `frontend/*.swiftinterface` | Generated Swift module interfaces | Swift compiler |

**Validation:**
✅ Build artifacts are ignored (frontend/.build/, DerivedData/, xcuserdata/)  
✅ Source files remain tracked (VCA.xcodeproj/project.pbxproj, Sources/, build.sh, run.sh, README.md)

**Scope & Safety:**
- All patterns scoped to `frontend/` to avoid affecting other directories
- No broad patterns (e.g., `*.xcodeproj/`) that could hide important source files
- Critical source files explicitly tracked: `.xcodeproj/project.pbxproj`, app source code, build scripts

**Impact:** Team members running `frontend/build.sh` and `frontend/run.sh` locally will generate DerivedData and xcuserdata without polluting git history or causing merge conflicts.

### 2026-05-12T19:59:35.461-07:00: Tech Spec Refresh — Current Architecture Documented (ADR)
**By:** Danny (Lead/Architect) | **Status:** Accepted (Implementation Complete)

The four primary technical specification documents have been updated to reflect the current state of the Value Compass v1 architecture, serving as a single source of truth for onboarding, implementation validation, and architectural reviews.

**Scope:** Documentation only (no code changes)

**Context & Motivating Changes:**
1. App folder moved from `ios/` to `frontend/` with build/run scripts at `frontend/build.sh` and `frontend/run.sh`
2. Backend deployment model finalized: Azure Container Apps with manual `workflow_dispatch` triggers (no automatic deployments until app MVP)
3. Database infrastructure: Supabase managed Postgres as v1 foundation for optional sync
4. Design scaffolding: Stitch is functional only, not canonical; Tess owns final design
5. TDD-first approach: Core business logic implemented test-first
6. Multi-platform support: iPhone and iPad navigation from v1; both light and dark modes required

**Changes Made:**

| File | Changes |
|------|---------|
| `docs/tech-spec.md` | Updated Appendix A from "Scaffolding Alignment" to "Repository Layout" with complete directory tree, purposes, and v1 usage. Clarified backend/api, backend/poller, backend/db, backend/common structure. |
| `docs/app-tech-spec.md` | Added "Platform and App Architecture" section documenting build/run scripts, env defaults (iOS/iPadOS 26.4, iPhone 17, iPad A16), and overrides. Added "App Design and Scaffolding Principles" subsection clarifying Stitch is functional scaffolding only, Tess owns final design, fonts per Stitch recommendations, iPhone+iPad support, light+dark required. Rewrote "App Test Strategy" to lead with TDD-first approach. |
| `docs/services-tech-spec.md` | Added "Deployment and DevOps" section documenting Azure Container Apps as v1 infra target, manual deployment only via `workflow_dispatch`, CI pipeline behavior (build/test/push containers, no automatic deploys until MVP). |
| `docs/db-tech-spec.md` | Updated metadata to include "Infrastructure: Supabase managed Postgres (v1 foundation)" and clarified Supabase as v1 infra foundation while emphasizing it is not required for offline app execution. |

**Validation:**
✓ Path references validated: No stale `ios/` references; `frontend/build.sh` and `frontend/run.sh` referenced correctly  
✓ Deployment model validated: Azure Container Apps and manual `workflow_dispatch` documented  
✓ Database references validated: Supabase mentioned appropriately as v1 foundation  
✓ Design scaffolding validated: Stitch reframed as "functional scaffolding only, not final visual specification"  
✓ TDD approach validated: Emphasized with practical benefits documented (clarity, reduced rework, tight coupling to requirements)

**Alternatives Considered:**
1. Defer documentation updates until next architecture review — Rejected: Specs are the primary reference for implementation
2. Create a new "Architecture Overview" document instead of updating existing specs — Rejected: Split specs are the agreed-upon single source of truth
3. Include code changes in scope — Rejected: Scope is documentation only

**Trade-offs:**
| Decision | Benefit | Cost |
|----------|---------|------|
| **TDD-first approach emphasized** | Clarity on expected behavior early, reduced refactor risk | Upfront test-writing overhead |
| **Stitch reframed as scaffolding** | Reduces design rework risk, clarifies Tess owns final visual spec | May confuse team if not clearly communicated |
| **Azure Container Apps documented** | Reduces operational overhead, clear manual-deploy expectations | Dependent on Azure account and credentials |
| **Supabase as v1 foundation** | Reduces dev time to build optional sync | Network latency considerations (deferred to deployment) |
| **Light/dark mode required from v1** | Avoids rework, accessibility best practice | Increased design/implementation effort upfront |

**Impact:** Specs serve as current, authoritative reference for all four concerns (app, services, database, infrastructure). Teams can implement with confidence that documentation reflects agreed-upon architecture.

### 2026-05-12T20:05:11.174-07:00: Frontend Build Outputs — Root Build Folder Convention
**By:** Basher (iOS Dev) | **Status:** Adopted

Frontend build outputs now default to the repository root build folder to align with the repo-wide build output strategy.

**Decision:** `frontend/build.sh` and `frontend/run.sh` now default Xcode DerivedData to `${REPO_ROOT}/build/frontend/xcode-derived-data`, while preserving `DERIVED_DATA_PATH` environment overrides for custom locations.

**Why:** Consolidates all generated artifacts under the repo-root `build/` directory, which is ignored by git, preventing build artifacts from polluting version control.

**Scope:** Build script defaults only; no breaking changes to existing builds.

### 2026-05-12T20:07:05.152-07:00: iOS App Deployment — Manual Trigger Only
**By:** Livingston (DevOps Engineer) | **Status:** Adopted

During MVP, deployment to Apple/App Store Connect is manual-only via the `ios-deploy.yml` workflow `workflow_dispatch` trigger.

**Decision:** iOS CI can continue running on push/PR, but signing/archive/upload to Apple requires an explicit manual run with the desired `ref`.

**Why:** Matches the backend MVP deployment posture and prevents automatic TestFlight/App Store uploads from push or tag events, ensuring release control remains explicit.

**Related Workflow:** `.github/workflows/ios-deploy.yml` (manual-only via `workflow_dispatch`)

**Next Steps:** When app MVP is ready, evaluate promotion to automatic deployment based on branch or tag events.

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
