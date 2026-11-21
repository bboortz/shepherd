---
id: SH-011
slug: dependabot-enforce-automerge
status: shipped
created: 2026-11-21
shipped: 2026-11-21
owner: @benni
---

# SH-011 — Dependabot baseline: enforce presence + opt-in gated auto-merge

## 1. Who is the consumer?

Fleet operator who wants ambient dependency hygiene on every managed repo with low cognitive load. Secondary consumer: the repo owner of a backlog-heavy repo (e.g. `bboortz/ham-radio-compass`) who wants Dependabot's security-update PRs to auto-merge without human-in-the-loop on patch/minor — but still inside Shepherd's §12 gate semantics.

## 2. When does the story fire?

- **Verify path.** Any time shepherd audits a managed repo (locally, or in a future fleet pass) `shepherd-bump --verify-dependabot` reports whether `.github/dependabot.yml` is present and well-formed.
- **Auto-merge path.** Any time Dependabot opens or synchronises a PR on a managed repo that has opted in via `.shepherd.yml` `dependabot.auto_merge: true`.

## 3. What does success look like?

Mechanically checkable outcomes:

- `templates/shepherd.yml` carries a new `dependabot:` block (`enforce_enabled: true`, `auto_merge: false` defaults).
- `templates/dependabot.yml` exists as a reference baseline: `version: 2` + at least one `- package-ecosystem:` entry.
- `templates/dependabot-automerge.yml` exists. Every `uses:` is under `actions/*` and is a 40-hex SHA. `dependabot/fetch-metadata` is never referenced (SH-001 invariant).
- `./bin/shepherd-bump --verify-dependabot --root PATH` exit codes: `0` ok, `3` missing `.github/dependabot.yml`, `4` malformed (no `version: 2` or no `updates:` entry). `.shepherd.yml` with `dependabot: { enforce_enabled: false }` short-circuits to `0`.
- `docs/CAPABILITIES.md` lists new Dependabot CAPs and extends `gate.diff-size`, `gate.waiting-period`, `supply-chain.no-third-party-actions-critical-path` with bidirectional links to this story's test.
- All four pilot repos (`shepherd`, `beaconry`, `healthy`, `ham-radio-compass`) carry a `.github/dependabot.yml` after rollout.
- `ham-radio-compass` additionally carries `.github/workflows/dependabot-automerge.yml` + `.shepherd.yml` with `dependabot.auto_merge: true`.
- At least one existing Dependabot PR on `ham-radio-compass` (PR #25 or #26) auto-merges through the new workflow after rollout.

## 4. How urgent?

- [x] Security-critical — reduces `ham-radio-compass` vulnerability backlog without pushing scan-not-worse further out; also hardens hygiene on the other three pilots.
- [x] Onboarding — gives Shepherd a usable value prop ("Dependabot on everywhere, selectively auto-merged with real gates") before SH-006's smart-fix path ships on Fri 4 Dec.

## 5. Happy path

```
# Verify (local or future fleet pass):
./bin/shepherd-bump --verify-dependabot --root /path/to/managed-repo
#   exit 0 → ok (dependabot.yml present and well-formed, OR .shepherd.yml opted out)
#   exit 3 → missing .github/dependabot.yml
#   exit 4 → present but malformed (no `version: 2` or no `updates:` entry)

# Auto-merge (per Dependabot PR, repo opted in):
#   .github/workflows/dependabot-automerge.yml fires on pull_request from dependabot[bot]
#   Classify via PR title ("Bump <name> from X.Y.Z to A.B.C"):
#     - bump_level = major | minor | patch | unknown  (unknown → no auto-merge)
#     - lines_ok  = (additions + deletions ≤ 50)
#     - age_ok    = (now − upstream release date ≥ 24h)
#         npm: `curl https://registry.npmjs.org/<name> | jq .time["<to>"]`
#         gh-actions: `gh api repos/<owner>/<repo>/releases/tags/v<to> --jq .published_at`
#         other ecosystems: age_ok = false (safe default)
#   Gate: bump_level ∈ {patch, minor} AND lines_ok AND age_ok
#     green → `gh pr merge --auto --merge`
#     not green → leave the PR open, no comment, no needs-human issue (SH-009 scope)
```

## 6. Edge cases / failure modes that matter

- **Major bump** (e.g. `v1.x.x → v2.0.0`): `bump_level=major` → no auto-merge. Left for human review.
- **Oversize diff** (>50 lines): `lines_ok=false` → no auto-merge.
- **Unsupported ecosystem** (pip, go, docker, etc.): `age_ok=false` → no auto-merge. Pip/Go/Docker/etc. follow as follow-up stories.
- **Missing release date** (upstream deleted the tag or npm 404s the version): `age_ok=false` → no auto-merge.
- **Unknown PR title shape** (Dependabot renamed the format): `bump_level=unknown` → no auto-merge.
- **Scan not worse**: NOT CHECKED in this story. Documented gap; extends with SH-009.
- **`.shepherd.yml` present but has no `dependabot:` block**: treated as `enforce_enabled: true`, `auto_merge: false` (safest defaults).
- **`.shepherd.yml` parse failure**: verify exits 4 (malformed shepherd config), auto-merge workflow doesn't fire because repo owner must install it deliberately anyway.
- **GitHub "automated security fixes" setting already on**: fine. Dependabot keeps opening security PRs; the auto-merge workflow treats them like any other Dependabot PR.
- **Dependabot PR targets a non-default branch**: workflow still fires (triggered by pull_request event); `gh pr merge --auto` respects the base branch's protection rules.

## 7. Out of scope

- `gate.scan-not-worse` for the Dependabot flow — lives in SH-009 (R1 umbrella).
- Fleet-wide auto-install of `.github/dependabot.yml` into managed repos — fleet layer, post-R3 (per `docs/DESIGN.md §13`). This story drops the file in by hand on four pilots.
- Ecosystems beyond npm and GitHub Actions for the release-date gate. pip/Go/Docker/Zig fall through to `age_ok=false` and need-human review. Each gets its own follow-up.
- Needs-human issue on verify failure or gate failure. Follow-up, co-located with SH-009's gate stack.
- macOS / Windows runners, forges other than GitHub, model providers other than Anthropic.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: templates ship the shepherd side of the baseline
  Given this repository on the feat branch
  Then  templates/shepherd.yml contains a `dependabot:` block
  And   templates/dependabot.yml contains "version: 2" and at least one "- package-ecosystem:"
  And   templates/dependabot-automerge.yml exists
  And   every `uses:` line in templates/dependabot-automerge.yml references `actions/*` and is 40-hex SHA-pinned
  And   templates/dependabot-automerge.yml does not reference `dependabot/fetch-metadata`

Scenario: verify-dependabot on repo without .github/dependabot.yml
  Given a managed-repo fixture with no .github/dependabot.yml
  When  ./bin/shepherd-bump --verify-dependabot --root FIXTURE runs
  Then  exit code is 3

Scenario: verify-dependabot on repo with a well-formed config
  Given a fixture with .github/dependabot.yml containing "version: 2" and "- package-ecosystem: github-actions"
  When  ./bin/shepherd-bump --verify-dependabot --root FIXTURE runs
  Then  exit code is 0

Scenario: verify-dependabot on repo with a malformed config
  Given a fixture with .github/dependabot.yml that is empty / missing "version: 2" / has no updates entry
  When  ./bin/shepherd-bump --verify-dependabot --root FIXTURE runs
  Then  exit code is 4

Scenario: enforce-enabled: false opts out of verification
  Given a fixture with .shepherd.yml `dependabot: { enforce_enabled: false }` and no .github/dependabot.yml
  When  ./bin/shepherd-bump --verify-dependabot --root FIXTURE runs
  Then  exit code is 0
```

## 9. Capabilities delivered or extended

New:

- `dependabot.presence-verified` — `shepherd-bump --verify-dependabot` reports presence + version:2 + ≥1 updates entry.
- `dependabot.config-enforce-opt-in` — `.shepherd.yml` `dependabot.enforce_enabled` toggles the verify check (default `true`).
- `dependabot.auto-merge-opt-in-per-repo` — `.shepherd.yml` `dependabot.auto_merge` toggles the auto-merge workflow (default `false`).
- `dependabot.auto-merge-level-patch-minor` — only patch + minor bumps auto-merge; major stays human-reviewed.

Extended (status flips from `design` → `active`):

- `gate.diff-size` — now also applied to the Dependabot flow (≤50 lines).
- `gate.waiting-period` — 24h since upstream release date. Active for `npm_and_yarn` + `github_actions`; other ecosystems fall through to `age_ok=false` (needs-human).

Extended (status stays `active`, test coverage widened):

- `supply-chain.no-third-party-actions-critical-path` — new workflow template upholds the invariant: no `dependabot/fetch-metadata`, every `uses:` is `actions/*` SHA-pinned.

Explicit gap (stays `design`, deferred to SH-009):

- `gate.scan-not-worse` — not implemented on the Dependabot path. Tracked in SH-009.
