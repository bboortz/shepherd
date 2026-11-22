---
id: SH-018
slug: hrc-migration-investigation
status: draft
created: 2026-11-22
owner: @benni
---

# SH-018 — HRC dev-cycle migration: assess + produce catch-up plan

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** HRC (`bboortz/ham-radio-compass`) is a bit behind on contract-shape today — flagged by the user 2026-11-22. This story audits HRC against the contract, produces a per-gap migration plan, and lands the migration PRs. HRC stays IN the fleet verifier, not carved out.

## 1. Who is the consumer?

- HRC maintainer (the user) applying the migration PRs.
- `shepherd-bump --verify-contract` (SH-017), which must not fail silently on HRC — if HRC can't meet a budget, SH-018 captures that as a documented gap in FLEET.md, not a silent skip.

## 2. When does the story fire?

- Once, as an audit: compare HRC's current Makefile + workflows against `docs/specs/dev-cycle-contract.md`.
- Then per-gap PRs are landed on HRC (adding missing targets, adjusting workflows, documenting any genuine hardware-bound budget constraint).

## 3. What does success look like?

Mechanically checkable:

- The plan doc for this story (cut under `docs/plan/` when the story moves `draft → ready`) ships with an appendix: "HRC audit" — one row per missing / nonconforming contract target.
- A sequence of PRs lands on HRC (one per gap), each linked from the plan doc.
- HRC's row in `docs/FLEET.md` gets a `contract-adopted: <PR link>` cell OR a `contract-gap: <reason>` cell with an accompanying IDEAS entry.
- `shepherd-bump --verify-contract` (SH-017) passes on HRC — or the plan documents a configured opt-out for a measured, justified gap.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (keeps the fleet uniform; prevents HRC from becoming a special case drifting indefinitely)
- [x] Quality-of-life
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: HRC's current CI exceeds a budget on the shared runner; measured regression blocks a budget-cap PR._

## 7. Out of scope

- Non-contract HRC CI work (separate HRC stories).
- Device-side HRC changes (post-R3 scope per DESIGN §13).
- The shepherd-side verifier itself (SH-017).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up. The acceptance for an investigation story is: the plan doc's "HRC audit" appendix lists every gap and either (a) a merged PR or (b) a documented, justified opt-out._

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.uniformity` — contributes HRC's share. Flips `design → active` only once all fleet repos are green or documented-gap on `--verify-contract`.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
