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
- `docs/specs/CAPABILITIES.md` — new CAPs + flipped CAPs (part 1 set only).
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

### Part 1 (2026-11-21)

| PR | Repo | What |
|---|---|---|
| [shepherd #11](https://github.com/bboortz/shepherd/pull/11) | shepherd | v0.6.0-rc1 — reusable gates workflow + caller template + gate-diff-size.sh + schema v1 + labels. 31/0 red test. |
| [healthy #20](https://github.com/bboortz/healthy/pull/20) | healthy | Adds gates caller SHA-pinned to shepherd@dc939b6. |

**Canary wiring verified**: on healthy #20 (a human PR with no `shepherd-agent` label), the gates workflow fired and correctly reported `gates: skipping` — the label-filter in the caller workflow works as designed. A labelled test PR + actual auto-merge demonstration lands with SH-009 part 2 along with the beaconry + HRC rollout.

### Part 2 (2026-11-21, same-day as part 1)

| PR | Repo | Result |
|---|---|---|
| [shepherd #13](https://github.com/bboortz/shepherd/pull/13) | shepherd | v0.6.0-rc3: scan-not-worse + needs-human + dry-run + workflow_run |
| shepherd direct commits `fbc68b8` → `b138272` | shepherd | 3 rapid bugfixes on main (rc4/5/6) — see below |
| [healthy #22](https://github.com/bboortz/healthy/pull/22) + [#23](https://github.com/bboortz/healthy/pull/23) | healthy | rc3 gates caller + later re-pin |
| [beaconry #81](https://github.com/bboortz/beaconry/pull/81) | beaconry | First gates caller install |
| [HRC #46/#48/#50/#51](https://github.com/bboortz/ham-radio-compass/pull/51) | HRC | 4 rc-chase re-pins |
| **[HRC #47](https://github.com/bboortz/ham-radio-compass/pull/47) (synthetic canary)** | **HRC** | **AUTO-MERGED by `app/github-actions` (merge commit `d0524d48`)** after rc6 unlocked the immediate-merge path |

### Bug-chase through the rc3→rc6 cycle

Each rc exposed one bug that only a live run could find; the 44/0→45/0 test suite plus the escalation issue #49 proved the paths worked even when they failed:

| rc | Bug | Fix |
|---|---|---|
| rc3 | `workflow_run: [shepherd, "*"]` fired on push events with `pull_requests=[]` → `pr_number=0` → `gh pr view 0` errored | rc4 drop workflow_run from part-1 scope; add PR_NUMBER=0 guard |
| rc4 | HRC's pre-SH-009 `.shepherd.yml` had none of the schema v1 fields; `grep | head | sed` pipeline exited 1 under `set -euo pipefail` | rc5 wrap `grep` in `{ ... || true; }` so defaults apply |
| rc5 | `scan-not-worse.sh` used `<(...)` process substitution with `#!/bin/sh` shebang; Ubuntu's `/bin/sh` is `dash` | rc6 `#!/bin/bash` |
| rc6 | Gates reusable workflow had `contents: read`; when PR is CLEAN, `gh pr merge --auto` performs `mergePullRequest` directly which needs `contents: write` | (final) `contents: write` on the gates workflow |

### Side-proof — escalation path verified end-to-end

The rc4→rc5 interval caught `scan-not-worse.sh`'s dash crash, which the gates workflow's `escalate()` helper correctly converted into [needs-human issue #49 on HRC](https://github.com/bboortz/ham-radio-compass/issues/49). Even though the finding was a false positive, the full chain (gate failure → `open-needs-human.sh` → `gh issue create` with dedupe title) was proven in production. Issue closed after the fix landed.

### SH-009 is complete

All four §12 auto-merge gates are **active on the agent flow**:
- `gate.diff-size` (SH-004 + SH-009)
- `gate.pipelines-green` (SH-009 part 1)
- `gate.scan-not-worse` (SH-009 part 2)
- `gate.security-fix-removes-finding` (SH-009 part 2, strict)

Plus `escalation.needs-human-issue`, `escalation.dedupe`, and `onboarding.dry-run-first` all flipped `design → active`.

### Original part 2 scope (now shipped)

- `gate.scan-not-worse` — new `scripts/shepherd-poc/scan-not-worse.sh` doing Trivy base-vs-PR diff; dedupe by `(package, cve, ghsa_id)`.
- `scripts/shepherd-poc/open-needs-human.sh` — on gate failure, open (or comment on existing) a needs-human issue; dedupe by `(package, cve, gate)`.
- Strict `gate.security-fix-removes-finding` — verify the HIGH/CRITICAL named in the finding is absent from the re-scan.
- `.shepherd.yml → dry_run: true` → `open-pr.sh` posts a comment-only PR summary instead of opening a merging PR. Closes `onboarding.dry-run-first`.
- Caller-side `shepherd-gates.yml` on `bboortz/beaconry` and `bboortz/ham-radio-compass`.
- Live auto-merge canary on HRC: produce a real shepherd-agent PR with 3-line package.json bump, observe all gates pass, PR auto-merges.
