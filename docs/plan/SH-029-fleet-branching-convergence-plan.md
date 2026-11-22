---
id: SH-029
slug: fleet-branching-convergence
story: docs/stories/SH-029-fleet-branching-convergence.md
branch: feat/SH-029-branching-convergence
status: in-progress
---

# SH-029 plan — Fleet branching convergence (feat/* → dev → main)

**Story:** [SH-029](../stories/SH-029-fleet-branching-convergence.md)

## Design delta

Two code changes in this PR (shepherd dogfood):

1. **`templates/Makefile.contract.snippet`** — add `ci-release-promote` as a shared target. Fast-forward `main` to `dev`, tag from `VERSION`, push. Must run on `dev` branch (asserts and exits 1 if not). Mutates the working tree; intended for CI only. The existing `ci-release` default body is replaced to call `ci-release-promote` (via the timing wrapper) so repos that want promote-only need no override.

2. **`templates/ci-release.yml` + `.github/workflows/ci-release.yml`** — `checkout` now pins `ref: dev` (not the triggering branch), and a `git config user.name/email` step runs before `make ci-release` so the FF push has a signed author. Permissions already allow `contents: write`.

Shepherd's own `Makefile` mirrors the snippet change (shepherd carries an inlined copy of the contract per SH-016's dogfood pattern).

No operator action in this PR. Phase 2 (operator-driven, documented in story §5) migrates shepherd itself: cut `dev`, flip default branch via `gh repo edit`, apply branch-protection rulesets (strict per decision 2026-11-22), dispatch one no-op `ci-release` run to validate the FF path end-to-end.

Phase 3 (follow-up PRs, one per repo) migrates healthy, homelab, kernel-test the same way. HRC deferred to SH-018.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| FF logic inside `ci-release.yml` directly (not via Makefile) | Bypasses the contract. Every repo's `make ci-release` would then need its own logic. The snippet target is the uniformity enforcement. |
| Put FF logic in shepherd's Makefile only, not the snippet | Every other repo would need to rewrite it. The snippet is the single source of truth — one bug-fix site. |
| Auto-trigger release on VERSION-bump merge to dev | Too much magic; forgot-to-bump = silent no-release; version-bump-only PR = immediate release before anyone reviews. Manual dispatch is the right default per the SH-029 question answered 2026-11-22. |
| Keep current split (2 repos on dev / 5 on main) | Contract's `ci-patch.yml` triggers on `[dev, main]`; the split flow silently double-fires or no-fires per repo. SH-029 is the last structural piece of the SH-014 umbrella; without it the uniformity CAP stays in design. |
| Separate `release.yml` + `ci-release.yml` workflows | Overcomplicated. `ci-release.yml` already exists as the tier workflow; adding promote logic to its Makefile-wrapped body keeps the contract shape intact. |

## Breaking changes

- [x] Yes — `make ci-release` now MUTATES git state (FF main to dev, tag, push) when run on `dev`. Previously it printed a placeholder. Impact:
  - A human running `make ci-release` interactively on a feature branch gets a clean exit-1 error ("must run on 'dev'") — not destructive.
  - A human running it on `dev` locally would promote + push. **Intended for CI only.**
  - Mitigation: documented in the Makefile comment + story §6 edge-cases.
- [ ] No other breaks. New `ci-release-promote` target is additive. Existing workflows untouched except for the `ref: dev` checkout pin + git config step.

## Rollout

- [x] README untouched — internal contract mechanics, no public-contract shift.
- [x] `memory/project.md` invariants unchanged.
- [x] `memory/workflow.md` — the `feat → dev → main` flow is already documented there; SH-029 is the execution, not a doc change.
- [x] `docs/specs/DESIGN.md` — no §12 / §13 shift.
- [ ] Downstream notice — Phase 3 per-repo migration PRs will link to this plan.

**Target slot**: R2 (2026-12-11). This PR is Phase 1 of 3 (shepherd dogfood). Phase 2 (operator migration) + Phase 3 (per-repo PRs) follow.

## Shipping evidence (fill at step 6a)

### Lens 1 — Gherkin coverage

| Scenario (from story §5) | Test pointer | Status |
|---|---|---|
| `make ci-release` on a non-dev branch exits 1 | `make -n ci-release-promote` inspection + manual run on feat branch (verified locally) | ✅ |
| `make ci-release-promote` needs VERSION file | inspection; VERSION exists on shepherd today (0.7.1-rc1) | ✅ |
| `ci-release.yml` checks out `dev` on dispatch | manual `yaml-lint` + `grep "ref: dev"` on `.github/workflows/ci-release.yml` | ✅ |
| `git config` user.name/email is `github-actions[bot]` | inspection | ✅ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `dev-cycle.fleet.branching-convergence` | ⚠️ (Phase 1 ships mechanics only; no end-to-end test. Phase 2 operator dispatch validates live; CAP flips to active after Phase 3 last repo migrates.) | ✅ (branch-check + VERSION-check + FF-only exit paths covered by shell asserts in Makefile) | in-progress → active after Phase 3 |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (out-of-scope) — no main-rename, no squash-only flip, no merge-queue adoption | ✅ |
| New CAP in §9 appears in `docs/specs/CAPABILITIES.md` | ✅ |
| Protected-files invariant intact (DESIGN §12) — `templates/**` touched under human review, not agent | ✅ |
| Budget caps unchanged | ✅ n/a |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

## Post-merge notes

_(filled after merge)_

**Operator migration checklist (post-merge, per repo)**:

- [ ] shepherd: `git switch -c dev main && git push -u origin dev && gh repo edit bboortz/shepherd --default-branch dev`
- [ ] healthy: open per-repo migration PR adding `.github/workflows/ci-release.yml` + Makefile ci-release override. After merge: cut dev + flip default.
- [ ] homelab: same
- [ ] kernel-test: same
- [ ] HRC: deferred to SH-018 (needs Makefile first)

**Branch protection (shepherd first, rest to follow)**:

- `dev`: required checks `drill`, `ci-branch` (once SH-016 workflow is live); allow auto-merge; 1 PR review required.
- `main`: FF-only; no direct push except `github-actions[bot]` via ci-release.yml. No PRs. No branch deletion.
