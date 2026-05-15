# Skill — Issue Triage by Stream

> Apply `team:*` workstream labels to GitHub issues based on `.squad/streams.json` folder scope, not on legacy specialist labels.

## When to Use

- A new issue is opened and is missing a `team:*` label.
- A batch of legacy issues need stream routing (e.g., after a streams.json refresh).
- Auditing existing issues for label drift.

## Inputs

- `.squad/streams.json` — the source of truth for stream → folderScope mapping.
- The issue body (title alone is insufficient — read acceptance criteria and scope).
- The repo's actual folder layout (to validate file references in the issue).

## The Heuristic (apply in order)

### Step 1 — Read the issue's Scope and Acceptance Criteria

Skim the issue body for:
- Explicit file paths (`app/Sources/Backend/...`, `docs/audits/...`, etc.)
- Topic keywords (UI, navigation, persistence, networking, audit, etc.)
- Artifacts the issue produces (a screen, a model, a service, a doc, a test).

### Step 2 — Match to folderScope

For each stream in `streams.json`, check whether **any** of the issue's artifacts/keywords land inside the stream's `folderScope`. Use this default keyword map (derived from the v1 streams.json):

| Stream | Folder anchors | Topic signals |
|---|---|---|
| `team:frontend` | `app/Sources/Features/**`, `app/Sources/App/AppFeature/**`, `app/Sources/DesignSystem/**`, `app/Sources/Assets/**`, `app/Tests/**`, `docs/design-system-colors.md` | screens, view models, navigation, design tokens, color/typography, XCTest, snapshot tests, accessibility on the iOS surface, charts/UI rendering, onboarding flow UI |
| `team:backend` | `app/Sources/Backend/**`, `app/Sources/App/Dependencies/**` | SwiftData models, persistence, networking (URLSession), Contracts/protocols, Keychain, DI/composition root, calc engine, market data, indicator/TA packages |
| `team:strategy` | `docs/audits/**`, `docs/research/**`, `docs/legal/**`, `docs/aso/**` | market research, legal/compliance, accessibility audit (WCAG docs), ASO, HIG audit, API contract monitoring (read-only review) |

### Step 3 — Multi-label when multiple streams hit

If an issue legitimately spans streams (typical for a feature with both UI and persistence), apply **all** matching `team:*` labels. Don't force a single-label bucket.

Examples:
- "Build Snapshot save UI + persist exact inputs" → both `team:frontend` (UI) and `team:backend` (persistence).
- "Add typeahead UI + bundled metadata service" → both.
- "Implement SwiftData models" → backend only (no UI surface).
- "Implement NavigationStack" → frontend only (no data layer).

### Step 4 — Leave unlabeled when nothing fits

Don't guess. If the issue is:
- DevOps/CI (workflow files, build scripts, `.github/`),
- Leadership/architecture spec (`docs/tech-spec*.md`),
- Mothballed Python `backend/` directory,
- Or otherwise unowned,

…then leave it without a `team:*` label and **note it in the triage report with the reason**.

## Anti-Patterns

- ❌ **Don't trust legacy `squad:*` labels for stream routing.** A `squad:virgil` issue may be pure UI work; the file scope wins.
- ❌ **Don't single-label cross-stream features.** Forcing a feature to "pick a side" hides the real coordination cost.
- ❌ **Don't use the Python `backend/` folder as a `team:backend` signal.** That tree is mothballed in v1; only `app/Sources/Backend/**` and `app/Sources/App/Dependencies/**` count.
- ❌ **Don't remove existing labels when adding `team:*`.** Use `--add-label` only. Preserve `squad:*`, `priority:*`, `mvp`, `ios`, etc.
- ❌ **Don't guess when uncertain.** Flag for human review.

## Mechanics

```bash
# 1. Create labels (idempotent — fall back to edit if they exist)
gh label create "team:frontend" --color "1f6feb" --description "Frontend stream — iOS/iPadOS UI, design system, features, tests" --repo <OWNER>/<REPO> \
  || gh label edit "team:frontend" --color "1f6feb" --description "..." --repo <OWNER>/<REPO>

# 2. Pull all open issues with labels and body
gh issue list --repo <OWNER>/<REPO> --state open --limit 100 --json number,title,labels,body

# 3. Add labels (NEVER use --remove-label here)
gh issue edit <N> --add-label "team:frontend,team:backend" --repo <OWNER>/<REPO>

# 4. Verify
gh issue list --repo <OWNER>/<REPO> --state open --json number,labels \
  | jq -r '.[] | "#\(.number): \([.labels[].name | select(startswith("team:"))] | join(", "))"'
```

## Reporting Template

After a triage run, report:

1. **Labels created/updated** (3-row table with verified colors).
2. **Issues labeled** — table of `# | Title (truncated) | Labels Applied | 1-line rationale`.
3. **Issues left unlabeled** — table of `# | Title | Why not stream-routed`.
4. **Uncertain / flagged** — issues you couldn't confidently triage (do NOT guess).
5. **Distribution stats** — count per stream and per multi-label combo, useful for spotting whether one stream is overloaded.

## Maintenance

If `.squad/streams.json` changes (new stream added, folderScope edited), refresh:
1. The label set (create new `team:*` label if a stream is added).
2. This skill's keyword/topic table.
3. The standing decision drop at `.squad/decisions/inbox/danny-team-label-rollout.md` (or its archived successor).
4. Re-triage open issues if folder scope shifted materially.

## Related

- `.squad/streams.json` — source of truth.
- `.squad/decisions/inbox/danny-team-label-rollout.md` — initial rollout record (2026-05-15).
- `.squad/decisions.md` — broader squad decisions context.
