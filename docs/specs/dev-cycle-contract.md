# Dev-cycle contract — one pipeline model for the fleet

*Authoritative contract for how every shepherd-managed repo exposes build + test
+ release work to CI and to the shepherd verifier. Seeded by SH-014 (umbrella).*

> **Status:** draft (SH-014). Promoted to active when SH-015 (shepherd self-CI
> gate) and SH-016 (shepherd Makefile contract) ship and dogfood the shape.
> **Enforcement:** `shepherd-bump --verify-contract` (SH-017) fails the
> verification step on a managed repo whose Makefile does not expose the
> targets below. HRC catch-up: tracked in SH-018.

## Why

Pipelines today diverge. Healthy fits a 3.0 / 3.7 / 1.5-min tier set already.
Homelab runs the same CI twice per commit. Forge globs 83 tests on every PR.
Beaconry runs 1714 tests with coverage in one serial process. Kernel-Test has
no kernel build in CI. Shepherd has no per-PR gate for its own code.

The fix is one shape, exposed as `make` targets, so (a) every repo looks
identical to the shepherd verifier and to a human arriving cold, and (b) a
future Shepherd scope-level-3 agent can propose Makefile improvements without
touching workflow YAML (which stays on the §12 protected list).

Rationale sources: `docs/stories/SH-014-dev-cycle-umbrella.md §1–3`; two
research briefs (Nov 2026) in the SH-014 plan's "Design delta" appendix.

## The contract — eight `make` targets

Every managed repo exposes these eight targets. Shepherd's own `.shepherd.yml`
schema already points at `build` and `test`; those stay unchanged. The other
six are new. The four `ci-*` targets are tiered by budget; the three agent
entry points (`test-affected`, `smoke`, `release-artifacts`) carry the
build-once-promote mechanic between tiers.

| Target | Role | Budget | Who calls it |
|---|---|---|---|
| `make build` | Build the repo's artifact (binary, image, package, or lint equivalent). Must succeed on a clean runner with no cached state. | — | Shepherd verifier; developer; CI |
| `make test` | Full test suite — lint + types + unit + integration. Already the shepherd verifier's hook. | 5 min | Shepherd verifier; developer; CI |
| `make test-affected` | Only the tests that cover changed code. Each repo aliases to its native idiom: homelab `test-updates`, forge `scripts/smart-check.sh`, shepherd `test-acceptance`. Repos with nothing today alias to `test` (identity — compliant, no speedup) and upgrade in a dedicated SH. | 5 min | `ci-branch` |
| `make smoke` | Quick sanity check against the artifact promoted from `ci-branch`. Runs the service long enough to hit health endpoints or exercises the binary's main code path. **Does not rebuild.** Default alias: `test`. | 2 min | `ci-patch` |
| `make release-artifacts` | Produce the single artifact that gets promoted across tiers — the binary, image, or tarball keyed by commit SHA. Called once in `ci-branch`; `ci-patch` + `ci-release` consume what this emitted. Default alias: `build`. Image repos override to push `sha-<commit>` to a registry. | included in `ci-branch` budget | `ci-branch` |
| `make ci-branch` | Gate for a feature branch / PR. Runs `lint` + `test-affected` + `release-artifacts`. Uploads the artifact keyed by commit SHA for cross-tier promotion. | 5 min wall | `.github/workflows/ci-branch.yml` |
| `make ci-patch` | After merge into `dev` / `main`. Downloads the `ci-branch` artifact, runs `smoke`. **Never calls `build` or `release-artifacts`.** | 5 min wall | `.github/workflows/ci-patch.yml` |
| `make ci-release` | Promote `dev` to `main` and tag. Fast-forward only; publishes images and signatures in parallel. **No new build.** Promote-by-digest (image repos): `docker buildx imagetools create` from `sha-<commit>` to `vX.Y.Z`. | 15 min wall | `.github/workflows/ci-release.yml` (manual `workflow_dispatch`) |
| `make ci-nightly` | Everything slow: full matrices, cold builds, compose and e2e, kernel builds, mutation tests. Opens needs-human issues on failure. | unbounded (target ≤ 2 h) | `.github/workflows/ci-nightly.yml` (cron 02:30 UTC) |

Three design rules make the shape trustworthy:

1. **Budget is a hard cap.** Each workflow job sets `timeout-minutes` to its
   tier budget. A tier that cannot meet it must move work to nightly, not
   raise the cap. Copies Forge FG-038.
2. **Build once, promote.** `release-artifacts` runs once in `ci-branch`;
   the `actions/upload-artifact` step keyed by `sha-<commit>` is the
   contract boundary. `ci-patch` runs `actions/download-artifact` + `smoke`
   — it has no `build` call. `ci-release` promotes the same digest/tarball.
   This is the mechanical enforcement of "never rebuild"; no separate
   `--verify-no-rebuild` verifier is needed.
3. **Trigger discipline — run each commit once.** `ci-branch` runs only on
   `pull_request` (never on `push` for feature branches). `ci-patch` runs
   only on `push` to `dev` or `main`. This prevents the double-run that
   cost Homelab 7.1 min per commit (measured 2026-11-22).

## What stays as it is

- **Branch flow.** `feat/*` → `dev` → `main`. Merge commits into `dev`;
  fast-forward only into `main`. **Not** squash-only. See
  `memory/workflow.md`.
- **Auto-merge.** Per-repo opt-in via `.shepherd.yml`
  (`auto_merge.{patch,minor,major}`). The §12 gates still gate every merge.
- **No third-party Actions in the critical path** (SH-001). All `uses:` lines
  in workflow templates are SHA-pinned to `actions/*` or shepherd-first-party.
- **Merge queue:** not adopted. Public shepherd/healthy/beaconry are
  `bboortz` personal repos; merge queue needs an org. One shepherd agent at a
  time does not need one.
- **Self-hosted runner policy:** `server2` stays limited to the private
  `bb-claw/homelab` Lint job it already runs. No expansion.

## Timing instrumentation

Every `ci-*` target emits `build/ci-timing.json` (schema:
[`ci-timing.md`](ci-timing.md)). The workflow uploads it as an artifact. A
future digest step (SH-020) flags any tier that exceeds its budget or grows
25 % over its median and opens a needs-human issue naming the slowest step.

## Protected files

`templates/Makefile.contract.snippet` and `templates/ci-*.yml` are shipped
INTO managed repos by onboarding. A silent edit to these baselines would
propagate through every new onboarding, so they live on the §12 protected
list from 2026-11-22 forward:

```
templates/**
```

The `templates/` entry is enforced by the agent sandbox and by the
injection-drill (fixture to land with SH-016 implementation). The regular
developer workflow (humans editing `templates/` in a PR) is unaffected.

## Relationship to other SH

- **SH-008** (sandbox perimeter + budget caps): budget there is € per
  Anthropic API call. Budget here is wall-clock seconds per tier. Different
  axes; independent tracks.
- **SH-001** (no third-party Actions): the workflow templates in this spec
  SHA-pin `actions/*` only, same as `templates/caller-shepherd.yml`.
- **SH-011** (`.github/dependabot.yml` enforcement): `--verify-dependabot`
  gives the pattern `--verify-contract` (SH-017) follows — same exit-code
  shape, same needs-human escalation, same opt-out shape in `.shepherd.yml`.
- **SH-013** (`make verify-traceability`): the SH-014 CAPs are listed in
  `docs/specs/CAPABILITIES.md` under "Dev cycle (SH-014)" and traced to
  their sub-story acceptance tests as they land.
- **SH-027 (risk-paths)**: distinct from §12 blocklist. Blocklist =
  "agent cannot write". Risk-paths = "agent CAN write but a human MUST
  approve before auto-merge". `.shepherd.yml → risk_paths: [glob, ...]`.
- **SH-028 (auto-revert)**: narrow pre-merge gates + broad post-merge
  backstop. On `ci-patch` failure, opt-in automatic revert PR.
- **SH-026 (baseline capture)**: one-shot `scripts/measure-baseline.sh`
  freezes `gh run list` medians to `docs/specs/dev-cycle-baseline.md`
  BEFORE per-repo speed-up stories ship. Lets Shipping evidence tables
  claim measured deltas, not estimates.

## Per-repo adoption (summary — one sub-story per repo)

- **Healthy (SH-025).** Already fits all three budgets. Rename existing tiers
  to `ci-*`; use as reference implementation.
- **Homelab (SH-021).** Stop the double run (push + PR). Move Lint off the
  `server2` self-hosted runner. Already measured: median 4.1 min on dev, 7.1
  min on PRs; 20–29 min queue spikes come from single-runner contention.
- **Forge (SH-022).** Affected-only test matrix in `ci-branch` (reuse
  existing `scripts/affected_images.py` and `smart-check.sh` logic). Full
  83-test matrix moves to `ci-nightly`.
- **Beaconry (SH-023).** Add `pytest-xdist`; split `make check` into
  `check-fast` (lint, types, unit, verify scripts) and keep integration
  markers in `ci-nightly`.
- **Kernel-Test (SH-024).** Add `ci-nightly` with tinyconfig x86_64 smoke
  build (`ccache`-warmed) + QEMU boot. `ci-branch` stays framework-only.
- **Shepherd (SH-015 + SH-016).** Dogfood: add `ci-branch.yml` that runs
  `make check` on every PR to `main`. Add `ci-*` Makefile targets.
- **HRC (SH-018).** Catch-up investigation: assess current state vs.
  contract, produce migration PRs. Not deferred — tracked.

## Not in scope

- macOS / Windows runners (DESIGN §13 "Linux first").
- Forges besides GitHub.
- Dagger / Earthly as the pipeline runtime. Keep plain `make` + workflow
  YAML; Dagger is a future candidate when Forge's pipeline complexity
  justifies it (candidate for `docs/plan/IDEAS.md`).
- GitHub merge queue adoption (needs org repo; not applicable to `bboortz`).
- `squash`-only merges (contradicts shepherd's `feat → dev → main`
  merge-commit flow, which SH-009's auto-merge path depends on).
- Device-side pipelines (post-R3 scope per DESIGN §13).

## Open questions (tracked in `docs/plan/IDEAS.md`)

- Affected-only logic in `ci-branch`: how does each repo detect "changed
  files"? Shepherd's own `make test` runs the full acceptance suite today
  (small enough). Forge has `scripts/affected_images.py`. Homelab needs a
  path-to-host mapping. Beaconry's Python-side solution (if any) TBD.
- Timing-digest consumption shape: does SH-020 feed into the existing
  (stubbed) weekly `digest.yml` or open an issue per regression? Deferred to
  the SH-020 plan.
