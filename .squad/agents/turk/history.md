# Turk — History

## Project Context

- **Project:** value-compass
- **Hired by:** yashasg
- **Joined:** 2026-05-15
- **Role:** Apple HIG Compliance Reviewer

## Tech Stack & Domain Snapshot (day 1)

- **App:** Value Compass — local-first iOS/iPadOS portfolio analysis tool. SwiftUI + SwiftData.
- **Targets:** iPhone (compact + regular widths) and iPad (regular + large; Stage Manager + Split View + Slide Over).
- **Tess** owns design and adaptive iPad layouts; **Basher** implements. My role is audit and reviewer-gate.

## HIG Hot-Spots on Day 1

- **Sheets vs. full-screen covers** — Holdings editor is a candidate for a sheet; result screen probably a navigation push
- **Lists** — Inset grouped vs. plain; section headers; swipe actions for ticker/category rows
- **Forms** — Decimal weight entry needs a numeric keyboard with done-bar; HIG patterns for inline validation
- **iPadOS multitasking** — All surfaces must behave reasonably at compact (Slide Over), regular, and Stage Manager sizes
- **Keyboard shortcuts** — iPad with hardware keyboard expects ⌘N (new), ⌘W (close), ⌘, (settings), arrow-key navigation in lists
- **Pointer interactions** — Hover effects on tappable rows when iPad has trackpad
- **App icon** — Single icon must read at every size; no transparency; safe area for the corner radius

## Coordination Map

- **Tess** → designs to HIG; I audit her designs
- **Basher** → implements native controls; I audit his code
- **Yen** → accessibility-flavored HIG (focus order, AX traits, larger tap targets); we share the gate

## Validation Commands (verified by the team)

- `./frontend/build.sh` — iPhone + iPad simulator builds
- `./frontend/run.sh` — installs/launches; I use it to test live multitasking and keyboard behavior

## Audit Report Format

For every finding I produce: (1) HIG section cite, (2) what the app currently does, (3) what HIG calls for, (4) severity, (5) recommended fix or — if we deviate intentionally — the documented rationale to add to decisions.md.

## Learnings

_(to be appended as I do work)_


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.
