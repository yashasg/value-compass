# Scribe — History

## Core Context

- **Project:** A value-compass product with a backend API, infrastructure, and iOS client.
- **Role:** Session Logger
- **Joined:** 2026-05-12T22:54:36.371Z

## Learnings

### 2026-05-12T19:12:00.000-07:00: Decision Inbox Merge — App Development TDD & Design Follow-Up Phase
Merged 5 inbox files documenting app development decisions, TDD practices, and design follow-ups:
- Font scaffolding directive (use Stitch font set, not SF-only)
- App development practices directive (small incremental issues, TDD-first)
- App tech spec reconciliation with Tess-approved flows (onboarding clarification, TDD guidance)
- 12 TDD-first app implementation issues created (#30–#45)
- 4 non-blocking design follow-up issues created (#34–#35, #37–#38)

**Key Decision:** Navigation remains Apple-native (NavigationStack iPhone, NavigationSplitView iPad, no v1 tab bar). Stitch is functional scaffolding only; design refinement deferred. App implementation proceeds with semantic colors and adaptive layouts while design tokens are formalized in parallel.

### 2026-05-12T19:22:02.523-07:00: Decision Inbox Merge — DevOps Infrastructure & Deployment, Issue #46 Workflow Fix
Merged 7 inbox files documenting DevOps decisions and infrastructure fixes:
- Supabase managed database as v1 foundation
- FastAPI backend deployment to Azure Container Apps
- CI pipeline (test, build, publish; no auto-deploy pre-MVP)
- Manual workflow_dispatch deployment only
- No shared backend environments until MVP
- GitHub issue #46 created to fix Azure Container Apps auto-deploy violation
- Livingston diagnosed and remediated workflow run #25774741652 failure: removed auto-trigger, fixed invalid parameters, fixed appSourcePath, documented secret/resource requirements

**Key Decision:** All backend deployment is manual (`workflow_dispatch` only) until app MVP approval. Shared backend environments forbidden in v1. Infrastructure foundation is Supabase managed database + Azure Container Apps + CI-published container images.

### 2026-05-12T19:50:09.861-07:00: Decision Inbox Merge — iOS Build Script Defaults
Merged 1 inbox file documenting root build/run script defaults:
- Root `build.sh` and `run.sh` created for iOS/iPadOS frontend development
- Defaults pin to iOS Simulator 26.4 (iPhone 17, iPad A16); all values environment-overridable
- Scripts preserve iOS/iPadOS 17+ deployment baseline
- Syntax validation passed (`bash -n`); scripts are executable
- Blocked: xcodebuild testing pending app project scaffolding (missing `project.pbxproj`)

**Key Decision:** Local development build/run infrastructure is ready. Team can test commands once Xcode project structure is created. Simulator defaults match installed runtime while staying within deployment constraints.

### 2026-05-12T20:01:38.315-07:00: Decision Inbox Merge — Frontend Folder Convention, Build Artifacts, and Tech Spec Refresh
Merged 3 inbox files documenting frontend folder structure, build artifact management, and architecture documentation:
- Frontend folder convention: `ios/` → `frontend/`, with build/run scripts at `frontend/build.sh` and `frontend/run.sh` (replaces stale root-level script entries)
- iOS Xcode .gitignore patterns: Comprehensive rules for frontend/ build artifacts while keeping source/project files trackable
- Tech Spec Refresh (ADR): All four primary tech specs (tech-spec.md, app-tech-spec.md, services-tech-spec.md, db-tech-spec.md) updated to reflect current architecture, deployment model (Azure Container Apps, manual `workflow_dispatch`), database foundation (Supabase managed Postgres), Stitch scaffolding scope (functional only), TDD approach, and multi-platform (iPhone+iPad, light+dark) requirements

**Key Decision:** App folder and build/run tooling now unified under `frontend/` directory with scoped gitignore rules preventing build artifacts from polluting the repository. All tech specs align on current architecture: local-first iOS/iPadOS app, optional backend sync via Azure Container Apps, Supabase as v1 database foundation, Stitch as functional scaffolding only, TDD-first implementation practices, and universal platform support (iPhone+iPad, light+dark modes).

<!-- Append learnings below -->

