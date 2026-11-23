---
id: SH-006
slug: r1-reusable-action
status: shipped
created: 2026-11-21
owner: @benni
---

# SH-006 — R1 umbrella: reusable Action + sandbox perimeter + auto-merge gates + waiting period

> **Umbrella story.** R1 per DESIGN §13 Release 1 bundles four distinct deliverables. This story owns the design and the exit criteria; the plan doc splits it into four sub-stories (SH-007, SH-008, SH-009, SH-010) that ship independently. Follows the SH-004 pattern (umbrella + in-repo implementation stories).

## 1. Who is the consumer?

Repo owner onboarding a new repo to shepherd. In R0 they had to copy five scripts + one workflow + create labels + enable Actions-PR permission (steps shepherd learned the hard way across 14 PRs on 3 pilots). In R1 they get:

- `uses: bboortz/shepherd/.github/workflows/reusable-shepherd.yml@v1.0.0` in one caller workflow.
- One secret (`ANTHROPIC_API_KEY`).
- Optionally, `.shepherd.yml` for per-repo overrides.
- Total setup: ≤ 15 minutes (the headline promise from DESIGN §13).

## 2. When does the story fire?

- A new repo onboards to shepherd.
- An existing pilot (healthy / beaconry / ham-radio-compass) migrates from the copied scripts to the reusable Action.
- A R0-shipped repo's cron fires and the agent produces a PR that is **eligible for auto-merge** under the gates.

## 3. What does success look like?

Mechanically checkable, decomposed by sub-story:

### R1-A — Reusable Action (SH-007)

- `bboortz/shepherd/.github/workflows/reusable-shepherd.yml` exists and is a reusable workflow (`on: workflow_call`).
- The current scripts under `scripts/shepherd-poc/` move into the Shepherd repo (or into a composite action) — pilots don't carry their own copies anymore.
- Caller-workflow template at `templates/caller-shepherd.yml` is ≤ 20 lines.
- All 3 R0 pilots migrated: their `.github/workflows/shepherd-poc.yml` is replaced by a thin caller workflow referencing the shepherd Action by SHA.
- A tagged release `v1.0.0` on shepherd (or a beta tag like `v1.0.0-rc1`).

### R1-B — Sandbox perimeter (SH-008)

- The agent-call step runs inside a container (or namespace) where outbound network is denied **except** to `api.anthropic.com:443`.
- Verifiable live: inside the step, `curl -m 3 https://api.openai.com/` exits non-zero; `curl -m 3 https://api.anthropic.com/v1/messages` resolves (even if 401 unauth without a key).
- `sandbox.no-network-except-model` and `gateway.model-only` flip `design → active` with evidence pointers.
- Documented how (iptables in a sidecar vs docker `--network` vs netns); decision in the plan.

### R1-C — Auto-merge gates (SH-009)

- `.shepherd.yml` schema v1 published; `auto_merge: {patch: true, minor: true, major: false}` and risk-tier knobs.
- Four gates implemented and each blocks auto-merge independently:
  - `gate.pipelines-green` — all configured pipelines on the PR must pass.
  - `gate.diff-size` — ≤ 50 changed non-lockfile lines (R0 default, configurable).
  - `gate.scan-not-worse` — re-scan the PR; no new HIGH/CRITICAL findings vs. base.
  - `gate.security-fix-removes-finding` — PRs labelled `shepherd-security-fix` must remove ≥ 1 finding.
- When all gates pass **and** the repo has opted in via `.shepherd.yml`, the PR auto-merges.
- Ham-radio-compass is the live proof: one real agent-produced PR auto-merges after the gates clear.

### R1-D — Waiting period (SH-010)

- `gate.waiting-period` — a PR is not eligible for auto-merge until **24 h** have elapsed since the new dependency's upstream **release date**, not the PR date. Configurable; `0` disables.
- Release-date lookup via ecosystem APIs (`npm view <pkg>@<version> time.modified`, PyPI `/pypi/<pkg>/<version>/json`, Go proxy `@v/<version>.info`).
- Fails open on unknown ecosystem (log, don't block) so auto-merge isn't a cliff.

### R1 overall exit

- **5 outside R0 pilots → 3 self, 2 friendlies** use the Action for 2 weeks without hand-holding except for needs-human issues.
- ≥ 10 merged shepherd PRs across the fleet during that soak.
- Zero broken `main` branches.
- Setup measured at ≤ 15 minutes on a fresh repo (timed against the quickstart).

## 4. How urgent?

- [x] Launch-schedule bound (R1 target: Fri 4 Dec per DESIGN §13 — 13 days from now).
- [x] Trust-boundary — R1 is where the sandbox invariants actually become true (R0 documented them as gaps).
- [x] Public-facing — the caller-workflow template is the *first thing* an outside user copy-pastes. Its shape matters for the 100-stars goal.

## 5. Happy path

```
# Onboard a new repo (public user, R1):
cp ~/git/shepherd/templates/caller-shepherd.yml .github/workflows/shepherd.yml
# edit cron / schedule if needed; commit; push
gh secret set ANTHROPIC_API_KEY -R <org>/<repo>
# Done. 15 minutes total.

# Daily cron on an onboarded repo:
#   1. Trivy scan                         (unchanged)
#   2. Agent call in sandboxed container  (R1-B)
#   3. validate.sh + regen-lockfile       (R0 artefacts, moved into the Action)
#   4. Open PR
#   5. Wait 24h since the dep's upstream release-date timestamp (R1-D)
#   6. Re-check all gates on the PR (R1-C)
#   7. If .shepherd.yml opts in and gates pass → auto-merge
#   8. If any gate fails → stay open; operator reviews
```

## 6. Edge cases / failure modes that matter

- **A pilot's old workflow still runs alongside the new caller workflow after migration.** → Migration PR also deletes `scripts/shepherd-poc/` from the pilot repo. Explicit.
- **The sandbox container can't find the `ANTHROPIC_API_KEY` secret** because GitHub Actions default scoping. → Pass secrets through the caller workflow's `secrets: inherit` or `secrets: ANTHROPIC_API_KEY`.
- **A PR becomes eligible for auto-merge mid-review** — maintainer wants to block. → `shepherd-hold` label suppresses auto-merge (standard pattern).
- **Release-date lookup fails** (ecosystem registry down, package not on registry). → Fail-open: log warning, skip the waiting gate, let other gates decide.
- **A re-scan shows the same finding but with different metadata** (different CVSS, different advisory) — `gate.scan-not-worse` false-positive. → Hash the finding by `(package, installed-version, cve)` not the whole JSON; be tolerant of advisory metadata drift.
- **Auto-merge races with a maintainer's in-progress review.** → Standard GitHub auto-merge semantics: merge-when-ready only fires when all enabled checks + reviews pass.

## 7. Out of scope

- GitHub App identity (DESIGN §13 "Optional advanced mode announced but not required" — R3).
- `shepherd-managed` topic-based auto-discovery of repos (fleet layer, post-R3).
- Scope levels 2–4 (R2).
- `ntfy` / Slack / Telegram notifications (R3 optional).
- Public-user-facing docs, demo repo, launch post (R2).
- Dependency-graph-wide "fix all related CVEs in one PR" (R2).

## 8. Acceptance (Gherkin → sub-story tests)

Each sub-story owns its own acceptance script. This umbrella owns only the **integration-level** acceptance:

```gherkin
Scenario: Caller workflow end-to-end (SH-007)
  Given a repo with only `.github/workflows/shepherd.yml` (caller workflow ≤ 20 lines) and ANTHROPIC_API_KEY secret
  When the caller workflow is dispatched
  Then it invokes the reusable shepherd action
  And the action runs the full pipeline (scan → sandboxed agent → validate → regen → PR)
  And a PR is opened against the base branch of the caller

Scenario: Sandbox network lockdown (SH-008)
  Given the agent step inside the reusable Action
  When it tries `curl -m 3 https://api.openai.com/`
  Then the request fails with a connection error
  When it tries `curl -m 3 https://api.anthropic.com/v1/messages` (no auth)
  Then the request returns an HTTP 401 (reachable; auth-rejected)

Scenario: Auto-merge after all gates pass (SH-009)
  Given a PR opened by the Action with a 5-line package.json bump + 170-line lockfile diff
  And .shepherd.yml opts into auto-merge for patch+minor
  And required pipelines on the PR are green
  And the finding removed from the re-scan matches the PR's claimed fix
  And no new HIGH/CRITICAL found in the re-scan
  And 24+ hours have elapsed since the dep's upstream release-date
  When the gates run
  Then the PR is auto-merged
  And a note is posted to the PR naming the gate that cleared it last

Scenario: Waiting period blocks a same-day CVE auto-merge (SH-010)
  Given a PR opened for a dep bumped to version X released 2 hours ago
  When the gates run
  Then auto-merge is deferred
  And the PR carries a bot comment "waiting-period: 22 hours remaining"
  And the next scheduled run auto-merges once 24h has elapsed
```

## 9. Capabilities delivered or extended

Delivered via sub-stories (status flipped at each sub-story's ship):

- `r1.reusable-action` (new)
- `sandbox.no-network-except-model` → `active`
- `gateway.model-only` → `active`
- `gateway.budget-day` → `active` (cumulative cap enforced by the gateway, not just per-run)
- `auto-merge.opt-in-per-repo` → `active`
- `auto-merge.risk.low` / `.medium` / `.high` → `active`
- `gate.pipelines-green` → `active`
- `gate.waiting-period` → `active` (new mechanism)
- `gate.scan-not-worse` → `active`
- `gate.security-fix-removes-finding` → `active`
- `blocklist.unblock-per-repo` → `active`
- `blocklist.protected-registration-files` → `active`
- `onboarding.one-workflow` → `active`
- `onboarding.default-github-token` → `active`
- `onboarding.zero-config-default` → `active`
- `onboarding.dry-run-first` → `active`

That's 16 CAPs flipping to `active` over R1 — the design's substance lands here.

---

## Plan doc

Lives at [`docs/plan/SH-006-r1-reusable-action-plan.md`](../plan/SH-006-r1-reusable-action-plan.md). Decomposes R1 into SH-007/008/009/010 sub-stories.
