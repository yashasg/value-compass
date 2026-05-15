# SKILL: iOS CI Optimization Checklist

**Author:** Livingston (DevOps)
**Extracted from:** ios-ci performance audit (2026-05-14)

---

## When to Apply
Use this checklist whenever diagnosing slow iOS GitHub Actions workflows, or when setting up a new iOS CI pipeline.

---

## Checklist: Diagnosing iOS CI Performance

### Step 1: Measure what you actually have
```bash
# Use github-mcp-server-actions_list: list_workflow_runs for ios-ci.yml and codeql*.yml
# For each completed run: compare job.created_at vs job.started_at (queue wait) and job.started_at vs job.completed_at (execution)
# Per-step timing: use list_workflow_jobs on the run_id
```

**Key metrics to extract:**
- Runner queue wait time (job.created_at → job.started_at)
- Step-level timing for: cache restore, build phase, cache save
- Cache hit ratio (look at "Cache Xcode derived data" step duration — <10s = hit, >30s = miss/partial)
- Cancellation rate (codeql runs cancelled before completing = silent security gap)

### Step 2: Known iOS CI bottlenecks (ranked by frequency)

| Bottleneck | Symptom | Fix |
|---|---|---|
| macOS runner queue | Wall clock >> job execution | Dedicated/larger runners, reduce concurrent macOS jobs |
| Redundant `xcodebuild analyze` + `build` | Build step > 7 min | Set `RUN_ANALYZE=false` if CodeQL runs elsewhere |
| CodeQL on every PR | Never completes, always cancelled | Move to nightly schedule on main |
| DerivedData cache miss | Cache restore > 30s but still slow build | Check cache key — avoid hashing ALL Swift files for the primary key |
| Sequential `build` then `test` | 2x compile overhead | Use `build-for-testing` + `test-without-building` |
| `PLATFORM_MODE=both` on PRs | 2x simulator boot + build time | Use `PLATFORM_MODE=iphone` on PRs, `both` on deploy/main |
| Simulator boot on fresh runner | 30-60s implicit overhead per xcodebuild | Boot simulator before xcodebuild, or warm it in setup |

### Step 3: Cache strategy for iOS

**Good primary cache key pattern:**
```yaml
key: ${{ runner.os }}-xcode-{workflow-name}-${{ hashFiles('app/**/*.swift', 'app/**/*.xcodeproj/project.pbxproj') }}
restore-keys: |
  ${{ runner.os }}-xcode-{workflow-name}-
  ${{ runner.os }}-xcode-
```

**What to cache:**
- `build/app/xcode-derived-data` — compiled objects, avoids full recompile
- `~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex` — Swift module cache, speeds up incremental builds

**Warning:** If DerivedData is >2GB, cache save/restore each add 40-60s. For very large projects, consider only caching ModuleCache.

### Step 4: CodeQL for iOS — correct configuration

**Anti-pattern:** Running CodeQL on every PR with `cancel-in-progress: true` — CodeQL will never finish.

**Correct pattern:**
```yaml
on:
  schedule:
    - cron: '0 6 * * *'    # nightly
  push:
    branches: [main]        # only on merge to main
  workflow_dispatch:         # manual trigger
# Do NOT add pull_request trigger for CodeQL on high-commit repos
```

**CodeQL build phase:** Always uses `build-mode: manual` for Swift. It runs a full xcodebuild compile (same duration as CI build). The CodeQL analysis phase adds 5-15 min after compile. Total: 16-26 min. Never put this behind `cancel-in-progress: true`.

### Step 5: Quick wins vs. bigger investments

**Quick wins (< 1 hour, ships today):**
- Set `RUN_ANALYZE=false` in ios-ci workflow (`PLATFORM_MODE=iphone RUN_ANALYZE=false ./app/build.sh`)
- Move CodeQL to nightly schedule (remove `pull_request` trigger from codeql-ios.yml)

**Medium effort (design needed):**
- Refactor build.sh to use `build-for-testing` + `test-without-building`
- Add a "fast PR check" job (swift-format only, no xcodebuild) that runs in <60s on ubuntu/swift container

**Bigger investments:**
- Dedicated macOS runner or GitHub Teams plan (eliminates 10-45 min queue waits)
- Parallelise iPhone + iPad builds in separate jobs (instead of sequential in one job)
- Split DerivedData and ModuleCache into separate cache entries

---

## Reference: Measured Timings (value-compass, macos-26, May 2026)

| Step | Typical Duration |
|---|---|
| Runner queue wait | 1–45 min (high variance) |
| Cache restore (DerivedData + ModuleCache) | 45–55s |
| swift-format lint (parallel, recursive) | ~30s |
| `xcodebuild analyze` (iPhone sim, Debug) | ~2-3 min |
| `xcodebuild build` (iPhone sim, Debug) | ~3-4 min |
| `xcodebuild test` (iPhone sim, Debug) | ~1-2 min |
| Cache save | 40–58s |
| CodeQL init | ~30s |
| CodeQL analysis (Swift, ~10K LOC) | est. 8–15 min |
