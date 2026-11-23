---
id: SH-019
slug: fleet-contract-rollout
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-019 — Fleet contract rollout: track per-repo adoption across healthy / beaconry / homelab / kernel-test / forge

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Shepherd-side tracking story. The actual fixes land as human-driven PRs on each managed repo (not automated — Makefile edits across repos are scope-level-3+ and deserve human review each time). This story is the ledger.

## 1. Who is the consumer?

- Shepherd's maintainer (the user) landing contract-adoption PRs on five repos in sequence.
- `docs/FLEET.md` — the canonical fleet registry — gets a `contract-adopted` column that this story owns.

## 2. When does the story fire?

- Once per repo, when the contract-adoption PR on that repo merges.
- Then this story's plan doc appends the PR link, FLEET.md row is updated, and once all five rows are green, `dev-cycle.fleet.uniformity` flips `design → active` (combined with SH-018 HRC).

## 3. What does success look like?

Mechanically checkable:

- The plan doc for this story (cut under `docs/plan/` when the story moves `draft → ready`) has a table with one row per non-HRC fleet repo (healthy, beaconry, homelab, kernel-test, forge) — each row carries the PR link that added the contract targets + the date it merged.
- Each of the five managed repos exposes `make ci-branch` / `ci-patch` / `ci-release` / `ci-nightly` + (if missing) the aliased `build` / `test` the dev-cycle doc identified (Forge `test`, Beaconry `build`, Kernel-Test `build`+`test`, Homelab `build`).
- `docs/FLEET.md` — new "contract adoption" column OR extended description for each row with the PR link.
- `shepherd-bump --verify-contract` passes on all five repos (gated by SH-017 shipping first).

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness
- [x] Quality-of-life
- [x] Onboarding (the contract becomes the onboarding script for repo #7+)

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: Forge's nightly build is already configured with 2h timeout — reconcile that with the contract's "nightly target under 2h" soft target._

## 7. Out of scope

- The deep per-repo speed-ups themselves (SH-021 Homelab dedupe, SH-022 Forge affected-only, SH-023 Beaconry xdist, SH-024 Kernel-Test nightly kernel smoke, SH-025 healthy rename). SH-019 tracks the *minimum* contract-shape; those are independent follow-ups.
- HRC adoption (SH-018).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up. The acceptance is: table complete, all five repos linked, `--verify-contract` green across the fleet._

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.uniformity` — contributes the five non-HRC rows. Combined with SH-018 flips the CAP `design → active`.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
