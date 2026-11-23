---
id: SH-025
slug: healthy-ci-rename
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-025 — Healthy: rename existing tiers to shared `ci-*` names + become reference impl

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Healthy (`bboortz/healthy`) already fits all three budgets today (PR median 3.0 min, push to dev 3.7 min, release 1.5 min — measured 2026-11-22). No speed work needed. The story is: rename to the shared `ci-*` target names so new repos can use healthy's Makefile as the template.

## 1. Who is the consumer?

- Future repo owner onboarding to shepherd, looking at healthy as the reference implementation of the contract.
- Shepherd's docs: healthy is the "see this repo for a working example" link.

## 2. When does the story fire?

- Once: rename healthy's existing tier targets (whatever they're called today) to `ci-branch` / `ci-patch` / `ci-release` / `ci-nightly`. Copy the four `templates/ci-*.yml` into `.github/workflows/`.

## 3. What does success look like?

Mechanically checkable:

- Healthy's Makefile exposes the six contract targets.
- Healthy's workflows match the four `templates/ci-*.yml` (SHA-pinned, `timeout-minutes`).
- `shepherd-bump --verify-contract` passes on healthy (gated by SH-017).
- `docs/FLEET.md` healthy row links to this PR; healthy gets a "reference implementation" annotation.
- No measurable regression: healthy's existing 3.0 / 3.7 / 1.5 min medians hold.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (keeps the reference impl in lockstep with the spec)
- [x] Quality-of-life
- [x] Onboarding

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: a build hook references the old tier name — grep healthy's CLAUDE.md + docs._

## 7. Out of scope

- Any new work on healthy. This is a rename + copy.
- Healthy's own contract adoption shape beyond rename (SH-019 covers the minimum).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.uniformity` — Healthy becomes the reference impl; combined with SH-019 contributes to the CAP.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
