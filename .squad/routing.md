# Work Routing

How to decide who handles what.

The table below summarizes the policy for humans. `.squad/routing.json` is the machine-readable source of truth used by automation for owner and keyword routing.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Architecture, cross-cutting decisions | Danny | Tech specs, ADRs, domain boundaries, priorities, multi-domain trade-offs |
| iOS implementation (UI layer) | Basher | SwiftUI views, screens, navigation, view models, animations, design implementation |
| iOS data & business logic | Virgil | SwiftData models, persistence, VCA calculator, `ContributionCalculating`, services, validation, future networking/sync |
| iOS/iPadOS experience design | Tess | Onboarding, disclaimer/settings UX, adaptive iPad layouts, accessibility, Dynamic Type, empty states |
| Cross-cutting Dev QA & test strategy | Linus | XCTest organization, test plans, reviewer gate on test adequacy, cross-module tests, edge-case hunting |
| Infrastructure and delivery | Livingston | GitHub Actions, TestFlight, Azure deploys, secrets wiring, build/release automation |
| Market research & positioning | Saul | Competitive teardowns, personas, TAM/SAM/SOM, pricing, positioning briefs |
| Legal & compliance | Reuben | Financial-advice disclaimer, App Privacy labels, ToS/EULA/privacy policy, license review, GDPR/CCPA |
| Accessibility audit | Yen | VoiceOver / Dynamic Type / contrast / Switch Control audits, regression gating |
| App Store optimization | Frank | App name/subtitle/keywords, screenshots, preview videos, listing copy, ASO iteration |
| HIG compliance | Turk | Apple HIG audits, native control selection, iPadOS multitasking, keyboard shortcuts, pointer interactions |
| API contract surveillance | Nagel | iOS-internal contracts (ContributionCalculating, SwiftData @Model schemas, public Swift declarations, service interfaces); future OpenAPI drift |
| Code review | Danny | Review PRs, check quality, suggest reviewers |
| Testing | Domain owner writes; Linus gates | Domain owner writes tests for their area; Linus reviews adequacy and authors integration/contract tests |
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
| Swift, mobile UX | Basher | Virgil (data ↔ UI seams) |
| iOS data, persistence, VCA algorithm | Virgil | Basher (UI seams), Linus (test gates) |
| Cross-cutting Dev QA, cross-module tests | Linus | Domain owner (writes their own unit/UI tests) |
| iOS/iPadOS design, onboarding, usability | Tess | Basher |
| Infra, deployment | Livingston | — |
| Market research, personas, positioning | Saul | Danny (consumes for scope) |
| Legal, compliance, privacy, licensing | Reuben | Frank (App Privacy labels), Tess (disclaimer placement) |
| Accessibility audit & regression gating | Yen | Tess (designs to be accessible), Basher (implements), Turk (HIG overlap) |
| App Store metadata, screenshots, ASO | Frank | Saul (positioning), Reuben (privacy labels), Tess (visual direction) |
| Apple HIG conformance, iPadOS multitasking | Turk | Tess (design), Basher (implementation), Yen (a11y overlap) |
| API contract surveillance (iOS protocols, SwiftData schemas, OpenAPI drift) | Nagel | Virgil (owns iOS contracts), Linus (owns OpenAPI spec) |
