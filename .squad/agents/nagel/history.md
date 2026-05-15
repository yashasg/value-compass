# Nagel — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** API Contract Monitor

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool. v1 ships **without** a server.
- **Backend:** Python/FastAPI exists in `backend/` but is unused in v1. Rusty (the backend dev) has been retired.
- **iOS internal contracts (the v1 surface I own):**
  - `ContributionCalculating` protocol — the seam that makes the VCA algorithm user-swappable. Hardened API stability target.
  - SwiftData `@Model` types — Portfolio, Category, Ticker. Schema versioning matters; a botched migration corrupts user data.
  - Service / repository interfaces between Virgil's data layer and Basher's UI layer.
  - Any `public` declaration in the app or future SPM modules.
- **OpenAPI surface:** `openapi.json` exists for the FastAPI backend. Generated Swift clients exist (Linus owns). Activates when sync work begins.

## Day-1 Scope (active)

I am ON from day 1 watching iOS-internal contracts:

1. **Every PR that touches a `public` declaration** — diff, classify, gate if breaking.
2. **Every change to `ContributionCalculating`** — presumed breaking until proven purely additive.
3. **Every SwiftData `@Model` schema change** — requires explicit schema-version bump and a migration plan I sign off on.
4. **Every change to data-layer ↔ UI-layer service interfaces** — coordinate with Virgil and Basher.

## Sync-Era Activation (post-MVP)

Additional responsibilities ramp up when **any** of the following are true:

1. The team decides to wire iOS sync to the existing backend.
2. The OpenAPI spec changes (server-side) for any reason — I diff and report.
3. The iOS client begins generating from a new version of the spec.
4. Linus needs a second pair of eyes on a contract decision.

## Coordination Map

- **Virgil** — owns the iOS-side contracts I watch every day: SwiftData schemas, `ContributionCalculating`, service interfaces. We are partners; he writes, I monitor and gate.
- **Basher** — consumes Virgil's contracts from the UI side. I alert him when a contract change requires UI updates.
- **Linus** — Dev QA. Writes tests across the iOS app. We coordinate when a contract change needs new test coverage; he authors the tests.
- **OpenAPI spec ownership** — currently unassigned (Linus stepped back from integration in v1). When sync work begins, this will need a re-assigned owner before the sync-era surface activates.
- **Danny** — final arbiter when a breaking change is unavoidable; he weighs migration cost.

## Useful Files

**iOS internal contracts (day-1 active):**

- `ios/Sources/Models/DomainModels.swift` — SwiftData `@Model` types (Portfolio, Category, Ticker). Schema lives here.
- `ContributionCalculating` protocol — the user-swap seam (Virgil knows the exact path; likely `ios/Sources/VCA/` or similar).
- Service / repository protocols in the data layer — Virgil owns the paths.

**Future sync surface (activates when sync work begins):**

- `backend/api/main.py` — FastAPI app; OpenAPI spec is generated from this.
- `openapi.json` (or wherever the snapshot lives) — the contract surface.
- iOS generated client output directory (Linus knows the path).

## Outputs the team expects from me

- Spec-diff reports (one per change)
- Breaking-change alerts with severity
- Versioning recommendations (semver bumps, deprecation timelines)
- Migration plans when a breaking change is unavoidable
- Periodic compatibility matrix

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.
