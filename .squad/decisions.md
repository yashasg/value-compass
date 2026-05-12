# Squad Decisions

## Active Decisions

### 2026-05-12: V1 Architecture — Local-First iOS with Protocol Seams
**Author:** Danny (Lead/Architect) | **Status:** Proposed

V1 of Value Compass is an offline-first iOS/iPadOS app. The backend scaffolding exists but is not used in v1. The VCA algorithm is user-owned.

**Key Decisions:**
1. **SwiftData** for local persistence (iOS 17+ baseline). Trade-off: less mature migration tooling vs. simpler API and future CloudKit path.
2. **Category layer** added to the domain model (Portfolio → Category → Ticker). Diverges from backend's flat `Portfolio → Holding` model. Backend schema extended when sync is built.
3. **`ContributionCalculating` protocol** is the single algorithm seam. Proportional-split stub ships with the app. User provides the real VCA implementation.
4. **`MarketDataProviding` protocol** abstracts market data. V1 reads manually-entered values from local Ticker model. Later: calls the backend API.
5. **Input validation before, rounding after** the algorithm call. Algorithm receives clean data and returns raw allocations; app rounds to cents.

**Affected:** All — shapes v1 implementation surface.

### 2026-05-12: Tech Specs Split into App, Services, and Database
**By:** Coordinator (Danny, Basher, Rusty, Linus) | **Status:** Adopted

The combined v1 technical specification has been split into three focused documents:

**App Tech Spec** (`docs/app-tech-spec.md`) — Basher
- iOS/iPadOS concerns: SwiftUI/SwiftData app behavior, navigation, validation UX, app service seams
- Contribution-result flow, history UI, app/UI test strategy, implementation phases
- Algorithm internals, backend services, and database schema are intentional references only

**Services Tech Spec** (`docs/services-tech-spec.md`) — Linus
- V1 services defined as local protocol seams (`ContributionCalculating`, `MarketDataProviding`)
- No required backend/OpenAPI client consumption until later phases
- Stable seams now without coupling v1 delivery to API, poller, or generated networking work

**Database Tech Spec** (`docs/db-tech-spec.md`) — Rusty
- SwiftData model is the required runtime data model for v1
- Existing backend Postgres/SQLAlchemy schema documented for future sync (deferred)
- iOS can implement SwiftData without waiting on backend schema changes
- Future sync must handle lossy `Category → Holding` flattening

### 2026-05-12: User Directives
**By:** yashasg (via Copilot) | **Status:** Active

1. **Moving Average Algorithm (15:56 UTC):** For v1, target moving average for value cost averaging, but do NOT implement the algorithm yet. The user will handle the algorithm. Build on existing scaffolding. For anything needed from the user to unblock work, create GitHub issues and assign them to yashasg.

2. **Tech Spec Split (16:12 UTC):** The project should have separate technical specifications for app, services, and database rather than one combined tech spec.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
