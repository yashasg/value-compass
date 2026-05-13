# Rusty — History

## Core Context

- **Project:** A value-compass product with a backend API, infrastructure, and iOS client.
- **Role:** Backend Dev
- **Joined:** 2026-05-12T22:54:36.368Z

## Learnings

<!-- Append learnings below -->

- 2026-05-12: Split v1 DB/data concerns into `docs/db-tech-spec.md`: SwiftData is the v1 runtime source of truth; backend Postgres remains deferred sync alignment only.
- 2026-05-12T23:12:56.058Z — Team Decision Sync: All agents completed spec splits. Decisions merged into `decisions.md`. Core decisions: V1 offline-first with SwiftData model as runtime truth. Postgres schema changes deferred to sync phase. See orchestration log at `.squad/orchestration-log/2026-05-12T23-12-56-058Z-rusty.md`
- 2026-05-12: Updated DB spec for user-confirmed hybrid/offline-first v1: local SwiftData remains offline source of truth, backend sync stores only flattened holdings, categories/history/manual market inputs stay local-only, and tickers are portfolio-unique.
- 2026-05-12T23:27:45Z — Team Update: Tess (iOS/iPadOS Designer) joined Squad for onboarding and usability focus. Decision inbox merged into decisions.md. Database constraints captured for app-services-backend alignment. See `.squad/orchestration-log/2026-05-12T23-27-45Z-rusty.md`
- 2026-05-12T16:32:06-07:00: Created DB/data implementation backlog issues #16-#20 for hybrid/offline-first v1 sync boundaries, flattened holdings mapping, validation, contract tests, and DB invariant coverage.
- 2026-05-12T23:34:17.555Z — Scribe Inbox Merge: Decision inbox files merged into decisions.md. User directives captured (Tess UI/UX design, small incremental issues per user request). Backlog tracking added to decisions.md for Rusty DB issues #16-#20 and Linus services issues #21-#29. Session logged.
