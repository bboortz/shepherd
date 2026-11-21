# Capabilities — shepherd

The source of truth for what Shepherd does. Every capability is a mechanical property we can test. Entries are seeded from `docs/DESIGN.md §12`; they become test-linked once the Action lands in Release 1.

Each row: a stable `cap.id`, a one-line description, the source paragraph in DESIGN.md, and — once tests exist — a bidirectional pointer to the acceptance test that proves it. `make verify-traceability` will enforce bidirectional links from R1 onward.

Status values: `design` (described in DESIGN, not implemented yet), `active` (implemented, test-linked), `aspirational` (R2+), `deprecated`.

---

## Gates (DESIGN §12 — Auto-merge gates)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `gate.pipelines-green` | All configured build/test pipelines are green before auto-merge; the pipeline list is configurable per repo. | §12 | design | — |
| `gate.diff-size` | Auto-merge only when the PR changes ≤50 lines by default; configurable per repo. | §12 | design | — |
| `gate.waiting-period` | 24 h default from the new version's release date (not PR date); configurable or disable. | §12 | design | — |
| `gate.scan-not-worse` | No new findings vs base. Default scope HIGH+CRITICAL; widenable. | §12 | design | — |
| `gate.security-fix-removes-finding` | A PR labelled security must remove ≥1 finding. | §12 | design | — |

## Auto-merge policy (DESIGN §3, §12)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `auto-merge.opt-in-per-repo` | Off by default; `.shepherd.yml` opts in. Without it, the bot only opens PRs. | §12 | design | — |
| `auto-merge.risk.low` | Patch and minor auto-merge once CI is green. | §3 | design | — |
| `auto-merge.risk.medium` | Only patch auto-merges. | §3 | design | — |
| `auto-merge.risk.high` | Nothing auto-merges; everything is needs-human. | §3 | design | — |

## Sandbox (DESIGN §12 — Smart fix agent)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `sandbox.no-network-except-model` | Agent has no network except the locked gateway to the model API. | §12 | design | — |
| `sandbox.no-secrets` | Agent has no secrets of its own. It reads the checkout only. | §12 | design | — |
| `sandbox.diff-only` | Agent produces a diff; a separate trusted step commits and opens the PR. | §12 | design | — |

## Gateway (DESIGN §12 — Smart fix agent)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `gateway.model-only` | The gateway only reaches the Claude API. No other egress. | §12 | design | — |
| `gateway.budget-day` | Hard budget €5/day by default, configurable. Hitting it stops the run + ntfy note. | §12 | design | — |
| `gateway.budget-run` | Hard budget €1/run by default, configurable. | §12 | design | — |
| `gateway.in-action` | The gateway is built into the Action (R1+). No central hosted service in the default path. | §13 | design | — |

## Protected files (DESIGN §12 — Path blocklist)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `blocklist.protected-files` | Agent cannot touch workflows, secrets, deployment config, or `.shepherd.yml` by default. | §12 | design | — |
| `blocklist.unblock-per-repo` | Each repo can unblock specific paths. | §12 | design | — |
| `blocklist.protected-registration-files` | `.shepherd.yml` and the shepherd workflows can only be unblocked through a human-reviewed change — never by the bot or by a setting the bot can edit. | §12 | design | — |

## Supply chain (DESIGN §12 — SH-001)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `supply-chain.no-third-party-actions-critical-path` | No third-party GitHub Actions in shepherd's critical path. Exceptions: `actions/*` (GitHub-native), SHA-pinned only. Trivy wrapper replacement tracked in IDEAS. | §12 (SH-001) | active | `test/acceptance/test_SH_001_retire_renovate.sh` (renovatebot/ absence + Renovate-file absence) |
| `supply-chain.first-party-bump-engine` | Shepherd operates its own bump path; no reliance on Renovate or similar third-party services. | §4, §7 (SH-001) | active | `test/acceptance/test_SH_001_retire_renovate.sh` (bump.yml present; renovatebot/ absent) |
| `supply-chain.sha-pin-all-actions` | Every `uses:` line in `.github/workflows/` references a 40-hex commit SHA. | §12 | active | `test/acceptance/test_SH_001_retire_renovate.sh` (SHA-format invariant over `shepherd-bump --list`) |

## Bump engine (SH-001 → SH-003)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `bump.gh-actions` (discovery) | Discover `uses: owner/repo@<sha>` lines across `.github/workflows/*.yml` and `.github/actions/**/action.yml`. | SH-001 | in-progress | `test/acceptance/test_SH_001_retire_renovate.sh` (`--list` output shape) |
| `bump.sha-pin` (output invariant) | `--list` never emits non-40-hex refs; `--check` / `--pr` write only commit SHAs, dereferencing annotated tags. | SH-001 | in-progress | `test/acceptance/test_SH_001_retire_renovate.sh` (SHA-format invariant) |
| `bump.stay-within-major` | Default: latest patch within the current major. Major bumps require explicit opt-in. | SH-002 | design | — |
| `bump.open-pr-grouped` | One PR per bumpable dep; grouping per ecosystem per schedule in a follow-up. | SH-003 | design | — |
| `bump.orphaned-pin-detection` | Detect pinned SHAs that no longer match any upstream tag; open a needs-human issue rather than silently rewriting. | SH-002 | design | — |

## Failures and escalation (DESIGN §12)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `retries.failed-fixes` | 3 retries by default on failed verification, configurable per repo. | §12 | design | — |
| `escalation.needs-human-issue` | After the last failed attempt — or any time the bot needs human help — open a needs-human issue. No quiet logging. | §12 | design | — |
| `escalation.dedupe` | If a needs-human issue for the same problem is already open, comment on it instead of duplicating. | §12 | design | — |

## Fix scope levels (DESIGN §12)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `scope.level-1` | Version bumps and lockfiles (R1 default). | §12 | design | — |
| `scope.level-2` | Dependency fixes that need small code changes (R2). | §12 | aspirational | — |
| `scope.level-3` | General source-code fixes for security findings (R2). | §12 | aspirational | — |
| `scope.level-4` | Pipelines and workflows — always requires a human-reviewed approval. | §12 | aspirational | — |

## Policy (DESIGN §9)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `policy.quiet-hours` | Default `22:00-07:00 Europe/Berlin`. | §9 | design | — |
| `policy.digest.weekly` | Weekly digest, delivered by ntfy. | §9 | design | — |
| `policy.page-immediately` | `critical-cve-no-fix`, `rollback-failed`, `ladder-exhausted`. | §9 | design | — |
| `policy.always-human` | `major-version`, `cve-without-fix`, `failed-rollback`, `data-migration`. | §9 | design | — |

## Onboarding (DESIGN §13 design principles)

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `onboarding.one-workflow` | 15-minute setup: copy one workflow, add one secret, push. | §13 | aspirational | — |
| `onboarding.default-github-token` | Default auth is the built-in `GITHUB_TOKEN` or a fine-grained PAT; the App is advanced-mode only. | §13 | aspirational | — |
| `onboarding.zero-config-default` | `.shepherd.yml` is optional; defaults are the ones in `templates/shepherd.yml`. | §13 | aspirational | — |
| `onboarding.dry-run-first` | Dry-run mode is the first experience; the bot comments what it would fix and changes nothing. | §13 | aspirational | — |
