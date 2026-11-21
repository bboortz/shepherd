# Ideas backlog — shepherd

Not-yet-promoted ideas. New ideas land here immediately, even if we won't pick them up. Promote to `docs/stories/SH-NNN-<slug>.md` when a story is cut.

## Promoted

- **[SH-001](../stories/SH-001-retire-renovate.md) — Retire Renovate; add `shepherd-bump --list` for GitHub Actions.** Status: **shipped** 2026-11-21 (v0.1.0). Scope narrowed to `--list` + Renovate removal. `--check` and `--pr` promoted to SH-002/003 below.
- **[SH-004](../stories/SH-004-r0-poc-on-healthy.md) — Release 0 POC.** Status: **shipped** 2026-11-21. 3 real agent-produced CVE fixes merged on `bboortz/ham-radio-compass`.
- **[SH-005](../stories/SH-005-prompt-injection.md) — Prompt-injection drill.** Status: **shipped** 2026-11-21 (v0.4.0, [PR #8](https://github.com/bboortz/shepherd/pull/8) + HRC [PR #43](https://github.com/bboortz/ham-radio-compass/pull/43)). Replay drill (10 fixtures) + CI gate on shepherd/main + live drill on HRC (`inject_fixture=modify-shepherd-yml` blocked at `validate.sh` — [run 44936144397](https://github.com/bboortz/ham-radio-compass/actions/runs/44936144397)). R0 exit-criterion ⚠️ → ✅. Follow-ups: `fake-fix-benign-looking` guard (R2); pilot resync of `validate.sh` to healthy + beaconry.
- **[SH-006](../stories/SH-006-r1-reusable-action.md) — R1 umbrella.** Status: ready. Decomposes to SH-007 (reusable Action), SH-008 (sandbox perimeter), SH-009 (auto-merge gates), SH-010 (waiting-period). Target ship: Fri 4 Dec 2026 per DESIGN §13.
- **[SH-007](../stories/SH-007-reusable-action.md) — R1-A reusable Action.** Status: **shipped** 2026-11-21 (v0.5.0-rc1, [shepherd #9](https://github.com/bboortz/shepherd/pull/9) + [healthy #18](https://github.com/bboortz/healthy/pull/18)). Also flipped DESIGN §13: `.shepherd.yml` now required (replaces zero-config-default). Canary on healthy ran end-to-end ([run 44938249380](https://github.com/bboortz/healthy/actions/runs/44938249380)). Follow-up: migrate beaconry + HRC; validate the agent-produces-diff path (canary was clean-state).
- **[SH-011](../stories/SH-011-dependabot-enforce-automerge.md) — Dependabot baseline.** Status: **shipped** 2026-11-21 (v0.3.0, PR #2). Enforces `.github/dependabot.yml` on managed repos; opt-in gated auto-merge (patch/minor, ≤50 lines, ≥24h release-age). `gate.scan-not-worse` deferred to SH-009 (documented gap). Rollout to pilots in-progress.

## shepherd-bump — split from SH-001

- **SH-002 — `shepherd-bump --check` (upstream resolution).** Query `GET /repos/{owner}/{repo}/tags`; dereference annotated tags to commit SHAs; pick highest patch within current major; detect orphaned pins (upstream tag force-pushed or deleted) and open a needs-human issue instead of rewriting. Needs HTTP + JSON support in Zig 0.17.1 (`std.Io.net` + `std.json`), or shell-out to `gh api`. Delivers: `bump.stay-within-major`, `bump.orphaned-pin-detection`, the "upstream resolution" half of `bump.gh-actions` / `bump.sha-pin`.
- **SH-003 — `shepherd-bump --pr` (write + open PR).** For each bumpable dep found by `--check`, write a single-line patch, commit on a branch, push, open a PR against `dev`, label `shepherd-bump` + `gh-actions`. Needs `SHEPHERD_BUMP_TOKEN` secret (fine-grained PAT; contents+pull-requests+issues write). Delivers: `bump.open-pr-grouped`.

## Open from DESIGN.md §13

- **Project name for the public release.** Keep *Shepherd* or rename. Decide before R2's README lands.

## shepherd-bump — follow-up ecosystems (after SH-001)

One story per ecosystem. Each extends `shepherd-bump` (Zig single-file budget permitting). Scope per story: discovery, version resolution, PR shape, orphan-pin handling.

- **npm.** `package.json` + `package-lock.json`. Registry: `registry.npmjs.org`. Highest user value for the public launch.
- **pip.** `requirements.txt`, `pyproject.toml`, `Pipfile.lock`. Registry: PyPI simple index.
- **Go modules.** `go.mod`. Registry: Go module proxy.
- **Docker images.** `FROM` lines in `Dockerfile` + Compose refs. Registries: Docker Hub, GHCR. Pin by digest, not tag.
- **Zig.** `build.zig.zon`. Keep internal first; interesting mostly for `healthy`.

## Supply chain — further hardening

- **Replace `aquasecurity/trivy-action` with an inline, sigstore-verified Trivy install.** The binary is fine; the Action wrapper is the vector (CVE-2026-33634). Install via `curl` + `cosign verify-blob` of the sigstore bundle in `reusable-verify.yml`. Alternative: switch scanner to osv-scanner or grype entirely. Needs a story.
- **Lint: refuse mutable action refs.** A gate (`verify-sha-pinned-actions`) that fails CI if any `uses:` line is not a 40-hex SHA. Complement to `shepherd-bump`.

## Dependabot flow — follow-ups from SH-011 rollout

Discovered during the 2026-11-21 rollout on `bboortz/ham-radio-compass` + `bboortz/beaconry` (post-merge notes: `docs/plan/SH-011-dependabot-enforce-automerge-plan.md`).

- **SH-012 candidate — `shepherd-bump --verify-branch-protection`.** `.shepherd.yml` → `dependabot.auto_merge: true` silently fails without branch protection on the base branch (`gh pr merge --auto` rejects with "Protected branch rules not configured"). The v0.3.4 workflow fallback logs the gap but can't fix it; shepherd should verify preconditions before claiming auto-merge is on. Symmetric with `--verify-dependabot` (0/3/4 → 0/5/6: ok / missing protection / protection without required checks). Two non-obvious invariants the verifier must enforce: (a) the required-check context must actually fire on Dependabot PRs (HRC's `Detect changes` wouldn't have worked — had to use `gate`); (b) `required_pull_request_reviews` must be `null` or allow Dependabot bypass, else auto-merge waits for a human. Optional second mode `--ensure-branch-protection` (with `--yes` guard) to `PUT` minimal protection; keep behind a flag because it modifies repo settings.
- **Grouped Dependabot PR title parsing.** Current title regex is `Bump <name> from X.Y.Z to A.B.C`; grouped PRs ship as `Bump <a> and <b>`. The SH-011 workflow classifies them as `unknown` → no auto-merge. Fix: parse `.github/dependabot.yml` `groups:` config, inspect PR body for per-package version pairs, or walk manifest diff files. Small story.
- **0.x.y semver treatment.** SH-011 classifier treats `0.14.1 → 0.17.5` as `minor` (digit equality). Under SemVer 2.0 this is potentially breaking. Consider promoting any `0.x.y → 0.y+.z` change to `major` in the gate — matches ecosystem convention (npm, ruff, zig).
- **Dependabot-recreate-after-config-change nudge.** After a repo first adopts `.github/dependabot.yml`, pre-existing GitHub automated-security PRs are orphaned ("delete the PR so Dependabot can recreate") and Dependabot does not immediately recreate them on close. Need a procedural note in the SH-011 docs or a shepherd helper that re-triggers the security scan.

## Candidates from DESIGN.md §12

- **Scope level 2 (small code changes after an upgrade).** Lands in R2 per §13, but worth a story to pin the guardrails — how to detect that a dep bump broke an API surface, what the retry/escalation ladder looks like.
- **Scope level 3 (general source fixes for security findings).** Same release, higher blast radius — needs its own story with an injection-safety section.
- **Scope level 4 (pipelines / workflows).** Explicitly requires a human-reviewed approval — the story is how the bot even surfaces it as a candidate without being able to touch the files.

## Candidates from DESIGN.md §13 principles

- **Dry-run mode as the first experience.** Folded into SH-006 (R1 umbrella). Deliberately covered by SH-009's `.shepherd.yml` + "first-run comment-only" default. Will migrate to shipped CAP `onboarding.dry-run-first`.
- **Zero-config defaults.** Folded into SH-006 (R1 umbrella) via SH-009's `.shepherd.yml` schema v1.
- **Built-in gateway with network lockdown.** Folded into SH-006 (R1 umbrella) as **SH-008**.
