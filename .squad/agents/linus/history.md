# Linus — History

## Core Context

- **Project:** A value-compass product with a backend API, infrastructure, and iOS client.
- **Role:** Integration Engineer
- **Joined:** 2026-05-12T22:54:36.369Z

## Learnings

<!-- Append learnings below -->
- 2026-05-12: Split services/interfaces concerns into `docs/services-tech-spec.md`, preserving v1 as local/no-network while documenting future OpenAPI, API, poller, and error-contract boundaries.
- 2026-05-12T23:12:56.058Z — Team Decision Sync: All agents completed spec splits. Decisions merged into `decisions.md`. Core decisions: V1 uses local protocol seams with no required backend/API consumption. Stable interfaces defined for future OpenAPI/polling integration. See orchestration log at `.squad/orchestration-log/2026-05-12T23-12-56-058Z-linus.md`
- 2026-05-12: Updated services spec for confirmed hybrid/offline-first direction: optional eligible-data sync when backend is available, manual app-local market inputs, user-owned algorithm internals, generated OpenAPI clients, and local-only contribution history.
- 2026-05-12T23:27:45Z — Team Update: Tess (iOS/iPadOS Designer) onboarded for smooth app onboarding and usability. All decision inboxes merged. Services boundaries finalized for sync, market data caching, and async fetch architecture. See `.squad/orchestration-log/2026-05-12T23-27-45Z-linus.md`
