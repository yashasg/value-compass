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

