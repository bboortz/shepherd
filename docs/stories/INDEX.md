# Stories — shepherd

Status board, grep-friendly. One line per story. Status lifecycle: `draft → ready → in-progress → shipped`.

| ID | Status | Slug | Title |
|---|---|---|---|
| SH-001 | shipped | [retire-renovate](SH-001-retire-renovate.md) | Retire Renovate; add shepherd-bump for GitHub Actions |
| SH-004 | shipped | [r0-poc-on-healthy](SH-004-r0-poc-on-healthy.md) | Release 0 POC (shipped 2026-11-21: 3 real fixes in `ham-radio-compass`; pipeline live on 3 pilots) |
| SH-005 | shipped | [prompt-injection](SH-005-prompt-injection.md) | Prompt-injection drill: `make injection-drill` 10/0 + live drill on ham-radio-compass closed R0 exit-criterion 2026-11-21 (v0.4.0, PR #8). |
| SH-006 | ready | [r1-reusable-action](SH-006-r1-reusable-action.md) | R1 umbrella: reusable Action + sandbox + auto-merge gates + waiting period. Decomposes to SH-007/008/009/010. |
| SH-007 | shipped | [reusable-action](SH-007-reusable-action.md) | R1-A: reusable `workflow_call` workflow + thin caller + required `.shepherd.yml` gate. Shipped 2026-11-21 (v0.5.0-rc1, PR #9) + canary on `bboortz/healthy` (PR #18 + run 44938249380 ✅ end-to-end). |
| SH-009 | shipped | [auto-merge-gates](SH-009-auto-merge-gates.md) | R1-C: auto-merge gates + schema v1 + dry-run + needs-human. Shipped 2026-11-21 across rc1→rc6 (v0.6.0-rc6, [PR #13](https://github.com/bboortz/shepherd/pull/13) + direct fixes). All 4 §12 gates active. Live canary auto-merged [HRC #47](https://github.com/bboortz/ham-radio-compass/pull/47) by `app/github-actions`. |
| SH-010 | shipped | [waiting-period](SH-010-waiting-period.md) | R1-D: `gate.waiting-period` on agent flow. Shipped 2026-11-21 (v0.7.0-rc1, [PR #15](https://github.com/bboortz/shepherd/pull/15)). All five §12 auto-merge gates now active on the agent flow. Pilot re-pin + live canary deferred (daily cron will pick it up tomorrow). |
| SH-011 | shipped | [dependabot-enforce-automerge](SH-011-dependabot-enforce-automerge.md) | Dependabot baseline: enforce `.github/dependabot.yml` on managed repos; opt-in gated auto-merge (patch/minor, ≤50 lines, ≥24h release-age; scan-not-worse gap until SH-009). Shipped 2026-11-21 (v0.3.0, PR #2). |
| SH-012 | in-progress | [docs-layout-reshape](SH-012-docs-layout-reshape.md) | Reshape `docs/` into `specs/` + `plan/` + `stories/`. DESIGN.md + CAPABILITIES.md move to `docs/specs/`. New `test_SH_012_docs_layout.sh` + wired `make verify-traceability` enforce layout + reference integrity across all tracked non-CHANGELOG files. |
