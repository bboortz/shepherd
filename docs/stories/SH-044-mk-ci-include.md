---
id: SH-044
slug: mk-ci-include
status: shipped
created: 2026-11-23
owner: @benni
---

# SH-044 — `mk/ci.mk` as the canonical fleet master include

> **Follow-up from [v3 dev-workflow contract proposal](../plan/IDEAS-dev-workflow-contract-v3.md).** After SH-042 landed `hook-commit` / `hook-push` across all 7 fleet repos, each repo was duplicating ~90 lines of tier scaffolding (ci-timing-init, step macro, finish-cmd, tier recipes). SH-044 extracts the canonical body into `mk/ci.mk` so repos declare only their `*_STEPS` variables and `include mk/ci.mk`.

## 1. Who is the consumer?

- Repo maintainer migrating a managed repo to the fleet contract. After SH-044 the Makefile goes from ~90 lines of duplicated scaffolding to ~10 lines (`*_STEPS` + `include mk/ci.mk`).
- Shepherd's `shepherd-bump --verify-contract` (SH-017), which now scans both `Makefile` and `mk/ci.mk` when the former `include`s the latter.

## 2. When does the story fire?

- A repo adopting the fleet contract types `include mk/ci.mk` into its Makefile — tier wrappers (`hook-commit`, `hook-push`, `ci-branch`, `ci-patch`, `ci-release`) and timing scaffolding become available.
- `shepherd-bump --verify-contract` is invoked against any managed repo (pre-push / CI / fleet audit).

## 3. What does success look like?

Mechanically checkable:

- `mk/ci.mk` exists in shepherd's repo root, declares the six tier wrappers + `run_tier` macro + timing scaffolding.
- Shepherd's own `Makefile` contains `include mk/ci.mk` and declares six `*_STEPS` variables (`COMMIT_STEPS`, `PUSH_STEPS`, `BRANCH_STEPS`, `PATCH_STEPS`, `RELEASE_STEPS`, `NIGHTLY_STEPS`).
- `make hook-commit`, `make hook-push`, `make ci-branch`, `make ci-patch`, `make ci-release` all resolve cleanly on dogfood (dry-run exits 0; live run produces `build/ci-timing.json`).
- `shepherd-bump --verify-contract` returns 0 on shepherd with the new include pattern.
- `mk/**` is on the §12 protected-files list (CAP: `blocklist.protected-files`).

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (contract convergence — one place to fix bugs that propagate to all managed repos)
- [x] Quality-of-life (new fleet repos onboard with a 10-line Makefile instead of 90)
- [ ] Onboarding

## 5. Happy path

```
$ cat Makefile
# shepherd — top-level Makefile.
...
COMMIT_STEPS  = yaml-lint md-lint verify-memory-size
PUSH_STEPS    = verify-traceability build test-acceptance
BRANCH_STEPS  = lint release-artifacts test-affected injection-drill
PATCH_STEPS   = smoke
RELEASE_STEPS = ci-release-promote
NIGHTLY_STEPS = check

include mk/ci.mk

$ make hook-commit
yamllint .
markdownlint-cli2 '**/*.md'
...

$ bin/shepherd-bump --verify-contract
verify-contract: ok (9/9 contract targets present)
```

## 6. Edge cases / failure modes that matter

- **Repo has no `mk/ci.mk` yet.** `verify-contract` only reads `mk/ci.mk` if `Makefile` contains `include mk/ci.mk`. Repos not yet migrated keep their inline tier recipes and still pass.
- **`mk/ci.mk` is edited by the agent.** §12 blocks writes to `mk/**` — the trusted step rejects such diffs (`validate.sh`).
- **ci-nightly has repo-specific policy.** Mk/ci.mk intentionally does NOT define `ci-nightly`; each repo wraps it locally (shepherd opens a needs-human issue on failure; other repos may ntfy or just log).
- **`include mk/ci.mk` appears in a comment.** The scanner's `indexOf("include mk/ci.mk")` matches comment occurrences too; false-positive makes the target scan include an extra file but still produces correct exit code.

## 7. Out of scope

- sha256 integrity check of `mk/ci.mk` vs the shepherd master copy. Deferred to a follow-up (SH-045+) — would require a sha256 manifest and per-repo copies to be byte-identical.
- Step-reachability check (every `*_STEPS` token resolves to a `.PHONY` target in the combined Make surface). Deferred.
- Per-repo migration PRs (SH-045…SH-051). Each managed repo gets its own `include mk/ci.mk` migration PR; this story only ships the include file + shepherd dogfood.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: mk/ci.mk exists and declares the fleet tiers
  Given the shepherd repo
  When  mk/ci.mk is read
  Then  it declares .PHONY: hook-commit hook-push ci-branch ci-patch ci-release
  And   it defines the run_tier macro
  And   it defines ci-timing-finish-cmd

Scenario: shepherd dogfoods via include
  Given shepherd's Makefile
  When  grep "include mk/ci.mk" Makefile
  Then  the line is present
  And   shepherd declares all six *_STEPS variables

Scenario: verify-contract scans the include
  Given shepherd's Makefile uses include mk/ci.mk
  When  shepherd-bump --verify-contract runs
  Then  exit 0 with "9/9 contract targets present"

Scenario: step exit-code propagation preserved
  Given mk/ci.mk's run_tier macro
  When  the acceptance test scans for `_rc=$$?` + `exit $$_rc`
  Then  both patterns are present (SH-034 regression guard)
```

Test: `test/acceptance/test_SH_044_mk_ci_include.sh`.

## 9. Capabilities delivered or extended

- `dev-cycle.master-include` — new CAP: `mk/ci.mk` ships the canonical tier wrappers + timing scaffolding.
- `blocklist.protected-files` — extended: `mk/**` added to agent blocklist.
- `dev-cycle.step.exit-code-propagation` — extended: SH-034 guard now covers `mk/ci.mk` (which hosts the migrated `run_tier` macro).

---

## Plan doc

See `docs/plan/SH-044-mk-ci-include-plan.md`.
