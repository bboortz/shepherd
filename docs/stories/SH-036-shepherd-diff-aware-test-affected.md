---
id: SH-036
slug: shepherd-diff-aware-test-affected
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-036 — shepherd diff-aware `test-affected` (column-11 convergence)

> **Follow-up from the [2026-11-22 fleet consistency audit](../specs/fleet-consistency-audit-2026-11-22.md) — column 11 ⚠️ fix.** Shepherd's `test-affected` was an identity alias to `test-acceptance` (ran every acceptance test regardless of diff). Audit rated this ⚠️ "contract-permitted but suboptimal". This story adds a real diff-aware implementation.

## 1. Who is the consumer?

- Shepherd contributor whose pre-push `make check` (and CI's `make ci-branch`) would previously run every SH-NNN acceptance test even on a 1-line docs change. Now only tests whose source material changed run.

## 2. When does the story fire?

- Every `make test-affected` call (invoked by `make ci-branch` + pre-commit's pre-push stage via `make check`).

## 3. What does success look like?

Mechanically checkable:

- `scripts/test-affected.sh` exists, is `+x`, shellcheck-clean.
- Makefile `test-affected:` recipe calls the script (no longer identity-alias to `test-acceptance`).
- Diff-aware selection rules:
  - Change to `test/acceptance/test_SH_<N>_*.sh` → run that test.
  - Change to `docs/stories/SH-<N>-*.md` or `docs/plan/SH-<N>-*.md` → run `test_SH_<N>_*.sh`.
  - Change to `scripts/shepherd-poc/<name>.sh` → run acceptance tests that mention `<name>`.
- Full-run bailouts (safety-first):
  - `Makefile`, `bump.zig`, `build.zig`, `.github/workflows/**`, `docs/specs/CAPABILITIES.md`, or `scripts/test-affected.sh` itself changed.
  - No diff detectable (clean tree with no upstream to compare).
- Opt-out / override: `TEST_AFFECTED_BASE=<ref>` env knob overrides the auto-detected diff base.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (fleet uniformity — audit column 11 goes ⚠️ → ✅)
- [x] Quality-of-life (faster pre-push on docs-only PRs)
- [ ] Onboarding

## 5. Happy path

```
$ echo "" >> docs/stories/SH-027-risk-paths.md     # tweak one story
$ make test-affected
test-affected: diff-aware (1 test(s) selected from diff)
  test/acceptance/test_SH_027_risk_paths.sh
→ test/acceptance/test_SH_027_risk_paths.sh
pass=12 fail=0
test-affected: all passed
```

Full-run fallback:

```
$ echo "" >> Makefile
$ make test-affected
test-affected: full-run (diff touches build/workflow/CAPABILITIES surface)
  test/acceptance/test_SH_001_retire_renovate.sh
  …
```

## 6. Edge cases / failure modes that matter

- **No upstream** (fresh clone with no origin): fall back to HEAD; full-run.
- **Story/plan without matching test**: `ls test/acceptance/test_SH_NNN_*.sh` returns no match → skipped (safety net: traceability test still runs).
- **CAPABILITIES.md touched**: full-run (CAP changes can affect multiple tests via the `Covers:` network).
- **Changed file matches no mapping rule**: falls back to running `test_SH_013_*.sh` (traceability) + `test_SH_012_*.sh` (docs-layout) as a safety net.

## 7. Out of scope

- Diff-aware for `smoke` / `release-artifacts` targets (shepherd has no distinct smoke tier).
- Tracing individual CAP changes to test subsets (too granular; CAP-wide change = full-run).

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: script is +x and shellcheck-clean
  Given scripts/test-affected.sh
  Then  the file is executable and shellcheck reports zero warnings

Scenario: Makefile wires test-affected to the script
  Given Makefile
  Then  `test-affected:` recipe calls `sh scripts/test-affected.sh`
  And   it is no longer an identity alias to `test-acceptance`

Scenario: full-run bailout on Makefile change
  Given a working tree with a 1-line diff to Makefile
  When  scripts/test-affected.sh --list runs
  Then  stdout contains "full-run"
  And   stdout lists every test/acceptance/test_SH_*.sh
```

Test: `test/acceptance/test_SH_036_test_affected.sh` (new).

## 9. Capabilities delivered or extended

- `dev-cycle.shepherd.test-affected-diff-aware` — new CAP.

---

## Plan doc

See `docs/plan/SH-036-shepherd-diff-aware-test-affected-plan.md`.
