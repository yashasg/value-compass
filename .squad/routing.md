# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Architecture, cross-cutting decisions | Danny | Tech specs, ADRs, domain boundaries, priorities, multi-domain trade-offs |
| Backend APIs and service code | Rusty | FastAPI endpoints, `backend/api`, `backend/common`, service errors, request/response models |
| Database and poller behavior | Rusty | SQLAlchemy models, Alembic migrations, `stock_cache`, scheduled refreshes, persistence invariants |
| iOS implementation | Basher | Swift, SwiftUI, SwiftData, Xcode project changes, view models, calculator wiring |
| iOS/iPadOS experience design | Tess | Onboarding, disclaimer/settings UX, adaptive iPad layouts, accessibility, Dynamic Type, empty states |
| OpenAPI and sync contracts | Linus | `openapi.json`, generated Swift clients, backend/frontend contract tests, sync mapping |
| Infrastructure and delivery | Livingston | GitHub Actions, TestFlight, Azure deploys, secrets wiring, build/release automation |
| Code review | Danny | Review PRs, check quality, suggest reviewers |
| Testing | Domain owner | Write tests, find edge cases, verify fixes in the touched area |
| Scope & priorities | Danny | What to build next, trade-offs, decisions |
| Session logging | Scribe | Automatic — never needs routing |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, assign `squad:{member}` label | Lead |
| `squad:{name}` | Pick up issue and complete the work | Named member |

### How Issue Assignment Works

1. When a GitHub issue gets the `squad` label, the **Lead** triages it — analyzing content, assigning the right `squad:{member}` label, and commenting with triage notes.
2. When a `squad:{member}` label is applied, that member picks up the issue in their next session.
3. Members can reassign by removing their label and adding another member's label.
4. The `squad` label is the "inbox" — untriaged issues waiting for Lead review.

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `squad:{member}` label is applied to an issue, route to that member. The Lead handles all `squad` (base label) triage.
8. **Keep PR scope owner-aligned** — prefer one primary owner per branch. If work must span owners, name the handoff in the PR and keep generated artifacts with the contract owner.

## Work Type → Agent

| Work Type | Primary | Secondary |
|-----------|---------|----------|
| Architecture, decisions | Danny | — |
| APIs, data models | Rusty | — |
| Swift, mobile UX | Basher | — |
| iOS/iPadOS design, onboarding, usability | Tess | Basher |
| OpenAPI, client sync | Linus | — |
| Infra, deployment | Livingston | — |
