# Changelog

All notable changes to `shepherd` are recorded here. The format is based on
[Keep a Changelog](https://keepachangelog.com/) and this project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

Next: SH-009 **part 2** (scan-not-worse + needs-human + dry-run + beaconry/HRC rollout + live canary) + SH-008 (sandbox perimeter) + SH-010 (waiting-period on agent flow). See [`docs/DESIGN.md §13`](docs/DESIGN.md).

## [v0.6.0-rc1] — 2026-11-21 — SH-009 part 1: auto-merge gates + schema v1

**R1-C part 1 ships: three of four §12 gates + `.shepherd.yml` schema v1.** The missing fourth gate (`scan-not-worse`) + needs-human issue dedupe + dry-run + full fleet rollout + live auto-merge canary ship as **SH-009 part 2** in a follow-up PR.

### Added

- `.github/workflows/reusable-shepherd-gates.yml` — reusable workflow (`on: workflow_call`) evaluating:
  - `gate.diff-size` — non-lockfile line count ≤ `gates.max_diff_lines` (default 50).
  - `gate.pipelines-green` — every monitored required-check must be `SUCCESS` / `NEUTRAL` / `SKIPPED`. Default `monitored_pipelines: all`; explicit allowlist supported.
  - `gate.security-fix-removes-finding` (**partial — label-trust**; strict check in part 2).
  - Enables `gh pr merge --auto --merge` when all pass + `.shepherd.yml` opts into the semver level. Falls back to "leave open" with `::notice::` reason.
- `templates/caller-shepherd-gates.yml` — 23-line drop-in for managed repos. Triggers on `pull_request` (label-filtered) + `workflow_run` (re-fires on CI completion).
- `scripts/shepherd-poc/gate-diff-size.sh` — standalone non-lockfile line counter. Sole owner of `LOCKFILE_RE`; used by both `validate.sh` (R0 path) and the gates workflow (SH-009 path).
- `test/acceptance/test_SH_009_gates.sh` — 31 assertions covering schema, workflow shape, caller template, label logic, counter behaviour, size-cap regression.
- `docs/stories/SH-009-auto-merge-gates.md` + `docs/plan/SH-009-auto-merge-gates-plan.md`.

### Changed

- `templates/shepherd.yml` — schema v1: `schema_version: 1`, new `gates.{monitored_pipelines, max_diff_lines, rescan_scope}`, `dry_run`, `needs_human_label`. Existing `auto_merge.{patch,minor,major}` kept; now formally part of schema v1.
- `scripts/shepherd-poc/validate.sh` — refactored to delegate line counting to `gate-diff-size.sh`. **R0 contract unchanged** — exit codes 0/2/3 identical, byte-for-byte compatible stderr.
- `scripts/shepherd-poc/open-pr.sh` — always applies `shepherd-agent` label; applies `shepherd-security-fix` label when `FINDINGS_PATH` contains at least one HIGH/CRITICAL vuln. Auto-creates labels if missing; tolerates failure.
- 5 CAPs flipped `design → active` in `docs/CAPABILITIES.md`:
  - `gate.pipelines-green`
  - `gate.security-fix-removes-finding` (partial — label-trust)
  - `auto-merge.opt-in-per-repo`
  - `auto-merge.risk.low` / `.medium` / `.high`
- 1 new CAP: `config.schema-v1`.

### Deferred to SH-009 part 2

- `gate.scan-not-worse` — Trivy base-vs-PR diff.
- `escalation.needs-human-issue` + `escalation.dedupe` — auto-opened issue per gate failure.
- `onboarding.dry-run-first` — `.shepherd.yml → dry_run: true` → comment-only PR path.
- Beaconry + HRC caller rollout; live auto-merge canary on HRC.

### Not breaking

Strictly additive. Managed repos with the pre-SH-009 `.shepherd.yml` continue to work unchanged — the new `gates`/`dry_run`/`needs_human_label` fields are all optional with sensible defaults.

## [v0.5.0-rc2] — 2026-11-21 — SH-007 Trivy scan widened

**Bug surfaced on `bboortz/homelab` cross-check:** Trivy was only picking up files named exactly `requirements.txt`, skipping `requirements-dev.txt` / `requirements-ui-test.txt` / etc. by name — a silent blind spot for any Python repo that splits dev / test / ui requirements into separate files. Fixed by adding `--file-patterns` to the Trivy invocation in the reusable workflow.

### Changed

- `.github/workflows/reusable-shepherd.yml` Trivy step now passes:
  - `--file-patterns 'pip:requirements.*\.txt$'` — additive to the built-in pip detector. Now scans `requirements-dev.txt`, `requirements-ui-test.txt`, etc. All other ecosystems (npm, Cargo, go.mod, Dockerfile, …) keep their built-in patterns — they are **not** replaced.
  - `--include-deprecated-checks` — widens coverage to historical / deprecated vuln + misconfig rule entries.
- `test/acceptance/test_SH_007_reusable.sh` extended to assert both flags are present (now 22/0).

### Known remaining gap

Trivy's pip analyzer still drops `requirements.txt` files that use only loose version constraints (`package>=X.Y`, wildcards like `==21.*`) because there's no concrete version to look up. Fix is **source-side** — use `pip-compile` (`pip-tools`) to generate fully-pinned lockfiles from `.in` files. Parked as an IDEAS entry: "pip-compile-or-fail enforcement" (R2 territory — treat loose-pin files as a needs-human issue because shepherd can't gate what it can't scan).

### Zig coverage gap (unchanged, noted)

Trivy has no Zig analyzer today. `bboortz/shepherd` and `bboortz/healthy` have no vuln-scan coverage for Zig deps. Mitigation: Zig deps on the fleet are few and `build.zig.zon`-hashed. Tracked as an IDEAS entry for R2+ consideration.

## [v0.5.0-rc1] — 2026-11-21 — SH-007 R1-A: reusable shepherd Action

**R1-A ships: shepherd as a reusable workflow.** Managed repos drop in a thin caller + `.shepherd.yml` + one secret. Scripts no longer live in each pilot.

### Added

- `.github/workflows/reusable-shepherd.yml` — reusable workflow (`on: workflow_call`). Required secret: `ANTHROPIC_API_KEY`. Checks out the caller + shepherd scripts (second checkout pinned to the invoking commit via `github.job_workflow_sha`), then runs the trusted-step chain: verify-shepherd-yml → install-trivy → scan → agent → validate → setup-node → regen-lockfile → validate-combined → open-pr.
- `templates/caller-shepherd.yml` — thin caller (16 lines) that managed repos drop into `.github/workflows/shepherd.yml`. Explicit `secrets: {ANTHROPIC_API_KEY: ...}` (tighter audit than `secrets: inherit`). SHA-pinning is `@main` in rc1; R1 release ships a tagged ref.
- `scripts/shepherd-poc/verify-shepherd-yml.sh` — new gate. Exits 1 with a GitHub Actions `::error::` annotation if the caller has no `.shepherd.yml` at the repo root. Part of the SH-007 required-config decision.
- `test/acceptance/test_SH_007_reusable.sh` — 20 assertions covering reusable workflow shape, caller template shape + size, verify-shepherd-yml behaviour, DESIGN §13 language alignment.
- `docs/stories/SH-007-reusable-action.md` + `docs/plan/SH-007-reusable-action-plan.md`.
- 4 CAPs: `r1.reusable-action` (new, active), `onboarding.one-workflow` (aspirational → active), `onboarding.default-github-token` (aspirational → active), `config.required-per-repo` (new, active).

### Changed — DESIGN §13 (2026-11-21 decision)

- R1 scope line: "Optional `.shepherd.yml`" → **"Required `.shepherd.yml`"**. The reusable Action verifies presence and fails fast.
- Onboarding principle: "Zero config by default. The config file is optional…" → **"Required config, templated"**. `templates/shepherd.yml` is the copyable baseline; the 15-min setup budget now covers one caller workflow + one `.shepherd.yml`.
- Sharp pitch updated: "One workflow file + one config, one secret, 15 minutes."
- New "Decided on 2026-11-21" entry naming the flip + rationale (explicit beats magic / auditable at repo boundary / symmetric with SH-011).

### Deprecated

- CAP `onboarding.zero-config-default` → `deprecated`. Replaced by `config.required-per-repo`. Rationale in DESIGN §13 "Decided on 2026-11-21".

### Breaking

- Managed repos **must** ship `.shepherd.yml`. All three R0 pilots already have one (post-SH-011); future pilots copy from `templates/shepherd.yml`. The reusable Action exits 1 with a clear annotation + link if it's missing.

### Pending (follow-up ship, not in rc1)

- Canary migration PR on `bboortz/healthy` (replace `shepherd-poc.yml` with the thin caller; delete `scripts/shepherd-poc/`). Live `workflow_dispatch` recorded in SH-007 plan's post-merge notes.
- Migration of `beaconry` + `ham-radio-compass` to the reusable Action — follow-up ship after the healthy canary produces a successful live run.
- `v1.0.0` tag: ships after SH-008/009/010 complete R1.

## [v0.4.0] — 2026-11-21 — SH-005 prompt-injection drill

**Replayable, offline injection drill on `bboortz/shepherd` itself.** Blocks merge on any regression in the trust boundary. Part of the R0 exit-criterion closure.

### Added

- `scripts/shepherd-poc/` — imported from `bboortz/ham-radio-compass` (`agent-call.sh`, `validate.sh`, `open-pr.sh`, `regen-lockfile.sh`, `install-trivy.sh`, `README.md`). Shepherd is now the source of truth for these; pilots pull from here going forward.
- `scripts/shepherd-poc/agent-call.sh` gains a `--replay <fixture>` mode that skips the Anthropic API call and writes the fixture's `canned_agent_response` to `$DIFF_PATH`. No network, no `ANTHROPIC_API_KEY` required. Live-mode behaviour on non-`--replay` paths unchanged.
- `tests/injection/payloads/` — 12 adversarial fixture JSON files (10 replay + 2 live-API + 1 known R2-scope gap). Attacker-goal categories: protected-file write, secret exfil in diff, URL exfil, oversize diff, model-identity escalation, injection-in-manifest, newline smuggling, file-creation into protected path, delete-shepherd-poc.
- `tests/injection/run.sh` — drill harness. Replays each fixture through `agent-call.sh --replay` + `validate.sh` in isolated scratch worktrees. Drill-side scans (`secret_scan`, `url_exfil_scan`) cover content that passes the path gate. Asserts per-fixture expected gate + log substring.
- `tests/injection/global_invariants.sh` — post-run audit: scratch dirs cleaned up.
- `make injection-drill` target + `.github/workflows/injection-drill.yml` CI gate (PR to `main` + daily schedule, read-only token).
- 7 new CAPs in `docs/CAPABILITIES.md` under "Prompt-injection drill (SH-005)" section.

### Fixed

- `scripts/shepherd-poc/validate.sh` — `scripts/shepherd-poc/**` added to `PROTECTED_RE`. The enforcement scripts themselves are now protected from agent modification. `scripts/shepherd-poc/agent-call.sh` prompt updated to match.

### Trust boundary

- `docs/DESIGN.md §13` gains one "Decided on 2026-11-21" entry stating the injection drill is part of the trust boundary: changes to `validate.sh` or the path blocklist must not reduce drill coverage.
- `blocklist.protected-files` extended to cover `scripts/shepherd-poc/**` (previously not protected).
- `sandbox.no-secrets` extended: beyond "no secrets in agent env", now also "no secrets leaked via agent output" (drill `secret_scan`).

### Known gap (tracked)

- `tests/injection/payloads/09-fake-fix-benign-looking.json` — no "fix-is-a-downgrade / known-malicious-fork" guard today. Fixture is marked `known_gap: true`; the drill logs it and passes. Promote to an R2 story when the guard lands.

### Pending

- Live-drill track: one end-to-end run on `bboortz/ham-radio-compass` with a crafted finding. Closes the R0 exit-criterion ⚠️ row in `docs/plan/SH-004-r0-poc-on-healthy-plan.md`.
- Re-sync `scripts/shepherd-poc/validate.sh` + `agent-call.sh` into the three managed pilots (healthy, beaconry, ham-radio-compass) so the `PROTECTED_RE` extension applies there too. Rollout PR follows this ship.

## [v0.3.4] — 2026-11-21 — SH-011 bugfix: graceful fallback when branch protection missing

### Fixed

- `templates/dependabot-automerge.yml` crashed with `GraphQL: Pull request Protected branch rules not configured for this branch (enablePullRequestAutoMerge)` when the base branch had no protection rule. `gh pr merge --auto` requires at least one protection rule to wait on. Now captures the failure, emits a `decision()` log line naming the missing setup, and exits 0 so the step doesn't flap red on every Dependabot PR.
- Test regex tightened: `gh pr view/merge without -R` check now ignores comment lines.

### Operational note

Repos opting into `auto_merge: true` must additionally have minimal branch protection on their base branch (one required status check is enough — e.g. `Detect changes`). Without it, the workflow falls through to "leaves PR open" instead of actually merging. This is a one-time repo setup, done via `gh api -X PUT repos/<repo>/branches/main/protection` or the GitHub UI.

## [v0.3.3] — 2026-11-21 — SH-011 bugfix: jq regex escape

### Fixed

- `templates/dependabot-automerge.yml` LOCK_RE used `\.` inside a jq `test()` string. jq string literals reject `\.` as an invalid escape, so the diff-size gate crashed before any decision. Fixed by using `\\.` so jq sees a backslash-plus-dot and passes a literal `.` to its regex engine.
- Test now runs the LOCK_RE against a fixture via `jq` to catch escape-parsing regressions at build time (SH-011: 26/0).

Same propagation as v0.3.2: must re-copy `templates/dependabot-automerge.yml` into each auto-merge-opted-in managed repo.

## [v0.3.2] — 2026-11-21 — SH-011 bugfix: `gh pr view/merge` needs `-R`

### Fixed

- `templates/dependabot-automerge.yml` was calling `gh pr view "$PR_NUMBER"` and `gh pr merge "$PR_NUMBER"` without `-R owner/repo`. The workflow has no `actions/checkout` step, so `gh` had no git context and failed with `fatal: not a git repository`. The bug was latent on `ham-radio-compass` because every PR there was a major bump and short-circuited before the broken call; it surfaced on `beaconry` where patch/minor PRs reached the diff-size gate and crashed the workflow.
- Added test assertion: every `gh pr view` / `gh pr merge` line in the template must carry `-R`. `test/acceptance/test_SH_011_dependabot.sh` now 25/0.
- New `REPO: ${{ github.repository }}` in the workflow's env block so both calls can use `-R "$REPO"`.

Affected managed repos: `ham-radio-compass` (no observable impact — everything was major anyway) and `beaconry` (workflow re-copied). Follow-up required: re-copy `templates/dependabot-automerge.yml` into each auto-merge-opted-in managed repo.

## [v0.3.1] — 2026-11-21 — SH-011: pip ecosystem release-date lookup

### Added

- `templates/dependabot-automerge.yml` now queries PyPI JSON (`https://pypi.org/pypi/<name>/json`) for `pip`-ecosystem Dependabot PRs, so Python dep bumps on managed repos (e.g. `bboortz/beaconry`) can satisfy `gate.waiting-period`.
- `gate.waiting-period` CAP description extended: active for `npm_and_yarn` + `pip` + `github_actions`.
- Test assertion added: `test/acceptance/test_SH_011_dependabot.sh` (SH-011 24/0).

Follow-up ecosystems (go, docker, cargo) remain in the IDEAS list; they fall through to `age_ok=false` and are left open for human review.

### Post-ship update — SH-011 rolled out to all four pilots (2026-11-21)

Templates dropped into `bboortz/shepherd` (PR #3), `bboortz/beaconry` (PR #63), `bboortz/healthy` (PR #12), and `bboortz/ham-radio-compass` (PRs #27 + #36 config-tweak). Auto-merge workflow live on `ham-radio-compass` only. `allow_auto_merge` toggled on for HRC via API.

**Workflow observed on 9 Dependabot PRs on `ham-radio-compass`.** All 9 correctly left open — 7 major bumps + 1 grouped PR (title classifier gap) + 2 pre-config security PRs that Dependabot asked to be closed. Zero false-positive auto-merges. Zero crashes. Decisions logged as `::notice::` annotations on each run.

**Fan-out:** adding `.github/dependabot.yml` also triggered fresh version-update PRs on the three repos that didn't opt into auto-merge (beaconry 10, healthy 4, shepherd 2) — those await human review.

**Follow-ups parked in IDEAS.md:** grouped-PR title parsing, 0.x.y semver treatment, Dependabot-recreate-after-config-change nudge.

## [v0.3.0] — 2026-11-21 — SH-011 Dependabot baseline

**Per-repo configurable Dependabot layer (SH-011).** Shepherd now ships three new templates and a Zig verifier that together give managed repos a hygiene floor: Dependabot always on, selectively auto-merged.

### Added

- `templates/dependabot.yml` — reference baseline (`version: 2`, github-actions ecosystem).
- `templates/dependabot-automerge.yml` — reusable auto-merge workflow for repos that opt in. Pure `gh` CLI; no third-party actions; title-based bump classification.
- `templates/shepherd.yml` — new optional `dependabot:` block with `enforce_enabled` (default `true`) and `auto_merge` (default `false`).
- `shepherd-bump --verify-dependabot [--root PATH]` — new mode. Exit 0 ok, 3 missing `.github/dependabot.yml`, 4 malformed (no `version: 2` or no `updates:` entry). Honours `.shepherd.yml` → `dependabot.enforce_enabled: false` opt-out.
- `test/acceptance/test_SH_011_dependabot.sh` — 23 assertions covering template shape, SH-001 compliance (no `fetch-metadata`, every `uses:` is `actions/*` SHA-pinned), and the five verify-dependabot exit paths.
- Docs: `docs/stories/SH-011-dependabot-enforce-automerge.md`, `docs/plan/SH-011-dependabot-enforce-automerge-plan.md`, four new CAPs + three extensions in `docs/CAPABILITIES.md`, one §13 decision line in `docs/DESIGN.md` dated 2026-11-21.

### Gated-minus-scan-not-worse (SH-009 gap)

The auto-merge workflow enforces three of the four §12 gates — `bump_level ∈ {patch, minor}`, diff ≤ 50 non-lockfile lines, release age ≥ 24 h (npm + github_actions only; other ecosystems fall through to needs-human). `gate.scan-not-worse` is **not** applied on this path and is tracked as a documented gap until SH-009 lands (Fri 4 Dec target per DESIGN §13).

### Supply chain

The new auto-merge workflow uses no third-party GitHub Actions. PR classification is derived from the Dependabot PR title; release-date lookup is `curl registry.npmjs.org` for npm and `gh api repos/.../releases/tags/...` for GitHub Actions. `dependabot/fetch-metadata` is explicitly not used. Extends `supply-chain.no-third-party-actions-critical-path` test coverage.

## [v0.2.0] — 2026-11-21 — R0 shipped

**🎯 DESIGN §13 Release 0 — shipped on three pilots instead of one.**

### Ship summary

- **3 real vulnerable-dependency fixes merged autonomously** on `bboortz/ham-radio-compass`:
  - [`#10`](https://github.com/bboortz/ham-radio-compass/pull/10) — CRITICAL CVE-2025-7783 in `form-data` (`package.json` override + regenerated `package-lock.json`)
  - [`#12`](https://github.com/bboortz/ham-radio-compass/pull/12) — CRITICAL CVE-2026-9277 in `shell-quote`
  - [`#14`](https://github.com/bboortz/ham-radio-compass/pull/14) — CRITICAL CVE-2026-102422 in `shell-quote`
- **Three live pilots** registered in `docs/FLEET.md` (healthy, beaconry, ham-radio-compass); byte-identical shepherd-poc scripts across all three.
- **End-to-end autonomy proven** on the third dispatch: Trivy install (sigstore-verified) → scan → agent call → validate → `npm install --package-lock-only` regen → validate (combined) → `gh pr create` with labels — no manual rescue.

### SH-004 shipped — story + plan at `docs/stories/SH-004-r0-poc-on-healthy.md`

Post-merge notes section captures the five R1-forward design insights (lockfile size cap, LLM file-hallucination → hybrid flow, hunk-line-count errors → `--recount` cascade, Actions-PR-creation setting, deterministic top-1 picker).

### CAPs flipped `design → active` with evidence pointers

- `gate.diff-size` — path-aware cap (lockfile paths exempt)
- `sandbox.no-secrets` — agent step `env:` audit
- `sandbox.diff-only` — step ordering + live evidence
- `gateway.budget-run` — `max_tokens=4096` approximation (~€0.12/run observed)
- `blocklist.protected-files` — `validate.sh` + fixture-based tests
- `scope.level-1` — hybrid flow with manifest-only agent + lockfile regen

### Known gaps carried into R1

- `sandbox.no-network-except-model` — agent runs on stock runner today.
- `gateway.budget-day` — only per-run cap enforced in R0.
- `escalation.needs-human-issue` / `escalation.dedupe` — R1 scope; R0 opens PRs without an escalation ladder.
- `blocklist.unblock-per-repo` — R0 ships a fixed blocklist.
- Live prompt-injection drill — validator layer is covered by acceptance tests in all three pilots; a live drill against a crafted dep changelog is deferred.
- Ecosystem coverage beyond npm — pip / Go / Docker stubbed in `regen-lockfile.sh`.

## [v0.1.0] — 2026-11-21

First feature release. Retires Renovate from shepherd's fleet scaffold and
introduces `shepherd-bump`, a first-party Zig single-file tool that
discovers SHA-pinned GitHub Action references across the repo.

### Added (SH-001)

- `bump.zig` (~330 lines, Zig 0.17.1) — single-file source. `--list` mode
  parses `.github/workflows/*.yml` and `.github/actions/**/action.yml`,
  discovers `uses: owner/repo@<40-hex>  # vX.Y.Z` lines, emits
  deterministic tab-separated output. Non-pinned refs are skipped.
- `build.zig` — stock Zig build script. `zig build --prefix .` produces
  `bin/shepherd-bump`.
- `.github/workflows/bump.yml` — cron (04:00 UTC) + `workflow_dispatch`;
  installs Zig 0.17.1, builds shepherd-bump, runs `--list`. The `--check`
  and `--pr` steps are scaffolded as comments; implementation lands in
  SH-002 / SH-003.
- `test/acceptance/test_SH_001_retire_renovate.sh` — 21 assertions.
  Covers Scenarios 1–2 and the SHA-format invariant.
- `Makefile` targets: `build`, `test`, `test-acceptance`. `check` wires
  them in alongside the existing lint gates.
- `docs/FLEET.md` from the previous commit cycle; this release records it.

### Removed (SH-001)

- `.github/workflows/renovate.yml`
- `renovate/default.json` (and the empty `renovate/` directory)
- All references to `renovatebot/github-action` — enforced by the
  acceptance test, so this invariant stays true going forward.

### Changed (SH-001)

- `VERSION`: `0.0.0` → `0.1.0`.
- `docs/DESIGN.md §2 / §4 / §7 / §11 / §12 / §13` — described in the
  SH-001 draft commit.
- `docs/CAPABILITIES.md` — new Supply chain + Bump engine sections; the
  SH-001-delivered CAPs flip to `in-progress`.

### Deferred

- `shepherd-bump --check` — upstream-tag resolution, semver, annotated-tag
  dereference, highest-in-major, orphan detection. Scoped to **SH-002**.
- `shepherd-bump --pr` — commit + push + PR opening via
  `SHEPHERD_BUMP_TOKEN`. Scoped to **SH-003**.
- `scripts/check-commit-msg.sh` and `scripts/verify-traceability.sh`
  ports from `bboortz/healthy` — scoped to a follow-up `chore/` branch.

## [v0.0.0] — 2026-11-19

Pre-release scaffold. Not tagged or published yet.

### Security

- Pin `aquasecurity/trivy-action` to `v0.36.0` SHA (`ed142fd0673e97e23eac54620cfb913e5ce36c25`) in `.github/workflows/reusable-verify.yml`. The previous `@0.28.0` tag was in the vulnerable range of **GHSA-69fq-xp46-6x23 / CVE-2026-33634** — the TeamPCP supply-chain attack of March 2026, which force-pushed 76 of 77 `trivy-action` tags to malicious commits containing a secret-stealer. Dependabot flagged this on the very first push — the irony is noted and the lesson is Shepherd's (`docs/CAPABILITIES.md § sandbox` and `blocklist.protected-registration-files`).
- SHA-pin the remaining third-party actions in the shepherd fleet workflows. Mutable major-version tags removed in favour of resolved commit SHAs at the latest patch within each current major:
  - `actions/create-github-app-token@v1` → `d72941d7…` (`v1.12.0`) in `discover.yml`, `renovate.yml`, `digest.yml`.
  - `actions/checkout@v4` → `11d5960a…` (`v4.4.0`) in `discover.yml`, `renovate.yml`, `reusable-verify.yml`.
  - `renovatebot/github-action@v41` → `8ac70de2…` (`v41.0.22`) in `renovate.yml`.
  The Trivy advisory's generalisation applies: force-push on a mutable tag is a supply-chain entry point. Renovate's shared preset already extends `helpers:pinGitHubActionDigests`, so future bumps stay SHA-pinned.

### Added

- **Design source of truth** (`docs/DESIGN.md`): fleet layer (§1–11), trust
  boundary decisions (§12), Release 0 → Release 3 plan (§13), decisions made
  on 2026-11-19 (MIT, public, Linux-first, GitHub-only, Anthropic API).
- **Fleet layout** (§2) scaffolded: `policy/default.yml`, `renovate/default.json`,
  `templates/shepherd.yml`, `templates/caller-verify.yml`,
  `.github/workflows/{discover,renovate,digest,reusable-verify}.yml`,
  `docs/needs-human.md`. Workflow bodies described "in words" in the design
  are structural stubs — they activate from Release 1+.
- **DD-TGD scaffold**: `CLAUDE.md`, `memory/{MEMORY,project,workflow}.md`,
  `docs/stories/{_template,_9-questions}.md`, `docs/plan/{_template,IDEAS}.md`,
  `docs/CAPABILITIES.md` seeding 30 design capabilities from `docs/DESIGN.md §12`.
- **Release metadata**: `VERSION`, this `CHANGELOG.md`.
- **Contributor docs**: `CONTRIBUTING.md`, `SECURITY.md`.
- **Developer UX**: `Makefile` with `help`, `check`, `install-hooks`;
  `.yamllint`, `.markdownlint.json`; expanded `.gitignore`.
