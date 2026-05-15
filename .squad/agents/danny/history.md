# Danny — History

## Core Context

- **Project:** A value-compass product with a backend API, infrastructure, and iOS client.
- **Role:** Lead
- **Joined:** 2026-05-12T22:54:36.367Z

## Learnings

<!-- Append learnings below -->

### 2026-05-12T19:59:35.461-07:00 — v1 Tech Spec Reconciliation with Current Architecture

- **Task:** Update technical specifications and architecture docs to reflect all completed changes and repo layout.
- **Scope:** Refreshed 4 core spec files to document:
  1. **Repository layout** — `frontend/`, `backend/api`, `backend/poller`, `backend/db`, `backend/common`, `docs/`, `infra/` with explicit directory purposes.
  2. **App platform and build:** iOS/iPadOS 17+ baseline, `frontend/build.sh` and `frontend/run.sh` with env-configurable simulator targets (iOS/iPadOS 26.4, iPhone 17, iPad A16).
  3. **App design principles:** Stitch as functional scaffolding only, not canonical design; Tess owns final visual spec; fonts per Stitch recommendations, not SF-only hardcoding.
  4. **TDD-first approach:** View models, persistence, and service contracts tested before implementation; in-memory SwiftData for isolation; protocol seams tested as black boxes.
  5. **Services deployment:** Azure Container Apps as v1 infra target; manual deployment only via `workflow_dispatch`; no automatic deploys until app MVP.
  6. **Database foundation:** Supabase managed Postgres as v1 infra foundation for optional sync; local SwiftData remains the required runtime model.
  7. **Light/dark mode:** Both required from v1 onward, not deferred.
  8. **Repo structure:** Documented all top-level and nested directories with clear ownership and v1 usage.
- **Changes made:**
  - `docs/tech-spec.md` — Updated Appendix A to "Repository Layout" with full directory mapping and purposes.
  - `docs/app-tech-spec.md` — Added Platform section documenting build/run scripts, defaults, env overrides; added "App Design and Scaffolding Principles" subsection clarifying Stitch, fonts, Tess ownership, light/dark; rewrote Test Strategy section to emphasize TDD-first with practical benefits.
  - `docs/services-tech-spec.md` — Added "Deployment and DevOps" section documenting Azure Container Apps, manual deployment, CI pipeline behavior, and future phases.
  - `docs/db-tech-spec.md` — Updated metadata and opening sections to highlight Supabase managed Postgres as v1 infra foundation.
- **Validation:**
  - No stale `ios/` path references found in docs.
  - `frontend/build.sh` and `frontend/run.sh` properly referenced in app-tech-spec and top-level tech-spec.
  - Azure Container Apps and manual `workflow_dispatch` deployment documented in services-tech-spec.
  - Supabase references (12) properly scoped in db-tech-spec.
  - Font guidance scoped to "Stitch-mentioned fonts" with explicit rejection of hardcoded SF-only.
  - Auto-deployment reference correctly states "no automatic deployments on branch pushes."
- **Trade-offs documented:**
  - TDD upfront work vs. easier refactoring and fewer regressions — recommended for core logic (validation, persistence, error handling).
  - Stitch as scaffolding (not final design) — prioritizes functional validation over pixel-perfect implementation; design rework expected and planned.
- **Next steps:** These docs now serve as the source of truth for onboarding new team members, validating implementation against spec, and guiding design/architecture reviews.

### 2026-05-12T19:06:01.000-07:00 — App Tech Spec Reconciliation with Tess Approved Flow

- **Analysis:** Reviewed app-tech-spec against Tess-approved decisions (iPhone+iPad, NavigationStack+NavigationSplitView, no tab bar, light+dark mode, Stitch as scaffolding only).
- **Finding:** No conflicting flows or navigation patterns detected. Spec already enforced approved direction on platform, persistence, and service seams.
- **Clarifications added:** 
  1. **Onboarding flow** now explicitly guides users to create their **first real portfolio**, not a demo. Includes first-run disclaimer gate, empty-state prompt, and guided setup.
  2. **TDD-first practice** documented in test strategy. View models, persistence, and service contracts should be tested before implementation. Use in-memory SwiftData for unit test isolation.
  3. **Test scope boundaries** clarified: test behavior and contracts; avoid testing algorithm internals, API internals, or pixel-level UI details.
- **ADR created:** `.squad/decisions/inbox/danny-app-flow-spec-reconcile.md` — documents alignment and enforcement gates for next phase.
- **Key trade-off:** TDD upfront work vs. easier refactoring and fewer regressions. Recommended for core business logic (validation, persistence, error handling).

### 2026-05-12T20:07:05.152-07:00 — frontend/README.md Path Reference Refresh

- **Task:** Update documentation after folder rename from `ios/` to `frontend/`.
- **Changes:** Updated h1 heading and Layout section directory tree in `frontend/README.md` to reflect actual folder structure.
- **Validation:** Verified no remaining stale `ios/` folder path references in documentation.
- **Learning:** When folders are renamed, docs must be updated to reflect the current structure. Distinguish between literal path references (must update) and domain/platform references like iOS/iPadOS versions (preserve). This ensures developers have accurate navigation guidance.
- **Decision file:** `.squad/decisions/inbox/danny-frontend-readme-paths.md`

### 2026-05-12 — V1 Tech Spec Drafted

- **Decision: SwiftData over Core Data** for local persistence. iOS 17+ baseline makes this viable; simpler `@Model` macro, CloudKit path available later. Trade-off: less mature migration tooling.
- **Decision: Category layer is client-only in v1.** Backend model has `Portfolio → Holding` with per-holding weights. V1 introduces `Category` between them. Backend schema will be extended when sync is built — deliberate divergence documented.
- **Decision: Algorithm is a protocol seam (`ContributionCalculating`).** User owns implementation. Stub does proportional split. App handles input validation before and output rounding after the algorithm call.
- **Decision: Rounding strategy** — round each ticker to cents, assign remainder to the largest/most-underweight ticker. Exact "most-underweight" logic deferred to algorithm owner.
- **Key file:** `docs/tech-spec.md` — v1 technical specification.
- **GitHub Issue #15:** User to provide `ContributionCalculating` implementation.
- **User preference:** User owns the VCA algorithm; team builds everything else. Do not implement or specify algorithm internals.
- **Scaffolding note:** `ios/Sources/Models/`, `Features/`, `App/` are empty (.gitkeep only). `Networking/` unused in v1. Backend scaffolding (`backend/`, `openapi.json`) exists but is not wired for v1.

### 2026-05-12T23:12:56.058Z — Team Decision Sync

**Scribe session:** All four agents (Danny, Basher, Rusty, Linus) completed parallel spec splits. Decisions merged into unified `decisions.md`:
- V1 Architecture: SwiftData, Category layer, ContributionCalculating protocol, MarketDataProviding protocol, validation/rounding strategy
- Tech Spec Split: Separate app/services/database specs created by respective agents
- User Directives: Algorithm is user-owned; create GitHub issues for blockers assigned to yashasg

Orchestration logs created in `.squad/orchestration-log/`. Session log at `.squad/log/2026-05-12T23-12-56-058Z-split-tech-specs.md`.

### 2026-05-15T01:56:27-07:00 — Team Stream Label Rollout (team:frontend / team:backend / team:strategy)

- **Task:** Create the `team:*` GitHub labels backing the new 3-stream scheme in `.squad/streams.json`, then triage all open issues against folder scope.
- **Labels created (yashasg/value-compass):**
  - `team:frontend` — `#1f6feb` (blue) — "Frontend stream — iOS/iPadOS UI, design system, features, tests"
  - `team:backend` — `#8957e5` (purple) — "Backend stream — iOS data layer (Networking, Contracts, Models, Services, DI)"
  - `team:strategy` — `#bf8700` (gold) — "Strategy stream — market, legal, accessibility audits, ASO, HIG, contract monitoring"
- **Triage map applied (folder scope → keywords):**
  - **frontend** ← `app/Sources/Features/**`, `app/Sources/App/AppFeature/**`, `app/Sources/DesignSystem/**`, `app/Sources/Assets/**`, `app/Tests/**`, `docs/design-system-colors.md` → screens, navigation, view models, tokens, snapshot/XCTest, accessibility on the iOS surface.
  - **backend** ← `app/Sources/Backend/**`, `app/Sources/App/Dependencies/**` → SwiftData models, persistence, networking (URLSession/Massive client), Keychain/secret storage, calc engine (`ContributionCalculating`), market data providers, DI/composition root, TA-Lib/indicator packages.
  - **strategy** ← `docs/audits/**`, `docs/research/**`, `docs/legal/**`, `docs/aso/**` → market/legal/accessibility/ASO/HIG/contract-monitoring docs.
  - Multi-label = legitimate cross-stream work (e.g., a feature that ships a UI flow AND wires the data layer for it).
  - **No label** = DevOps/CI, leadership specs, mothballed Python `backend/` — explicitly out of stream routing per user.
- **Triage results (14 open issues, 14 labeled, 0 left unlabeled):**
  - **backend-only (4):** #123 (SwiftData models), #127 (Keychain/API key storage), #128 (Massive EOD client), #129 (TA-Lib indicators package).
  - **frontend-only (3):** #132 (Snapshot review + Swift Charts), #134 (NavigationStack/SplitView), #135 (MVP integration test pass — lives in `app/Tests/**`).
  - **frontend + backend (7):** #124 (app shell + DI composition), #125 (editor UI + uniqueness/weight rules), #126 (typeahead UI + bundled metadata service), #130 (Invest UI + calc seam), #131 (Snapshot UI + persistence), #133 (Settings UI + Keychain/reset), #145 (TCA migration — Reducers in features + Dependency interfaces).
  - **strategy:** zero hits this round — no audit/research/legal/ASO issues currently open.
- **Edge cases / future-self notes:**
  - **#135** is end-to-end regression. Marked **frontend-only** because the artifacts live in `app/Tests/**` (frontend folderScope). Even though it exercises the data layer, the file scope wins. If we ever split test ownership, revisit.
  - **#145** is meta/architectural (TCA migration plan). Labeled both frontend + backend because TCA Reducers replace ViewModels in features (frontend) and Dependency interfaces are the backend composition root. The follow-up issues this spawns can be labeled more narrowly per phase.
  - Several issues carry legacy `squad:virgil` (backend specialist) but are clearly UI work (e.g., #134). Don't trust legacy `squad:*` labels for stream routing — go off file scope and topic.
  - Multi-label was the right call ~50% of the time for this MVP backlog because most user-facing features cross UI ↔ persistence. That is expected and not a smell.
- **Decision drop:** `.squad/decisions/inbox/danny-team-label-rollout.md`
- **Skill captured:** `.squad/skills/issue-triage-by-stream/SKILL.md`
