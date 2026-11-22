---
id: SH-026
slug: baseline-capture
status: draft
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

_TBD — filled when picked up. Expected: `./scripts/measure-baseline.sh > docs/specs/dev-cycle-baseline.md`, commit, done._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: API rate limiting, HRC's low run count, repos with multiple workflows per event._

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
