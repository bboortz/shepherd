---
id: SH-042
slug: hook-tiers
status: in-progress
created: 2026-11-23
owner: @benni
---

# SH-042 — `hook-commit` + `hook-push` named tiers (fleet-wide)

> **Follow-up from [v3 dev-workflow contract proposal](../plan/IDEAS-dev-workflow-contract-v3.md).** Local-gate step names diverged across the fleet (`lint` + `check-fast` + `check-smart` + `check`…). Agents and humans had to memorize per-repo incantations. SH-042 aligns the **tier names** (`hook-commit`, `hook-push`) across all 7 repos without touching the underlying step names.

## 1. Who is the consumer?

- Anyone (agent or human) about to commit or push on a fleet repo. They should be able to type `make hook-commit` / `make hook-push` on any managed repo and get the right local gate.
- Shepherd's `shepherd-bump --verify-contract` (SH-017), which will enforce the eight canonical tier names from SH-044 onward.

## 2. When does the story fire?

- Any `make hook-commit` or `make hook-push` invocation in any of the seven fleet repos (shepherd, healthy, beaconry, HRC, homelab, kernel-test, forge).

## 3. What does success look like?

Mechanically checkable per-repo:

- `make hook-commit` — exit 0, runs the repo's documented `COMMIT_STEPS` (fmt + lint-staged). Budget: ~15 s.
- `make hook-push` — exit 0, runs the repo's documented `PUSH_STEPS` (fast tests + static checks + repo-rules). Budget: ~2 min.
- Each wrapper is ≤5 lines and delegates to targets that already exist. No step renames. No step moves.
- `.PHONY: hook-commit hook-push` declared in every repo.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (contract uniformity — tier names are the fleet contract)
- [x] Quality-of-life (one command to remember instead of seven)
- [x] Onboarding (new contributor doesn't need to learn seven dialects)

## 5. Happy path

Shepherd itself, as the reference:

```
$ make hook-commit
yamllint .
markdownlint-cli2 '**/*.md'
verify-memory-size: ok
→ 15 s

$ make hook-push
verify-traceability: ok
build: ok
test-acceptance: 42/42
→ 1m48s
```

## 6. Edge cases / failure modes that matter

- **Step not yet implemented.** HRC's `prettier-check` and kernel-test's `shellcheck-staged` are new wrappers that need to be added in the same PR. All other repos chain existing targets.
- **Step name collides with existing target.** None do — audited via v3 Layer 3 survey.
- **CI drift.** Some repos' `.github/workflows/ci-branch.yml` already call `make check` not `make hook-push`. SH-042 doesn't touch workflows; alignment of workflow entry-points is a separate SH-044 concern.

## 7. Out of scope

- No workflow-YAML edits (§12 protected).
- No step-name coercion. Repos keep their native target names inside `COMMIT_STEPS` / `PUSH_STEPS`.
- No `mk/ci.mk` include. Those come with SH-044.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: hook-commit runs the commit-tier aggregate
  Given shepherd's Makefile
  When  `make -n hook-commit` is parsed
  Then  it declares .PHONY: hook-commit
  And   it invokes yaml-lint, md-lint, verify-memory-size

Scenario: hook-push runs the push-tier aggregate
  Given shepherd's Makefile
  When  `make -n hook-push` is parsed
  Then  it declares .PHONY: hook-push
  And   it invokes verify-traceability, build, test-acceptance

Scenario: all seven fleet repos expose both targets
  Given each managed repo's Makefile
  When  `make -n hook-commit` is parsed
  Then  it exits with rc 0 (target exists)
  And   same for `make hook-push`
```

Test (shepherd-only in this story): `test/acceptance/test_SH_042_hook_tiers.sh`.

Per-repo migration tests land in the matching managed-repo PR.

## 9. Capabilities delivered or extended

- `dev-cycle.tier.hook-commit` — new CAP.
- `dev-cycle.tier.hook-push` — new CAP.

---

## Plan doc

See `docs/plan/SH-042-hook-tiers-plan.md`.
