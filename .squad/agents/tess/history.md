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

- 2026-05-12T16:59:37-07:00 — Reviewed Stitch-generated VCA designs (dashboard, add_holdings, create_portfolio, settings). Direction is visually promising but **needs revision before approval**. Major gaps vs decisions/app-tech-spec: (1) no Category layer — designs show flat ticker list with weight inputs, breaking Portfolio → Category → Ticker model; (2) dark-mode only, no light-mode tokens despite user directive for both; (3) bottom tab bar present but spec says no tab bar in v1; (4) no onboarding, empty states, contribution-result, contribution-history, or disclaimer screens; (5) no manual current-value or per-ticker moving-average input UI; (6) settings implies accounts ("John Doe / Institutional Investor Plan") but v1 is local-only/offline-first; (7) no iPad layouts (spec requires NavigationSplitView); (8) "Monthly Budget" + portfolio-level Moving Average Window in create_portfolio diverge from per-ticker moving-average model; (9) three custom fonts (Manrope/Work Sans/IBM Plex Sans) — Dynamic Type and SF integration unverified; (10) coral-on-navy contrast and color-only positive/negative signaling need a11y check. Awaiting user answers before approving direction.

## 2026-05-12T17:02:11.019-07:00 — Stitch reframed as functional scaffolding

User clarified Stitch screens are placeholder content + provisional colors; functionality first, new design system to come later. Decision logged: Stitch screens serve as functional scaffolding only for screen inventory, navigation, and field intent—not as final visual spec. Engineering unblocked to scaffold screens and models in parallel. Tess will propose replacement design system after functional MVP walkable.

## 2026-05-12T17:02:11.019-07:00 — Sessions and orchestration logged

Scribe processed Tess design review, Stitch reframing, and user directives. Inbox files merged to decisions.md. Session log and orchestration logs written.

## 2026-05-12T17:02:11.019-07:00 — Platform requirement confirmed: iPhone + iPad, light + dark

User confirmed v1 must ship both iPhone and iPad layouts and both light and dark mode. Combined with the prior reframe (Stitch is functional scaffolding only, not final visual spec), this unblocks Basher to begin SwiftUI screen scaffolding using adaptive layouts (NavigationStack on iPhone, NavigationSplitView on iPad) and semantic system colors so light/dark fall out of the design tokens. Tess approval scope is now: screen inventory, navigation, fields, and adaptive/appearance behavior — visual design system (typography, palette, iconography) deferred until functional MVP is walkable.

## 2026-05-12T19:05:12.285-07:00 — Design follow-up issues created

Created 4 non-blocking design follow-up issues to support app development alongside functional scaffolding:

- **#34 Design System Refresh: Light/Dark Color Tokens** — Replace current Stitch palette with accessible light/dark color system supporting financial data legibility and semantic color signaling (positive/negative/error/warning/info).
- **#35 Typography System: Font Integration and Dynamic Type** — Formalize Manrope/Work Sans/IBM Plex Sans usage, establish type scale and hierarchy, plan Dynamic Type support and SF fallbacks, document tabular lining for data columns.
- **#37 Onboarding, Disclaimer, and Empty States Design** — Create first-run onboarding flow, prominent disclaimer presentation, and empty states for portfolio/history/empty screens to guide new users without blocking functionality.
- **#38 iPad Layout Polish: Split-View Navigation and Adaptive Spacing** — Ensure NavigationSplitView layouts work comfortably on iPad (Pro/Air/mini), verify touch targets, balanced spacing, and readable line lengths across compact/regular width classes.

All issues labeled with "squad" for visibility. Issues are intentionally non-blocking design follow-ups that allow Basher's implementation work to proceed while planning visual system refinement.


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.
