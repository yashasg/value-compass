# Livingston — History

## Core Context

- **Project:** A value-compass product with a backend API, infrastructure, and iOS client.
- **Role:** DevOps
- **Joined:** 2026-05-12T22:54:36.370Z

## Learnings

### 2026-05-12T19:22:02.523-07:00: Azure-Generated Workflow Auto-Deploy Issue & Fix

When Azure DevOps generates GitHub Action workflows:
- Placeholder parameters (e.g., `_dockerfilePathKey_`) are left unfilled and cause action parsing failures
- Workflows are set to auto-trigger on push, which may violate MVP deployment policies
- File paths in action config (`appSourcePath`) may have incomplete interpolation (missing slashes)

**Action taken:** Updated `vc-services-AutoDeployTrigger` workflow to:
1. Remove automatic push triggers; deploy only via manual `workflow_dispatch` per MVP decision
2. Remove invalid placeholder parameters from Azure container-apps-deploy-action config
3. Fix appSourcePath path interpolation (`${{ github.workspace }}/backend/api`)
4. Document required secrets and Azure resources for future deployment

**Key lesson:** Always audit Azure-generated workflows before merging to main. Sanitize auto-generated config and enforce policy (manual-only deployment until MVP approval).

### 2026-05-12T19:22:02.523-07:00: GitHub Issue Created for Azure Workflow Fix

Created issue #46 to consolidate Azure Container Apps workflow remediation. Issue tracks:
- Removal of auto-deploy triggers (MVP policy: manual-only via `workflow_dispatch`)
- Removal of invalid Azure-generated placeholder parameters
- Validation of `appSourcePath` for FastAPI backend
- Documentation of required GitHub Secrets and Azure resources
- YAML linting and workflow validation

**Applied labels:** `squad` (squad:livingston, devops, ci labels do not exist in the repo; used available labels only).


### 2026-05-12T20:07:05.152-07:00: Apple Deploy Manual-Only MVP Policy

The iOS App Store Connect deployment workflow must remain manual-only during MVP:
- Keep `ios-deploy.yml` on `workflow_dispatch` only; do not add push or tag triggers.
- Preserve the manual `ref` input so release and rollback deploys can target an explicit commit, branch, or tag.
- iOS CI may still run on push/PR; this policy applies only to signing/upload to Apple.

**Action taken:** Removed the `ios-v*` tag push trigger from `ios-deploy.yml`, updated workflow/README wording, and captured the team decision in the inbox.

### 2026-05-13T03:07:05.152Z: Scribe Session — Apple Deployment Decision Archived

iOS App Deployment decision archived to `.squad/decisions.md` as "iOS App Deployment — Manual Trigger Only" (Adopted). MVP policy confirmed: manual-only via `workflow_dispatch`, no automatic TestFlight/App Store uploads from push or tag events. Orchestration log written at `.squad/orchestration-log/2026-05-13T03-07-05-152Z-livingston.md`.

### 2026-05-12T20:16:21-07:00: Staging & Validation Process for Multi-Domain Changes

**Process learning:** When committing cross-cutting changes (docs, team infrastructure, frontend rename, deploy policy), isolate intentional artifacts from scratch/runtime files:

1. **Inspect untracked files carefully** — distinguish project artifacts (docs, frontend/, stitch_value_compass_vca_calculator/, .squad/, .copilot/, .github/agents/, .gitattributes) from session scratch (excalidraw.log, loop.md, loop.sh).
2. **Stage explicitly by path** — avoid `git add .` blindly. Use `git add path1 path2 ...` grouped by logical domain.
3. **Validate before commit:**
   - Shell scripts with `bash -n` to catch syntax errors
   - Workflow YAML structure (especially `workflow_dispatch` constraints for deploy workflows)
   - .gitignore patterns with `git check-ignore` to verify artifact exclusion
4. **Single comprehensive commit** — summarize all changes (specs, team scaffolding, frontend setup, deploy policy) in one message with full context.
5. **Document blockers prominently** — note missing project.pbxproj so next engineer understands xcodebuild will fail.

**Result:** Commit 151a739 (PR #47): 147 files, 17.5K lines, clean staging with no scratch artifacts.

### 2026-05-14T20:24:17-07:00: iOS CI Performance Audit — Build Time & CodeQL Bottlenecks

**Context:** User reported "Analyze iOS" is slow and builds are ~6 minutes.

**Measured timings (from actual GitHub Actions runs):**

| Workflow | Run | Queue Wait | Job Execution | "Build" step |
|---|---|---|---|---|
| ios-ci | 25897741308 (success) | 18m28s | 9m25s | 7m25s |
| ios-ci | 25895856554 (success) | 16m21s | 11m7s | 9m21s |
| ios-ci | 25895119480 (success) | 1m33s | 7m16s | 5m44s |
| codeql-ios | 25896830357 (cancelled) | 45m23s | 8m58s | 6m24s (cancelled mid-build) |

**Key findings:**

1. **"Analyze iOS" (codeql-ios.yml) has NEVER completed in recent history** — every single run is cancelled. Root causes:
   - macOS runner queue wait: 10–45+ minutes waiting for a macos-26 runner
   - High squad commit cadence (many PRs rapidly merged) triggers `concurrency.cancel-in-progress` before the 20+ minute CodeQL job finishes
   - CodeQL requires: cache restore (~50s) + CodeQL init (~30s) + full xcodebuild build (~6-9min) + CodeQL static analysis (est. 8-15min for Swift) = estimated 16-26 minutes total if it ever ran

2. **ios-ci build step (6-minute claim)** — floor is 5m44s, typical is 7-9min. Three sequential xcodebuild invocations:
   - `xcodebuild analyze` (RUN_ANALYZE=true → adds 1-2 min, compiles whole app)
   - `xcodebuild build` (full debug build)
   - `xcodebuild test` (if testables present)
   - Plus swift-format lint (recursive, parallel) upfront

3. **Cache operations**: DerivedData cache restore takes 45-55s every run. Cache save takes 40-58s. Net: ~90s per run just in cache I/O. The cache key hashes all Swift files, so any PR with code changes falls back to the prefix restore key (partial hit), restoring only the module cache portion.

4. **Wall-clock dominators**: macOS runner queue (1-45 min) >> build step (6-9 min) >> cache (90s) > everything else.

**Recommended optimizations (ranked by impact):**

1. Move CodeQL to nightly schedule on main only (not every PR) — fixes the "never completes" problem entirely
2. Remove `RUN_ANALYZE=true` from ios-ci.yml (save ~1-2 min per build, since CodeQL handles analysis)
3. Split xcodebuild into `build-for-testing` + `test-without-building` to avoid redundant compile pass
4. Accept cache duplication cost or compress DerivedData before caching

**Skill:** Wrote `ios-ci-optimization` SKILL.md. Decision recommendation written to inbox.

### 2026-05-14T20:35:42-07:00: iOS CI/CD Findings Filed as P0 GitHub Issue

Filed P0 GitHub issue #206 (`yashasg/value-compass`) to track iOS CI/CD findings from this session:
- **Title:** "[P0] iOS CI/CD: Analyze workflow never completes; builds take 6-9 min — quick wins available"
- **Issue URL:** https://github.com/yashasg/value-compass/issues/206
- **Labels applied:** `squad`, `priority:p0`, `ci-cd`, `ios`
- **Content:** Captures both CodeQL "never completes" problem and redundant 6-minute build steps with root cause analysis and ranked fixes
- **Quick wins:** Flip `RUN_ANALYZE=true` to `false` in ios-ci.yml; move CodeQL to nightly cron on main only

**Effect:** Squad Lead (danny) will triage via `squad` label; issue is now tracked and prioritized for implementation.


**2026-05-15 — Cross-Agent Update:** Team:* label scheme is live on GitHub (team:frontend, team:backend, team:strategy). All 14 open issues triaged. See .squad/decisions.md for the triage map and rationale.

### 2026-05-15T02:18:00-07:00: Release — Squad Restructure (Commit 18bbfe3, PR #216)

**Commit SHA:** `18bbfe3`
**PR:** #216 — https://github.com/yashasg/value-compass/pull/216

Landed trailing artifacts from the team-restructure work-stream: 7 new agent charters (Yen, Turk, Nagel, Saul, Reuben, Frank, Virgil), casting state, config overrides, routing domain expansion (13 domains), and `loop-strategy.md` for specialist parallel loop. All staged explicitly (15 files, 905 insertions).

**Insight:** When squad-restructure work spans multiple Scribe-coordinated commits (e.g., `7790594` streams rollout, `1ad9c32` member onboarding, `18bbfe3` config+tooling), trailing config files (charters, casting/*.json, config.json, routing.*) often slip past staging because Scribe's HARD GATE rule restricts each spawn to specific file patterns. Future Scribe spawns should:
1. Explicitly check for unstaged `.squad/` config files before committing
2. Bundle trailing config into the same spawn manifest as the work that depends on them, or
3. Coordinator should pre-stage config files before spinning Scribe

**Outcome:** Clean release; Coordinator should restart session post-merge (routing.json, team.md, config.json affect agent model selection and routing behavior).

### 2026-05-15T02:22:30-07:00: Cleanup — Untrack Runtime Logs (Commit 98ea5bc, PR #216)

**Commit SHA:** `98ea5bc`
**PR:** #216 — appended cleanup commit on top of squad restructure

**The problem:** `.gitignore` lines 17–22 declare these paths as runtime-only (never tracked):
```
.squad/orchestration-log/
.squad/log/
.squad/decisions/inbox/
.squad/sessions/
.squad/.scratch/
```

Scribe's commit `1ad9c32` (member onboarding) bypassed this ignore by using explicit `git add -- <path>`. Once a file is tracked in git, `.gitignore` no longer blocks it — gitignore only applies to the *untracked* set during `git add .` or `git add <untracked-path>`.

**Impact:** 7 runtime files were committed:
- `.squad/log/2026-05-15T09:03:46Z-strategy-compliance-onboarding.md`
- `.squad/orchestration-log/2026-05-15T09:03:4[0-5]Z-{frank,saul,turk,yen,reuben,nagel}.md`

**Action taken:** Used `git rm --cached -- <file>` (7 commands, one per file) to untrack them while keeping the files on disk. Files are now untracked and respect `.gitignore`.

**Root cause:** Scribe's protocol is to stage files that Scribe wrote in this session via `git add -- <path>`. This assumes files in `.squad/` are intentional commits, but it bypasses gitignore. The contract states: runtime logs (orchestration-log/, log/, decisions/inbox/) are never committed, yet the explicit stage gate skipped the ignore check.

**Protocol fix (for future Scribe spawns):** Before staging any file under `.squad/`, Scribe should:
```bash
git check-ignore -v <path>
```
If the path matches a gitignore rule, skip the stage (or require explicit override flag) unless the rule is intentionally waived. This prevents runtime/intent contract drift.

**Verification:** Post-push, `git ls-files .squad/orchestration-log/ .squad/log/` returns empty (untracked); 37 files still on disk in orchestration-log/. PR #216 shows 7 deletions for the untrack commit.

### 2026-05-15T02:25:00-07:00: PR Cleanup — Rebase yashasg/subsquad to Drop 74e3ace (Massive API Key)

**Context:** PR #216 was built on `yashasg/subsquad`, which already had an unrelated commit `74e3ace` (feat: Massive API key validation + Keychain storage) from an earlier Squad Bot session. The commit was staged on a separate branch `users/squad/massive-api-key-keychain` with its own PR #215, but got bundled into #216 by accident when we started stacking commits.

**Goal:** Rebase `yashasg/subsquad` onto `main` directly, dropping `74e3ace`, so PR #216 shows only the 5 squad-restructure commits.

**Operation:**
```bash
git tag squad-pre-rebase-2026-05-15 yashasg/subsquad  # backup
git fetch origin main --quiet
git rebase --onto origin/main 74e3ace yashasg/subsquad
# replays: 7790594, 1ad9c32, 18bbfe3, 1ba637f, 98ea5bc (5 commits)
git push --force-with-lease origin yashasg/subsquad
```

**Result:**
- PR #216 now shows 5 commits, no 74e3ace (confirmed via `gh pr view 216`)
- PR #215 remains OPEN on `users/squad/massive-api-key-keychain` with only `74e3ace`
- New HEAD: `fc45f9d` (Squad: untrack runtime logs)
- All commit SHAs changed due to rebase; PR #216 body updated to note this

**Lesson for Squad:** When a session starts on a branch that already has unrelated commits, the Coordinator should **check `git log main..HEAD` BEFORE the first spawn** to either branch off cleanly or warn Scribe. Bundling unrelated commits into a PR is easy to miss until code review. The recovery pattern — tag-before-rebase + `--force-with-lease` — is safe and reversible but adds friction.

**Protocol fix:** Pre-session checklist for Coordinator:
1. If `git log main..HEAD` shows commits not authored in this session, offer to branch off or rebase first
2. If those commits have their own PR/branch, mention it explicitly in the session context to avoid accidental bundling

**Safety net:** The tag `squad-pre-rebase-2026-05-15` pointed to the old HEAD; deleted after verification. `users/squad/massive-api-key-keychain` remains untouched on origin — `74e3ace` is always recoverable.
