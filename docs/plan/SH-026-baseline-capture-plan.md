---
id: SH-026
slug: baseline-capture
story: docs/stories/SH-026-baseline-capture.md
branch: feat/SH-026-baseline-capture
status: in-progress
---

# SH-026 plan — Baseline capture: freeze pre-adoption fleet timings

**Story:** [SH-026](../stories/SH-026-baseline-capture.md)

## Design delta

One-shot shell script `scripts/measure-baseline.sh` (~120 lines bash + jq). Pulls `gh run list --json workflowName,createdAt,updatedAt,conclusion,event` for each fleet repo, groups by `(repo, workflowName, event)` tuple, computes `median_min` + `p90_min` + `pct_green` from the `(updatedAt - createdAt)` duration, and emits a markdown table to stdout. Writes the real baseline to `docs/specs/dev-cycle-baseline.md` (committed with captured timestamp).

Shape:

- No new dependencies — `gh` and `jq` are already available on every workstation + GitHub-hosted runner that runs shepherd CI.
- Replay mode via `SH_026_SAMPLE_FILE=fixture.jsonl` — lets the acceptance test exercise the script offline without API calls.
- Three exit codes: `0` success, `1` tool/API error, `2` MIN_SAMPLES breach (warning), `3` usage error.
- Default fleet list hardcoded (updated when `docs/FLEET.md` changes); positional args override.

New files:

- `scripts/measure-baseline.sh` — the script.
- `test/acceptance/test_SH_026_baseline.sh` — 21 assertions covering: script existence/executability, baseline doc shape, replay mode statistics (median/p90/pct_green), MIN_SAMPLES warning exit, usage flag, unknown flag, every fleet repo present.

Updated files:

- `docs/specs/dev-cycle-baseline.md` — replaces the SH-014 placeholder with the real 2026-11-22 capture (57 rows).
- `docs/specs/CAPABILITIES.md` — `dev-cycle.baseline.frozen-snapshot` flips `design → active` with the test pointer.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Python script | Adds a Python dep to shepherd (currently pure bash + Zig). Bash + jq handles the JSON fine. |
| Keep the placeholder; populate only when SH-022/023/024 pick up | Measurement happens AFTER adoption. The dev-cycle doc's point 3 ("Get Forge and Beaconry timings") is explicit that baselines ship BEFORE the per-repo speedup work. |
| Call `gh api /repos/.../actions/runs` directly | `gh run list --json` already filters to the fields we need; direct API adds auth plumbing + pagination for zero win. |
| Full workflow-step timing (not just wall-clock) | GitHub's `/runs/<id>/jobs` endpoint is paginated per-run; capturing step timings across 100 runs × 7 repos is 700 API calls → likely rate-limited. Wall-clock is the headline number anyway. SH-020 digest will add per-step timing live via `build/ci-timing.json`. |

## Breaking changes

- [ ] No — strictly additive. New script, new test, replaced placeholder doc, one CAP status flip. No existing behaviour changes.

## Rollout

- [x] README untouched — SH-026 is internal.
- [x] `memory/project.md` invariants unchanged.
- [x] `memory/workflow.md` — test suite grows by one file; `make test-acceptance` picks it up via the existing `test/acceptance/test_SH_*.sh` wildcard.
- [x] `docs/specs/DESIGN.md` — no §12 / §13 shift. The script reads public GitHub API with the user's gh auth; no secret scope change.
- [ ] Downstream notice — n/a.

**Target slot:** opportunistic cherry-pick in the SH-014 umbrella rollout — needs to ship BEFORE SH-022/023/024 so their Shipping evidence tables can claim measured deltas.

## Shipping evidence (fill at step 6a)

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Script exists + executable | `test_SH_026_baseline.sh:§1` | ✅ |
| Baseline doc exists + has expected table shape | `test_SH_026_baseline.sh:§2` | ✅ |
| Replay mode produces correct median/p90/pct_green | `test_SH_026_baseline.sh:§3` | ✅ |
| MIN_SAMPLES breach exits 2 | `test_SH_026_baseline.sh:§4` | ✅ |
| `--help` exits 3 | `test_SH_026_baseline.sh:§5` | ✅ |
| Unknown flag exits 3 | `test_SH_026_baseline.sh:§6` | ✅ |
| Every fleet repo appears in the baseline | `test_SH_026_baseline.sh:§7` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `dev-cycle.baseline.frozen-snapshot` | ✅ (`test_SH_026_baseline.sh`) | ✅ (MIN_SAMPLES exit 2, usage exit 3, replay mode) | design → active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (out-of-scope) — no digest / DORA / cross-repo aggregation | ✅ |
| New CAP in §9 appears in `docs/specs/CAPABILITIES.md` | ✅ |
| Protected-files invariant intact (DESIGN §12) | ✅ (templates/ untouched) |
| Budget caps unchanged | ✅ n/a |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

## Post-merge notes

_(filled after merge)_
