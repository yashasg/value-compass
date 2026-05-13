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
