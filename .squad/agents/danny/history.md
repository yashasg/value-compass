# Danny — History

## Core Context

- **Project:** A value-compass product with a backend API, infrastructure, and iOS client.
- **Role:** Lead
- **Joined:** 2026-05-12T22:54:36.367Z

## Learnings

<!-- Append learnings below -->

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
