---
id: SH-020
slug: ci-timing-digest
story: docs/stories/SH-020-ci-timing-digest.md
branch: feat/SH-020-timing-digest
status: shipped
---

# SH-020 plan — weekly timing digest + DORA

**Story:** [SH-020](../stories/SH-020-ci-timing-digest.md)

## Design delta

Extends the stubbed `.github/workflows/digest.yml` with a real body
that compares live fleet CI timings (via `gh run list --json`) against
the SH-026 frozen baseline at `docs/specs/dev-cycle-baseline.md`.
Regressions become needs-human issues (one per `(repo, workflow, event)`
tuple above the 25 % threshold). DORA metrics (deploy frequency + lead
time) ride in the same digest.

**New**: `scripts/digest-timing.sh` (~130 lines bash+jq+awk):

- `baseline_medians()` — regex-generic parser (not hardcoded to specific
  owner/repo names; works on fixtures)
- `current_medians($repo)` — gh-driven, grouped by `(workflow, event)`,
  computes median_min + p90_min + pct_green
- `dora_for_repo($repo)` — deploy_frequency_7d (releases) + lead_time
  (hours, median over 20 merged PRs)
- Fail-safe: subshell-pipeline bug fixed by routing rows through a
  tmpfile (`$regressions` counter survives the loop)
- Replay mode via `SH_020_FIXTURE` + `BASELINE_FILE` env vars (acceptance)

**Extended**: `.github/workflows/digest.yml`:

- Checks out repo, installs jq
- Runs `scripts/digest-timing.sh`, captures stdout + stderr
- Writes markdown to `$GITHUB_STEP_SUMMARY` (visible on the Actions run page)
- Posts digest to `NTFY_TOPIC_URL` if set
- Opens needs-human issues on regressed repos (dedupe via existing-issue search)

**New test**: `test/acceptance/test_SH_020_timing_digest.sh` (9 assertions,
2 fixture scenarios: no-regression + 50 %-above-baseline regression).

**CAP flipped**: `dev-cycle.timing.json-emission` design → active with
pointers to digest-timing.sh + test + workflow.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Download `ci-timing-*` artifacts per run + parse | Would require `gh run list` + per-run `gh run download`. Wall-clock from `gh run list --json` alone gives the same number without the artifact dance. Matches what SH-026 baseline does; comparisons are apples-to-apples. |
| Full DORA (change_failure_rate + time_to_restore) | Needs auto-revert history (SH-028) + known revert-PR convention. Out of R2 scope. Shipped with deploy_frequency + lead_time; other two land with SH-028. |
| Fail the digest workflow on regression | Would spam cron failure emails every Monday. Regressions open issues (actionable); the workflow itself continues. |

## Breaking changes

- [ ] No. New script + workflow body; existing `digest:` cron job gets real content.

## Rollout

- [x] README untouched — digest is internal shepherd ops.
- [x] `docs/specs/DESIGN.md` §9 (digest) stays pointing at this behaviour.
- [ ] Downstream: first live cron on next Monday 09:00 UTC will emit.
  Monitor the opened needs-human issues; tune regression threshold if
  the fleet's natural day-to-day noise exceeds 25 %.

**R2 slot**: Fri 2026-12-11.

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Script exists + executable + usage | `test_SH_020_timing_digest.sh:§1` | ✅ |
| No-regression fixture → exit 0 | `test_SH_020_timing_digest.sh:§2` | ✅ |
| Regression fixture → exit 2 | `test_SH_020_timing_digest.sh:§3` | ✅ |
| Regression row emits ⚠️ marker | `test_SH_020_timing_digest.sh:§4` | ✅ |
| Regression row emits +Δ% | `test_SH_020_timing_digest.sh:§4` | ✅ |
| Regression stderr names (repo, wf, ev) | `test_SH_020_timing_digest.sh:§5` | ✅ |
| Output header + baseline column | `test_SH_020_timing_digest.sh:§6` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `dev-cycle.timing.json-emission` | ✅ | ✅ (exits 0 / 2; stderr regression lines) | design → active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys §7 (no change_failure_rate / time_to_restore — those are SH-028) | ✅ |
| New CAP referenced in CAPABILITIES.md | ✅ |
| Protected-files invariant intact | ✅ |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

## Post-merge notes

_(filled after merge)_
