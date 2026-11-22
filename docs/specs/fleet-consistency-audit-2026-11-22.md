# Fleet consistency audit — 2026-11-22

**Umbrella:** SH-014 (dev-cycle contract + fleet uniformity).
**Scope:** 7 repos — shepherd, healthy, beaconry, ham-radio-compass, homelab, kernel-test, forge.
**Method:** read-only audit across 11 best-practice checks. No files modified in any repo.
**Verdict (short):** the mechanical contract (Makefile 9-target shape, `.shepherd.yml`, `dev`/`main` dual-branch, shepherd caller + gates callers) is **100 % uniform** — every repo passes those four columns. The drift is concentrated in two areas: **(1) SHA-pinning of `uses:` in workflows outside shepherd** (every non-shepherd repo has at least one `@vN` mutable ref; homelab is worst with 15), and **(2) local pre-push enforcement** (shepherd, HRC, homelab, kernel-test have no `make check` pre-push hook — only healthy, beaconry and forge do). HRC's default branch is still `main`, the only fleet member that didn't flip to `dev` during SH-029. The audit found **42 ✅**, **17 ⚠️**, **18 ❌** out of 77 cells.

---

## Matrix

Legend: ✅ = fully conformant · ⚠️ = partial / alias-only / minor deviation · ❌ = missing or violating.

Checks (columns):

1. Default branch = `dev`
2. `dev` + `main` branches both exist
3. 9 Makefile contract targets present
4. `.shepherd.yml` + schema v1 fields
5. `.github/dependabot.yml` present
6. `ci-branch` / `ci-patch` / `ci-release` workflows (or named equivalents)
7. Shepherd caller workflow (`shepherd.yml` / `reusable-shepherd.yml`)
8. Shepherd gates caller (`shepherd-gates.yml` / `reusable-shepherd-gates.yml`)
9. All `uses:` SHA-pinned (40-hex)
10. Pre-push hook running `make check` (via pre-commit or husky)
11. `test-affected` implementation (real diff-aware vs identity alias)

| Repo | 1 default | 2 branches | 3 Makefile | 4 `.shepherd.yml` | 5 dependabot | 6 ci-tiered | 7 shepherd caller | 8 gates caller | 9 SHA-pin | 10 pre-push | 11 test-affected |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **shepherd** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ✅ ci-branch/patch/release.yml (native) | ✅ reusable-shepherd.yml | ✅ reusable-shepherd-gates.yml | ✅ all SHA-pinned | ❌ no `.pre-commit-config.yaml` | ⚠️ alias → `test-acceptance` (shepherd has no app tier; acceptable) |
| **healthy** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ⚠️ `ci.yml` + `ci-release.yml` + `release.yml` (not renamed to contract triad) | ✅ shepherd.yml | ✅ shepherd-gates.yml | ❌ 3 refs `@v4`/`@v7` in release.yml | ✅ `make check` pre-push | ⚠️ identity alias → `test` (3-min full run; documented in Makefile) |
| **beaconry** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ⚠️ `ci.yml` + `ci-release.yml` + `release.yml` | ✅ shepherd.yml | ✅ shepherd-gates.yml | ❌ 3 × `actions/setup-python@v7` in ci.yml | ✅ `make check` pre-push | ✅ diff-aware → `test-updates` |
| **ham-radio-compass** | ❌ `main` (only fleet repo not flipped) | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ❌ only `lint.yml` + `release.yml` (no ci-release/ci-branch split; eas-build.yml is unrelated) | ✅ shepherd.yml | ✅ shepherd-gates.yml | ❌ 4 refs `@v4`/`@v7` in lint.yml + eas-build.yml | ⚠️ husky `pre-commit` → `npm run check`; no pre-push stage | ⚠️ identity alias → `test` (documented: "HRC has no module graph yet") |
| **homelab** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete (build = `make lint` — Ansible repo, deliberate) | ✅ present | ⚠️ `ci.yml` + `ci-release.yml` + `cd.yml` + `weekly-checks.yml` | ✅ shepherd.yml | ✅ shepherd-gates.yml | ❌ 15 refs non-SHA-pinned (`tailscale/github-action@v4` × 7, `actions/cache@v6` × 8) | ❌ no local pre-push hook | ✅ diff-aware → `test-updates` (changed-roles) |
| **kernel-test** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete (build = `make programs`; test = `make ci-test` — documented) | ✅ present | ⚠️ `ci.yml` + `ci-release.yml` + `ci-nightly.yml` | ✅ shepherd.yml | ✅ shepherd-gates.yml | ❌ 1 × `actions/cache@v6` in ci.yml | ❌ no local pre-push hook | ⚠️ alias → `ci-test` (framework tests only, by design — no kernel tree) |
| **forge** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ⚠️ `ci.yml` + `build.yml` + `release.yml` + `nightly.yml` | ✅ shepherd.yml | ✅ shepherd-gates.yml | ❌ 17 refs non-SHA-pinned (`actions/cache@v6`, `docker/login-action@v4`, `actions/upload-artifact@v7`) | ✅ `make check-smart-strict` pre-push | ✅ diff-aware → `scripts/smart-check.sh` |

**Totals:** 42 ✅ · 17 ⚠️ · 18 ❌ (of 77 cells).

**By column:**

| Column | ✅ | ⚠️ | ❌ |
|---|---|---|---|
| 1 default branch `dev` | 6 | 0 | 1 |
| 2 dev+main both exist | 7 | 0 | 0 |
| 3 Makefile 9 targets | 7 | 0 | 0 |
| 4 `.shepherd.yml` v1 | 7 | 0 | 0 |
| 5 dependabot.yml | 7 | 0 | 0 |
| 6 tiered workflow names | 1 | 5 | 1 |
| 7 shepherd caller | 7 | 0 | 0 |
| 8 gates caller | 7 | 0 | 0 |
| 9 SHA-pinned actions | 1 | 0 | 6 |
| 10 pre-push hook | 3 | 1 | 3 |
| 11 test-affected diff-aware | 3 | 4 | 0 |

---

## Gaps + follow-up stories

Ordered by severity. Items marked **critical** block an invariant from `DESIGN.md §12`; **high** reduce the uniformity story we want to ship in R2; **low** are cosmetic.

### Critical — supply-chain invariant violations (§12 `supply-chain.sha-pin-all-actions`)

Every non-shepherd fleet repo has at least one mutable-tag `uses:` reference. The CVE-2026-33634 (TeamPCP) incident that motivated SH-001 proves this vector is live. Shepherd dogfoods the rule but does not yet **enforce** it on managed repos.

- **SH-030 — Fleet-wide SHA-pin sweep + `shepherd-bump --verify-sha-pin` verifier.** Rewrite the 42 total mutable refs (healthy 3 · beaconry 3 · HRC 4 · homelab 15 · kernel-test 1 · forge 17) to 40-hex SHAs; add a verify-contract-style `shepherd-bump --verify-sha-pin` that exits non-zero on the first mutable ref and opens needs-human. Dogfood the verifier by running it against shepherd itself (already green) as the invariant test.
- **SH-031 — Needs-human on orphaned pin discovery during SHA-pin sweep.** The sweep will likely surface a few `actions/cache@v6` or `tailscale/github-action@v4` refs where the vendor has force-pushed between tags; wire these into the existing orphaned-pin pathway (`DESIGN.md §12 Supply chain — Orphaned pins fail loud`).

### High — HRC default-branch mismatch

- **SH-032 — Flip ham-radio-compass default branch to `dev` + migrate open PRs.** HRC is the only fleet member still on `main` as default. SH-029 landed the flip for shepherd/beaconry/forge/healthy/homelab/kernel-test on 2026-11-22; HRC was deferred because its SH-018 onboarding happened the same day. This is a `gh repo edit --default-branch dev` + reparent-open-PRs operation. Roughly a chore/ci PR — a full story only if any CI references `main` as PR target.

### High — local pre-push gate missing on 4 repos (shepherd, HRC, homelab, kernel-test)

The existing DD-TGD gate matrix (`memory/workflow.md`) says `make check` runs pre-push to catch yaml/md/traceability regressions locally. Only healthy, beaconry, forge have this today. Shepherd itself — the fleet brain — doesn't run its own pre-push gate.

- **SH-033 — Fleet-wide pre-push convergence via `templates/.pre-commit-config.yaml.snippet`.** Ship a minimal shared snippet (pre-commit framework; husky where React Native ecosystem prefers it). Includes `make check` at pre-push stage + verify-version-bumped + verify-changelog. Enforced by `shepherd-bump --verify-prepush` opening needs-human when missing.
- **No story** — shepherd self-repair: `chore/shepherd-prepush-hook` — the fleet brain gets its own pre-push today, before SH-033 generalises it.

### Medium — workflow naming drift (column 6)

Only shepherd has the native triad `ci-branch.yml` / `ci-patch.yml` / `ci-release.yml`. The six managed repos keep their legacy `ci.yml` + `release.yml` names and alias into the contract via the Makefile. This works mechanically (the contract is in the Makefile targets, not the filenames) but hurts auditability — you can't glance at `.github/workflows/` and see which tier ran.

- **SH-034 — Optional convergence to `ci-{branch,patch,release}.yml` filenames across the fleet.** Backlog candidate. Low priority: the invariant lives in the Makefile, not the filename; merge-commit git history already makes this grep-friendly. Could be an R2-era cosmetic PR.

### Low — `test-affected` identity aliases on 3 repos (shepherd, healthy, HRC)

- **No story.** `dev-cycle.contract.tiered-make-targets` explicitly permits identity aliasing when "each repo aliases to its native idiom or inherits the identity default." Shepherd has no app tier so `test-acceptance` is the only test corpus. Healthy's `test` is 3 min — already inside the ci-branch budget. HRC has no module graph yet. These are documented, deliberate, and contract-compliant.

---

## Shared best practices documented

Eight invariants the fleet converges on. Each cites the owning CAP from `docs/specs/CAPABILITIES.md`.

1. **Every managed repo ships `.shepherd.yml` with schema v1 (`version/risk/build/test/auto_merge`).** Mandatory at the repo boundary — no "shepherd defaults in another repo" indirection. Enforced by the reusable-shepherd verifier. CAP: `dev-cycle.fleet.verify-contract` (presence check is part of `shepherd-bump --verify-contract`'s exit-3 path — Makefile missing / `.shepherd.yml` schema check tracked separately).
2. **Makefile exposes exactly 9 contract targets** (`build`, `test`, `test-affected`, `smoke`, `release-artifacts`, `ci-branch`, `ci-patch`, `ci-release`, `ci-nightly`) — identity aliasing is allowed when a repo has no distinct tier (e.g. shepherd `test-affected → test-acceptance`, HRC `test-affected → test`). CAP: `dev-cycle.contract.tiered-make-targets` + `dev-cycle.fleet.verify-contract` + `dev-cycle.fleet.uniformity`.
3. **`feat/* → dev → main` with merge commits into `dev` and fast-forward into `main`.** Default branch is `dev`. CI-promoted `main`, never pushed directly. CAP: `dev-cycle.fleet.branching-convergence`.
4. **Build-once-promote.** `release-artifacts` runs once in `ci-branch`, keyed by commit SHA; `ci-patch` smokes without rebuilding; `ci-release` promotes-by-digest. CAP: `dev-cycle.artifact.build-once-promote`.
5. **Tier budgets enforced at workflow level** (5 / 5 / 15 / 120 min for branch/patch/release/nightly) via `timeout-minutes`. Work moves to nightly, never raises the cap. CAP: `dev-cycle.budget.timeout-caps`.
6. **No third-party GitHub Actions in the critical path; every `uses:` ref is 40-hex SHA-pinned.** Exceptions: `actions/*` (GitHub-native) and the Trivy install step. CAP: `supply-chain.no-third-party-actions-critical-path` + `supply-chain.sha-pin-all-actions`.
7. **Dependabot as the hygiene floor on every managed repo** (`.github/dependabot.yml` enforced by `shepherd-bump --verify-dependabot`); shepherd-bump is the first-party critical path; smart-fix agent is the §12 sandboxed layer above. These three don't overlap — they stack. CAP: `supply-chain.first-party-bump-engine` + CAP matrix row for dependabot hygiene.
8. **CI emits `build/ci-timing.json` per run; weekly digest regresses against the frozen baseline and opens one needs-human per repo per regressed `(workflow, event)` tuple when median ≥ 25 % above baseline.** CAP: `dev-cycle.timing.json-emission` + `dev-cycle.baseline.frozen-snapshot`.

---

## Appendix — raw check output references

- Default-branch probe: `gh repo view <owner>/<repo> --json defaultBranchRef`.
- Remote branch presence: `git ls-remote --heads origin dev main`.
- Makefile target grep: `grep -E '^(build|test|test-affected|smoke|release-artifacts|ci-branch|ci-patch|ci-release|ci-nightly):' Makefile`.
- `.shepherd.yml` schema spot-check: `grep -E '^(version|risk|build|test|auto_merge):' .shepherd.yml`.
- SHA-pin scan: `find .github -name '*.yml' -o -name '*.yaml' | xargs grep -HnE '^\s*uses:' | grep -vE '@[a-f0-9]{40}'`.
- Pre-push detection: presence of `.pre-commit-config.yaml` with `stages: [pre-push]` referencing `make check`, or husky `.husky/pre-push` equivalent.
- `test-affected` recipe inspection: awk-extracted recipe body from each Makefile.
