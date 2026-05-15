---
configured: true
interval: 5
timeout: 30
description: "Specialist QA + Market parallel loop"
---

# Specialist Parallel Loop

> ⚠️ Set `configured: true` in the frontmatter above to activate this loop.
> Run with: `squad loop`

## What to do each cycle

This loop is exclusively for the six specialist members below. Do not route work in this loop to other squad members.

### Members and Responsibilities

- **Yen** (Accessibility Auditor): Identify accessibility issues in product UX and implementation.
- **Turk** (HIG Compliance Reviewer): Identify iOS Human Interface Guidelines violations.
- **Nagel** (API Contract Monitor): Identify API contract drift and integration mismatches.
- **Saul** (Market Researcher): Consolidate market/competitor intelligence into actionable opportunities.
- **Reuben** (Legal & Compliance): Identify legal and compliance gaps in product surfaces and flows.
- **Frank** (App Store Optimizer): Monitor App Store competition and identify optimization opportunities.

### Parallel Specialist Pass (required every cycle)

1. Run **Yen**, **Turk**, **Nagel**, **Saul**, **Reuben**, and **Frank** in parallel.
2. Each specialist performs a focused pass and produces validated findings only (no speculative issues).
3. Before creating any issue, search open and recently closed issues for duplicates using title keywords, affected files/screens, and error signatures.
4. If a duplicate exists, do not open a new issue; add new evidence/context to the existing issue and link related findings there.
5. All six specialists can create GitHub issues for validated findings with clear evidence, impact, and proposed change only when no duplicate exists.
6. Every issue must include exactly one routing label: `team:frontend` or `team:backend`.
7. Label and prioritize each issue (`P0`-`P3`, `mvp` when applicable).

### App Store and Competitor Intelligence Flow

- **Frank** and **Saul** continuously monitor competitor App Store listings, reviews, ratings, keyword rankings, screenshots, and preview assets.
- **Frank** files issues for:
  - copy improvements
  - feature gaps surfaced in competitor reviews
  - screenshot and preview update opportunities
- **Frank** feeds all findings directly to **Saul**.
- **Saul** merges Frank's App Store findings with broader market research and files prioritized product opportunities.

### Output Required After Each Cycle

- blockers
- risky changes
- top 3 next actions
- action evidence (`issue #` and supporting links/snippets)
- specialist summary by member (`Yen`, `Turk`, `Nagel`, `Saul`, `Reuben`, `Frank`)
- issue routing proof (`issue #` + `team:frontend` or `team:backend` label)
- duplicate-check proof (`search terms used`, `existing issue links reviewed`, `new issue` vs `updated existing issue` decision)

## Monitoring (optional)

Optional command:

```bash
squad loop
```

## Personality (optional)

Be concise and architecture-first. Use bullets, cite file paths, and separate facts from recommendations.

## Tips

- Keep reports under 12 lines.
- Prefer root-cause fixes over local patches.
- Don't propose architecture changes unless drift is proven.
- Keep this loop exclusive to the six specialist members listed above.

## Re-validation hooks

Some specialists own documents whose accuracy depends on code surfaces that
ship in this repository. When those code surfaces change, the linked
specialist must re-verify the document before the change merges. Hooks are
keyed on file paths (case-sensitive). A change to any path in the trigger
column requires a touch (commit or PR comment) confirming the document is
still accurate.

| Document | Owner | Trigger files |
|---|---|---|
| [`docs/legal/privacy-policy.md`](docs/legal/privacy-policy.md) (issue #224) | Reuben | `app/Sources/Backend/Networking/APIClient.swift`, `app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`, `app/Sources/Backend/Networking/DeviceIDProvider.swift`, `app/Sources/App/PrivacyInfo.xcprivacy`, `app/Sources/App/AppFeature/SettingsFeature.swift` |
| [`docs/legal/third-party-services.md`](docs/legal/third-party-services.md) (issue #294) | Reuben | `app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift`, `app/Sources/Backend/Networking/MassiveAPIKeyStore.swift`, `app/Sources/Backend/Models/Disclaimer.swift`, `app/Sources/Features/SettingsView.swift` |
