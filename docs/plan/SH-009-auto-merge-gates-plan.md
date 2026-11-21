---
id: SH-009
slug: auto-merge-gates
story: docs/stories/SH-009-auto-merge-gates.md
branch: feat/SH-009-auto-merge-gates
status: in-progress
---

# SH-009 plan — R1-C: auto-merge gates + schema v1

**Story:** [SH-009](../stories/SH-009-auto-merge-gates.md). Umbrella: [SH-006](../stories/SH-006-r1-reusable-action.md).

## Design delta

### Phased split

| Chunk | Contents | Target |
|---|---|---|
| **Part 1** | Schema v1, validate.sh refactor, open-pr.sh labels, reusable-shepherd-gates.yml (3 of 4 gates), caller template, red test, canary rollout on `healthy` | This session |
| **Part 2** | `gate.scan-not-worse`, needs-human issue dedupe, dry-run, beaconry + HRC rollout, live auto-merge canary on HRC | Follow-up ship |

### New files (Part 1)

- `.github/workflows/reusable-shepherd-gates.yml` — reusable workflow (`on: workflow_call`). Triggered by caller on `pull_request` + `workflow_run`.
- `templates/caller-shepherd-gates.yml` — caller workflow dropped into managed repos (≤ 25 lines).
- `scripts/shepherd-poc/gate-diff-size.sh` — extracted non-lockfile line-counting function. Called by the gates workflow directly; also by validate.sh.
- `test/acceptance/test_SH_009_gates.sh` — shape assertions + reusable-counter behaviour.

### Modified files (Part 1)

- `templates/shepherd.yml` — schema v1 fields (schema_version, monitored_pipelines, max_diff_lines, rescan_scope, dry_run, needs_human_label). Existing `auto_merge` block kept; just formalised.
- `scripts/shepherd-poc/validate.sh` — refactored to source and use `gate-diff-size.sh`'s function. Exit-code semantics unchanged (0/2/3).
- `scripts/shepherd-poc/open-pr.sh` — add `--label shepherd-agent` always; add `--label shepherd-security-fix` when `FINDINGS_PATH` contains at least one HIGH/CRITICAL (capture via a small `jq` before the `gh pr create` call).
- `docs/CAPABILITIES.md` — new CAPs + flipped CAPs (part 1 set only).
- `CHANGELOG.md` + `VERSION` — v0.5.0-rc2 → v0.6.0-rc1.

### Deferred to Part 2

- `scripts/shepherd-poc/scan-not-worse.sh` — Trivy base-vs-PR diff + GHSA-ID-hash dedupe.
- `scripts/shepherd-poc/open-needs-human.sh` — issue dedupe + open/comment.
- `.shepherd.yml → dry_run: true` plumbing in `open-pr.sh` (comment-only path).
- Caller-side rollouts to beaconry + HRC.
- Live auto-merge canary.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Gate workflow runs inside the agent flow (reuse reusable-shepherd.yml) | The PR's own CI hasn't run yet at that point. `gate.pipelines-green` is impossible. Clean separation: agent flow opens PR; gates workflow evaluates PR. |
| `pull_request_target` trigger | Grants more permissions but reopens forked-PR attack surface. Shepherd-agent PRs are same-repo (not forks), so `pull_request` with `permissions:` works fine and is tighter. |
| Gates in the shepherd repo (not reusable) | Then every pilot would need to call shepherd from their PR context — fine for us, but the uses-cross-repo-workflow-call chain gets more complex. Reusable workflow is the standard. |
| One workflow with inline gate functions (no separate scripts) | Inline bash in YAML is harder to test. SH-005's existing fixture library pattern uses `scripts/shepherd-poc/*.sh`; staying consistent. |
| Composite action | Can't declare `secrets: X: required: true`. Would need plaintext inputs — worse hygiene. |
| Enforce gates via branch protection "require status checks" | Doesn't let shepherd *choose* to merge; just stops you merging manually. The point of gates is active auto-merge after they pass. |

## Breaking changes

- [ ] No for Part 1 — strictly additive. `.shepherd.yml` fields are optional with sensible defaults; existing managed repos continue to work.
- [ ] Part 2 will add the needs-human issue behaviour, which is additive but visible.

## Rollout

Part 1:

- [ ] `make check` green locally.
- [ ] CI green on the shepherd PR (including SH-005 injection drill).
- [ ] v0.6.0-rc1 tagged.
- [ ] `bboortz/healthy` adopts `templates/caller-shepherd-gates.yml` as `.github/workflows/shepherd-gates.yml`. SHA-pinned to the v0.6.0-rc1 shepherd commit.
- [ ] Test: open a hand-crafted PR on healthy with `shepherd-agent` label, 3 non-lockfile lines → observe gates workflow fire, enable auto-merge via `gh pr merge --auto --merge`, and (with healthy's branch protection in place) auto-merge once CI green.

Part 2 (follow-up ship): scan-not-worse, needs-human, dry-run, beaconry + HRC rollout.

## Shipping evidence (Part 1)

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| templates/shepherd.yml carries schema v1 | `test/acceptance/test_SH_009_gates.sh` (sc1) | TBD |
| gates reusable workflow shape | `test/acceptance/test_SH_009_gates.sh` (sc2) | TBD |
| caller template shape | `test/acceptance/test_SH_009_gates.sh` (sc3) | TBD |
| open-pr.sh applies shepherd-agent label | `test/acceptance/test_SH_009_gates.sh` (sc4) | TBD |
| validate.sh exposes a reusable counter | `test/acceptance/test_SH_009_gates.sh` (sc5) | TBD |
| **Canary end-to-end on healthy** | Live `gh pr` dispatch | TBD |

### Lens 2 — CAP evidence

| CAP | ≥1 fixture? | Status |
|---|---|---|
| `gate.pipelines-green` | gates workflow | TBD |
| `gate.diff-size` (extension) | validate.sh + gate-diff-size.sh | TBD |
| `gate.security-fix-removes-finding` (partial) | gates workflow label check | TBD |
| `auto-merge.opt-in-per-repo` | schema v1 opt-in gate | TBD |
| `config.schema-v1` | templates/shepherd.yml fields | TBD |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys §7 (no scan-not-worse / needs-human / dry-run in part 1) | TBD |
| New CAPs listed in §9 part-1 all appear in CAPABILITIES.md | TBD |
| SHA-pinned every `uses:` in both reusable workflow and caller template (SH-001) | TBD |
| `make check` green | TBD |
| `make injection-drill` still green (no SH-005 regression) | TBD |

## Post-merge notes

<Filled after part-1 PR merges and the healthy canary fires a test PR through the gates.>
