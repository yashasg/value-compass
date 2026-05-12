# Tess History

## Project Context

- **Project:** value-compass
- **User:** yashasg
- **Created:** 2026-05-12T16:27:45.408-07:00
- **Role:** iOS/iPadOS Designer
- **Focus:** Smooth onboarding and low-friction app usage for an iOS/iPadOS value cost averaging app.

## Seed Context

Value Compass helps users with value cost averaging. V1 targets moving average and produces target contribution amounts. The real VCA algorithm will live in the iOS app codebase but remains user-owned and should not be implemented by the team yet.

The app is offline-first with hybrid backend sync when available. Users create portfolios with categories; each category has a weight representing its percentage of incoming investment. Tickers inside a category split that category allocation equally. Categories remain local-only in v1, backend sync stores flattened holdings, and contribution history remains local-only.

## Learnings

- 2026-05-12T16:27:45.408-07:00 — User explicitly prioritized smooth onboarding and app usage. Design work should treat first-run clarity, empty states, category/ticker setup guidance, and iPad ergonomics as core requirements.
- 2026-05-12T23:27:45Z — Team Context: Basher, Rusty, and Linus completed spec split for app/services/database alignment. All decisions now unified in `decisions.md`. V1 is hybrid/offline-first with local SwiftData, optional backend sync, local categories, manual market inputs, and user-owned algorithm. Tess team onboarding complete; ready to unblock app design work.
