---
id: SH-010
slug: waiting-period
status: shipped
created: 2026-11-21
shipped: 2026-11-21
owner: @benni
parent: SH-006
---

# SH-010 — R1-D: waiting-period gate on the agent flow

> **Sub-story of [SH-006](SH-006-r1-reusable-action.md).** Lands the fifth §12 gate — `gate.waiting-period` — for the shepherd-agent flow. The same gate is already active on the Dependabot path via SH-011. This story closes the trust-boundary promise that **all five §12 auto-merge gates** are active on the agent flow.

## 1. Who is the consumer?

The repo owner who's seen a day-one supply-chain poisoning in the wild (event-stream, ua-parser-js, colors-sabotage) and wants shepherd to not auto-merge a dependency bump until the community has had **24 h** to catch it. Secondary consumer: the operator triaging a needs-human issue that names the `waiting-period` gate — they can read "release is 6 h old (< 24 h)" and know the PR will auto-merge later without them doing anything.

## 2. When does the story fire?

- Every shepherd-agent PR goes through the gates workflow.
- Between `scan-not-worse` and the auto-merge call, the new `gate.waiting-period` step evaluates whether the target version's upstream release date is ≥ `gates.waiting_period_hours` old (default 24 h).
- Re-fires on `workflow_run` + `pull_request: synchronize` (inherits from SH-009 part 2).

## 3. What does success look like?

Mechanically checkable:

**New files**

- `scripts/shepherd-poc/age-of-release.sh` — shared helper. Usage `age-of-release.sh <ecosystem> <package> <version>`. Exit codes: `0` (release-date printed to stdout), `2` (version not found on registry — hard fail), `3` (unknown ecosystem — fail-open signal).
- `test/acceptance/test_SH_010_waiting.sh` — red test with fixtures.

**Modified files**

- `scripts/shepherd-poc/agent-call.sh` — prompt extension: the model must emit an `<intent>...</intent>` block with `{ecosystem, package, from, to, cve?}` after the diff. Extract to `$INTENT_PATH` (default `/tmp/intent.json`).
- `scripts/shepherd-poc/open-pr.sh` — if `$INTENT_PATH` exists and is non-empty, copy to `.shepherd-intent.json` in the working tree and include it in the commit. If missing on a shepherd-agent PR, **hard-fail** (exit 2 with `::error::`).
- `scripts/shepherd-poc/validate.sh` — permit `.shepherd-intent.json` as an expected trusted-step output (not treated as a diff-touched protected path).
- `.github/workflows/reusable-shepherd-gates.yml` — new `gate.waiting-period` step after `scan-not-worse`. Reads `head/.shepherd-intent.json`, calls `age-of-release.sh`, compares to `gates.waiting_period_hours` from `.shepherd.yml`.
- `templates/shepherd.yml` — schema v1 extension: `gates.waiting_period_hours: 24` (0 disables).
- `docs/CAPABILITIES.md` — flip `gate.waiting-period` (agent flow) → active.

**Behaviours**

| Case | Gate decision |
|---|---|
| Intent file present, ecosystem supported, release ≥ 24 h old | ✅ pass |
| Intent file present, ecosystem supported, release < 24 h old | ❌ fail → needs-human issue naming hours remaining |
| Intent file present, ecosystem not supported (e.g. `cargo`) | ⚠️ **fail-open** — log `::warning::`, skip the gate |
| Intent file present, version not found on registry | ❌ hard-fail → needs-human |
| Intent file **missing** on a shepherd-agent PR | ❌ **hard-fail** → needs-human naming "`.shepherd-intent.json` missing — agent-call.sh drift" |
| `gates.waiting_period_hours: 0` in `.shepherd.yml` | ⏭ gate disabled, skip with `::notice::` |

**CAP flipped `design → active`**

- `gate.waiting-period` — fully active on both agent flow (SH-010) and Dependabot flow (SH-011).

## 4. How urgent?

- [x] R1 critical path — the last of the five §12 gates for the agent flow. Target Fri 4 Dec.
- [x] Security-critical — catches day-one supply-chain poisonings (event-stream class) that advisory DBs haven't caught up to yet.
- [x] Closes the §12 trust-boundary promise. Every §12 gate goes from design or partial → active after this story.

## 5. Happy path

```
# Daily cron on onboarded repo:
1. Agent produces a diff (manifest bump) + intent JSON:
     {ecosystem: npm, package: lodash, from: 4.17.20, to: 4.17.21}
2. validate.sh + regen-lockfile + open-pr.sh → PR opened with
   .shepherd-intent.json committed alongside the manifest diff.
3. Caller's shepherd-gates.yml fires. Gates workflow:
   - gate.diff-size:        ok
   - gate.pipelines-green:  ok
   - gate.scan-not-worse:   added=0 → ok
   - gate.security-fix-removes-finding: label absent → skip
   - gate.waiting-period:   reads .shepherd-intent.json; calls
                            age-of-release.sh npm lodash 4.17.21
                            → "2026-11-19T10:00:00Z"
                            → age=56h ≥ 24h → ok
   → gh pr merge --auto --merge → merged by app/github-actions
```

## 6. Edge cases / failure modes that matter

- **Clock skew between runner and registry.** Both return UTC; `date -d` handles timezone. Still, use `age_hours ≥ cap` (inclusive) to avoid off-by-one at the boundary.
- **Registry API temporarily down.** `age-of-release.sh` exits 2 (not-found) if `curl` returns non-200. Gate fails → needs-human. User's intervention is "re-run later." Not auto-merging a day-zero release because the registry is down is honest.
- **Pre-release / yanked version.** PyPI / npm expose these differently. For now, treat any version present in the `.time` map (npm) or `.releases` (pip) as valid; skip the "yanked" check (follow-up IDEAS entry if needed).
- **Multi-package agent PR.** The agent emits ONE intent. If it bumps two packages, only one is in the intent — the other evades the gate. **Mitigation**: `validate.sh` already caps diffs at 50 non-lockfile lines; a multi-package PR is unusual within that budget. Document the limitation; R2 adds structured-intent-array if needed.
- **Agent emits intent with wrong version.** E.g., the intent says `to: 1.2.3` but the diff bumps to `1.2.4`. Not detected in SH-010; opens a possible injection vector. **Mitigation**: SH-010 trusts the intent (same trust model as the agent's diff). A cross-check between intent and diff lands in R2 (structured-intent-verification).
- **`.shepherd.yml` → `gates.waiting_period_hours: 0`**. Gate disabled — explicit opt-out, auto-merge fires immediately. Logged as `::notice::`. Legitimate for internal-only repos or test fleets.

## 7. Out of scope

- Multi-package intent (array of {package, from, to}) — R2.
- Intent-vs-diff cross-check — R2.
- Yanked-version detection — IDEAS.
- Rust (`cargo`), Docker, Zig ecosystems in `age-of-release.sh` — initial cut is npm + pip + gh-actions + gomod. Others are fail-open.
- Any change to the Dependabot `dependabot-automerge.yml` flow — SH-011's waiting-period stays as-is.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: Fresh release — gate blocks
  Given a shepherd-agent PR with .shepherd-intent.json pointing at npm::lodash@<fresh-version>
  And the npm registry reports <fresh-version> released 2 hours ago
  When gate.waiting-period evaluates
  Then the gate fails
  And a needs-human issue is opened naming "22 hours remaining"
  And no auto-merge is enabled

Scenario: Aged release — gate passes
  Given a shepherd-agent PR with intent pointing at npm::lodash@4.17.21 (released 2026-10-01)
  When gate.waiting-period evaluates
  Then the gate passes
  And subsequent auto-merge path runs

Scenario: Unknown ecosystem — fail-open
  Given a shepherd-agent PR with intent ecosystem="cargo"
  When gate.waiting-period evaluates
  Then age-of-release.sh exits 3
  And the gate emits ::warning:: and skips
  And subsequent gates run normally

Scenario: Missing intent file — hard fail
  Given a shepherd-agent PR with NO .shepherd-intent.json committed
  When gate.waiting-period evaluates
  Then the gate fails
  And a needs-human issue names "intent file missing — agent-call.sh drift"

Scenario: waiting_period_hours=0 — gate disabled
  Given .shepherd.yml → gates.waiting_period_hours: 0
  When gate.waiting-period evaluates
  Then it emits ::notice:: "disabled by config" and skips
```

## 9. Capabilities delivered or extended

- `gate.waiting-period` — flips `active (partial)` → `active` (now covers agent flow + Dependabot flow).
- `onboarding.structured-intent` (new) — the agent emits a machine-readable intent alongside the diff. R2 extensions will tighten the trust model.

---

## Plan doc

Lives at [`docs/plan/SH-010-waiting-period-plan.md`](../plan/SH-010-waiting-period-plan.md).
