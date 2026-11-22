---
id: SH-033
slug: fleet-prepush-convergence
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-033 — Fleet-wide pre-push convergence

> **Follow-up from the [2026-11-22 fleet consistency audit](../specs/fleet-consistency-audit-2026-11-22.md) — high severity.** `memory/workflow.md`'s DD-TGD gate matrix mandates a `make check` pre-push hook. Only healthy, beaconry and forge have it today; shepherd, HRC, homelab, kernel-test do not — including the fleet brain itself.

## 1. Who is the consumer?

- Repo maintainer who wants local fast-feedback before CI (the "measure twice, cut once" habit).
- Shepherd policy: traceability, memory-size, yaml-lint, md-lint, and verify-contract regressions should be caught before push, not after.

## 2. When does the story fire?

- On every local `git push`. Blocks the push when `make check` fails locally.

## 3. What does success look like?

Mechanically checkable:

- Each managed repo has one of:
  - `.pre-commit-config.yaml` with a `stages: [pre-push]` hook running `make check` (or a documented variant: `make check-fast` for giant repos), OR
  - `.husky/pre-push` (for Node repos like HRC where pre-commit ergonomics don't fit).
- `shepherd-bump --verify-prepush --root <repo>` returns exit 0 (hook present) or exit 4 (missing). Default enforcement `on`; opt-out via `.shepherd.yml → dev_cycle.prepush_enforce: false`.
- Audit matrix column 10 flips 3✅/1⚠️/3❌ → 7✅.
- Shepherd itself gets its own pre-push today, before the generalisation lands (chore PR, see "Out of scope").

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (catches lint/traceability regressions locally)
- [x] Quality-of-life (CI round-trip is slow; local gate is seconds)
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up. Rough shape:_

1. Add `templates/.pre-commit-config.yaml.snippet` on shepherd with the minimal hook list.
2. Copy into each managed repo as part of the SH-033 rollout PR; rename to `.pre-commit-config.yaml` (merging with existing hooks).
3. `pre-commit install -t pre-push` on the dev machine; CI unaffected (hook is local-only).
4. `shepherd-bump --verify-prepush` enforces presence; opt-out is explicit.

## 6. Edge cases / failure modes that matter

- **Repo has its own pre-commit already.** Merge rather than overwrite; preserve custom hooks.
- **`make check` takes > 30 s.** Audit flags the repo and adds a `stages: [pre-push]`-only tier. Push is a conscious action; 30 s is tolerable.
- **Node ecosystem (HRC).** Use husky instead of pre-commit; the snippet covers both patterns.
- **Shepherd self-chore.** Needs to happen FIRST — the fleet brain missing its own pre-push gate is embarrassing. Separate `chore/` branch before SH-033 rollout.
- **Opt-out abuse.** `.shepherd.yml → dev_cycle.prepush_enforce: false` is allowed; the verifier records the opt-out reason in FLEET.md.

## 7. Out of scope

- CI-side `make check` already runs via `ci-branch.yml` across the fleet — SH-033 is about local fast-feedback, not CI.
- The shepherd self-chore (pre-SH-033) is a non-story chore PR, tracked separately.
- `make check-full` variants per repo (optional; most repos' `make check` is fast enough).

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: Clean repo passes
  Given a repo with `.pre-commit-config.yaml` naming `make check` at pre-push
  When  shepherd-bump --verify-prepush runs
  Then  exit 0

Scenario: Missing pre-push hook fails
  Given a repo with no pre-commit / husky pre-push wiring
  When  shepherd-bump --verify-prepush runs
  Then  exit 4
  And   stderr names the missing config file

Scenario: Opt-out is honoured
  Given `.shepherd.yml → dev_cycle.prepush_enforce: false`
  When  shepherd-bump --verify-prepush runs
  Then  exit 0 and stdout notes "pre-push enforcement disabled per .shepherd.yml"
```

Test: `test/acceptance/test_SH_033_verify_prepush.sh` (new).

## 9. Capabilities delivered or extended

- `dev-cycle.prepush.verify` — new CAP (`shepherd-bump --verify-prepush`).
- `dev-cycle.fleet.uniformity` — already active; this story extends its evidence to column 10.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
