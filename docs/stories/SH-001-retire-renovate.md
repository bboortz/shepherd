---
id: SH-001
slug: retire-renovate
status: in-progress
created: 2026-11-21
owner: @benni
---

# SH-001 — Retire Renovate; add shepherd-bump for GitHub Actions

> **Scope note (2026-11-21):** This story has been narrowed to ship an MVP. Its acceptance now covers Scenarios 1 and 2 (Renovate removed + `--list` discovery). The network-dependent scenarios — upstream-tag resolution, annotated-tag dereference, orphan detection, major-bump refusal, PR opening — are scoped to **SH-002** (`shepherd-bump --check`) and **SH-003** (`shepherd-bump --pr`). See `docs/plan/IDEAS.md`.

## 1. Who is the consumer?

Contributor extending Shepherd itself. The person who audits shepherd's trust base and wants no third-party GitHub Action with commit authority in the fleet workflow. Indirectly, every future managed-repo owner also benefits — they inherit the reduced attack surface when the fleet layer activates.

## 2. When does the story fire?

- A scheduled fleet bump pass that currently would be served by `.github/workflows/renovate.yml`. This story replaces the engine behind that workflow.
- Any time a `uses: owner/repo@<sha>` pin in `.github/workflows/*.yml` falls behind the latest patch within its current major.

## 3. What does success look like?

Mechanically checkable outcomes:

- `.github/workflows/renovate.yml` does not exist.
- `renovate/default.json` does not exist.
- No workflow in `.github/workflows/` references `renovatebot/`.
- `.github/workflows/bump.yml` exists and schedules shepherd-bump on cron + `workflow_dispatch`.
- A Zig source tree exists in-repo (single file `bump.zig` to start; split only if an invariant forces it) that builds to `bin/shepherd-bump` via `make build`.
- `./bin/shepherd-bump --ecosystem gh-actions` reads `.github/workflows/*.yml` and `.github/actions/**/action.yml`, discovers each `uses: owner/repo@<sha>` line, resolves the latest commit SHA within the pinned major, and opens one PR per bumpable dep.
- `docs/DESIGN.md §4` is retitled from "Shared Renovate preset" to "Bump engine (shepherd-bump)".
- `docs/DESIGN.md §7` is retitled from "Renovate workflow" to "Bump workflow".
- `docs/DESIGN.md §12` lists a new invariant: *No third-party GitHub Actions in shepherd's critical path (exceptions: `actions/*`, SHA-pinned only).*

## 4. How urgent?

- [x] Security-critical — removes one third-party Action with commit authority from the fleet critical path; narrows the TeamPCP-style attack surface (CVE-2026-33634 proved this is live, not theoretical).
- [x] Onboarding — first-party control of the bump path is a differentiator for the public launch in §13 R3.

## 5. Happy path

```
# .github/workflows/bump.yml fires on schedule (04:00 UTC daily) or workflow_dispatch.
# Steps:
#   - actions/checkout (SHA-pinned)
#   - make build      # produces bin/shepherd-bump
#   - ./bin/shepherd-bump --repo bboortz/shepherd --ecosystem gh-actions
#
# shepherd-bump --ecosystem gh-actions:
#   1. list .github/workflows/*.yml + .github/actions/**/action.yml
#   2. for each file, parse: uses: owner/repo@<40hex>  # vX.Y.Z
#   3. for each ref: GET /repos/{owner}/{repo}/tags → highest tag within current major
#   4. resolve to commit SHA (deref annotated tags via /git/tags/{sha} if needed)
#   5. if SHA differs: patch the single line, commit, push, open PR
#      - title:   "chore(deps): bump <owner>/<repo> to vX.Y.Z (sha abc1234)"
#      - labels:  shepherd-bump, gh-actions
#      - base:    dev
#      - body:    table of old → new (SHA + version), link to upstream release notes
#   6. exit 0 if PRs opened or no bumps needed
```

## 6. Edge cases / failure modes that matter

- **Annotated tag resolution.** `v0.36.0` of trivy-action was an annotated tag; the tag-object SHA ≠ the commit SHA. shepherd-bump must dereference, or pins will be wrong (we already made this mistake once this week).
- **Orphaned pin.** Upstream tag deleted or force-pushed (TeamPCP-style). shepherd-bump must refuse to rewrite and open a needs-human issue instead.
- **Pre-release / draft tags.** Skip unless `allow_prerelease: true` in `.shepherd.yml`.
- **Rate limit on tags API.** Backoff + resume; a single run should not exhaust the hourly quota.
- **`uses: owner/repo@main` (branch ref).** Report as "unpinned — refuses to bump". needs-human.
- **`uses: ./local/path`.** Skip (local composite action).
- **Workflow in a disabled or draft state.** Ignore.
- **`v4` → `v5` major move.** Refuse by default. A separate story can promote majors behind a human review.
- **Multiple tag families (`v0.0.1` and `0.0.1` both exist).** TeamPCP left artefacts like this. shepherd-bump prefers the newer `v`-prefixed form when both resolve to safe commits.

## 7. Out of scope

- Any ecosystem other than GitHub Actions. npm, pip, Go, Docker images, Zig come in follow-up stories.
- Auto-merging the PRs that shepherd-bump opens. That is the existing gate layer (lands with R1).
- Scheduling DSL. Only cron + `workflow_dispatch`.
- Multi-repo discovery via the `shepherd-managed` topic. This story only covers the shepherd repo itself (eats own food). Fleet-wide bump activates with the fleet layer after R3.
- Major-version bumps (own story).
- macOS / Windows runners.
- Replacing `aquasecurity/trivy-action`. A separate decision; see IDEAS.md.

## 8. Acceptance (Gherkin → test assertions)

In scope for SH-001 (shipped as `test/acceptance/test_SH_001_retire_renovate.sh`):

```gherkin
Scenario: Renovate removed from the scaffold
  Given the shepherd repo at this commit
  When  the repo tree is inspected
  Then  .github/workflows/renovate.yml does not exist
  And   renovate/default.json does not exist
  And   no workflow in .github/workflows/ contains "uses: renovatebot/"
  And   .github/workflows/bump.yml exists
  And   bump.yml schedules shepherd-bump on cron

Scenario: shepherd-bump discovers pinned actions (--list)
  Given .github/workflows/*.yml contain `uses: owner/repo@<40-hex>  # vX.Y.Z` lines
  When  ./bin/shepherd-bump --list --root . runs
  Then  it exits 0
  And   its stdout lists every pinned action as <file>\t<owner>/<repo>\t<sha>\t<version>
  And   no SHA field is non-40-hex
  And   no line references renovatebot/github-action

Scenario: --list fails cleanly on a missing root
  When  ./bin/shepherd-bump --list --root /nonexistent-path runs
  Then  it exits 1 (not panic)
```

Deferred to [SH-002](../stories/SH-002-shepherd-bump-check.md) and [SH-003](../stories/SH-003-shepherd-bump-pr.md) (see `docs/plan/IDEAS.md` for the current form):

- Upstream-tag resolution + highest-in-major selection (`--check`).
- Annotated tag → commit SHA dereference.
- Orphaned-pin detection + needs-human issue.
- `--promote-major` opt-in.
- PR opening (`--pr`).

## 9. Capabilities delivered or extended

Delivered by SH-001 MVP:

- `supply-chain.no-third-party-actions-critical-path` — Renovate is gone from the fleet workflow; invariant is now mechanically enforced by the acceptance test (`renovatebot/` absence).
- `supply-chain.first-party-bump-engine` — shepherd owns the discovery path (`shepherd-bump --list`).
- `bump.gh-actions` (discovery half) — read `uses: owner/repo@<sha>` lines across `.github/workflows/*.yml` and `.github/actions/**/action.yml`.
- `bump.sha-pin` (output invariant) — `--list` only reports 40-hex SHA pins; non-pinned refs are skipped.

Deferred to SH-002 / SH-003:

- `bump.gh-actions` (upstream resolution half).
- `bump.stay-within-major`, `bump.open-pr-grouped`, `bump.orphaned-pin-detection`.

New CAP ids are added to `docs/CAPABILITIES.md` in the same PR. Every CAP will need a bidirectional link to its acceptance test once the harness lands.

---

## Plan doc

Lives at [`docs/plan/SH-001-retire-renovate-plan.md`](../plan/SH-001-retire-renovate-plan.md).
