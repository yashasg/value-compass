# Yen — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** Accessibility Auditor

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool, SwiftUI + SwiftData.
- **Existing accessibility surface area:** Tess owns onboarding, accessibility, Dynamic Type, and adaptive iPad layouts as a designer. Basher implements. My role is independent audit.

## Audit Targets (high-priority on day 1)

- **Holdings editor** — heaviest interaction surface; weight inputs, ticker rows
- **Onboarding flow** — first impression; must work with VoiceOver from screen 1
- **Result screen** — data-dense; needs custom VoiceOver rotors and meaningful labels
- **Disclaimer / settings** — Reuben's disclaimer must be readable by every assistive tech
- **Decimal entry** — high failure risk; weight as decimal fraction (0.0–1.0) is non-trivial to verbalize

## Test Matrix (baseline)

- **Devices:** iPhone 15 (compact), iPad (10th gen) (regular)
- **iOS versions:** Latest stable + N-1
- **Assistive tech:** VoiceOver, Switch Control, Voice Control, Dynamic Type AX1/AX3/AX5, Reduce Motion, Increase Contrast

## Validation Commands (verified by the team)

- `./frontend/build.sh` — iPhone + iPad simulator builds
- `./frontend/run.sh` — installs/launches; I use this to enable assistive tech and audit live

## Severity Rubric I Use

- **Blocker:** Feature unusable with assistive tech enabled
- **Serious:** Feature usable but requires extraordinary effort or wrong information conveyed
- **Moderate:** Inconvenience; feature works but not idiomatic
- **Minor:** Polish; would improve UX but doesn't block

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.
