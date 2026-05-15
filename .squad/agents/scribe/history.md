# Scribe — History

## Core Context

- **Project:** A value-compass product with a backend API, infrastructure, and iOS client.
- **Role:** Session Logger
- **Joined:** 2026-05-12T22:54:36.371Z

## Learnings

### 2026-05-12T19:12:00.000-07:00: Decision Inbox Merge — App Development TDD & Design Follow-Up Phase
Merged 5 inbox files documenting app development decisions, TDD practices, and design follow-ups:
- Font scaffolding directive (use Stitch font set, not SF-only)
- App development practices directive (small incremental issues, TDD-first)
- App tech spec reconciliation with Tess-approved flows (onboarding clarification, TDD guidance)
- 12 TDD-first app implementation issues created (#30–#45)
- 4 non-blocking design follow-up issues created (#34–#35, #37–#38)

**Key Decision:** Navigation remains Apple-native (NavigationStack iPhone, NavigationSplitView iPad, no v1 tab bar). Stitch is functional scaffolding only; design refinement deferred. App implementation proceeds with semantic colors and adaptive layouts while design tokens are formalized in parallel.

### 2026-05-12T19:22:02.523-07:00: Decision Inbox Merge — DevOps Infrastructure & Deployment, Issue #46 Workflow Fix
Merged 7 inbox files documenting DevOps decisions and infrastructure fixes:
- Supabase managed database as v1 foundation
- FastAPI backend deployment to Azure Container Apps
- CI pipeline (test, build, publish; no auto-deploy pre-MVP)
- Manual workflow_dispatch deployment only
- No shared backend environments until MVP
- GitHub issue #46 created to fix Azure Container Apps auto-deploy violation
- Livingston diagnosed and remediated workflow run #25774741652 failure: removed auto-trigger, fixed invalid parameters, fixed appSourcePath, documented secret/resource requirements

**Key Decision:** All backend deployment is manual (`workflow_dispatch` only) until app MVP approval. Shared backend environments forbidden in v1. Infrastructure foundation is Supabase managed database + Azure Container Apps + CI-published container images.

### 2026-05-12T19:50:09.861-07:00: Decision Inbox Merge — iOS Build Script Defaults
Merged 1 inbox file documenting root build/run script defaults:
- Root `build.sh` and `run.sh` created for iOS/iPadOS frontend development
- Defaults pin to iOS Simulator 26.4 (iPhone 17, iPad A16); all values environment-overridable
- Scripts preserve iOS/iPadOS 17+ deployment baseline
- Syntax validation passed (`bash -n`); scripts are executable
- Blocked: xcodebuild testing pending app project scaffolding (missing `project.pbxproj`)

**Key Decision:** Local development build/run infrastructure is ready. Team can test commands once Xcode project structure is created. Simulator defaults match installed runtime while staying within deployment constraints.

### 2026-05-12T20:01:38.315-07:00: Decision Inbox Merge — Frontend Folder Convention, Build Artifacts, and Tech Spec Refresh
Merged 3 inbox files documenting frontend folder structure, build artifact management, and architecture documentation:
- Frontend folder convention: `ios/` → `frontend/`, with build/run scripts at `frontend/build.sh` and `frontend/run.sh` (replaces stale root-level script entries)
- iOS Xcode .gitignore patterns: Comprehensive rules for frontend/ build artifacts while keeping source/project files trackable
- Tech Spec Refresh (ADR): All four primary tech specs (tech-spec.md, app-tech-spec.md, services-tech-spec.md, db-tech-spec.md) updated to reflect current architecture, deployment model (Azure Container Apps, manual `workflow_dispatch`), database foundation (Supabase managed Postgres), Stitch scaffolding scope (functional only), TDD approach, and multi-platform (iPhone+iPad, light+dark) requirements

**Key Decision:** App folder and build/run tooling now unified under `frontend/` directory with scoped gitignore rules preventing build artifacts from polluting the repository. All tech specs align on current architecture: local-first iOS/iPadOS app, optional backend sync via Azure Container Apps, Supabase as v1 database foundation, Stitch as functional scaffolding only, TDD-first implementation practices, and universal platform support (iPhone+iPad, light+dark modes).

### 2026-05-15T09:03:47Z: Strategy & Compliance Squad Onboarding — 6-Agent Self-Onboarding Session

**Context:** Three-stream rollout (Frontend, Backend, Strategy) completed with label triage of 14/14 open issues. The 6 newest members (Frank, Saul, Turk, Yen, Reuben, Nagel) — all joining the Strategy stream — needed product and architecture context. Spawned all 6 agents in parallel (claude-opus-4.7-xhigh) against canonical specs and roadmap.

**Outcomes:**
- All 6 agents appended a structured `## Onboarding — 2026-05-15` section to their own history.md only (frank: 12.3KB, saul: 14.4KB, turk: 14.8KB, yen: 13.1KB, reuben: 20.8KB, nagel: 17.0KB)
- 6 orchestration-log entries created (one per agent, timestamp-staggered 2026-05-15T09:03:40–09:03:45Z)
- 1 session log written (2026-05-15T09:03:46Z-strategy-compliance-onboarding.md)

**Key Learning: Inbox-is-Empty-by-Design**
Decision inbox is empty because onboarding is personal context, not a team decision. Each agent writes to their own history.md only. **Do not merge empty inbox to decisions.md** — there is no decision to record. The absence of inbox entries is the correct signal that onboarding was self-contained role learning, not a directive requiring consensus.

**Key Learning: Size-Gate Deferral Pattern**
Reuben (20.8KB) and Nagel (17.0KB) exceed the 15KB summarization threshold, but consist almost entirely of fresh onboarding context (+ small Core Context header). There is no accumulated history to summarize. **Deferring summarization — the gate is for pruning stale history growth, not truncating role-defining context.** Fresh onboarding entries are foundational and must remain intact. Summarization queued for next entry (when context becomes superseded or file grows past ~25KB).

**Archive Decision**
decisions.md: 29,775 bytes (over soft 20,480, under hard 51,200). All entries dated 2026-05-12 or later; none qualify for 30-day archive threshold (≤2026-04-15). **No archive action taken.**

**Files Created/Modified**
- 6 history.md files appended (no files deleted or restructured)
- 6 orchestration-log entries (new)
- 1 session log (new)
- 1 learnings entry (this)

### 2026-05-15T02:30:03Z: Gitignore-Bypass Protocol Fix — PR #216 Cleanup Arc

**Context:** Livingston-1 opened PR #216 with 15 files (team restructure + loop strategy). Livingston-2 discovered that 7 runtime files (orchestration logs, session logs, decision inbox stubs) had been unintentionally committed in Livingston-1's initial push because Scribe-1 used `git add -- <path>` (explicit per-file add), which **bypasses `.gitignore`** filtering.

**Root Cause Analysis**
- `.gitignore` only filters the *untracked* set during `git add .` (broad add)
- Explicit `git add -- <path>` (per-file) ignores `.gitignore` entirely
- Files at `.gitignore:18-22`: `.squad/orchestration-log/`, `.squad/log/`, `.squad/decisions/inbox/`
- Livingston-2 fixed with `git rm --cached` on 7 files (commit `98ea5bc` → rebased to `fc45f9d`)

**Protocol Fix — NEW RULE**
Before staging ANY `.squad/` file:
1. Run `git check-ignore -v <path>`
2. If exit code 0 (file is gitignored) → **SKIP** (never override `.gitignore`)
3. If exit code 1 (file is not ignored) → eligible for staging with `git add -- <path>`

**Implementation**
Applied this session:
- Checked `.squad/agents/livingston/history.md` → exit 1 (not ignored) → staged ✅
- Wrote 3 orchestration logs to `.squad/orchestration-log/` → checked → exit 0 (gitignored) → skipped ✅
- Wrote 1 session log to `.squad/log/` → checked → exit 0 (gitignored) → skipped ✅

**Files Created (Untracked, Diagnostic Reference Only)**
- `.squad/orchestration-log/2026-05-15T02-30-00Z-livingston-{1|2|3}.md` (3 files, gitignored)
- `.squad/log/2026-05-15T02-30-00Z-pr-216-cleanup.md` (1 file, gitignored)

**Commits**
- `513fbf2` — Scribe commit with this learning, updated `.squad/agents/livingston/history.md`

**Key Takeaway**
`.gitignore` is a passive filter on `git add .` operations only. To respect `.gitignore` in explicit-file workflows (`git add -- <path>`), **always** validate with `git check-ignore -v <path>` first. This is now the standard protocol for all Scribe staging operations and should be documented in team onboarding.

<!-- Append learnings below -->

