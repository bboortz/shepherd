---
id: SH-028
slug: auto-revert-patch
story: docs/stories/SH-028-auto-revert-patch.md
branch: feat/SH-028-auto-revert-patch
status: shipped
---

# SH-028 plan — Auto-revert on ci-patch failure (opt-in)

**Story:** [SH-028](../stories/SH-028-auto-revert-patch.md)

## Design delta

On `ci-patch` workflow failure, run `scripts/shepherd-poc/auto-revert.sh decide` against `.shepherd.yml` and the diff from the failing SHA. Branch on the decision:

- `SKIP:disabled` — `auto_revert.enabled` is missing or `false`. Loud log, do nothing.
- `SKIP:touches-blocklist` — the revert would touch a §12 blocklist path. Open a needs-human issue; do **not** open the revert PR.
- `REVERT:comment-only` — open the revert PR, leave it for a human to merge.
- `REVERT:auto-merge` — open the revert PR and `gh pr merge --auto`.

Separation of concerns: `decide` is pure (parses config + matches blocklist globs) and testable offline; `execute` side-effects (git revert, push, gh pr create) and is exercised by the healthy canary PR per the shipping evidence table.

### New files

- `scripts/shepherd-poc/auto-revert.sh` (~140 lines sh) — two subcommands: `decide` (pure) and `execute` (side-effecting). `execute` needs `REPO` + `GH_TOKEN` env.
- `test/acceptance/test_SH_028_auto_revert.sh` — 16 assertions, 11 scenarios. Covers SKIP/REVERT branching, blocklist short-circuit, config edge cases, usage errors.

### Changed files

- `.github/workflows/ci-patch.yml` — three new steps after `make ci-patch`, all gated on `failure() && steps.patch.conclusion == 'failure'`:
  1. `Auto-revert decision` — `decide` → stores output in `steps.autorevert_decide.outputs.decision`.
  2. `Auto-revert execute` — fires on `REVERT:*` only; sets git identity, runs `execute`.
  3. `Auto-revert needs-human` — fires on `SKIP:touches-blocklist` only; shells out to `open-needs-human.sh`.
- `docs/specs/CAPABILITIES.md` — CAP `auto-revert.patch-tier` design → active with test pointer.
- `docs/stories/SH-028-auto-revert-patch.md` → shipped.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Single monolithic shell step that does decision + execute | Breaks offline testability — the scan-not-worse pattern (separate decide + execute) is already the house style. |
| Trigger auto-revert from `workflow_run` instead of inline `if: failure()` | Doubles permissions surface (needs `contents: write` in a separate workflow), adds a ~30s cold-start per revert. Inline is simpler and keeps blast radius narrow. |
| Store blocklist glob list only in `validate.sh` | Default list is duplicated between `validate.sh` and `auto-revert.sh`. Acceptable — both reference the same `templates/shepherd.yml` protected-files comment block. If/when the list grows, SH-NNN promotes it to a single source. |
| Auto-revert on `ci-branch` failure | Nothing to revert — the PR is still unmerged. The gate (SH-009) blocks the merge; SH-028 is strictly post-merge. |

## Breaking changes

- No. Opt-in only (`auto_revert.enabled: false` by default). Repos with no `auto_revert` block see `SKIP:disabled` on any ci-patch failure — same as today.
- Managed repos that bump `.shepherd.yml` without adding `auto_revert`: no behavioural change.

## Rollout

- `templates/shepherd.yml` already ships the schema block (SH-014 umbrella: `auto_revert: {enabled: false, comment_only: true}`). No further template edit needed.
- `.github/workflows/ci-patch.yml` lands here. Managed repos re-copy from `templates/ci-patch.yml` on their next contract-sync PR to pick up the new steps — **not** required to opt into auto-revert (the steps are no-ops on `enabled: false`). Fleet-wide contract-sync tracker lives in SH-019.
- Post-merge canary: after merge to `dev`, deliberately push a failing PR to shepherd with `auto_revert.enabled: true` and verify the revert PR opens. Record the run URL in post-merge notes. *(Deferred until SH-029 has flipped shepherd's `.shepherd.yml` to enabled; today shepherd keeps `enabled: false` and SH-028 is unexercised in prod — acceptable.)*

**R2/R3 boundary:** gate for graduation to `active` on fleet repos is the healthy canary. Healthy keeps `enabled: false` until SH-NNN-canary story lands.

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Script executable | `test_SH_028_auto_revert.sh:§0` | ✅ |
| auto_revert absent → `SKIP:disabled` | `test_SH_028_auto_revert.sh:§1` | ✅ |
| `enabled: false` → `SKIP:disabled` | `test_SH_028_auto_revert.sh:§2` | ✅ |
| `enabled: true` + default comment_only → `REVERT:comment-only` | `test_SH_028_auto_revert.sh:§3` | ✅ |
| `enabled: true` + `comment_only: true` → `REVERT:comment-only` | `test_SH_028_auto_revert.sh:§4` | ✅ |
| `enabled: true` + `comment_only: false` → `REVERT:auto-merge` | `test_SH_028_auto_revert.sh:§5` | ✅ |
| Revert touches default blocklist → `SKIP:touches-blocklist` + matched path emitted | `test_SH_028_auto_revert.sh:§6` | ✅ |
| Explicit `blocklist:` overrides default and matches | `test_SH_028_auto_revert.sh:§7` | ✅ |
| Comments in YAML don't confuse parser | `test_SH_028_auto_revert.sh:§8` | ✅ |
| `execute` usage errors (no args / only sha / bogus mode) → exit 3 | `test_SH_028_auto_revert.sh:§9` | ✅ |
| `decide` usage errors (no args / only one arg) → exit 3 | `test_SH_028_auto_revert.sh:§10` | ✅ |
| Unknown subcommand → exit 3 | `test_SH_028_auto_revert.sh:§11` | ✅ |

Workflow-side (not reachable in offline tests — landed with the PR):

| Scenario | Verified by | Status |
|---|---|---|
| Decide step only runs on `patch.conclusion == 'failure'` | Workflow `if:` guard review | ✅ |
| Execute step only runs on `REVERT:*` | Workflow `if:` guard review | ✅ |
| Needs-human step only runs on `SKIP:touches-blocklist` | Workflow `if:` guard review | ✅ |
| Merge-commit revert uses `-m 1` | `auto-revert.sh execute` parent-count branch | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Decision branches tested? | Status |
|---|---|---|---|
| `auto-revert.patch-tier` | ✅ | ✅ (4 branches: SKIP:disabled, SKIP:touches-blocklist, REVERT:comment-only, REVERT:auto-merge) | design → active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story §7 obeyed (no auto-revert on ci-branch; no device rollback; no bisect) | ✅ |
| `.shepherd.yml` schema v1 row in CAPABILITIES includes SH-028 fields | ✅ (already lists `auto_revert.{enabled,comment_only}`) |
| Protected-files invariant intact (blocklist short-circuits auto-revert) | ✅ |
| Budget caps unchanged | ✅ n/a |
| `templates/shepherd.yml` already shipped the schema (SH-014 umbrella) | ✅ |
| `make check` green | ✅ |
| 16/16 acceptance assertions pass | ✅ |

## Post-merge notes

- **R2 canary deferred.** Healthy / shepherd keep `auto_revert.enabled: false` for now. Promotion to `active` on a fleet repo is a separate story (post-R1 soak).
