---
id: SH-026
slug: baseline-capture
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-026 — Baseline capture: freeze pre-adoption fleet timings

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** One-shot: pull `gh run list --json` across the fleet and freeze medians to `docs/specs/dev-cycle-baseline.md` BEFORE the per-repo speed-up stories ship. Without this, SH-022/023/024 Shipping evidence tables cannot claim measured deltas — only estimates.

## 1. Who is the consumer?

- Future reader of SH-022 / SH-023 / SH-024 Shipping evidence — wants to see "Forge ci-branch: before 25 min median → after X min" with the before-number resolved to a concrete value.
- Dev-cycle doc §"Rollout order" step 3: explicit instruction to run `gh run list` against Forge and Beaconry "then do action 1 and 5 against real numbers".

## 2. When does the story fire?

Once, before the per-repo speed-up PRs land. Re-runnable if the baseline needs refreshing.

## 3. What does success look like?

Mechanically checkable:

- `scripts/measure-baseline.sh` exists and runs: iterates `docs/FLEET.md` rows, calls `gh run list -R <repo> -L 100 --json workflowName,createdAt,updatedAt,conclusion,event`, computes median wall-clock per workflow × event combination.
- Output file `docs/specs/dev-cycle-baseline.md` ships with a frozen table: one row per `(repo, workflow, event)` triple, columns `n_samples`, `median_minutes`, `p90_minutes`, `pct_green`.
- Covers at minimum the 5 non-HRC fleet repos + shepherd itself = 6 rows minimum per workflow.
- Script exit code 0 on success; 1 on API error; 2 on any repo with < 10 samples (likely needs a longer `-L`).

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (gates whether SH-022/023/024 can claim measured wins)
- [ ] Quality-of-life
- [ ] Onboarding

Ships right after SH-019 (fleet contract rollout) so `ci-branch` adoption hasn't yet distorted the pre-adoption numbers.

## 5. Happy path

```
$ scripts/measure-baseline.sh > docs/specs/dev-cycle-baseline.md
measure-baseline: 7 repo(s) had tuples below MIN_SAMPLES=10
$ echo $?
2    # warning-exit: at least one (repo,wf,event) had < 10 samples
```

Exit 2 on MIN_SAMPLES breach is expected on day one — some workflow+event combinations only fire once a month (release workflows, scheduled dependabot). The capture is still valid and committable.

Real captured data (2026-11-22):

- `bboortz/healthy / CI / pull_request`: 3.0 min median (dev-cycle doc claim ✅)
- `bb-claw/homelab / CI / pull_request`: 7.1 min median (dev-cycle doc claim ✅)
- `bboortz/forge / CI / pull_request`: 11.8 min median (NEW — dev-cycle doc had no timings)
- `bboortz/forge / Nightly check-strict / schedule`: 50.6 min (NEW — confirms the cold-build pain)
- `bboortz/beaconry / CI / pull_request`: 4.0 min median (NEW — dev-cycle doc had no timings)
- `bb-claw/kernel-test / CI / pull_request`: 1.7 min median (NEW)

## 6. Edge cases / failure modes that matter

- `gh` lookup fails on any repo → row shows `— | 0 | — | — | —`; script exits 1.
- A workflow has fewer than MIN_SAMPLES runs → row gets ⚠️ marker; script exits 2 (warning).
- A repo has multiple workflows with the same name but different `on:` triggers → grouped by `(workflow, event)` tuple, one row each.
- Script replayable offline via `SH_026_SAMPLE_FILE=fixture.jsonl` → acceptance test uses this.
- Script re-runnable — produces different numbers for runs since the last capture; snapshot is the "point in time" the per-repo speedup stories compare against.

## 7. Out of scope

- Ongoing timing emission (that's SH-020 + `build/ci-timing.json`).
- DORA metrics computation (SH-020 scope extension).
- Cross-repo aggregation / dashboards.

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.baseline.frozen-snapshot` — `design → active`.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
