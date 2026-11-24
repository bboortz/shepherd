---
id: SH-055
slug: check-docs
status: shipped
created: 2026-11-23
owner: @benni
---

# SH-055 — Fleet-wide `check-docs` target wired into `hook-push` + `ci-branch`

> **Follow-up prompted by observed doc-staleness incidents during the SH-042/044/052/054 push:** INDEX ↔ frontmatter drift (shepherd, closed via PR #55), VERSION mismatch across `/VERSION` + `/poc/VERSION` + `pyproject.toml` (beaconry BC-062), missing story-doc for `feat/*` branch (beaconry BC-150). Each repo already has equivalent drift-check logic under different target names. This story unifies the entry point as `check-docs` + wires it into the pre-push gate so drift is caught before it reaches the remote.

## 1. Who is the consumer?

- Agent or human about to push. They want one command that answers "is my doc trail consistent with the code I'm about to ship?" across every fleet repo.
- The fleet's cross-repo mental model: `make check-docs` means the same thing in every managed repo, same way `hook-commit` / `hook-push` do post-SH-042.

## 2. When does the story fire?

- `make check-docs` on any fleet repo — directly, or indirectly via `make hook-push` (pre-push hook) or CI (`ci-branch` on PR).

## 3. What does success look like?

Mechanically checkable per-repo:

- `.PHONY: check-docs` declared in every repo's Makefile.
- `make check-docs` exits 0 on a clean repo + non-zero on a staged drift case (deleted a doc the target checks).
- `check-docs` is in `PUSH_STEPS` AND `BRANCH_STEPS` on every repo that exposes those (post-SH-042). HRC's step list is minimal — add it to its native `check-pre-push` pattern.
- Each repo's `check-docs` is a thin wrapper: delegates to existing drift targets (no logic rewrite):

| Repo | `check-docs` body |
|---|---|
| shepherd | `verify-traceability verify-docs-layout verify-caps-traceability verify-memory-size` |
| healthy | `verify-traceability verify-version-bumped verify-changelog` |
| beaconry | `verify-docs-drift verify-docs-layout verify-version-sync verify-evidence-pointers verify-traceability verify-install-doc` |
| HRC | `verify-stories-index` — new tiny script; checks `docs/stories/INDEX.md` has a row for every `docs/stories/SH-NNN-*.md` (frontmatter → INDEX sync, same bug class we hit on shepherd) |
| homelab | `scripts/check-docs.sh` (unchanged — the existing 16-check script) |
| kernel-test | `verify-plan-docs` — new tiny script; on `feat/SH-NNN-*` branches asserts a matching plan doc exists (kernel-test uses `docs/plans` — plural — not shepherd's `docs/plan`) |
| forge | `verify-traceability verify-sid-pins verify-promises-version` |

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (every doc-staleness incident this week could have been caught pre-push)
- [x] Quality-of-life (one command across the fleet)
- [ ] Onboarding

## 5. Happy path

```
# Developer finishes a feature, runs make hook-push before `git push`:
$ make hook-push
  verify-traceability: ok (84 CAPs, 22 tests, 42 CAP refs)
  check-docs: ok
  build: ok
  test-acceptance: 22/22

# ... or directly:
$ make check-docs
  check-docs: ok
```

Failure case (stale INDEX row, as caught in the SH-012..SH-029 batch yesterday):
```
$ make check-docs
  check-docs: INDEX.md row for SH-017 is `draft`, but frontmatter says `shipped`
  exit 1
```

## 6. Edge cases / failure modes that matter

- **A repo lacks one of the delegate targets** (e.g. kernel-test doesn't have `verify-version-bumped`). The wrapper only names targets that actually exist in that repo's Makefile. Checked at wrap-time, not runtime.
- **False positives on a clean working tree.** Each delegate is already in `make check` / existing pre-push, so false positives would already be observed. SH-055 doesn't invent new checks, only unifies the entry point.
- **Divergent timings.** Homelab's 16-check script is ~20 s; most repos' delegate chain is < 5 s. All well within hook-push's ~2 min budget.
- **CI runs `check-docs` twice (hook-push + ci-branch).** Intentional belt-and-braces. Author pays the push cost once; CI backs it up if the hook was bypassed. Both run in parallel across the fleet.

## 7. Out of scope

- Fixing the staleness incidents themselves (already shipped: PR #55 INDEX sync, BC-062 version-sync, SH-054 homelab pipeline). This story is the gate that prevents re-occurrence.
- Standardising the delegate target *names* across repos (same scope rejection as SH-042 — v3 explicitly rejected step-name coercion). Each repo keeps its native vocabulary; only the wrapper name is fleet-aligned.
- Adding doc-staleness checks to repos that genuinely don't have docs yet. HRC + kernel-test get a tiny new verifier each; the rest wrap existing targets.
- Running `check-docs` from `hook-commit` (~15 s budget). Too tight for I/O-heavy scanning. `hook-push`'s ~2 min is the right stage.

## 8. Acceptance (Gherkin → test assertions)

Shepherd-side assertions:

```gherkin
Scenario: check-docs target exists
  Given shepherd's Makefile
  When  `grep '^check-docs:' Makefile` runs
  Then  the target is declared
  And   .PHONY: check-docs is declared

Scenario: check-docs runs the four delegate targets
  Given shepherd's check-docs definition
  Then  verify-traceability, verify-docs-layout, verify-caps-traceability,
        verify-memory-size are its prerequisites

Scenario: PUSH_STEPS + BRANCH_STEPS include check-docs
  Given shepherd's Makefile
  Then  PUSH_STEPS contains "check-docs"
  And   BRANCH_STEPS contains "check-docs"

Scenario: check-docs catches INDEX ↔ frontmatter drift
  Given a story file with frontmatter status: shipped
  And   its INDEX.md row says `draft`
  When  make check-docs runs
  Then  exit non-zero
  And   stderr names the disagreeing story ID
```

Test: `test/acceptance/test_SH_055_check_docs.sh`.

Per-repo acceptance tests land in the matching managed-repo PR.

## 9. Capabilities delivered or extended

- `dev-cycle.tier.check-docs` — new CAP: every fleet Makefile exposes `check-docs` as a thin wrapper over the repo's native drift checks, wired into `hook-push` + `ci-branch`.
- `dev-cycle.tier.hook-push` — extended: content now includes `check-docs`.

---

## Plan doc

See `docs/plan/SH-055-check-docs-plan.md`.
