# Fleet consistency audit — 2026-11-22

## Third pass — 2026-11-22 (late evening)

**When:** re-run after SH-035/SH-036/SH-037/SH-038 shipped.

**What changed since the second pass:**

- **SH-035 shipped** — workflow filename convergence on 5 non-HRC repos. Each got `ci.yml` renamed to `ci-branch.yml` and a new `ci-patch.yml` dropped in from `templates/ci-patch.yml`. Forge also renamed `nightly.yml` → `ci-nightly.yml`. Job names preserved so branch-protection rulesets still resolve. PRs: shepherd internal (no change — already native), [healthy #40](https://github.com/bboortz/healthy/pull/40), [beaconry #107](https://github.com/bboortz/beaconry/pull/107), [homelab #268](https://github.com/bb-claw/homelab/pull/268), [kernel-test #117](https://github.com/bb-claw/kernel-test/pull/117), [forge #171](https://github.com/bboortz/forge/pull/171).
- **SH-036 shipped** ([PR #44](https://github.com/bboortz/shepherd/pull/44)) — shepherd got a real diff-aware `test-affected` via `scripts/test-affected.sh`. Replaced the `test-affected: test-acceptance` identity alias.
- **SH-037 shipped** ([PR #41](https://github.com/bboortz/healthy/pull/41)) — healthy got the same diff-aware pattern (`scripts/test-affected.sh`).
- **SH-038 shipped** ([PR #118](https://github.com/bb-claw/kernel-test/pull/118)) — kernel-test got the same diff-aware pattern.

**New totals:** 75 ✅ · 1 ⚠️ · 1 ❌ out of 77 cells (second pass was 67 / 9 / 1). Net shift: +8 ✅ since the second pass. Of the 9 ⚠️ cells from the second pass, 8 flipped to ✅ — 5 column-6 workflow-filename ⚠️s resolved by SH-035, 3 column-11 test-affected ⚠️s resolved by SH-036/SH-037/SH-038.

**Remaining non-green** (both on HRC, both explicitly scoped-out per user direction):

- **HRC column 6** (`ci-release.yml` missing; workflows are `lint.yml` + `release.yml` + `eas-build.yml`) — ❌. Out of scope for SH-035 by user directive: HRC is a React Native / Expo app, the tiered filename story benefits native-repo auditability more than it does HRC's EAS-driven flow.
- **HRC column 11** (`test-affected: test` identity alias, no module graph) — ⚠️. Contract-permitted per `dev-cycle.contract.tiered-make-targets` (HRC has no module graph yet); same documented posture as the first pass. No story open.

**Follow-up stories open:**

- **SH-031 (orphaned pins)** — still backlog. The SH-030 sweep did not surface any orphaned pins in practice; SH-031 remains parked for when `shepherd-bump` begins opening bump PRs in anger (runtime orphan detection vs sweep-time).
- **HRC column 6 (`ci-release.yml` missing)** — tracked per user direction as explicitly out of scope. Would be reopened if HRC moves off the EAS flow.
- **HRC column 11 (`test-affected` identity alias)** — would become shippable once HRC grows a module graph (TypeScript path-aware test selection). No current driver.

The §12 supply-chain invariant stays green across the entire fleet. The DD-TGD pre-push gate stays present on every managed repo. The dev-cycle contract's **mechanical** uniformity (9-target Makefile, dual-branch, `.shepherd.yml`, dependabot) is 100 % intact. The remaining drift is confined to HRC's ecosystem-driven quirks.

---

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
| **shepherd** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ✅ ci-branch/patch/release.yml (native) | ✅ reusable-shepherd.yml | ✅ reusable-shepherd-gates.yml | ✅ verifier green | ✅ `.pre-commit-config.yaml` wires `make check` at pre-push (SH-033) | ✅ diff-aware → `scripts/test-affected.sh` (SH-036) |
| **healthy** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ✅ ci-branch/patch/release.yml (SH-035) + `release.yml` promote-job | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ pre-commit `make check` pre-push | ✅ diff-aware → `scripts/test-affected.sh` (SH-037) |
| **beaconry** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ✅ ci-branch/patch/release.yml (SH-035) + `release.yml` promote-job | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ pre-commit `make check` pre-push | ✅ diff-aware → `test-updates` |
| **ham-radio-compass** | ✅ `dev` (flipped via SH-032) | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ❌ only `lint.yml` + `release.yml` + `eas-build.yml` (no `ci-release.yml`; no tiered split — explicitly out of scope for SH-035) | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ `.husky/pre-push` → `make check` (SH-033) | ⚠️ identity alias → `test` (documented: "HRC has no module graph yet") |
| **homelab** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete (build = `make lint` — Ansible repo, deliberate) | ✅ present | ✅ ci-branch/patch/release.yml (SH-035) + `cd.yml` + `weekly-checks.yml` (deploy + nightly extras) | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ `.pre-commit-config.yaml` added (SH-033) | ✅ diff-aware → `test-updates` (changed-roles) |
| **kernel-test** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete (build = `make programs`; test = `make ci-test` — documented) | ✅ present | ✅ ci-branch/patch/release/nightly.yml (SH-035) | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ `.pre-commit-config.yaml` added (SH-033) | ✅ diff-aware → `scripts/test-affected.sh` (SH-038) |
| **forge** | ✅ `dev` | ✅ both | ✅ 9/9 | ✅ v1 complete | ✅ present | ✅ ci-branch/patch/release/nightly.yml (SH-035) + `build.yml` + `release.yml` promote-job | ✅ shepherd.yml | ✅ shepherd-gates.yml | ✅ verifier green (SH-030) | ✅ pre-commit `make check` pre-push | ✅ diff-aware → `scripts/smart-check.sh` |

**Totals (third pass):** 75 ✅ · 1 ⚠️ · 1 ❌ (of 77 cells). Second pass was 67 ✅ · 9 ⚠️ · 1 ❌ — a net shift of +8 ✅ since the second pass (and +33 ✅ since the first pass).

**By column:**

| Column | ✅ | ⚠️ | ❌ | Δ since second pass |
|---|---|---|---|---|
| 1 default branch `dev` | 7 | 0 | 0 | — |
| 2 dev+main both exist | 7 | 0 | 0 | — |
| 3 Makefile 9 targets | 7 | 0 | 0 | — |
| 4 `.shepherd.yml` v1 | 7 | 0 | 0 | — |
| 5 dependabot.yml | 7 | 0 | 0 | — |
| 6 tiered workflow names | 6 | 0 | 1 | +5 ✅ (SH-035) |
| 7 shepherd caller | 7 | 0 | 0 | — |
| 8 gates caller | 7 | 0 | 0 | — |
| 9 SHA-pinned actions | 7 | 0 | 0 | — |
| 10 pre-push hook | 7 | 0 | 0 | — |
| 11 test-affected diff-aware | 6 | 1 | 0 | +3 ✅ (SH-036 / SH-037 / SH-038) |

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

- **SH-035 — Workflow filename convergence to `ci-{branch,patch,release}.yml` across the fleet. _Shipped 2026-11-22_.** On 5 non-HRC repos: `ci.yml` renamed to `ci-branch.yml`; `ci-patch.yml` dropped in from `templates/ci-patch.yml`. Forge also renamed `nightly.yml` → `ci-nightly.yml`. Job names preserved so existing branch-protection rulesets still resolve. PRs: [healthy #40](https://github.com/bboortz/healthy/pull/40), [beaconry #107](https://github.com/bboortz/beaconry/pull/107), [homelab #268](https://github.com/bb-claw/homelab/pull/268), [kernel-test #117](https://github.com/bb-claw/kernel-test/pull/117), [forge #171](https://github.com/bboortz/forge/pull/171). Shepherd itself needed no change (already native). HRC was explicitly scoped out per user direction (React Native / Expo flow doesn't benefit from the native-repo triad). Column 6 now green on 6/7 repos; the single ❌ is HRC — tracked as out-of-scope.

### Low — `test-affected` identity aliases

- **SH-036 — Shepherd diff-aware `test-affected` via `scripts/test-affected.sh`. _Shipped 2026-11-22_ ([PR #44](https://github.com/bboortz/shepherd/pull/44)).** Replaced `test-affected: test-acceptance` identity alias with a diff-aware shell wrapper keyed on `origin/dev` merge-base; bailouts on Makefile / bump.zig / build.zig / workflows / CAPABILITIES.md changes.
- **SH-037 — Healthy diff-aware `test-affected` via `scripts/test-affected.sh`. _Shipped 2026-11-22_ ([PR #41](https://github.com/bboortz/healthy/pull/41)).** Same pattern as SH-036, adapted to healthy's two test tiers (`test/run.sh` + `test/acceptance/test_HC_<N>_*.sh`). Replaces the `test-affected: test` identity alias.
- **SH-038 — kernel-test diff-aware `test-affected` via `scripts/test-affected.sh`. _Shipped 2026-11-22_ ([PR #118](https://github.com/bb-claw/kernel-test/pull/118)).** Same pattern again, adapted to kernel-test's framework-only CI tests (`tests/ci/test-*.sh`). Replaces the `test-affected: ci-test` identity alias.
- **HRC `test-affected: test` identity alias — no story.** `dev-cycle.contract.tiered-make-targets` explicitly permits identity aliasing when the repo "has no module graph yet." HRC is a React Native app with no TS path-aware test selection; the identity alias is documented and contract-compliant. Would become shippable once HRC grows a module graph.
- **Beaconry (`test-updates`), homelab (`test-updates`), forge (`scripts/smart-check.sh`) — already diff-aware** from earlier stories (BC-149 / HL-xx / FG-017). Unchanged this pass.

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
