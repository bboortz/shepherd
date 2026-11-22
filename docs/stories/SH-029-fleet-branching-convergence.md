---
id: SH-029
slug: fleet-branching-convergence
status: shipped
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

Phase 1 — shepherd dogfood (this PR):

```
# Ship the shared promote logic + shepherd-side wiring
$ git switch -c feat/SH-029-branching-convergence main
# (adds ci-release-promote to templates/Makefile.contract.snippet,
#  updates shepherd's Makefile ci-release body to call it,
#  wires `ref: dev` + git config into ci-release.yml workflow)
$ make check          # green
$ gh pr create --base main
# → merge PR
```

Phase 2 — operator migrates shepherd (manual, post-merge):

```
$ git switch main && git pull --ff-only
$ git switch -c dev main && git push -u origin dev
$ gh repo edit bboortz/shepherd --default-branch dev
$ gh ruleset list    # inspect current main protection
# apply dev ruleset: required checks (`ci-branch`, `drill`) + 1 PR review
# apply main ruleset: FF-only, no PR, no direct push (except release.yml's GITHUB_TOKEN)
$ gh workflow run ci-release.yml   # smoke the FF-promote path on a no-op dev
# → verify main FF'd to dev + tag vX.Y.Z created
```

Phase 3 — per-repo (one PR each): healthy, homelab, kernel-test.

## 6. Edge cases / failure modes that matter

- **Dispatching ci-release on main instead of dev**: the workflow is configured with `ref: dev` on checkout; the `make ci-release-promote` body asserts `git branch --show-current == dev` and exits 1 with an operator-readable message. Safe-by-construction.
- **VERSION missing or malformed**: `ci-release-promote` fails fast with "VERSION file missing — cannot determine tag". Tag write + push is atomic — if any step fails, the tag is not pushed to origin.
- **dev is not FF-ahead of main** (someone force-pushed to main): `git merge --ff-only` returns non-zero; promote aborts without side-effects. Needs operator investigation.
- **Existing PRs targeting main at migration time**: the plan doc's Phase 2 step adds a `gh pr edit <n> --base dev` loop for in-flight PRs. Zero currently open on shepherd; loop is a no-op.
- **Branch protection applied to main blocks FF push**: the GitHub `contents: write` permission on `GITHUB_TOKEN` plus an explicit "bypass actors" entry in main's ruleset lets `github-actions[bot]` push. If missing, the workflow fails at `git push origin main` — operator fixes ruleset and re-dispatches.
- **ci-patch.yml double-fire on release**: triggers `push` to `[dev, main]`; ci-release pushes the same SHA to main, so ci-patch fires twice. Documented gap; narrow to `[dev]` only if it ever matters (SH-020 digest will flag budget breach).

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
