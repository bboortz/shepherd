---
id: SH-034
slug: step-macro-exit-code
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-034 — ci-release step macro propagates inner-recipe exit codes

> **Correctness bug fix**, caught on 2026-11-22 during the v0.8.0-rc1 release. `make ci-release` reported SUCCESS even though `ci-release-promote` failed to push `main` (ruleset rejection). The `step` macro in shepherd's `Makefile` + `templates/Makefile.contract.snippet` chained its inner recipe with `;`, letting the subsequent timing-write overwrite the non-zero exit code.

## 1. Who is the consumer?

- Release operator who dispatches `ci-release.yml` expecting a loud failure when the promotion step cannot push — not a green checkmark with silent breakage.
- Every managed repo that adopts `templates/Makefile.contract.snippet` via SH-019 (healthy, beaconry, homelab, forge, kernel-test) — they all inherited the same bug.

## 2. When does the story fire?

- Every `make ci-release`, `make ci-branch`, `make ci-patch`, `make ci-nightly` on every fleet repo (the `step` macro is used by all four tier targets).
- Any repo reusing `templates/Makefile.contract.snippet` inherits the fixed form.

## 3. What does success look like?

Mechanically checkable:

- The `define step ... endef` block in both files captures `_rc=$$?;` immediately after `$(2)` and ends the compound with `exit $$_rc`.
- `test_SH_034_step_macro_exit_code.sh` passes: 8 assertions across source-form checks (both files) and end-to-end verification (a synthetic Makefile with a `false` inner recipe fails `make`).
- `templates/Makefile.contract.snippet` carries an inline comment explaining the bug and the fix — prevents the pattern regressing on a copy-paste edit.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (release workflows silently succeeded; dev-main drift could go unnoticed)
- [x] Quality-of-life (loud failures = fast debugging)
- [ ] Onboarding

## 5. Happy path

```
$ make ci-release          # inner ci-release-promote fails to push main
SH-029 promote: dev → main as v0.8.0-rc1
Fast-forward
remote: error: GH013: Repository rule violations found for refs/heads/main.
make: *** [Makefile:XXXX: ci-release-promote] Error 1
$ echo $?
2
```

Before SH-034: the same sequence exited 0.

## 6. Edge cases / failure modes that matter

- **Inner recipe hits budget timeout.** `timeout-minutes` at the workflow level kills the whole job; the `exit $$_rc` is bypassed. Correct behaviour — timeout is the outer signal.
- **Inner recipe succeeds but the timing-write itself fails.** `printf … >> $(CI_STEPS_FILE)` could fail if the dir is read-only. `exit $$_rc` would still exit with the inner recipe's code (0), masking the timing-write failure. Acceptable: timing is diagnostic, not load-bearing.
- **`$(2)` itself is a compound with internal `set -e` disabled.** Captured `_rc` is the last command's exit code only — a prior failure inside the compound is still silently discarded. Mitigated by making recipes short + `set -euo pipefail`-like via explicit `&&` chains (ci-release-promote already does this).

## 7. Out of scope

- Reworking `ci-timing-finish-cmd` similarly (it's called with `@` + no inner recipe, not subject to the same bug).
- Adding a lint that forbids `$(2); \` without `_rc` in future macros — the regression test covers it.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: step macro captures inner recipe exit code
  Given shepherd Makefile and templates/Makefile.contract.snippet
  Then  both files' `define step ... endef` block contains `$(2); _rc=$$?;`
  And   both end the compound with `exit $$_rc`
  And   neither contains a bare `$(2); \` line (the old swallowed form)

Scenario: inner recipe failure propagates through the macro
  Given a synthetic Makefile that uses the fixed step macro
  And   a target `fail` whose inner recipe is `false`
  When  `make fail` runs
  Then  make exits with non-zero status

Scenario: inner recipe success passes cleanly through the macro
  Given the same synthetic Makefile
  And   a target `ok` whose inner recipe is `true`
  When  `make ok` runs
  Then  make exits with status 0
```

Test: `test/acceptance/test_SH_034_step_macro_exit_code.sh` — 8 assertions.

## 9. Capabilities delivered or extended

- `dev-cycle.step.exit-code-propagation` — new CAP guarding the macro.

---

## Plan doc

See `docs/plan/SH-034-step-macro-exit-code-plan.md`.
