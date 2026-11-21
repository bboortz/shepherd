# Changelog

All notable changes to `shepherd` are recorded here. The format is based on
[Keep a Changelog](https://keepachangelog.com/) and this project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

Next: R1 scope (reusable Action in this repo, sandbox perimeter, auto-merge gates, waiting period). See [`docs/DESIGN.md §13`](docs/DESIGN.md).

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
