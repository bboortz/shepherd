---
id: SH-042
slug: hook-tiers
story: docs/stories/SH-042-hook-tiers.md
branch: feat/SH-042-hook-tiers
status: in-progress
---

# SH-042 plan — `hook-commit` + `hook-push` as named fleet tiers

**Story:** [SH-042](../stories/SH-042-hook-tiers.md)

## Design delta

Add two new `.PHONY` targets to the Makefile of every fleet repo:

- `hook-commit` → delegates to `$(COMMIT_STEPS)` (repo-declared bundle of fmt + lint-staged targets)
- `hook-push` → delegates to `$(PUSH_STEPS)` (repo-declared bundle of fast tests + static checks)

Each repo's wrappers are ≤5 lines over existing targets. Specific blocks per v3 Layer 3:

| Repo | COMMIT_STEPS | PUSH_STEPS |
|---|---|---|
| shepherd | `yaml-lint md-lint verify-memory-size` | `verify-traceability build test-acceptance` |
| healthy | `zig-fmt shell-lint verify-traceability` | `build test verify-version-bumped verify-changelog` |
| beaconry | `lint type` | `check-fast verify-version-bumped verify-changelog verify-feature-complete` |
| HRC | `prettier-check` (new) | `check` |
| homelab | `lint-context shellcheck-staged yamllint-staged` | `lint-updates test-updates` |
| kernel-test | `shellcheck-staged` (new) | `lint ci-test` |
| forge | `lint verify-sid-pins verify-traceability` | `check-smart` |

This shepherd PR lands the reference implementation + acceptance test. Six follow-up PRs land the per-repo wrappers on each managed repo.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Rename step-level targets fleet-wide (v2 proposal) | Survey showed 7 repos with ~30 unique step-names. Rename churn with no payoff — the contract is the TIER name, not the step name. |
| Alias `hook-push` to existing `make check` | `check` is overloaded (shepherd = full gate including build + tests + drill; beaconry has no `check`; HRC's `check` is tsc + eslint only). The hook-push semantics are narrower than `check` in some repos and wider in others. |
| Ship tier wrappers inside a shared `mk/ci.mk` from day one | Correct end-state (SH-044) but requires migrating every repo's current `ci-branch`/etc. targets simultaneously. SH-042 is the smallest first step that proves value. |

## Breaking changes

- [ ] Yes
- [x] No — strictly additive. New targets, no removed targets.

## Rollout

- [x] README updated (if public contract moved) — N/A, local-gate targets not yet in README
- [ ] `memory/project.md` invariants updated — N/A
- [ ] `docs/specs/DESIGN.md` reconciled — N/A (dev-workflow is operational, not a §12 invariant)
- [x] CAPABILITIES.md rows added: `dev-cycle.tier.hook-commit`, `dev-cycle.tier.hook-push`
- [x] Acceptance test wired: `test/acceptance/test_SH_042_hook_tiers.sh`

Per-repo rollout waves (one PR per repo, each self-contained):

1. **Shepherd (this PR)** — reference implementation
2. **Healthy** — Zig single-binary; existing `build test verify-version-bumped verify-changelog` chain
3. **Beaconry** — Python stack with pytest + many verify-\* targets
4. **HRC** — add new `prettier-check` target (`npx prettier . --check`), then wrappers
5. **Homelab** — Ansible IaC; existing `lint-context` + `*-staged` targets
6. **Kernel-test** — add new `shellcheck-staged` target, then wrappers
7. **Forge** — existing `lint verify-sid-pins verify-traceability` + `check-smart`

## Shipping evidence

| Lens | Evidence | ✅ / ⚠️ / ❌ |
|---|---|---|
| Gherkin coverage | `test_SH_042_hook_tiers.sh` asserts `.PHONY: hook-commit hook-push` + both targets dry-run clean | ✅ |
| Behaviour symmetry | Wrapper is ≤5 lines; delegates verbatim to existing targets — no behaviour drift vs. `make lint && make build && make test-acceptance` | ✅ |
| Self-consistency | Entry CAPs + story Q9 + test Covers: block all three name `dev-cycle.tier.hook-commit` + `dev-cycle.tier.hook-push` | ✅ |
