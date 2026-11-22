---
created: 2026-11-22
scope: shepherd + 6 armed repos (healthy, beaconry, ham-radio-compass, homelab, kernel-test, forge)
companion-docs:
  - docs/specs/fleet-consistency-audit-2026-11-22.md  # 11-check conformance matrix
  - docs/specs/dev-cycle-baseline.md                  # frozen timing snapshot
  - docs/specs/dev-cycle-contract.md                  # the 9-target Makefile contract
  - docs/FLEET.md                                     # human-readable registry
---

# Fleet overview — 2026-11-22

Snapshot of the seven-repo fleet (shepherd itself + the six armed pilots) after
the SH-014 umbrella + SH-029/030/032/033/035/036/037/038 consistency-convergence
push merged on 2026-11-22. The post-SH-032 flip means **all seven repos now
default to `dev`** (the audit matrix row 1 column for HRC moved from ❌ to ✅
between capture at 03:12 UTC and the flip at 03:12 UTC+Δ).

Cross-references:

- Conformance matrix (11 checks × 7 repos, third pass: 75 ✅ · 1 ⚠️ · 1 ❌):
  [`fleet-consistency-audit-2026-11-22.md`](fleet-consistency-audit-2026-11-22.md)
- Pre-adoption timing baseline (100 most-recent runs per repo):
  [`dev-cycle-baseline.md`](dev-cycle-baseline.md)
- Contract spec (9 Makefile targets + 4 tier budgets):
  [`dev-cycle-contract.md`](dev-cycle-contract.md)

---

## Summary table

| Repo | Default | Rulesets | Workflow files | Contract targets | Tests | ci-branch median |
|---|---|---|---:|---|---:|---:|
| **shepherd** | `dev` | 2 (dev + main) | 11 | 9/9 ✅ | 13 acceptance + 14 injection payloads/runners | 0.1 min ⚠️ (n=1) |
| **healthy** | `dev` | 2 (dev + main) | 6 | 9/9 ✅ | 8 acceptance | 3.0 min (n=19 PR) |
| **beaconry** | `dev` | 2 (dev + main) | 6 | 9/9 ✅ | 148 integration + e2e (pytest) | 4.0 min (n=15 PR) |
| **ham-radio-compass** | `dev` (flipped post-audit) | 2 (dev + main) | 6 | 9/9 ✅ | 0 (tsc + lint only) | 0.7 min (n=15 PR) |
| **homelab** | `dev` | 2 (dev + main) | 8 | 9/9 ✅ | 127 pytest + 2 shell | 7.1 min (n=17 PR) |
| **kernel-test** | `dev` | 1 (main only) ⚠️ | 5 | 9/9 ✅ | 49 shell (ci harness) | 1.7 min (n=72 PR) |
| **forge** | `dev` | 2 (dev + main) | 8 | 9/9 ✅ | 84 shell (acceptance + smoke + unit) | 11.8 min (n=16 PR) ❌ |

**Key:** ✅ = conformant · ⚠️ = partial/below MIN_SAMPLES · ❌ = exceeds 5-min
tier budget. All seven repos pass `shepherd-bump --verify-contract` with 9/9.

**Standouts:**

- `forge` ci-branch is already past the 5-min budget (median 11.8 min, p90 18.4
  min — see baseline row). This is the primary budget violation the next sprint
  needs to deal with (SH-021-style double-fire + scope narrowing).
- `kernel-test` has only a `main` ruleset — no `dev` ruleset was created during
  SH-029. Audit column 2 passes because both branches exist; the ruleset gap
  is new.
- `homelab` ci-branch is 7.1 min (over budget) but the `test-affected` recipe
  is already diff-aware; the remaining cost sits in the dry-run Ansible step,
  not in test selection.

---

## 1. Branches + merge strategy

### 1.1 Default branch

Every repo returns `dev` from `gh repo view … --json defaultBranchRef` as of
2026-11-22 (HRC was flipped the same day as part of SH-032; the audit matrix
captured the pre-flip state).

| Repo | Default | `dev` exists | `main` exists |
|---|---|---|---|
| shepherd | `dev` | ✅ | ✅ |
| healthy | `dev` | ✅ | ✅ |
| beaconry | `dev` | ✅ | ✅ |
| ham-radio-compass | `dev` | ✅ | ✅ |
| homelab | `dev` | ✅ | ✅ |
| kernel-test | `dev` | ✅ | ✅ |
| forge | `dev` | ✅ | ✅ |

### 1.2 Integration pattern — `feat/* → dev → main`

All seven repos follow the SH-029 pattern:

- **Work branches** (`feat/*`, `fix/*`, `chore/*`, `refactor/*`, `docs/*`,
  `test/*`, `ci/*`) → open PR against **`dev`**.
- **Merge into `dev`** is a **merge commit** (no squash), preserving the PR
  boundary in git history. Enforced by `allowed_merge_methods: [merge, squash,
  rebase]` on the `dev` ruleset (merge-commit is the configured default on the
  repo; squash + rebase remain available but are not used for PR-into-dev).
- **Promotion `dev → main`** is a **fast-forward only** operation driven by
  `make ci-release-promote` (SH-029 pattern), run from the `ci-release.yml`
  workflow on `workflow_dispatch`. `main`'s ruleset denies `non_fast_forward`.
- **Forge exception (FG-087):** forge's `ci-release` creates a PR instead of
  direct fast-forward and auto-merges it; the branch protection on `main` still
  requires FF-only, so the auto-merge effectively FFs. Mechanically equivalent;
  the PR gives a visible promotion record.

### 1.3 Branch rulesets

All seven repos have a **`main` ruleset** that enforces:

- `deletion: blocked` (can't delete the branch)
- `non_fast_forward: blocked` (no force-push / history rewrite)
- `required_status_checks` with a single required context (varies per repo,
  see table below)

Six of seven also have a **`dev` ruleset** with a stricter policy:

- Same `deletion` + `non_fast_forward` as `main`
- `pull_request` rule requiring (at minimum) a PR exists — review count is
  **0** across the fleet (solo-maintained repos; the PR is for CI, not review)
- `required_status_checks` (same context as `main`'s ruleset in most repos)

| Repo | `dev` ruleset | `main` ruleset | Required check context | `strict` (up-to-date) | PR required | Extra rules |
|---|---|---|---|---|---|---|
| shepherd | ✅ | ✅ | `gate` | strict ✅ | ✅ (0 reviews) | `require_last_push_approval` off; `dismiss_stale_reviews_on_push` **on**; `review_thread_resolution` required; `extra_approval_for_unattributed_changes` **on** |
| healthy | ✅ | ✅ | `Fast check (lint + traceability)` | lax | ✅ (0 reviews) | — |
| beaconry | ✅ | ✅ | `Detect changes` | lax | ✅ (0 reviews) | — |
| ham-radio-compass | ✅ | ✅ | `lint` | strict ✅ | ✅ (0 reviews) | — |
| homelab | ✅ | ✅ | `Lint` | lax | ✅ (0 reviews) | — |
| kernel-test | ❌ **missing** | ✅ | `lint → programs → ci-test` | lax | ✅ (0 reviews) on main | **gap** — no `dev` ruleset |
| forge | ✅ | ✅ | `Acceptance aggregate (all green)` | lax | ✅ (0 reviews) | — |

**Bypass actors:** none configured on any ruleset. No admins listed as bypass,
no apps granted bypass. Enforcement is `active` on every rule.

**Finding — new:** `kernel-test` has no `dev` ruleset. It's protected only on
`main`. The audit row for kernel-test column 2 passes (both branches exist),
but the ruleset parity check wasn't in the audit's 11 columns. See
*Observations* at the bottom of this doc.

### 1.4 Exceptions worth noting

- **Forge's PR-based release** (FG-087): `ci-release-promote` opens a PR dev →
  main, auto-approves and auto-merges. The `main` ruleset FF-only still holds;
  the PR is a traceable record of the promotion. Documented in forge's
  `memory/design-decisions.md` entry FG-087.
- **Shepherd's dev ruleset stricter than the fleet:** shepherd uniquely enables
  `dismiss_stale_reviews_on_push`, `require_review_thread_resolution`, and
  `require_extra_approval_for_unattributed_changes`. Dogfood: shepherd is the
  fleet brain, so it enforces review thread resolution even with 0 required
  reviewers. The other six repos don't need this.
- **Strict required-checks policy** (`strict_required_status_checks_policy: true`
  — forces a PR to be up-to-date with the base before merging) is on for
  shepherd + HRC only. The other five repos run `strict: false`.

---

## 2. Pipelines (workflow files)

Grouped by tier. All times from `.github/workflows/*.yml` `on:` and
`timeout-minutes:` fields; parsed via yaml.safe_load.

### 2.1 Contract tier — `ci-branch` / `ci-patch` / `ci-release` / `ci-nightly`

The three repos that already ship the native contract filenames are
**shepherd**, **homelab**, **kernel-test** (partial — no `ci-branch.yml`
rename yet; tracked in SH-034 backlog).

| Repo | Filename | `on:` events | `timeout-minutes` | Required by ruleset? |
|---|---|---|---|---|
| shepherd | `ci-branch.yml` | `pull_request`, `workflow_dispatch` | 5 | yes (`gate` aggregates it) |
| shepherd | `ci-patch.yml` | `push`, `workflow_dispatch` | 5 | no |
| shepherd | `ci-release.yml` | `workflow_dispatch` | 15 | no |
| shepherd | `ci-nightly.yml` | `schedule`, `workflow_dispatch` (cron `30 2 * * *`) | 120 | no |
| homelab | `ci-branch.yml` | `push` (dev,main), `pull_request` (dev,main) | — ⚠️ | yes (`Lint`) |
| homelab | `ci-patch.yml` | `push`, `workflow_dispatch` | 5 | no |
| homelab | `ci-release.yml` | `workflow_dispatch` | 15 | no |
| homelab | *(no ci-nightly.yml; weekly-checks.yml covers slow lane)* | | | |
| kernel-test | `ci.yml` *(not renamed)* | `pull_request` | 15 ⚠️ | yes (`lint → programs → ci-test`) |
| kernel-test | `ci-release.yml` | `workflow_dispatch` | 15 | no |
| kernel-test | `ci-nightly.yml` | `schedule`, `workflow_dispatch` (cron `30 2 * * *`) | 120 | no |

**Legacy naming** (healthy, beaconry, HRC, forge) — the Makefile targets are
the contract; filenames keep their historical names.

| Repo | Filename | Serves as tier | `on:` events | `timeout-minutes` |
|---|---|---|---|---|
| healthy | `ci.yml` | ci-branch + ci-patch | `pull_request`, `push` | — ⚠️ |
| healthy | `ci-release.yml` | ci-release | `workflow_dispatch` | 15 |
| healthy | `release.yml` | legacy release (pre-SH-029) | `workflow_dispatch` | — |
| beaconry | `ci.yml` | ci-branch + ci-patch | `pull_request`, `push` | — ⚠️ |
| beaconry | `ci-release.yml` | ci-release | `workflow_dispatch` | 15 |
| beaconry | `release.yml` | legacy release | `workflow_dispatch` | — |
| HRC | `lint.yml` | ci-branch (+ patch via push) | `pull_request`, `push` | — ⚠️ |
| HRC | `release.yml` | ci-release | `workflow_dispatch` | — |
| forge | `ci.yml` | ci-branch (acceptance matrix fans out) | `pull_request`, `push` | 2,3,5,15 (per-step) |
| forge | `ci-release.yml` | ci-release | `workflow_dispatch` | 15 |
| forge | `release.yml` | legacy release | `workflow_dispatch` | 8,10 (per-step) |
| forge | `build.yml` | daily image publish (not a tier) | `schedule`, `workflow_dispatch` (cron `0 3 * * *`) | 3,5,10,16 |
| forge | `nightly.yml` | ci-nightly | `schedule`, `workflow_dispatch` (cron `30 2 * * *`) | 3,50 |

**Finding:** four repos (healthy, beaconry, HRC, homelab's ci-branch) have
**no top-level `timeout-minutes:` on the ci-branch-equivalent job**. The 5-min
budget exists in `dev-cycle-contract.md` but is not mechanically enforced in
the workflow. See *Observations*.

### 2.2 Shepherd caller + gates

Every repo in the fleet (including shepherd itself, for dogfood) has these two
callers:

| Repo | `shepherd.yml` triggers | `shepherd-gates.yml` triggers | Shepherd daily cron (UTC) |
|---|---|---|---|
| shepherd | — *(uses `reusable-shepherd.yml` directly)* | — *(uses `reusable-shepherd-gates.yml`)* | 04:00 (bump), 03:00 (discover), 05:17 (injection-drill) |
| healthy | `schedule`, `workflow_dispatch` | `pull_request`, `workflow_run` | 05:00 |
| beaconry | `schedule`, `workflow_dispatch` | `pull_request`, `workflow_run` | 05:30 |
| ham-radio-compass | `schedule`, `workflow_dispatch` | `pull_request`, `workflow_run` | 06:00 |
| homelab | `schedule`, `workflow_dispatch` | `pull_request`, `workflow_run` | 06:30 |
| kernel-test | `schedule`, `workflow_dispatch` | `pull_request`, `workflow_run` | 07:00 |
| forge | `schedule`, `workflow_dispatch` | `pull_request`, `workflow_run` | 07:30 |

Crons are staggered 30 min apart per repo so a single API-key budget blow-up
can only affect one repo's daily run at a time.

### 2.3 Dependabot + automerge

All six managed repos (not shepherd itself) ship `dependabot-automerge.yml`
with `pull_request` trigger. Kernel-test is the one exception — it has
Dependabot alerts enabled via `.github/dependabot.yml` but no automerge
workflow; its row in the audit is ✅ for column 5 because the dependabot.yml
file exists.

| Repo | `dependabot-automerge.yml` | `.github/dependabot.yml` | opt-in auto_merge |
|---|---|---|---|
| shepherd | — *(bot itself, not managed by itself)* | ✅ | n/a |
| healthy | ✅ | ✅ | false |
| beaconry | ✅ | ✅ | **true** |
| ham-radio-compass | ✅ | ✅ | **true** |
| homelab | ✅ | ✅ | false |
| kernel-test | ❌ *(file missing)* ⚠️ | ✅ | false |
| forge | ✅ | ✅ | false |

**Finding — new:** kernel-test does not have the `dependabot-automerge.yml`
caller even though it has a valid `.github/dependabot.yml`. Patch/minor bumps
will open PRs but will not auto-merge even if the policy allowed it. This
was not caught by the audit's column 5 (which only checks for
`.github/dependabot.yml` presence).

### 2.4 Other workflows

| Repo | Workflow | Purpose | Trigger |
|---|---|---|---|
| shepherd | `bump.yml` | run `shepherd-bump` on cron | `schedule` (04:00 UTC), `workflow_dispatch` |
| shepherd | `discover.yml` | nightly fleet discovery (stub) | `schedule` (03:00 UTC), `workflow_dispatch` |
| shepherd | `digest.yml` | weekly digest to ntfy (stub) | `schedule` (Mon 09:00 UTC), `workflow_dispatch` |
| shepherd | `injection-drill.yml` | replay SH-005 injection drill | `pull_request`, `schedule` (05:17 UTC), `workflow_dispatch` |
| shepherd | `reusable-verify.yml` | reusable build + test + Trivy | `workflow_call` |
| shepherd | `reusable-shepherd.yml` | reusable R0 agent caller | `workflow_call` |
| shepherd | `reusable-shepherd-gates.yml` | reusable SH-009/010 gates caller | `workflow_call` |
| homelab | `cd.yml` | push-triggered Ansible deploy to server | `push` (main) |
| homelab | `weekly-checks.yml` | Thursday Docker-image scan over Tailscale | `schedule` (Thu 06:00 UTC), `workflow_dispatch` |
| ham-radio-compass | `eas-build.yml` | Expo EAS device-build publish | `push`, `workflow_dispatch` |
| forge | `build.yml` | daily image publish (03:00 UTC) | `schedule`, `workflow_dispatch` |
| forge | `nightly.yml` | FG-017 nightly `make check-strict` | `schedule` (02:30 UTC), `workflow_dispatch` |

---

## 3. Make targets (dev-cycle contract)

All seven repos pass `bin/shepherd-bump --verify-contract --root <repo>`:

```
verify-contract: ok (9/9 contract targets present)
```

Recipe inspection, grouped by target. **alias** = identity aliasing to another
target (contract-permitted per `dev-cycle.contract.tiered-make-targets`);
**real** = non-trivial recipe body.

### 3.1 `build`

| Repo | Recipe body | Shape |
|---|---|---|
| shepherd | `$(BUMP)` *(builds `bin/shepherd-bump` Zig binary)* | real |
| healthy | *(Zig build; invoked via `zig build`)* | real |
| beaconry | `; @true` | **no-op** (pure Python repo) |
| ham-radio-compass | `npm run check` *(tsc + lint)* | real |
| homelab | `lint` (alias → Ansible lint) | alias |
| kernel-test | *(builds test programs)* | real |
| forge | *(docker build pipeline)* | real |

### 3.2 `test`

| Repo | Recipe body | Shape |
|---|---|---|
| shepherd | `test-acceptance` | alias |
| healthy | `build` *(then runs test binary via zig)* | real |
| beaconry | *(pytest -q poc/tests)* | real |
| ham-radio-compass | `npm run check` | real (alias to lint+tsc) |
| homelab | *(pytest -q tests/)* | real |
| kernel-test | *(runs `build/<cfg>-<arch>/build.status` matrix)* | real |
| forge | `test-fast` | alias |

### 3.3 `test-affected`

| Repo | Recipe body | Shape | Diff-aware? |
|---|---|---|---|
| shepherd | `test-acceptance` | alias | ⚠️ identity — no app tier |
| healthy | `test` | **identity alias** (3-min full run) | no (documented) |
| beaconry | `test-updates` *(pytest changed-file scope)* | real | ✅ yes |
| ham-radio-compass | `test` | **identity alias** (no module graph) | no (documented) |
| homelab | `test-updates` *(pytest changed-role scope)* | real | ✅ yes |
| kernel-test | `ci-test` *(framework tests only)* | alias | ⚠️ documented (no kernel tree) |
| forge | `scripts/smart-check.sh` | real | ✅ yes (image-dependency graph) |

### 3.4 `smoke`

| Repo | Recipe body | Shape |
|---|---|---|
| shepherd | `test-acceptance` | alias |
| healthy | `test` | alias |
| beaconry | *(pytest -m smoke)* | real |
| ham-radio-compass | `test` | alias |
| homelab | `check` *(Ansible dry-run — operator-only)* | alias |
| kernel-test | *(empty / no-op body in Makefile head)* | no-op |
| forge | `test-fast` | alias |

### 3.5 `release-artifacts`

| Repo | Recipe body | Shape |
|---|---|---|
| shepherd | `build` | alias |
| healthy | `cross` *(cross-compiles all targets)* | real |
| beaconry | `; @true` | no-op |
| ham-radio-compass | *(empty — EAS owns artifacts)* | no-op |
| homelab | `; @true` | no-op |
| kernel-test | `; @true` *(no artifact to promote)* | no-op |
| forge | `build` | alias |

### 3.6 `ci-branch` (budget: 5 min)

| Repo | Recipe body | Dependencies |
|---|---|---|
| shepherd | `ci-timing-init` *(then lint + verify-traceability + test-acceptance)* | real |
| healthy | `lint test cross` | real |
| beaconry | `lint test` | real |
| ham-radio-compass | `build test` | alias chain → `npm run check` twice |
| homelab | `lint-updates test-updates` | real (diff-aware) |
| kernel-test | `lint programs ci-test` | real |
| forge | `lint test-affected` | real (diff-aware via smart-check.sh) |

### 3.7 `ci-patch` (budget: 5 min)

| Repo | Recipe body |
|---|---|
| shepherd | `ci-timing-init` *(then smoke)* |
| healthy | `smoke` |
| beaconry | `smoke` |
| ham-radio-compass | `smoke` |
| homelab | `test-updates` *(no rebuild)* |
| kernel-test | `ci-test` |
| forge | `smoke` |

### 3.8 `ci-release` (budget: 15 min)

All seven repos: `ci-release-promote` (SH-029 FF pattern). Shepherd adds
`ci-timing-init` ahead of the promote step for the JSON emission.

### 3.9 `ci-nightly` (budget: unbounded; 120-min soft cap)

| Repo | Recipe body |
|---|---|
| shepherd | `ci-timing-init` *(then ci-nightly-body)* |
| healthy | `ci-nightly-body` |
| beaconry | `ci-nightly-body` |
| ham-radio-compass | `build test` *(same as ci-branch; prettier check-only)* |
| homelab | `ci-nightly-body` |
| kernel-test | `ci-nightly-body` |
| forge | `ci-nightly-body` *(wraps `make check-strict`)* |

---

## 4. Tests (count + harness)

Test file counts exclude `node_modules`, `venv`, and `OLD` directories.

| Repo | Count | Harness | Notable categories |
|---|---:|---|---|
| shepherd | 13 acceptance + 14 injection payloads/runners | shell (`test_SH_NNN_<slug>.sh` under `test/acceptance/`) | injection drill (SH-005): 12 JSON payloads under `tests/injection/payloads/` driven by `run.sh` + `global_invariants.sh` |
| healthy | 8 acceptance | shell (`test_HC_NNN_<slug>.sh` under `test/acceptance/`) | per-story: HC_001 DD-TGD bootstrap, HC_002 ci-dev-main promotion, HC_003 release pipeline, HC_005 GHCR publish, HC_008 shepherd-poc |
| beaconry | 148 pytest + 1 shell | pytest (`test_BC_NNN_<slug>.py`) | split across `poc/tests/{e2e,integration}` — 1 e2e (BC_011 probe flow), 147 integration (incl. BC_086 auto-fix) |
| ham-radio-compass | **0** | **tsc + lint** (`npm run check`) stands in | no unit-test harness today — HRC's `.shepherd.yml` test command is `make test` which aliases to `npm run check` (documented gap in SH-018) |
| homelab | 127 pytest + 2 shell | pytest (`test_<topic>.py` under `tests/`) + `test_local.sh` + `scripts/test-updates.sh` | infra/role tests: CI workflows, deploy, backups, docker roles, healthcheck, Prometheus, Hetzner, Tailscale, beaconry/healthy sidecars |
| kernel-test | 49 shell (CI harness) + 103 shell (total incl. `tests/ci/`) + 13 `.c` | shell (`test-<slug>.sh` under `tests/ci/`) + C program tests | ci harness (parser, consolidation, metrics), hardware tests, programs (`arena-test`, `perf-event`, `serial-capture`, `snapshot`, `syscall-tests`), namespace tests |
| forge | 84 shell (acceptance 82 + smoke 1 + unit 1) | shell (`test_FG_NNN_<slug>.sh` under `tests/acceptance/`) | image pipelines (python-slim, scratch-trixie, go-source, etc.), per-service smokes (beaconry-hub, prometheus, redis, postgres), CI hardening (FG_038 timeouts, FG_017 smart pre-push, FG_019 scan regression) |

**Harness summary:**

- **Shell-first:** shepherd, healthy, kernel-test, forge (plus homelab for the
  `test-updates.sh` dispatcher).
- **Pytest:** beaconry, homelab (the two Python-heavy repos).
- **TypeScript (tsc + lint only):** ham-radio-compass — there is no Jest/
  Vitest harness today.

**Pass counts** are not grepped per-run on this snapshot (the audit matrix and
baseline cover green %); add a `grep pass= <latest-log>` loop into
`fleet-consistency-audit` runs if you want per-repo green counts in a future
revision.

---

## 5. Time wall — CI budget + measured median

All medians pulled from [`dev-cycle-baseline.md`](dev-cycle-baseline.md) (frozen
2026-11-22T13:43:26Z, 100 most-recent runs per repo, MIN_SAMPLES=10). Rows
under threshold are marked ⚠️ as in the baseline; cells with no sampled run
are `no baseline yet`.

### 5.1 ci-branch (budget: 5 min)

| Repo | Event | n | Median | p90 | Green % | Status |
|---|---|---:|---:|---:|---:|---|
| shepherd | pull_request | 1 ⚠️ | 0.1 | 0.1 | 0 % | too few samples |
| healthy | pull_request | 19 | 3.0 | 3.7 | 89 % | ✅ inside budget |
| healthy | push | 30 | 0.4 | 3.8 | 93 % | ✅ |
| beaconry | pull_request | 15 | 4.0 | 4.2 | 53 % | ✅ just inside; p90 tight |
| beaconry | push | 24 | 0.6 | 4.3 | 87 % | ✅ |
| ham-radio-compass | pull_request | 15 | 0.7 | 27.7 | 86 % | ✅ median; ❌ p90 (EAS?) |
| ham-radio-compass | push | 19 | 0.6 | 0.8 | 100 % | ✅ |
| homelab | pull_request | 17 | 7.1 | 14.7 | 82 % | ❌ over budget |
| homelab | push | 24 | 4.2 | 9.6 | 75 % | ⚠️ p90 over |
| kernel-test | pull_request | 72 | 1.7 | 2.1 | 70 % | ✅ |
| forge | pull_request | 16 | **11.8** | 18.4 | 50 % | ❌ well over budget |
| forge | push | 29 | 1.1 | 13.2 | 93 % | ⚠️ p90 over |

### 5.2 ci-patch (budget: 5 min)

Dedicated `ci-patch.yml` exists only on shepherd + homelab; everywhere else the
patch-tier work runs inside `ci.yml` on the `push` event (rows above).

**No baseline yet** for native `ci-patch.yml` on shepherd or homelab — both
workflows landed in the SH-035/037 renames on 2026-11-22. Expect first samples
after the next feat-merge-to-dev cycle.

### 5.3 ci-release (budget: 15 min)

| Repo | Event | n | Median | p90 | Green % | Status |
|---|---|---:|---:|---:|---:|---|
| shepherd | workflow_dispatch | 0 | — | — | — | no baseline yet |
| healthy | workflow_dispatch | 8 ⚠️ | 1.5 | 2.1 | 62 % | ✅ |
| beaconry | workflow_dispatch | 8 ⚠️ | 0.3 | 1.2 | 87 % | ✅ |
| ham-radio-compass | workflow_dispatch | 14 | 0.3 | 0.7 | 78 % | ✅ |
| homelab | workflow_dispatch | 0 | — | — | — | no baseline yet |
| kernel-test | workflow_dispatch | 0 | — | — | — | no baseline yet |
| forge | workflow_dispatch | 12 | 0.3 | 0.8 | 50 % | ✅ |

### 5.4 ci-nightly (budget: unbounded, 120-min soft cap)

Only shepherd, kernel-test, forge (via `nightly.yml`), and homelab (via
`weekly-checks.yml`) run slow-lane jobs.

| Repo | Workflow | Event | n | Median | p90 | Green % | Status |
|---|---|---|---:|---:|---:|---:|---|
| shepherd | ci-nightly | schedule | 0 | — | — | — | no baseline yet (cron just activated) |
| forge | Nightly check-strict | schedule | 1 ⚠️ | 50.6 | 50.6 | 0 % | ❌ failing + near cap |
| forge | Build — daily publish | schedule | 1 ⚠️ | 22.7 | 22.7 | 100 % | ✅ |
| homelab | *(weekly-checks runs Docker-image scan)* | schedule | 0 | — | — | — | no baseline yet |
| kernel-test | ci-nightly | schedule | 0 | — | — | — | no baseline yet |

**Finding:** forge's nightly `check-strict` is **failing** (0/1 green in the
sample) at ~50 minutes wall clock. Below the 120-min cap but needs attention
— it's the FG-017 safety net for forge's smart-check.sh pre-push.

### 5.5 Shepherd caller + gates

| Repo | Workflow | Event | n | Median | Green % |
|---|---|---|---:|---:|---:|
| shepherd (self) | injection-drill | pull_request | 17 | 0.2 | 100 % |
| shepherd (self) | injection-drill | schedule | 1 ⚠️ | 0.2 | 100 % |
| healthy | shepherd | schedule | 1 ⚠️ | 0.4 | 100 % |
| healthy | shepherd-gates | pull_request | 16 | 0.1 | 93 % |
| healthy | shepherd-gates | workflow_run | 8 ⚠️ | 0.2 | 100 % |
| beaconry | shepherd | schedule | 1 ⚠️ | 0.3 | 100 % |
| beaconry | shepherd-gates | pull_request | 16 | 0.1 | 100 % |
| HRC | shepherd | workflow_dispatch | 10 | 0.7 | 60 % |
| HRC | shepherd-gates | pull_request | 15 | 0.3 | 93 % |
| homelab | shepherd | workflow_dispatch | 3 ⚠️ | 0.5 | 100 % |
| homelab | shepherd-gates | pull_request | 19 | 0.1 | 100 % |
| kernel-test | shepherd | workflow_dispatch | 5 ⚠️ | 0.3 | 100 % |
| kernel-test | shepherd-gates | pull_request | 16 | 0.1 | 100 % |
| forge | shepherd | schedule | 1 ⚠️ | 0.3 | 100 % |
| forge | shepherd-gates | pull_request | 16 | 0.1 | 93 % |

**Shepherd caller typical duration:** 0.3–0.7 min across all six managed
repos. Well inside any budget — it's a status-check wrapper on `shepherd-bump`
+ Trivy, not a build.

**Shepherd-gates caller typical duration:** 0.1 min on `pull_request`, 0.1–0.2
min on `workflow_run`. Essentially free — it reads PR metadata and gate
state, no heavy work.

### 5.6 Budget-vs-actual gaps worth tracking

- **forge ci-branch PR median 11.8 min** vs 5-min budget → 2.4× over.
- **homelab ci-branch PR median 7.1 min** vs 5-min budget → 1.4× over
  (`test-affected` already diff-aware; residual cost is in Ansible dry-run).
- **forge nightly check-strict 50.6 min at 0 % green** — needs the next
  look. Documented in forge's own backlog (FG-017 follow-up).
- **HRC ci-branch p90 27.7 min** — median is fine (0.7 min) but p90 shows an
  outlier mode. Likely EAS build interaction; worth investigating before it
  normalises into the median.

---

## Observations worth promoting to IDEAS

Three items the audit didn't surface, discovered while writing this overview:

1. **kernel-test is missing both a `dev` ruleset and a `dependabot-automerge.yml`.**
   The audit's column 2 checks for branch presence (both exist), not for
   ruleset parity. The audit's column 5 checks for `.github/dependabot.yml`
   presence (it exists), not for the automerge caller. Two one-line follow-ups:
   create the `dev` ruleset matching homelab's shape, and copy the
   automerge workflow from the sibling repos. Candidate SH-039 (dev-ruleset
   fleet parity verifier in `shepherd-bump`).

2. **Four repos have no `timeout-minutes:` on the ci-branch-equivalent job.**
   healthy, beaconry, HRC `lint.yml`, and homelab's `ci-branch.yml` all rely
   on GitHub's default 360-min cap. The dev-cycle contract specifies a 5-min
   budget per tier and `templates/ci-*.yml` includes it, but the audit's
   column 6 (tiered workflow names) didn't check for the `timeout-minutes:`
   field itself. Candidate IDEAS entry: `shepherd-bump --verify-timeouts`
   (or extend `--verify-contract` with a workflow-timeout cross-check).

3. **Forge nightly check-strict at 50.6 min / 0 % green is an untracked
   pager.** The baseline captured 1 sample; the wall clock is close to
   forge's historical 55-min upper bound and the single run failed. This
   isn't a shepherd gap, but it's the kind of thing the SH-020 weekly digest
   should surface once it activates. Candidate IDEAS entry: "weekly digest
   regress check should also open a needs-human on a 0 %-green slow-lane
   workflow, not only on 25 %-regression medians."

Plus one minor:

4. **HRC ci-branch p90 27.7 min** on `pull_request` with 15 samples — median
   0.7 min so the outlier mode is rare but real. Worth a one-sample-deep
   investigation before SH-020's regression detector trains on it as the
   baseline (currently it would).

---

## Appendix — commands used to generate this snapshot

```sh
# Default branch
gh repo view <owner>/<repo> --json defaultBranchRef

# Rulesets
gh api repos/<owner>/<repo>/rulesets
gh api repos/<owner>/<repo>/rulesets/<id>

# Makefile contract verification
bin/shepherd-bump --verify-contract --root <repo>

# Workflow metadata (python yaml.safe_load)
python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/<f>.yml').read()); print(d.get('on'), d.get('name'))"

# Test counts
find <repo>/test <repo>/tests -type f \( -name 'test_*.sh' -o -name 'test-*.sh' -o -name 'test_*.py' \) | wc -l

# Timing baseline
cat docs/specs/dev-cycle-baseline.md
```

Owners:

- `bboortz/*`: shepherd, healthy, beaconry, ham-radio-compass, forge
- `bb-claw/*`: homelab, kernel-test
