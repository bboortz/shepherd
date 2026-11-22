# Fleet consistency audit — 2026-11-22

## Second pass — 2026-11-22 (evening)

**When:** re-run on 2026-11-22, same day as the first pass, after three follow-up stories shipped.

**What changed since the first pass:**

- **SH-030 shipped** ([PR #39](https://github.com/bboortz/shepherd/pull/39)) — `shepherd-bump --verify-sha-pin` verifier added at `bin/shepherd-bump`; all 89 mutable `uses:` refs across the 6 non-shepherd repos rewritten to 40-hex SHAs.
- **SH-032 shipped** — ham-radio-compass default branch flipped `main → dev`; HRC is now in line with the rest of the fleet.
- **SH-033 shipped** ([PR #40](https://github.com/bboortz/shepherd/pull/40)) — `shepherd-bump --verify-prepush` verifier added; `.pre-commit-config.yaml` added to homelab + kernel-test, `.husky/pre-push` added to HRC, and shepherd itself got its own pre-push hook.
- **SH-034 shipped** — `make` step-macro exit-code propagation fix; orthogonal to the audit columns.
- Housekeeping: [PR #42](https://github.com/bboortz/shepherd/pull/42) flipped SH-030 + SH-033 to shipped status.

**New totals:** 67 ✅ · 9 ⚠️ · 1 ❌ out of 77 cells (first pass was 42 / 17 / 18). The only hard ❌ left is **HRC column 6** (workflow filename drift: HRC has no `ci-release.yml` yet). The 9 ⚠️ cells are all explicitly contract-permitted (workflow-filename aliasing on 5 repos, `test-affected` identity aliasing on 4 repos — both documented, both inside the dev-cycle contract's permitted-aliasing clause).

The §12 supply-chain invariant (`supply-chain.sha-pin-all-actions`) is now **enforced and green across the entire fleet**. The DD-TGD pre-push gate is **present on every managed repo**. The audit's "critical" and "high" severity rows from the first pass are resolved.

---

## First pass — 2026-11-22 (morning)

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
| **shepherd** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ✅ ci-branch/patch/release.yml (native) | ✅ reusable-shepherd.yml | ✅ reusable-shepherd-gates.yml | ✅ verifier green | ✅ `.pre-commit-config.yaml` wires `make check` at pre-push (SH-033) | ⚠️ alias → `test-acceptance` (shepherd has no app tier; acceptable) |
| **healthy** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ⚠️ `ci.yml` + `ci-release.yml` + `release.yml` (aliased via Makefile) | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ pre-commit `make check` pre-push | ⚠️ identity alias → `test` (3-min full run; documented in Makefile) |
| **beaconry** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ⚠️ `ci.yml` + `ci-release.yml` + `release.yml` | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ pre-commit `make check` pre-push | ✅ diff-aware → `test-updates` |
| **ham-radio-compass** | ✅ `dev` (flipped via SH-032) | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ❌ only `lint.yml` + `release.yml` + `eas-build.yml` (no `ci-release.yml`; no tiered split) | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ `.husky/pre-push` → `make check` (SH-033) | ⚠️ identity alias → `test` (documented: "HRC has no module graph yet") |
| **homelab** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete (build = `make lint` — Ansible repo, deliberate) | ✅ present | ⚠️ `ci.yml` + `ci-release.yml` + `cd.yml` + `weekly-checks.yml` | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ `.pre-commit-config.yaml` added (SH-033) | ✅ diff-aware → `test-updates` (changed-roles) |
| **kernel-test** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete (build = `make programs`; test = `make ci-test` — documented) | ✅ present | ⚠️ `ci.yml` + `ci-release.yml` + `ci-nightly.yml` | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ `.pre-commit-config.yaml` added (SH-033) | ⚠️ alias → `ci-test` (framework tests only, by design — no kernel tree) |
| **forge** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ⚠️ `ci.yml` + `build.yml` + `release.yml` + `nightly.yml` | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ pre-commit `make check` pre-push | ✅ diff-aware → `scripts/smart-check.sh` |

**Totals (second pass):** 67 ✅ · 9 ⚠️ · 1 ❌ (of 77 cells). First pass was 42 ✅ · 17 ⚠️ · 18 ❌ — a net shift of +25 ✅.

**By column:**

| Column | ✅ | ⚠️ | ❌ | Δ since first pass |
|---|---|---|---|---|
| 1 default branch `dev` | 7 | 0 | 0 | +1 ✅ (SH-032) |
| 2 dev+main both exist | 7 | 0 | 0 | — |
| 3 Makefile 9 targets | 7 | 0 | 0 | — |
| 4 `.shepherd.yml` v1 | 7 | 0 | 0 | — |
| 5 dependabot.yml | 7 | 0 | 0 | — |
| 6 tiered workflow names | 1 | 5 | 1 | — (alias policy unchanged) |
| 7 shepherd caller | 7 | 0 | 0 | — |
| 8 gates caller | 7 | 0 | 0 | — |
| 9 SHA-pinned actions | 7 | 0 | 0 | +6 ✅ (SH-030) |
| 10 pre-push hook | 7 | 0 | 0 | +4 ✅ (SH-033) |
| 11 test-affected diff-aware | 3 | 4 | 0 | — (alias policy unchanged) |

---

## Gaps + follow-up stories

Ordered by severity. Items marked **critical** block an invariant from `DESIGN.md §12`; **high** reduce the uniformity story we want to ship in R2; **low** are cosmetic.

### Critical — supply-chain invariant (§12 `supply-chain.sha-pin-all-actions`)

- **SH-030 — Fleet-wide SHA-pin sweep + `shepherd-bump --verify-sha-pin`. _Shipped 2026-11-22_ ([PR #39](https://github.com/bboortz/shepherd/pull/39), [PR #42](https://github.com/bboortz/shepherd/pull/42)).** All 89 mutable `uses:` refs across the 6 non-shepherd repos rewritten to 40-hex SHAs. The verifier at `bin/shepherd-bump --verify-sha-pin --root <path>` exits non-zero on the first mutable ref. Re-run of the audit confirms all 7 repos are green. The invariant is now enforced.
- **SH-031 — Needs-human on orphaned pin discovery during SHA-pin sweep.** _Status: not shipped._ The SH-030 sweep did not surface any orphaned pins in practice (vendors had not force-pushed between the audit and the rewrite window). SH-031 remains a backlog item for when `shepherd-bump` starts opening bump PRs in anger (runtime orphan detection vs sweep-time).

### High — HRC default-branch mismatch

- **SH-032 — Flip ham-radio-compass default branch to `dev`. _Shipped 2026-11-22_.** `gh repo edit bboortz/ham-radio-compass --default-branch dev` applied; HRC is now in line with the other six repos.

### High — local pre-push gate missing on 4 repos

- **SH-033 — Fleet-wide pre-push convergence via `templates/.pre-commit-config.yaml.snippet` + `shepherd-bump --verify-prepush`. _Shipped 2026-11-22_ ([PR #40](https://github.com/bboortz/shepherd/pull/40), [PR #42](https://github.com/bboortz/shepherd/pull/42)).** `.pre-commit-config.yaml` added to homelab + kernel-test; `.husky/pre-push` added to HRC (React Native ecosystem keeps husky); shepherd itself got its own `.pre-commit-config.yaml` wiring `make check` at pre-push. Verifier at `bin/shepherd-bump --verify-prepush --root <path>` exits 0 for all 7 repos. The DD-TGD gate matrix is now enforceable fleet-wide.

### Medium — workflow naming drift (column 6)

Only shepherd has the native triad `ci-branch.yml` / `ci-patch.yml` / `ci-release.yml`. Five managed repos keep their legacy `ci.yml` + `release.yml` names and alias into the contract via the Makefile. HRC is the outlier: it has **no** `ci-release.yml` at all — only `lint.yml` + `release.yml` + `eas-build.yml`. This works mechanically (the contract is in the Makefile targets, not the filenames) but hurts auditability on HRC specifically.

- **SH-035 _(previously numbered SH-034 in the first pass; renumbered because SH-034 was taken by the step-macro exit-code fix)_ — Optional convergence to `ci-{branch,patch,release}.yml` filenames across the fleet.** Backlog candidate. Low priority: the invariant lives in the Makefile, not the filename; merge-commit git history already makes this grep-friendly. Could be an R2-era cosmetic PR. HRC gets the biggest value (addresses the sole ❌ cell in the matrix).

### Low — `test-affected` identity aliases on 4 repos (shepherd, healthy, HRC, kernel-test)

- **No story.** `dev-cycle.contract.tiered-make-targets` explicitly permits identity aliasing when "each repo aliases to its native idiom or inherits the identity default." Shepherd has no app tier so `test-acceptance` is the only test corpus. Healthy's `test` is 3 min — already inside the ci-branch budget. HRC has no module graph yet. kernel-test's `ci-test` is framework-only (no kernel tree required). These are documented, deliberate, and contract-compliant.

### Orthogonal — SH-034 step-macro exit-code fix (_Shipped 2026-11-22_)

Not an audit column, but worth recording for traceability: `fix(SH-034)` made the shared `step` macro propagate the inner recipe's exit code so a failing sub-shell actually fails the `make` target. This prevents false-green `ci-branch` runs — but it changes no cell in the matrix (all audit columns are structural, not behavioural).

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
