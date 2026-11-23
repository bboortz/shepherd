---
id: SH-044
slug: mk-ci-include
story: docs/stories/SH-044-mk-ci-include.md
branch: feat/SH-044-mk-ci-include
status: in-progress
---

# SH-044 plan — `mk/ci.mk` as the canonical fleet master include

**Story:** [SH-044](../stories/SH-044-mk-ci-include.md)

## Design delta

New file: `mk/ci.mk` — ships the canonical tier scaffolding so fleet repos declare only their `*_STEPS` variables.

Contents (ordered as they appear in the file):

1. Budget variables (`CI_BRANCH_BUDGET` = 300, `CI_PATCH_BUDGET` = 300, `CI_RELEASE_BUDGET` = 900, `CI_NIGHTLY_BUDGET` = 0) + timing file paths.
2. Step defaults (`COMMIT_STEPS` / `PUSH_STEPS` / `BRANCH_STEPS` / `PATCH_STEPS` / `RELEASE_STEPS` / `NIGHTLY_STEPS` — all empty-defaulted).
3. `.PHONY` declaration for the five canonical tier targets + `ci-release-promote` + `ci-timing-init`.
4. Local-gate wrappers: `hook-commit: $(COMMIT_STEPS)` / `hook-push: $(PUSH_STEPS)`.
5. `ci-timing-init` target.
6. `define ci-timing-finish-cmd` macro (SH-014 schema v1 JSON emission).
7. `define run_tier` macro (loops `$(1)` steps via `$(MAKE)`, records per-step JSON, propagates failing step's exit code — SH-034 invariant preserved).
8. Tier wrappers: `ci-branch`, `ci-patch`, `ci-release` — each delegates to `run_tier` with its budget. `ci-nightly` intentionally NOT shipped (per-repo policy differs — shepherd opens needs-human, others may just log).
9. `ci-release-promote` — SH-029 FF-only promote.

Shepherd's own Makefile edits:

- Remove the ~90-line inline block (`CI_*_BUDGET` + `CI_TIMING_FILE` + `define step` + `ci-timing-init` + `define ci-timing-finish-cmd` + `ci-branch`/`ci-patch`/`ci-release`/`ci-nightly`/`ci-release-promote` recipes + hook-commit/hook-push wrappers).
- Declare six `*_STEPS` variables (shepherd-specific values).
- `include mk/ci.mk`.
- Keep shepherd's custom `ci-nightly` wrapper locally (opens needs-human issue on failure).

Bump.zig edits:

- `cmdVerifyContract` — when `Makefile` contains `include mk/ci.mk`, concatenate `mk/ci.mk` contents before scanning for contract targets. Target coverage check now spans both files.

Test extensions:

- `test_SH_034_step_macro_exit_code.sh` — swap `Makefile` → `mk/ci.mk` in the primary scan; template snippet still scanned too.
- `test_SH_044_mk_ci_include.sh` — new; 15 assertions covering file presence, macros, dogfood, verify-contract.

CAPABILITIES rows:

- `dev-cycle.master-include` — new.
- `blocklist.protected-files` — extend description to mention `mk/**`.
- `dev-cycle.step.exit-code-propagation` — extend test pointer to `mk/ci.mk`.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Keep each repo's ~90-line inline block | Loses the primary win — one place to fix bugs (e.g. SH-034) that propagate fleet-wide. |
| Also ship `ci-nightly` in `mk/ci.mk` | Nightly escalation policy differs per repo (shepherd opens needs-human; HRC notifies ntfy; kernel-test logs). Leaving it out lets each repo decide. |
| sha256 integrity check in this PR | Would require the file to exist byte-identically in every managed repo before this PR can turn green. Deferring to a per-repo migration wave (SH-045…SH-051). |
| Step-reachability check in this PR | Nice-to-have but adds ~50 lines of bump.zig for a verify-time guard. Shepherd's dogfood is the first canary; per-repo migrations can validate by eye for now. Deferred. |
| Parameterise `include mk/ci.mk` via symlink from managed repos | Repos are separate GitHub repos; cannot share filesystem. Each repo must have its own copy (eventual sha256 check will enforce byte-identity). |

## Breaking changes

- [ ] Yes
- [x] No — strictly additive on shepherd. The migration moves logic location but preserves every target name, budget, and exit-code shape. Managed repos opt in one at a time (SH-045+); none are forced here.

## Rollout

- [x] README updated — N/A (local-gate contract not yet in README; `docs/specs/dev-cycle-contract.md` is the source of truth).
- [x] `memory/project.md` invariants updated — not modified; §12 protected-files CAP covers `mk/**` via CAPABILITIES edit.
- [x] `docs/specs/DESIGN.md` reconciled — §12 already protects `templates/**`; the CAPABILITIES edit clarifies `mk/**` is on the same tier. A follow-up may add an explicit §12 decision line (deferred — not a trust-boundary CHANGE, just a formalisation of the same pattern).
- [x] CAPABILITIES rows added
- [x] Acceptance test wired

Per-repo rollout (follow-up, out of this PR's scope):

| Repo | Follow-up story | Status |
|---|---|---|
| shepherd | SH-044 (this PR) | in-progress |
| healthy | SH-045 | TBD |
| beaconry | SH-046 | TBD |
| HRC | SH-047 | TBD |
| homelab | SH-048 | TBD |
| kernel-test | SH-049 | TBD |
| forge | SH-050 | TBD |

## Shipping evidence

| Lens | Evidence | ✅ / ⚠️ / ❌ |
|---|---|---|
| Gherkin coverage | `test_SH_044_mk_ci_include.sh` covers all four scenarios (file existence, dogfood, verify-contract, SH-034 guard) | ✅ |
| Behaviour symmetry | Shepherd's `make -n ci-branch` output verified identical pre/post migration (same four steps, same timing emission, same budgets) | ✅ |
| Self-consistency | CAPs referenced by story Q9 + test `Covers:` block + CAPABILITIES.md rows all name the same three CAPs | ✅ |
