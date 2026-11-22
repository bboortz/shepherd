---
id: SH-032
slug: hrc-default-branch-flip
story: docs/stories/SH-032-hrc-default-branch-flip.md
branch: docs/SH-030-SH-033-fleet-audit
status: shipped
---

# SH-032 plan — HRC default-branch flip

**Story:** [SH-032](../stories/SH-032-hrc-default-branch-flip.md)

## Design delta

Single `gh repo edit` flip. No code change.

- `gh repo edit bboortz/ham-radio-compass --default-branch dev` (executed 2026-11-22).
- `test/acceptance/test_SH_029_fleet_defaults.sh` extended: `EXPECTED_DEV` grows to include `bboortz/ham-radio-compass`; `EXPECTED_MAIN` becomes empty. Comment updated. Now 8 assertions (was 7 + 1 skip).

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Wait for the next HRC-side story | Fleet-uniformity drift costs us the "dev-cycle is uniform across 7 repos" story. The flip is 10 seconds of operator time. |
| Separate dedicated chore/* branch | Bundled with SH-030/SH-033 audit follow-ups — the three stories share the audit doc + reference each other. |

## Breaking changes

- Any HRC contributor who opens a new PR will now default to `dev` as base instead of `main`. GitHub preserves the base of **open** PRs. Verified: `gh pr list --repo bboortz/ham-radio-compass --base main --state open` → empty.

## Rollout

- [x] GitHub setting flipped.
- [x] Fleet-defaults acceptance test updated.
- [x] Audit cell column 1 flipped 6✅/1❌ → 7✅.
- [x] Story → shipped.

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Evidence | Status |
|---|---|---|
| HRC default is `dev` | `gh repo view bboortz/ham-radio-compass --json defaultBranchRef --jq .defaultBranchRef.name` → `dev` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | Evidence | Status |
|---|---|---|
| `dev-cycle.fleet.branching-convergence` | 7/7 fleet repos default to `dev`; `test_SH_029_fleet_defaults.sh` 8/8 green | active (row evidence refreshed) |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story §7 obeyed (no code change) | ✅ |
| No open PRs stranded on `main` base | ✅ (verified via `gh pr list --base main`) |
| `test_SH_029_fleet_defaults.sh` 8/8 green | ✅ |
| `make check` green on shepherd | ✅ |
