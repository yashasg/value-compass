# Virgil — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** iOS Backend Engineer (data + business logic side of the iOS app)

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool. v1 ships without a server.
- **Language/Frameworks:** Swift, SwiftUI, **SwiftData** (persistence), XCTest.
- **Domain model:** Portfolio → Category → Ticker. Diverges from the legacy backend's flat Portfolio → Holding model. Category is client-only until backend sync.
- **Critical invariant:** `Category.weight` is a **Decimal fraction (0.0–1.0)**. UI captures percent and stores `weightPercent / 100`. Validation compares total weight to 1 (100%).
- **VCA algorithm:** User-owned via the `ContributionCalculating` protocol seam — this is mine to maintain and evolve.
- **Backend:** Python/FastAPI exists but is **unused in v1**. Rusty (the backend dev) has been retired. Sync work is post-MVP and will route through Linus when it arrives.

## Scope Split with Basher

| Layer | Owner |
|-------|-------|
| SwiftUI views, screens, navigation, animations | Basher |
| View models that are presentation-focused | Basher |
| SwiftData models, persistence, migrations | **Virgil** |
| `ContributionCalculating` & VCA calculator pipeline | **Virgil** |
| Service classes, repositories, data validation | **Virgil** |
| Future networking/sync layer | **Virgil** (post-MVP) |
| Unit tests for business logic | **Virgil** |
| UI tests, view-level tests | Basher |

When work crosses the boundary (e.g., new model field that needs UI exposure), Virgil and Basher coordinate via the coordinator.

## Validation Commands (verified by the team)

- `./frontend/build.sh` — builds VCA for iPhone and iPad simulators; runs XCTest if scheme contains testables.
- `./frontend/run.sh` — builds, installs, and launches the iOS app.
- Swift formatting: `xcrun swift-format lint` (run by `frontend/build.sh` over Sources and Tests).

## Known Open Issue Touching My Domain

- **#206 — iOS CI/CD perf (P0):** Livingston owns the workflow changes (RUN_ANALYZE flip, CodeQL nightly cron). I should keep an eye on test runtime if/when I add unit tests so I don't regress the savings.

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.
