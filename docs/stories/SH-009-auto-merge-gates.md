---
id: SH-009
slug: auto-merge-gates
status: shipped
created: 2026-11-21
shipped: 2026-11-21
owner: @benni
parent: SH-006
---

# SH-009 — R1-C: auto-merge gates + schema v1 + dry-run + needs-human

> **Sub-story of [SH-006](SH-006-r1-reusable-action.md).** Lands the §12 gate stack for the agent flow. Phased: **part 1** (3 of 4 gates + schema + labels + canary) ships first; **part 2** (scan-not-worse + needs-human dedupe + dry-run + full rollout + live auto-merge) ships as a follow-up PR on the same story.

## 1. Who is the consumer?

The repo owner whose managed repo has shepherd opening dependency-fix PRs. They want **auto-merge for the obviously-safe cases** (small diff, non-security, CI green) and **PR-opened-but-not-merged** for everything else. Secondary consumer: the operator triaging the fleet — gate failures surface as needs-human issues with the specific gate named, so triage is `find issue → read gate name → act`.

## 2. When does the story fire?

- A shepherd-agent-labelled PR is opened or updated.
- CI on a shepherd-agent PR completes (via `workflow_run`).
- A maintainer applies / removes the `shepherd-hold` label (suppresses auto-merge regardless of gate state — standard escape hatch).

## 3. What does success look like?

Mechanically checkable:

**Schema v1** (`templates/shepherd.yml`):

- `schema_version: 1` present at the top.
- `auto_merge: {patch, minor, major}` keys (already present post-SH-007; schema v1 formalises them).
- `monitored_pipelines: [...]` — default `all` (every required branch-protection check); explicit list overrides.
- `max_diff_lines: 50` — cap for `gate.diff-size`.
- `rescan_scope: high_critical` — `all | high_critical`; drives `gate.scan-not-worse` (part 2).
- `dry_run: false` — flips the agent PR step to a comment-only summary (part 2).
- `needs_human_label: needs-human` — label applied to the auto-opened escalation issue.

**Gates workflow** (`.github/workflows/reusable-shepherd-gates.yml` on shepherd):

- `on: workflow_call` with `permissions: contents: write, pull-requests: write`.
- Triggered by the caller on `pull_request` (`types: [opened, synchronize, labeled, reopened]`) **and** via `workflow_run` on CI completion. Caller-side the filter is `if: contains(github.event.pull_request.labels.*.name, 'shepherd-agent')`.
- Runs these gates **in order**; first failure short-circuits:

  | # | Gate | Part | Mechanism |
  |---|---|---|---|
  | 1 | **`gate.diff-size`** | **1** | Re-run `validate.sh`'s non-lockfile line counter on the PR's current head. Cap = `.shepherd.yml → max_diff_lines`. |
  | 2 | **`gate.pipelines-green`** | **1** | `gh pr checks <num> -R <repo> --json name,state` → filter to pipelines named in `.shepherd.yml → monitored_pipelines` (default = all required checks). Every selected check must be `success`. |
  | 3 | **`gate.security-fix-removes-finding`** | **1** | Only runs if PR carries `shepherd-security-fix` label. Checks that a re-scan removes ≥1 finding. Part 1 **mocks** this by trusting the label — a stricter check lands in part 2. |
  | 4 | **`gate.scan-not-worse`** | **2** | Trivy-scans base and PR heads; diffs HIGH/CRITICAL findings; fails if PR adds any. |

- All gates pass + repo opted in via `.shepherd.yml → auto_merge.patch/minor` → `gh pr merge --auto --merge -R <repo>`.
- Any gate fails → open (or comment on existing) a needs-human issue. Dedupe key = `(package, cve, gate)`. **Part 2.**
- Workflow always exits 0; decisions encoded as `::notice::` annotations (matches SH-011 pattern).

**Caller template** (`templates/caller-shepherd-gates.yml`, ≤ 25 lines):

- Thin caller. SHA-pins the reusable gates workflow to shepherd.
- Explicit `secrets:` pass (no `secrets: inherit`).
- Managed repos drop into `.github/workflows/shepherd-gates.yml` alongside their existing SH-007 agent caller.

**Agent PR labels** (`scripts/shepherd-poc/open-pr.sh`):

- Always applies `shepherd-agent` label (so the gates workflow knows which PRs to evaluate).
- Applies `shepherd-security-fix` label when the originating Trivy finding was HIGH/CRITICAL (detected via findings.json metadata captured earlier in the pipeline).

**validate.sh refactor:**

- Core line-counting logic lifted into a function callable from both `validate.sh` (existing R0 contract: exit 0/2/3) and the gates workflow (returns a count via stdout).
- Backwards-compatible — existing R0 callers (tests, HRC live drill, canary) continue to work byte-for-byte.

**CAPs flipped** (part 1):

- `gate.pipelines-green` → active
- `gate.diff-size` → active (was already active via SH-004; extended with PR re-run coverage)
- `gate.security-fix-removes-finding` → **active (partial — label-trust only; strict check in part 2)**
- `auto-merge.opt-in-per-repo` → active
- `auto-merge.risk.low` / `.medium` / `.high` → active (via schema v1 risk tiers)

**CAPs deferred to part 2:**

- `gate.scan-not-worse` → active
- `onboarding.dry-run-first` → active
- `escalation.needs-human-issue` → active
- `escalation.dedupe` → active

## 4. How urgent?

- [x] R1 critical path (DESIGN §13 R1 scope; target Fri 4 Dec).
- [x] Closes `gate.scan-not-worse` — the hole SH-011's Dependabot flow documented as a known gap.
- [x] Without this, the R1 soak measures *your availability*, not shepherd's reliability. Required for the "10 merged PRs in 2 weeks hands-off" exit criterion.

## 5. Happy path

```
# Daily cron on an onboarded repo (e.g. bboortz/healthy):
#  1. Scheduled fire → reusable-shepherd.yml agent flow runs.
#  2. Agent produces a 4-line package.json bump; regen-lockfile adds 30 lines.
#  3. open-pr.sh opens a PR labelled `shepherd-agent` (+ `shepherd-security-fix` if HIGH/CRITICAL).
#  4. Caller's shepherd-gates.yml fires on `pull_request: opened`.
#  5. Gates workflow (reusable-shepherd-gates.yml):
#     - gate.diff-size: 4 non-lockfile lines ≤ 50 → ok
#     - gate.pipelines-green: PR's CI checks still pending → leave open
#  6. PR CI runs. On completion, workflow_run fires the gates workflow again.
#  7. Gates workflow:
#     - gate.diff-size: ok
#     - gate.pipelines-green: all required checks green → ok
#     - gate.security-fix-removes-finding: PR has no shepherd-security-fix label → skip
#     - (part 2: gate.scan-not-worse: base-vs-PR Trivy diff shows no new HIGH → ok)
#  8. gh pr merge --auto --merge → GitHub merges immediately (all required checks pass).
#  9. (part 2) needs-human issue if any gate failed; dedupe by (package, cve, gate).
```

## 6. Edge cases / failure modes that matter

- **Gates fire mid-CI** (PR open event, checks still pending). → Leave PR open, log `::notice::pending`. `workflow_run` re-fires when CI completes.
- **`monitored_pipelines: all`** on a repo with no required checks configured. → Falls back to "no pipelines to monitor", gate.pipelines-green trivially passes. Operator can tighten by adding required checks or an explicit list.
- **Oversize diff.** → gate.diff-size fails, needs-human issue (part 2) names the line count.
- **A maintainer applies `shepherd-hold`.** → Workflow sees the label, exits 0 without touching auto-merge; PR stays open.
- **Gate workflow runs on a non-shepherd-agent PR** (someone miswired the `if:`). → First step checks the label, exits 0 if absent.
- **Dependabot-gate + shepherd-gate racing** on the same repo. → Separate labels (`dependencies` vs `shepherd-agent`); separate workflows don't overlap; distinct branches.
- **`shepherd-security-fix` label without a corresponding finding** (manual mislabel). Part 1: trusted; part 2: strict re-scan verification.

## 7. Out of scope

Scan-not-worse mechanics, needs-human issue dedupe, dry-run, beaconry + HRC rollout, live auto-merge canary on HRC — **all part 2**, not this session.

## 8. Acceptance (Gherkin → test assertions)

Part 1:

```gherkin
Scenario: templates/shepherd.yml carries schema v1
  Given this repository
  Then templates/shepherd.yml contains `schema_version: 1`
  And it contains `monitored_pipelines:`
  And it contains `max_diff_lines:`

Scenario: gates reusable workflow shape
  Given .github/workflows/reusable-shepherd-gates.yml on shepherd
  Then it declares `on: workflow_call`
  And it declares `permissions: contents: write, pull-requests: write`
  And it references `gate.diff-size`, `gate.pipelines-green`, `gate.security-fix-removes-finding`
  And every `uses:` is SHA-pinned to `actions/*`

Scenario: caller template shape
  Given templates/caller-shepherd-gates.yml
  Then it is ≤ 25 lines
  And it references `bboortz/shepherd/.github/workflows/reusable-shepherd-gates.yml@<sha>`
  And it filters by `shepherd-agent` label

Scenario: open-pr.sh applies shepherd-agent label
  Given an agent-produced diff
  When open-pr.sh runs
  Then the resulting `gh pr create` invocation includes `--label shepherd-agent`

Scenario: validate.sh exposes a reusable counter
  Given a fixture diff with 30 non-lockfile + 200 lockfile lines
  When the gates workflow sources the counter function
  Then the function returns 30 (or writes it to stdout)
  And the existing validate.sh CLI still exits 0 on the same input
```

## 9. Capabilities delivered or extended

### Part 1 (this session)

- `gate.pipelines-green` — new, active. Default = all required checks; `.shepherd.yml → monitored_pipelines` overrides.
- `gate.diff-size` — existing, extended coverage (now also fires on PR update / `workflow_run`).
- `gate.security-fix-removes-finding` — new, **active (partial — label-trust)**.
- `auto-merge.opt-in-per-repo` — flip `design → active`.
- `auto-merge.risk.low` / `.medium` / `.high` — flip `design → active` (schema v1 risk tiers).
- `config.schema-v1` (new) — `.shepherd.yml` schema is pinned, version-stamped, documented.

### Part 2 (follow-up ship)

- `gate.scan-not-worse` — active (Trivy base-vs-PR diff).
- `gate.security-fix-removes-finding` — strict (no longer label-trust).
- `escalation.needs-human-issue` — active.
- `escalation.dedupe` — active.
- `onboarding.dry-run-first` — active (`.shepherd.yml → dry_run: true` → comment-only PR path).

---

## Plan doc

Lives at [`docs/plan/SH-009-auto-merge-gates-plan.md`](../plan/SH-009-auto-merge-gates-plan.md).
