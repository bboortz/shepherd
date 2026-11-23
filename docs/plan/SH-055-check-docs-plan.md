---
id: SH-055
slug: check-docs
story: docs/stories/SH-055-check-docs.md
branch: feat/SH-055-check-docs
status: in-progress
---

# SH-055 plan — fleet-wide `check-docs` wrapper

**Story:** [SH-055](../stories/SH-055-check-docs.md)

## Design delta

Per-repo PR adds:

1. `check-docs` target in `Makefile` (thin wrapper over existing drift targets — see §9 Q3 table in story).
2. `check-docs` added to `PUSH_STEPS` + `BRANCH_STEPS` variables (post-SH-042 pattern).
3. Acceptance test confirming shape (`.PHONY: check-docs` declared, target resolves clean, steps lists reference it).

Shepherd PR (this one) also:

4. Writes the story + plan + CAPABILITIES row (`dev-cycle.tier.check-docs`).
5. Refreshes `dev-cycle.tier.hook-push` CAP description to mention check-docs.

HRC + kernel-test additionally need a new tiny verifier script:

- **HRC** `scripts/verify-stories-index.sh` — scans `docs/stories/SH-NNN-*.md` + checks each has a matching row in `docs/stories/INDEX.md`. Same bug class as the shepherd INDEX drift we fixed via PR #55.
- **kernel-test** `scripts/verify-plan-docs.sh` — on `feat/SH-NNN-*` branches, asserts a matching plan doc exists (kernel-test uses `docs/plans` — plural — not shepherd's `docs/plan`). This rule is already in `.githooks/pre-push`; SH-055 exposes it under the fleet-aligned name so CI backs up the local hook.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Rename all repos' `verify-docs-drift` / `verify-traceability` / etc. to `check-docs` | Scope creep. Same objection v3 made against step-name coercion for SH-042. Each repo keeps its vocabulary; only the wrapper name is fleet-aligned. |
| Only add to `hook-push`, skip `ci-branch` | Loses the belt. A developer who skipped the hook (e.g. with `--no-verify`) ships drift. CI needs to catch it too. |
| Add to `hook-commit` instead of `hook-push` | ~15 s budget too tight for I/O-heavy scanning (homelab's check-docs alone is ~20 s). |
| Centralise `check-docs` logic in `mk/ci.mk` with a plugin mechanism | `mk/ci.mk` deliberately stays content-free; it only carries tier scaffolding. Each repo's doc shape is too different to template. |
| Ship as a single mega-PR touching all 7 repos | Different repos, different CI gates. Separate PRs let each one go through its own rulesets. |

## Breaking changes

- [ ] Yes
- [x] No — strictly additive. `check-docs` is a new target; existing targets unchanged. `PUSH_STEPS` + `BRANCH_STEPS` grow by one token.

## Rollout

Shepherd lands the reference + story (this PR). Six managed-repo PRs follow, one per repo, each self-contained:

1. **shepherd** (this PR) — reference impl + CAP + story
2. **healthy** — wrap `verify-traceability + verify-version-bumped + verify-changelog`
3. **beaconry** — wrap `verify-docs-drift + verify-docs-layout + verify-version-sync + verify-evidence-pointers + verify-traceability + verify-install-doc`
4. **HRC** — add `scripts/verify-stories-index.sh` + wrap
5. **homelab** — add `check-docs` to `PUSH_STEPS` (already in `PATCH_STEPS` via SH-054, but not on push)
6. **kernel-test** — add `scripts/verify-plan-docs.sh` + wrap
7. **forge** — wrap `verify-traceability + verify-sid-pins + verify-promises-version`

Per-repo PRs are small (~5–20 LoC Makefile + optional new tiny script).

## Shipping evidence

| Lens | Evidence | ✅ / ⚠️ / ❌ |
|---|---|---|
| Gherkin coverage | `test_SH_055_check_docs.sh` asserts `.PHONY: check-docs`, delegate list, PUSH_STEPS + BRANCH_STEPS membership | ✅ |
| Behaviour symmetry | `check-docs` delegates verbatim to existing targets — no behaviour drift vs. running them individually | ✅ |
| Self-consistency | Story Q9 + test Covers: block + CAPABILITIES rows all name `dev-cycle.tier.check-docs` | ✅ |
