---
id: SH-015
slug: shepherd-self-ci-gate
status: draft
created: 2026-11-22
owner: @benni
---

# SH-015 — Shepherd self-CI gate: run `make check` on every PR

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Dogfood the dev-cycle contract on shepherd itself: the repo that other repos trust has no per-PR gate today (only `injection-drill.yml` runs on PRs to main). This fixes it.

## 1. Who is the consumer?

Contributor opening a PR to shepherd. Today they rely on local `make check` + the main-branch injection-drill. With this story, every PR gets the full `make check` (yaml-lint + md-lint + verify-memory-size + verify-traceability + build + test-acceptance + injection-drill) run in CI before merge.

## 2. When does the story fire?

Every PR opened against `main` (and later `dev`). Workflow `ci-branch.yml` triggers on `pull_request`.

## 3. What does success look like?

Mechanically checkable:

- `.github/workflows/ci-branch.yml` exists on shepherd, copies `templates/ci-branch.yml` verbatim (SHA-pinned actions, `timeout-minutes: 5`).
- The job runs `make ci-branch` — which (after SH-016) wraps `make check` + timing emission.
- Required-check status set on the `main` branch ruleset: `ci-branch` must pass before merge.
- Shepherd becomes the first repo whose Makefile exposes the contract-shaped `ci-branch` target in the wild.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (today shepherd ships without a PR gate — a lint regression on the enforcement scripts can land unverified)
- [x] Quality-of-life
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up. Expected: `gh pr create` → `ci-branch` runs → green → mergeable._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: 5-min timeout on a slow runner, concurrent injection-drill + ci-branch on PRs to main (dedupe or keep both?)._

## 7. Out of scope

- The other three tier workflows (`ci-patch.yml` / `ci-release.yml` / `ci-nightly.yml`) land with SH-016.
- Makefile `ci-*` target bodies on shepherd land with SH-016.
- `dev` branch creation + promotion flow is a separate SH.

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.shepherd.self-ci-gate` — flips `design → active` when this story ships.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
