---
id: SH-029
slug: fleet-branching-convergence
status: draft
created: 2026-11-22
owner: @benni
---

# SH-029 — Converge fleet branching: feat/* → dev → main on all 6 repos

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Resolves an asymmetry the SH-014 revision surfaced: `dev-cycle-contract.md` prescribes `feat/* → dev → main` with merge commits into `dev` and fast-forward into `main`, but only 2 of 6 fleet repos (beaconry + forge) actually have `dev`. Shepherd + healthy + homelab + kernel-test + HRC run `feat/* → main` directly today. This story converges all six on the prescribed flow.

## 1. Who is the consumer?

- Shepherd's own `ci-patch` workflow (template `ci-patch.yml`) — triggers on `push` to `[dev, main]`. On a `feat → main` repo both the PR merge AND the post-merge push to main fire the workflow twice; wasted runner time + flaky "already ran" skipping logic.
- Future `shepherd-bump --verify-contract` (SH-017) — simpler verifier when all six repos share the same promotion path.
- Repo owner cutting a release — one `release.yml` shape for all six.

## 2. When does the story fire?

Once per repo. Three-step migration per repo:

1. Cut `dev` branch from `main`: `git switch -c dev main && git push -u origin dev`.
2. Switch default branch to `dev` (GitHub Settings or `gh repo edit --default-branch dev`).
3. Add `.github/workflows/release.yml` (copy from shepherd's existing shape — FF-promote `dev` to `main` on `workflow_dispatch`, assert CI green on `dev`, tag `vX.Y.Z`).

## 3. What does success look like?

Mechanically checkable per repo:

- `git rev-parse --verify origin/dev` returns a commit SHA (dev exists).
- `gh repo view --json defaultBranchRef` → `dev`.
- `.github/workflows/release.yml` exists and is SHA-pinned to `actions/*` (SH-001 invariant).
- PRs now target `dev` (not `main`). Branch-protection ruleset applies to `dev`.
- A manual `gh workflow run release.yml` promotes `dev → main` + tags.

Fleet-wide success:

- All six fleet repos (shepherd, healthy, beaconry, homelab, kernel-test, HRC, forge) use `feat/* → dev → main` with merge commits into dev + FF into main.
- `docs/FLEET.md` columns extended with `branching_convergence: ✓` per row.
- No more "`ci-patch` fires twice per commit" condition on any repo.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (the contract spec currently misstates 4 of 6 repos' reality)
- [x] Quality-of-life (wasted runner time on double-fired workflows)
- [x] Onboarding (one promotion shape across the fleet is quickstart-friendly)

Dependency: none. Can start in parallel with the rest of SH-019. **Does NOT block SH-019 PRs already open** — those continue targeting each repo's current base branch.

## 5. Happy path

_TBD — filled when picked up. Rough shape:_

```
# Per repo (shepherd example):
$ git switch main && git pull --ff-only
$ git switch -c dev main && git push -u origin dev
$ gh repo edit bboortz/shepherd --default-branch dev
$ cp .github/workflows/release.yml.template .github/workflows/release.yml
$ gh workflow run release.yml   # smoke the FF-promotion path
```

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely:_

- Existing PRs open against `main` — they need to be rebased onto `dev`.
- Branch protection on `main` needs to be relaxed temporarily to permit the one-time FF push from `release.yml`.
- `shepherd`-side auto-merge (SH-009) assumes PRs target `main` today; SH-017 verifier needs to know each repo's `default_branch`.

## 7. Out of scope

- Converting `main` to a protected FF-only branch — that's part of the release.yml workflow setup, included here.
- Renaming `main` → `release` or similar — out of scope, keep `main` as the FF-only tag target.
- GitHub merge queue adoption — still rejected (needs org repo).
- Squash-only merges — still rejected (contradicts §12 auto-merge path).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.branching-convergence` — NEW. Every fleet repo uses `feat/* → dev → main` with merge commits into `dev` and FF into `main`. Delivered when all six rows in FLEET.md show convergence.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
