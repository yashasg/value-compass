---
configured: true
interval: 5
timeout: 30
description: "My squad work loop"
---

# Squad Work Loop

> ⚠️ Set `configured: true` in the frontmatter above to activate this loop.
> Run with: `squad loop`

## What to do each cycle

1. Validate the `app/build.sh` and `app/run.sh works`, if not make it a P0 and fix it.
2. If open GitHub issues exist, pick the highest-priority unblocked issue and make code changes in this cycle.
3. For squad work, create branches as `users/squad/<issue_name_fix>`, commit and push changes, then open/update a PR linked with a closing keyword (for example `Closes #123`).
4. **Before creating a PR, run `.github/scripts/validate-secrets.sh` to ensure no GitHub secrets are logged in CI/CD workflows.** Fail the PR if validation fails.
5. Monitor CI/CD for squad PRs, fix failing checks, address comments, and squash merge to `main` when green so linked issues close with the merge.
6. If no open GitHub issues remain, run a parallel sweep, open validated issues, and start the highest-impact issue immediately.
7. Use the MVP milestone tag on new issues
8. Maintain clean code, use docs/python/coding_standards.md and docs/swift/coding_standards.md. Always look to remove/delete stale code and files.
9. Work on multiple issues in parallel when agents are unlikely to overwrite each other's changes (e.g. issues that touch disjoint files, or independent docs/CI/feature scopes). Use one branch + PR per issue so reviews and merges stay isolated.
10. After completing work, output:
	- blockers
	- risky changes
	- top 3 next actions
	- action evidence (`commit SHA` and/or `PR #` and/or `issue #`, or blocker logs)

## Monitoring (optional)

Optional command:

```bash
squad loop
```

## Personality (optional)

Be concise and architecture-first. Use bullets, cite file paths, and separate
facts from recommendations.

## Tips

- Keep reports under 12 lines.
- Prefer root-cause fixes over local patches.
- Don't propose architecture changes unless drift is proven.
- Parallelize only when changes don't conflict; serialize anything that touches the same file or migration.
