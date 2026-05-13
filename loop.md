---
configured: false
interval: 10
timeout: 30
description: "My squad work loop"
---

# Squad Work Loop

> ⚠️ Set `configured: true` in the frontmatter above to activate this loop.
> Run with: `squad loop`

## What to do each cycle

1. Validate the `frontend/build.sh` and `frontend/run.sh works`, if not make it a P0 and fix it
1. If open GitHub issues exist, pick the highest-priority unblocked issue and make code changes in this cycle.
2. For squad work, create branches as `users/squad/<issue_name_fix>`, commit and push changes, then open/update a PR linked with a closing keyword (for example `Closes #123`).
3. Monitor CI/CD for squad PRs, fix failing checks, address comments, and squash merge to `main` when green so linked issues close with the merge.
4. If no open GitHub issues remain, run a parallel sweep, open validated issues, and start the highest-impact issue immediately.
5. Use the MVP milestone tag on new issues
5. After completing work, output:
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
- Don’t propose architecture changes unless drift is proven.
h cycle

Describe what your squad should do every time the loop wakes up. Be specific —
the more context you give, the better your squad performs.

Examples:
- Check for new messages in a Teams channel and summarize action items
- Review recent pull requests and flag anything needing attention
- Run a health check on staging and report anomalies
- Scan the inbox for anything that needs a response today

<!-- Replace this section with your actual loop instructions. -->

## Monitoring (optional)

If you want your squad to watch external channels, enable monitor capabilities:

```bash
squad loop --monitor-email --monitor-teams
```

## Personality (optional)

If your squad has a specific voice or style, describe it here so each cycle
stays consistent.

Example: "Be concise. Use bullet points. Flag blockers clearly."

## Tips

- **Be specific.** Vague prompts produce vague results.
- **Set boundaries.** Tell the squad what NOT to do (e.g., "Don't send messages to anyone but me").
- **Start small.** Begin with one task per cycle, then expand.
- **Use frontmatter.** `interval` controls how often the loop runs. `timeout` caps each cycle.
