---
id: SH-022
slug: forge-affected-only
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-022 — Forge: affected-only test matrix in ci-branch

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Forge (`bboortz/forge`) today globs all 83 `test_FG_*.sh` on every PR; the affected-only logic in `scripts/affected_images.py` + `smart-check.sh` runs only in the local pre-push hook. Moving affected-only into `ci-branch` is the single biggest expected PR-time win across the fleet.

## 1. Who is the consumer?

Forge maintainer (the user) opening a PR. Today every PR runs the full matrix; after this story, only the matrix cells for affected images run.

## 2. When does the story fire?

- Once: edit `bboortz/forge/.github/workflows/ci.yml` (or whatever the equivalent becomes under SH-019 adoption) to run `discover` + emit only affected matrix cells. The full 83-test matrix moves to `ci-nightly`.

## 3. What does success look like?

Mechanically checkable:

- Forge's `ci-branch` matrix size on a typical PR goes from 83 → handful (range depends on diff).
- Full matrix runs nightly (via `ci-nightly.yml`); failures open needs-human issues.
- `scripts/affected_images.py` + `smart-check.sh` are the single source of affected-detection logic (no duplication between the hook and CI).
- PR-tier wall-clock decreases measurably (baseline will be captured once `build/ci-timing.json` emission lands).

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness
- [x] Quality-of-life (biggest expected single win; reduces agent-wait during a shepherd PR on Forge)
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: an image change that transitively affects other images (dependency graph in `affected_images.py` — already handled by that script, verify)._

## 7. Out of scope

- Rewriting the affected-only logic. SH-022 wires the existing scripts into `ci-branch`; it does not touch the detection algorithm.
- Forge's own contract adoption shape (SH-019 covers the minimum).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.uniformity` — Forge adoption; combined with SH-019 contributes to the CAP.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
