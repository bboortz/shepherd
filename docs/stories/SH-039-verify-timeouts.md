---
id: SH-039
slug: verify-timeouts
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-039 — `shepherd-bump --verify-timeouts` (workflow-level timeout verifier)

> **Follow-up from the [2026-11-22 fleet overview](../specs/fleet-overview-2026-11-22.md).** Four managed repos (healthy, beaconry, HRC, homelab) had no explicit `timeout-minutes:` on their ci-branch job — the contract's 5-min budget wasn't mechanically enforced at the workflow level. This story adds a first-party verifier so budgets become CI-enforceable.

## 1. Who is the consumer?

- Repo maintainer or shepherd operator who wants the dev-cycle contract's tier budgets (`ci-branch=5 min`, `ci-patch=5 min`, `ci-release=15 min`, `ci-nightly=120 min`) mechanically enforced at the workflow level, not just documented.
- Future SH-NNN rollouts that stamp `timeout-minutes:` into managed repos through `shepherd-bump` or a template-sync tool.

## 2. When does the story fire?

- Any `shepherd-bump --verify-timeouts --root <repo>` invocation. Intended uses: pre-push, CI `make check`, fleet audit.

## 3. What does success look like?

Mechanically checkable:

- `shepherd-bump --verify-timeouts --root <repo>` returns:
  - **exit 0** when every tier workflow (`ci-branch.yml`, `ci-patch.yml`, `ci-release.yml`, `ci-nightly.yml`) has at least one job with `timeout-minutes:` set, and the **highest** value is within its tier's budget.
  - **exit 3** when any tier workflow file is absent.
  - **exit 4** when a tier workflow is present but has no `timeout-minutes:` key, OR when the highest `timeout-minutes:` in any job exceeds the tier's budget.
- Per-tier budgets (hard-coded, matches SH-014 spec):
  - ci-branch: 5 min
  - ci-patch: 5 min
  - ci-release: 15 min
  - ci-nightly: 120 min (soft cap)
- Permissive scan: inline comments after the value (`timeout-minutes: 5 # hard cap`) are tolerated.
- Multiple-job workflows: the **max** value is compared against budget (worst-case honest).

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (fleet uniformity — contract budgets become enforceable)
- [x] Quality-of-life (no more silent 360-min inherited default)
- [ ] Onboarding

## 5. Happy path

```
$ shepherd-bump --verify-timeouts
verify-timeouts: ok .github/workflows/ci-branch.yml timeout-minutes=5 (budget 5)
verify-timeouts: ok .github/workflows/ci-patch.yml timeout-minutes=5 (budget 5)
verify-timeouts: ok .github/workflows/ci-release.yml timeout-minutes=15 (budget 15)
verify-timeouts: ok .github/workflows/ci-nightly.yml timeout-minutes=120 (budget 120)
```

Over-budget failure:

```
verify-timeouts: .github/workflows/ci-branch.yml timeout-minutes=10 > budget 5 min
```

Missing-key failure:

```
verify-timeouts: .github/workflows/ci-branch.yml has no `timeout-minutes:` key — budget 5 min unenforced
```

## 6. Edge cases / failure modes that matter

- **Workflow uses flow-style YAML.** `jobs: {p: {timeout-minutes: 5, ...}}` — the permissive line-scanner won't find the key. Fleet repos all use block-style; flow-style would fail the verifier (correct behaviour: ask the operator to reformat).
- **Comment after value.** `timeout-minutes: 5 # cap` — scanner strips the `# ...` suffix before parsing.
- **Multiple jobs with different values.** Verifier uses the max — worst-case honest.
- **Workflow present but no jobs.** Treated as missing-key (exit 4).
- **Shepherd itself has longer-than-5-min needs.** Not permitted — if a tier can't meet its budget, the work moves to nightly (SH-014 invariant).

## 7. Out of scope

- Enforcing step-level `timeout-minutes:` (per-step caps are a separate story).
- Auto-fixing missing/over-budget values. Verifier reports; operator fixes.
- Scoping budgets per-repo. The contract has one fleet-wide budget set; per-repo deviations need a story.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: clean fleet passes
  Given 4 tier workflows with timeout-minutes within budget
  When  shepherd-bump --verify-timeouts runs
  Then  exit 0 with per-tier "ok" lines

Scenario: over-budget fails
  Given ci-branch.yml with timeout-minutes: 10
  When  shepherd-bump --verify-timeouts runs
  Then  exit 4
  And   stderr names "timeout-minutes=10 > budget 5"

Scenario: missing key fails
  Given ci-branch.yml without any timeout-minutes line
  When  shepherd-bump --verify-timeouts runs
  Then  exit 4
  And   stderr names "no `timeout-minutes:` key"

Scenario: missing workflow fails
  Given ci-release.yml present, others absent
  When  shepherd-bump --verify-timeouts runs
  Then  exit 3
  And   stderr names each missing workflow

Scenario: multi-job picks max
  Given ci-branch.yml with jobs having timeout-minutes 3 and 7
  When  shepherd-bump --verify-timeouts runs
  Then  exit 4 because 7 > 5

Scenario: comment-tolerant parse
  Given timeout-minutes: 5    # inline comment
  When  shepherd-bump --verify-timeouts runs
  Then  exit 0
```

Test: `test/acceptance/test_SH_039_verify_timeouts.sh` (18 assertions, 8 scenarios).

## 9. Capabilities delivered or extended

- `dev-cycle.budget.verify-timeouts` — new CAP.

---

## Plan doc

See `docs/plan/SH-039-verify-timeouts-plan.md`.
