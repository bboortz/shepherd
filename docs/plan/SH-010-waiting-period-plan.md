---
id: SH-010
slug: waiting-period
story: docs/stories/SH-010-waiting-period.md
branch: feat/SH-010-waiting-period
status: in-progress
---

# SH-010 plan — R1-D: waiting-period on the agent flow

**Story:** [SH-010](../stories/SH-010-waiting-period.md). Umbrella: [SH-006](../stories/SH-006-r1-reusable-action.md).

## Design delta

### New files

- `scripts/shepherd-poc/age-of-release.sh` — standalone registry lookup. Takes `<ecosystem> <package> <version>`; emits ISO-8601 release timestamp to stdout. Exit codes: `0` ok, `2` not-found (hard fail), `3` unknown-ecosystem (fail-open signal).
- `test/acceptance/test_SH_010_waiting.sh` — fixtures: fresh / aged / unknown / missing-intent.

### Modified files

- `scripts/shepherd-poc/agent-call.sh` — prompt addendum: emit `<intent>{...}</intent>` block after the diff. Extract via awk; write `$INTENT_PATH` (default `/tmp/intent.json`).
- `scripts/shepherd-poc/open-pr.sh` — if `$INTENT_PATH` present and non-empty, copy to `.shepherd-intent.json` in the working tree before committing. Hard-fail (exit 2) if intent is empty/missing on a shepherd-agent flow run (detect via env marker set by agent-call.sh success path).
- `scripts/shepherd-poc/validate.sh` — intent file is a trusted-step output; ensure PROTECTED_RE still blocks the AGENT from writing it, but the committed file (written by open-pr.sh outside the agent diff) passes.
- `.github/workflows/reusable-shepherd-gates.yml` — new step `gate.waiting-period` after `scan-not-worse`. Reads `head/.shepherd-intent.json`; calls `_shepherd/scripts/shepherd-poc/age-of-release.sh`; computes age; gate on `gates.waiting_period_hours`.
- `templates/shepherd.yml` — schema v1 field `gates.waiting_period_hours: 24`.
- `docs/specs/CAPABILITIES.md` — `gate.waiting-period` flips to active (full).

### Ecosystem support in age-of-release.sh

| Ecosystem | API | Field |
|---|---|---|
| `npm` | `GET https://registry.npmjs.org/<name>` | `.time[<version>]` |
| `pip` | `GET https://pypi.org/pypi/<name>/json` | `.releases[<version>][0].upload_time` |
| `gh-actions` / `github_actions` | `gh api repos/<owner>/<repo>/releases/tags/v<version>` (fallback `tags/<version>`) | `.published_at` |
| `gomod` | `GET https://sum.golang.org/lookup/<name>@v<version>` | 2nd line (`YYYY-MM-DDTHH:MM:SSZ`) — new |
| anything else | exit 3 → fail-open | — |

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Parse the PR diff for (package, version) in the gates workflow | Fragile — overrides blocks, multi-dep, non-`package.json` ecosystems. Explicit intent file is the forward-compat move. |
| Emit intent in the PR body | HTML comments renderer-dependent + title-injection risk. File is cleaner. |
| Fail-open on missing intent file | User's decision: hard-fail. Catches agent-call.sh drift immediately rather than silently regressing. |
| Fail-closed on unknown ecosystem | User's decision: fail-open. Matches SH-006 explicitly, avoids an "auto-merge cliff" when shepherd learns a new ecosystem. |
| Reuse the Dependabot flow's waiting-period logic in-place | SH-011's code lives inside `templates/dependabot-automerge.yml`. SH-010 factors it into a shared `age-of-release.sh` so both flows call the same code going forward. Dedupe only; no behaviour change on SH-011. |

## Breaking changes

- [x] Yes — shepherd-agent PRs **must** carry `.shepherd-intent.json` from this ship forward, or `gate.waiting-period` hard-fails. All three pilots use the central `scripts/shepherd-poc/agent-call.sh`, so the rollout is centralised.

## Rollout

- [ ] `make check` green locally.
- [ ] Shepherd PR merges.
- [ ] Repin healthy / beaconry / HRC to the SH-010 SHA.
- [ ] Craft a synthetic shepherd-agent PR with a `.shepherd-intent.json` → observe `gate.waiting-period` evaluating.
- [ ] One canary scenario per outcome (aged-pass / fresh-fail / unknown-skip / missing-hard-fail) OR rely on test_SH_010_waiting.sh fixtures (likely sufficient — live only for the pass path).

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Fresh release — blocks | `test_SH_010_waiting.sh` (age<cap fixture) | TBD |
| Aged release — passes | `test_SH_010_waiting.sh` (age>cap fixture) | TBD |
| Unknown ecosystem — fail-open | `test_SH_010_waiting.sh` (cargo fixture) | TBD |
| Missing intent — hard fail | `test_SH_010_waiting.sh` (no-file fixture) | TBD |
| waiting_period_hours=0 — disabled | `test_SH_010_waiting.sh` (config fixture) | TBD |

### Lens 2 — CAP evidence

| CAP | Status |
|---|---|
| `gate.waiting-period` (full) | TBD |
| `onboarding.structured-intent` (new) | TBD |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story §7 obeyed (no multi-package intent, no intent-vs-diff cross-check) | TBD |
| New CAPs listed in §9 appear in CAPABILITIES.md | TBD |
| SH-001 SHA-pinning preserved | TBD |
| `make injection-drill` still green (no SH-005 regression) | TBD |
| `make check` green | TBD |

## Post-merge notes

<Filled after the live canary runs through all five §12 gates.>
