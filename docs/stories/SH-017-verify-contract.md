---
id: SH-017
slug: verify-contract
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-017 — `shepherd-bump --verify-contract`: enforce the dev-cycle contract on managed repos

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Symmetric with `--verify-dependabot` (SH-011). Scans each managed repo's Makefile for the six contract targets; fails fast if any is missing; opens a needs-human issue naming the gap.

## 1. Who is the consumer?

- Shepherd's daily `bump.yml` run (once fleet-side verification is wired, post-R3).
- For R2: the managed-repo's own Shepherd reusable-workflow run — a new step calling `shepherd-bump --verify-contract` before the agent step.
- The repo owner reviewing the needs-human issue that says "your Makefile is missing `ci-branch`; here's the copy-paste."

## 2. When does the story fire?

- Every reusable-shepherd.yml run on a managed repo: new verify step precedes the agent step.
- Every `make check` on shepherd itself (dogfood).

## 3. What does success look like?

Mechanically checkable:

- New flag `--verify-contract` on `shepherd-bump` (Zig side).
- Reads `Makefile` in the current working directory; checks for `.PHONY: ci-branch ci-patch ci-release ci-nightly` + the `build` + `test` targets referenced by `.shepherd.yml`.
- Exit codes: 0 ok, 3 missing target(s), 4 malformed Makefile. Symmetric with `--verify-dependabot`.
- `.shepherd.yml` → `contract.enforce_enabled` toggles the verifier (default `true`); setting `false` short-circuits to exit 0.
- Missing-target detection opens a needs-human issue on the managed repo with title `[shepherd] dev-cycle contract gap: missing <target>` and body carrying a copy-pasteable snippet from `templates/Makefile.contract.snippet`.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (without this, SH-014's contract is advisory only; drift goes unflagged)
- [x] Quality-of-life
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: Makefile uses `$(MAKE) -f other.mk ci-branch`; `.PHONY` declaration split across lines; `.shepherd.yml` opts out._

## 7. Out of scope

- Automated PR to add missing targets (would make shepherd edit a managed repo's Makefile — scope-level-3 territory, deferred to a follow-up).
- Verifying `timeout-minutes` in workflow YAML (that's `--verify-ci-timeouts`, a follow-up IDEA).
- The HRC migration PRs themselves (SH-018).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.verify-contract` — `design → active`.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
