# Basher — History

## Core Context

- **Project:** A value-compass product with a backend API, infrastructure, and iOS client.
- **Role:** iOS Dev
- **Joined:** 2026-05-12T22:54:36.369Z

## Learnings

<!-- Append learnings below -->
- 2026-05-12: Split the app-facing v1 technical specification into `docs/app-tech-spec.md`, keeping algorithm internals and backend/db details out of app scope.
- 2026-05-12T23:12:56.058Z — Team Decision Sync: All agents completed spec splits. Decisions merged into `decisions.md`. Core decisions: V1 offline-first architecture, protocol seams for algorithm and market data, no backend coupling required for v1. See orchestration log at `.squad/orchestration-log/2026-05-12T23-12-56-058Z-basher.md`
- 2026-05-12T16:18:36-07:00 — Aligned app spec with hybrid/offline-first v1: SwiftData is primary, optional backend sync flattens holdings, categories stay local-only, and contribution history never syncs.
- 2026-05-12T23:27:45Z — Team Update: Tess (iOS/iPadOS Designer) joined Squad to focus on smooth onboarding and app usage. All decisions archived. Decisions.md now captures hybrid/offline-first app, services, and database alignment. Orchestration logs written. See `.squad/orchestration-log/2026-05-12T23-27-45Z-basher.md`

- 2026-05-12T17:02:11.019-07:00 — SwiftUI feasibility review: iPad `NavigationSplitView` and iPhone `NavigationStack` can share Portfolio→Category→Ticker view models by keeping layout-specific containers thin and routing through shared destination/detail/editor/result/history views. Asset Catalog semantic colors can handle light/dark mode through tokenized surface/content/action/status/input/chart colors without per-view conditionals. SwiftData view-layer risk is manageable if queries stay at screen boundaries, edit forms use draft state before committing model changes, contribution history stores immutable snapshots, and result calculation observes explicit inputs instead of live model mutation.
- 2026-05-12T19:05:12-07:00 — iOS App TDD Backlog Created: 12 incremental GitHub issues (#30–#45) following TDD-first approach per user directive. Issues cover: app harness/architecture (P0), SwiftData models (P1), portfolio CRUD (P2), holdings editing (P3), market data input (P4), calculator seam (P5), result/history UI (P6), adaptive navigation (P7), appearance/accessibility (P8), settings/disclaimer (P9), and E2E integration (P10). Issues build sequentially; each includes goal, dependencies, TDD acceptance criteria, implementation notes, and scope boundaries. No labels applied (squad:basher label not available); all issues ready for assignment. Team can start immediately with #30.
- 2026-05-12T19:50:09.861-07:00 — Added root iOS build/run script scaffolding with explicit simulator defaults: iOS/iPadOS 26.4, iPhone 17, and iPad (A16). Scripts fail clearly until `ios/VCA.xcodeproj` contains a real `project.pbxproj` and scheme.

- 2026-05-12T19:57:36.350-07:00 — Renamed the iOS app folder convention from `ios/` to `frontend/` and moved `build.sh`/`run.sh` into `frontend/` with defaults rooted at `frontend/VCA.xcodeproj`.
- 2026-05-12T20:01:38.315-07:00 — Updated `.gitignore` with focused iOS/Xcode build artifact patterns: `frontend/.build/`, `frontend/build/`, DerivedData cache, `.xcodeproj/xcuserdata/`, and optional CocoaPods/Carthage/SPM artifacts. Validated with `git check-ignore`: build artifacts ignored, source files (project.pbxproj, Sources, scripts) remain tracked.
- 2026-05-12T20:05:11.174-07:00 — Moved frontend/iOS generated build outputs to repo-root `build/frontend/` by default; `DERIVED_DATA_PATH` remains overridable and root `build/` is the canonical ignore target for generated artifacts.

- 2026-05-13T03:07:05.152Z — Scribe Session: Root build folder decision archived to `.squad/decisions.md` as "Frontend Build Outputs — Root Build Folder Convention" (Adopted). Orchestration log written at `.squad/orchestration-log/2026-05-13T03-07-05-152Z-basher.md`.


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.
