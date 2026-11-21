# Stories — shepherd

Status board, grep-friendly. One line per story. Status lifecycle: `draft → ready → in-progress → shipped`.

| ID | Status | Slug | Title |
|---|---|---|---|
| SH-001 | shipped | [retire-renovate](SH-001-retire-renovate.md) | Retire Renovate; add shepherd-bump for GitHub Actions |
| SH-004 | shipped | [r0-poc-on-healthy](SH-004-r0-poc-on-healthy.md) | Release 0 POC (shipped 2026-11-21: 3 real fixes in `ham-radio-compass`; pipeline live on 3 pilots) |
| SH-005 | ready | [prompt-injection](SH-005-prompt-injection.md) | Prompt-injection drill: automated simulation, CI gate, live R0-closer on ham-radio-compass |
| SH-006 | ready | [r1-reusable-action](SH-006-r1-reusable-action.md) | R1 umbrella: reusable Action + sandbox + auto-merge gates + waiting period. Decomposes to SH-007/008/009/010. |
| SH-011 | shipped | [dependabot-enforce-automerge](SH-011-dependabot-enforce-automerge.md) | Dependabot baseline: enforce `.github/dependabot.yml` on managed repos; opt-in gated auto-merge (patch/minor, ≤50 lines, ≥24h release-age; scan-not-worse gap until SH-009). Shipped 2026-11-21 (v0.3.0, PR #2). |
