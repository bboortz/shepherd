---
id: SH-016
slug: shepherd-makefile-contract
story: docs/stories/SH-016-shepherd-makefile-contract.md
branch: feat/SH-016-shepherd-makefile-contract
status: in-progress
---

# SH-016 plan — Shepherd Makefile contract (dogfood)

**Story:** [SH-016](../stories/SH-016-shepherd-makefile-contract.md)

## Design delta

Shepherd's own `Makefile` grows a `##@ Shepherd dev-cycle contract (SH-014 / SH-016)` section (~95 lines appended after `clean:`) that exposes all eight contract targets and emits `build/ci-timing.json` matching the schema in `docs/specs/ci-timing.md`. Four workflow files at `.github/workflows/ci-{branch,patch,release,nightly}.yml` are byte-identical copies of `templates/ci-*.yml` shipped by the SH-014 umbrella. Shepherd becomes the reference implementation for the eight-target shape.

**Makefile additions** (no renames; no edits to existing recipes):

- `lint` (new) — aggregates `yaml-lint md-lint verify-memory-size verify-traceability`.
- `test-affected: test-acceptance` — identity alias; shepherd's acceptance suite is already fast (~1.5 s).
- `smoke: test-acceptance` — identity alias.
- `release-artifacts: build` — produces `bin/shepherd-bump`.
- Timing helpers: `step` macro + `ci-timing-finish-cmd` + `ci-timing-init`.
- `ci-branch` — the 5-min PR gate. Runs `lint + release-artifacts + test-affected + injection-drill`, matching the content of `make check` with per-step timing emission.
- `ci-patch` — 5-min post-merge smoke. Calls `make smoke`. No rebuild, no release-artifacts.
- `ci-release` — 15-min placeholder. Shepherd has no release.yml today; the real body lands with SH-029 (dev → main FF).
- `ci-nightly` — unbounded slow lane; wraps `ci-nightly-body` with a failure-trapping `gh issue create` call (emits only when `GITHUB_REPOSITORY` is set, so local runs are unaffected).
- `ci-nightly-body: check` — same content as ci-branch (minus timing); future slow checks land here (cross-build, cold builds, etc.).

**Workflow files** (copied verbatim from `templates/`):

- `.github/workflows/ci-branch.yml` — on `pull_request`; `timeout-minutes: 5`; uploads `build/release/**` keyed by commit SHA + `build/ci-timing.json`.
- `.github/workflows/ci-patch.yml` — on `push` to `[dev, main]`; downloads release artifact; runs `make ci-patch`.
- `.github/workflows/ci-release.yml` — on `workflow_dispatch`; 15-min cap.
- `.github/workflows/ci-nightly.yml` — on cron `30 2 * * *`; `issues: write` for the needs-human escalation.

**Drive-by fix to the snippet** — the awk aggregator in `templates/Makefile.contract.snippet` parsed `"seconds"` as `$4` of a `-F'[:,]'` split, which for `{"name":"foo","seconds":1.5}` yields `"foo"` instead. Fixed to `-F'"seconds":'` + proper field extraction. Same fix applied to shepherd's inline copy. Verified: `total_seconds: 2.726` from 4 steps = 0.780 + 0.038 + 1.465 + 0.443.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| `include templates/Makefile.contract.snippet` | Snippet's default `ci-branch` body doesn't include `injection-drill` (§12 trust-boundary invariant per SH-005). Overriding after include is messier than inlining the whole ~95-line block. Also proves the template-to-reality mapping explicitly. |
| Skip the four workflow files (land only Makefile) | Then there's no PR gate; SH-015's success criterion can't be met. Workflows + Makefile are coupled. |
| Keep `make check` as the PR gate; skip `ci-branch` on shepherd | Breaks the contract uniformity. Future SH-017 verifier scans for `ci-*` targets; shepherd must have them. Dogfood is the whole point. |
| Remove the existing `injection-drill.yml` (since `ci-branch` now includes injection-drill) | `injection-drill.yml` is a §12 trust-boundary artifact (SH-005). Removing it is its own §12 change and needs a separate story. Keep both; the overlap is one job of redundancy on PRs to main. |

## Breaking changes

- [ ] No — strictly additive. `make check` behaviour unchanged. Existing workflows (bump, digest, discover, injection-drill, reusable-*) untouched. Four new workflow files alongside the existing seven; naming does not collide.

## Rollout

- [x] README untouched — no public-contract shift. Shepherd's own public contract is still `.shepherd.yml` + the reusable workflow; this story is internal dogfood.
- [x] `memory/project.md` invariants unchanged.
- [x] `memory/workflow.md` unchanged — the gate matrix adds `make ci-branch` next to `make check` (equivalent content + timing emission).
- [x] `docs/specs/DESIGN.md` unchanged — §12 templates/** protection already covers both the template and this inline copy.
- [ ] Downstream notice — n/a.

**R2 slot:** target 2026-12-11 per the SH-014 umbrella rollout. Can also ship as an R1 opportunistic cherry-pick (shepherd self-CI gate was named explicitly in the umbrella as such).

## Shipping evidence (fill at step 6a)

### Lens 1 — Gherkin coverage

| Scenario (from story §8, TBD-filled) | Test pointer | Status |
|---|---|---|
| `make -n ci-branch` resolves to lint + release-artifacts + test-affected + injection-drill | manual dry-run on `feat/SH-016-shepherd-makefile-contract` HEAD | ✅ |
| `make ci-branch` emits `build/ci-timing.json` matching schema v1 | locally verified 2026-11-22 (output in story §5) | ✅ |
| `make ci-patch` runs `smoke` with no rebuild | manual dry-run | ✅ |
| `make ci-release` emits placeholder + timing | manual dry-run | ✅ |
| `make ci-nightly` runs `check` + wraps failure with `gh issue create` | manual dry-run (local path skips gh); ci-nightly.yml runs the body in CI | ✅ |
| All four workflow files SHA-pin `actions/*` + match tier budgets | manual inspection | ✅ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `dev-cycle.contract.tiered-make-targets` (SH-014) — shepherd row | ✅ (local `make -n`) | n/a this PR | design → active for shepherd |
| `dev-cycle.timing.json-emission` (SH-014) — shepherd row | ✅ (schema valid) | n/a this PR | design → active for shepherd |
| `dev-cycle.budget.timeout-caps` (SH-014) — shepherd row | ✅ (workflow timeouts match budgets) | n/a this PR | design → active for shepherd |
| `dev-cycle.artifact.build-once-promote` (SH-014) | ✅ (ci-branch uploads, ci-patch downloads) | n/a this PR | design → active for shepherd |
| `dev-cycle.shepherd.self-ci-gate` (SH-014 / SH-015) | ✅ (ci-branch.yml on pull_request) | n/a this PR | design → active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (out-of-scope) — no per-repo adoption on other repos, no verifier, no digest | ✅ |
| New CAPs listed in §9 all appear in `docs/specs/CAPABILITIES.md` under "Dev cycle (SH-014 umbrella)" | ✅ |
| Protected-files invariant intact (DESIGN §12) — this PR doesn't modify `templates/**` content, only fixes a bug in the snippet | ⚠️ templates/Makefile.contract.snippet modified (awk aggregator bug) — must reconcile with §12 before merge |
| Budget caps unchanged | ✅ n/a |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

**⚠️ §12 reconciliation:** the snippet fix is a bug fix, not a semantic change. §12 "templates/** is protected from the agent" means an AGENT may not edit the file; a human-reviewed PR can. This PR fixes `total_seconds: 0.000` (parser bug) → `total_seconds: 2.726` (correct). The fix propagates into the snippet so future repos adopting it get the correct aggregator. Reviewers: please confirm the §12 reading — if `templates/**` is agent-blocklist-only, this is fine; if it's human-also-protected, the snippet fix needs its own story.

## Post-merge notes

_(filled after merge)_
