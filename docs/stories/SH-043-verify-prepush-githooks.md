---
id: SH-043
slug: verify-prepush-githooks
status: shipped
created: 2026-11-23
owner: @benni
---

# SH-043 — `--verify-prepush` accepts `.githooks/` form

> **Follow-up from the [2026-11-23 Makefile deep-dive survey](../plan/IDEAS-dev-workflow-contract-v3.md).** The survey caught that homelab + kernel-test carry a *shadow* `.pre-commit-config.yaml` (shepherd's SH-033 convergence skeleton) but the real policy-rich pre-push gates live under `.githooks/` with `git config core.hooksPath .githooks`. `shepherd-bump --verify-prepush` as it stood returned `ok` based on the shadow file — a false positive.

## 1. Who is the consumer?

- Shepherd operator running `--verify-prepush` on homelab or kernel-test.
- Fleet audit (3rd / 4th pass) that classifies each repo by its pre-push mechanism.

## 2. When does the story fire?

- Every `shepherd-bump --verify-prepush` invocation.

## 3. What does success look like?

Mechanically checkable:

- `--verify-prepush` accepts three forms in this order:
  1. `.pre-commit-config.yaml` with `entry: … make check …` + `stages: [pre-push]`
  2. `.husky/pre-push` script invoking `make check`
  3. **NEW**: `.githooks/pre-push` script invoking `make check` (must be executable; `git config core.hooksPath .githooks` separately required at install time).
- Exit 3 if NONE present; exit 4 if any present but mis-wired.
- Error message on exit 3 lists all three accepted forms.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (false-pass on homelab + kernel-test today)
- [ ] Quality-of-life
- [ ] Onboarding

## 5. Happy path

```
$ cd homelab
$ shepherd-bump --verify-prepush
verify-prepush: ok (.pre-commit-config.yaml wires `make check` at pre-push)
```

(The shadow pre-commit config wins the check order; operator can delete it if they want to force detection of the `.githooks/` form.)

Or:

```
$ cd kernel-test-fresh-clone      # no .pre-commit-config.yaml yet
$ shepherd-bump --verify-prepush
verify-prepush: ok (.githooks/pre-push invokes `make check`; ensure `git config core.hooksPath .githooks` is set)
```

## 6. Edge cases / failure modes that matter

- **Shadow pre-commit-config (homelab + kernel-test today)**: the verifier's check order means the shadow wins. Operator sees `ok` from `.pre-commit-config.yaml`, not from the real `.githooks/`. Not ideal but not wrong — the shadow config *does* actually fire if `pre-commit install -t pre-push` was run without `core.hooksPath` being set.
- **`.githooks/pre-push` exists but not executable**: verifier currently only checks file contents, not mode. Acceptable; executability is an install-time concern.
- **`core.hooksPath` not set**: verifier cannot read git-config. Best it can do is print a reminder in the success line ("ensure `git config core.hooksPath .githooks` is set").

## 7. Out of scope

- Reading `git config core.hooksPath` from a Zig CLI (not portable; separate story if needed).
- Normalizing the shadow-vs-real config situation on homelab + kernel-test (separate cleanup story).

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: .githooks/pre-push with make check passes
  Given .githooks/pre-push exists and contains `make check`
  When shepherd-bump --verify-prepush runs
  Then exit 0 with "ok (.githooks/pre-push ...)"

Scenario: .githooks/pre-push without make check fails
  Given .githooks/pre-push exists but does not invoke `make check`
  When shepherd-bump --verify-prepush runs
  Then exit 4

Scenario: error message on exit 3 names all three forms
  Given no .pre-commit-config.yaml, no .husky/pre-push, no .githooks/pre-push
  When shepherd-bump --verify-prepush runs
  Then exit 3 with "no pre-push config found (.pre-commit-config.yaml, .husky/pre-push, or .githooks/pre-push)"
```

Test: `test/acceptance/test_SH_033_verify_prepush.sh` (extended with 3 new scenarios; now 21 assertions / 13 scenarios).

## 9. Capabilities delivered or extended

- `dev-cycle.prepush.verify` — row refreshed; now cites all three forms + check order.

---

## Plan doc

See `docs/plan/SH-043-verify-prepush-githooks-plan.md`.
