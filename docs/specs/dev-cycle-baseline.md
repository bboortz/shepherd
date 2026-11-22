# Dev-cycle baseline — frozen snapshot of pre-adoption fleet timings

> **Status: placeholder (SH-014).** This file gets its real content from SH-026
> (baseline capture) — one-shot bash script `scripts/measure-baseline.sh` that
> pulls `gh run list -L 100 --json workflowName,createdAt,updatedAt,conclusion,event`
> across the fleet and freezes per-repo per-workflow medians here.
>
> The placeholder exists so references from `docs/specs/CAPABILITIES.md` and
> `docs/stories/INDEX.md` resolve under `make verify-traceability` while
> SH-026 is still in `draft` status.

## Why a baseline matters

Both source docs (dev-cycle doc §"Rollout order" step 3; research doc §"Measurement") are explicit: measure before and after. SH-022 Forge affected-only and SH-023 Beaconry pytest-xdist both claim measurable speedups; without a frozen pre-adoption snapshot, the Shipping evidence table for those sub-stories can only record "post-hoc estimate", not "measured delta".

## Schedule

SH-026 ships right after SH-021 Homelab dedupe (which is the opportunistic R1 cherry-pick) and before SH-022/023/024. See `docs/plan/SH-014-dev-cycle-umbrella-plan.md` §"Rollout order (revised 2026-11-22)".

## Target shape (reference)

One table per workflow category, one row per `(repo, workflow, event)` triple:

| Repo | Workflow | Event | n_samples | median_min | p90_min | pct_green |
|---|---|---|---|---|---|---|
| bboortz/healthy | ci | pull_request | 100 | 3.0 | 3.8 | 97 |
| bboortz/healthy | ci | push | 100 | 3.7 | 4.3 | 99 |
| bboortz/healthy | release | workflow_dispatch | 15 | 1.5 | 1.9 | 100 |
| bboortz/forge | ci | pull_request | ? | ? | ? | ? |
| …                 |      |              |     |     |     |     |

Access to Forge / Beaconry / Kernel-Test / Shepherd histories was refused in the Nov 2026 preliminary pass — SH-026's script runs with the repo-owner's local `gh` auth and resolves that.

## Not in scope

- Ongoing timing emission — `build/ci-timing.json` schema in `docs/specs/ci-timing.md`, consumed by SH-020 digest.
- DORA metrics — SH-020 scope.
