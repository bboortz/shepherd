---
id: SH-033
slug: fleet-prepush-convergence
story: docs/stories/SH-033-fleet-prepush-convergence.md
branch: feat/SH-033-verify-prepush
status: shipped
---

# SH-033 plan — Fleet pre-push convergence + `shepherd-bump --verify-prepush`

**Story:** [SH-033](../stories/SH-033-fleet-prepush-convergence.md)

## Design delta

Two deliverables, same pattern as SH-030 (verifier + fleet sweep).

**Part A — verifier + shepherd self-prepush (this PR):**

- `shepherd-bump --verify-prepush --root <repo>` returns:
  - **exit 0** when `.pre-commit-config.yaml` has a hook whose `entry` contains `make check` AND `stages: [pre-push]` is present, OR when `.husky/pre-push` script contains `make check`.
  - **exit 3** when neither config file exists.
  - **exit 4** when a config file exists but `make check` isn't wired at pre-push.
- Opt-out: `.shepherd.yml → dev_cycle.prepush_enforce: false` (section-aware — bare `prepush_enforce: false` under a different block does NOT opt out).
- Shepherd gets its own `.pre-commit-config.yaml` — dogfood.
- `templates/pre-commit-config.yaml.snippet` ships the minimal baseline for managed repos.

**Part B — fleet sweep (follow-up PRs):**

Pre-SH-033 state (`shepherd-bump --verify-prepush` on each fleet repo):

| Repo | State | Action |
|---|---|---|
| shepherd | **new** `.pre-commit-config.yaml` added | Dogfood (this PR) |
| healthy | ok | — |
| beaconry | ok | — |
| forge | ok | — |
| **homelab** | exit 3 (no config) | Sweep PR — add `.pre-commit-config.yaml` |
| **kernel-test** | exit 3 (no config) | Sweep PR — add `.pre-commit-config.yaml` |
| **ham-radio-compass** | exit 3 (no config) | Sweep PR — add `.husky/pre-push` (Node ecosystem) |

Fleet state after sweep: **7/7 pass**.

### Changed files (this PR — Part A)

- `bump.zig` — new `Mode.verify_prepush`, `preCommitHasMakeCheck`, `huskyPrePushHasMakeCheck`, `cmdVerifyPrepush`.
- `.pre-commit-config.yaml` (new) — shepherd's own pre-push gate.
- `templates/pre-commit-config.yaml.snippet` (new) — minimal baseline for managed repos.
- `test/acceptance/test_SH_033_verify_prepush.sh` (new) — 17 assertions, 11 scenarios.
- `docs/specs/CAPABILITIES.md` — new CAP `dev-cycle.prepush.verify`.
- `docs/stories/SH-033-fleet-prepush-convergence.md` → in-progress.
- `docs/plan/SH-033-fleet-prepush-convergence-plan.md` (this file).

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Enforce via `shepherd-bump --verify-contract` as a new target | Different cadence + different opt-out semantics. Separate verifier keeps `.shepherd.yml` field groups orthogonal. |
| Require the exact text `make check` (no wrapper) | Beaconry's existing hook wraps in `bash -c 'source .venv/bin/activate && make check'`. Permissive substring match (`indexOf`) honours real-world configs without compromising the invariant. |
| Reject YAML-less repos (Node-only like HRC) | Husky is the idiomatic Node pre-push mechanism. Verifier accepts `.husky/pre-push` as an equivalent gate. |
| Block `.shepherd.yml` opt-out entirely | Future repos may have truly incompatible constraints (e.g. extremely slow `make check`); keep the escape hatch but require the explicit section. |

## Breaking changes

- No. Verifier is opt-in (new CLI mode). Shepherd self-prepush is net-new; existing contributors who push with `--no-verify` are unaffected.

## Rollout

- [x] Part A — verifier + shepherd self-prepush shipped (this PR).
- [ ] Part B — 3 fleet sweep PRs (HRC husky, homelab pre-commit, kernel-test pre-commit). Tracked in post-merge notes; opened immediately after Part A merges.
- [ ] Future: optionally plumb `--verify-prepush` into the contract-sync rollout + fleet consistency audits.

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Binary present + executable | `test_SH_033_verify_prepush.sh:§0` | ✅ |
| Shepherd itself passes (dogfood) | `test_SH_033_verify_prepush.sh:§1` | ✅ |
| Clean pre-commit config → 0 | `test_SH_033_verify_prepush.sh:§2` | ✅ |
| Wrapped entry (`bash -c '... make check'`) accepted | `test_SH_033_verify_prepush.sh:§3` | ✅ |
| pre-commit without pre-push hook → 4 | `test_SH_033_verify_prepush.sh:§4` | ✅ |
| pre-commit + pre-push but wrong entry → 4 | `test_SH_033_verify_prepush.sh:§5` | ✅ |
| `.husky/pre-push` with `make check` accepted | `test_SH_033_verify_prepush.sh:§6` | ✅ |
| `.husky/pre-push` without `make check` → 4 | `test_SH_033_verify_prepush.sh:§7` | ✅ |
| No config at all → 3 | `test_SH_033_verify_prepush.sh:§8` | ✅ |
| `.shepherd.yml` opt-out honoured inside `dev_cycle:` → 0 | `test_SH_033_verify_prepush.sh:§9` | ✅ |
| Opt-out NOT honoured outside `dev_cycle:` block | `test_SH_033_verify_prepush.sh:§10` | ✅ |
| Bad root → 1 | `test_SH_033_verify_prepush.sh:§11` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Exit paths tested? | Status |
|---|---|---|---|
| `dev-cycle.prepush.verify` | ✅ | ✅ (0 / 1 / 3 / 4) | new, active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Shepherd dogfoods the verifier (own `.pre-commit-config.yaml`) | ✅ |
| Template snippet shipped for managed-repo sweep | ✅ |
| Opt-out field is section-aware (no silent discovery) | ✅ |
| `make check` green on shepherd | ✅ |
| Live fleet smoke: 4/7 pass, 3 pending | ✅ |

## Post-merge notes

- **Fleet sweep PRs** (follow-up, one per repo):
  1. homelab: copy `templates/pre-commit-config.yaml.snippet` → `.pre-commit-config.yaml`; verify locally.
  2. kernel-test: same.
  3. HRC: ship `.husky/pre-push` instead (Node ecosystem).
  Each PR: `chore/sh-033-prepush`, verifier-green before merge.
