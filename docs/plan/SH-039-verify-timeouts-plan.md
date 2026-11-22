---
id: SH-039
slug: verify-timeouts
story: docs/stories/SH-039-verify-timeouts.md
branch: feat/SH-039-verify-timeouts
status: shipped
---

# SH-039 plan — `shepherd-bump --verify-timeouts`

**Story:** [SH-039](../stories/SH-039-verify-timeouts.md)

## Design delta

Add `cmdVerifyTimeouts` to `bump.zig`. Scans `.github/workflows/ci-{branch,patch,release,nightly}.yml`; emits one line per tier; returns 0 (clean) / 3 (missing file) / 4 (missing key or over-budget).

### Hard-coded tier budgets (per SH-014 spec)

| Workflow | Budget (min) |
|---|---|
| `ci-branch.yml` | 5 |
| `ci-patch.yml` | 5 |
| `ci-release.yml` | 15 |
| `ci-nightly.yml` | 120 (soft) |

### Permissive line-based scan

`readMaxTimeout(contents)` walks lines, matches `<ws>timeout-minutes:<ws><number>` at any indent, strips inline comments, returns the max integer found. Flow-style YAML (`jobs: {p: {timeout-minutes: 5}}`) is explicitly not supported — the fleet uses block-style universally.

### Changed files

- `bump.zig` — new `Mode.verify_timeouts`, `TierBudget` struct, `TIER_BUDGETS` array, `readMaxTimeout`, `cmdVerifyTimeouts` function.
- `test/acceptance/test_SH_039_verify_timeouts.sh` — 18 assertions, 8 scenarios.
- `docs/specs/CAPABILITIES.md` — new CAP `dev-cycle.budget.verify-timeouts`.
- Story + plan docs.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Full YAML parser (`yq`, external dep) | Shepherd's §12 bans third-party in critical path; line-scan is sufficient for the fleet's block-style idiom. |
| Soft fail (exit 0 + warning) on missing key | Enforcement requires loud failure. Missing timeout = silent 360-min inherited default = contract bypass. |
| Separate budget for each repo | SH-014 is explicit: one fleet-wide budget. Per-repo deviations get their own story. |
| Report min instead of max across jobs | Max is worst-case honest; min would let a slow job hide behind a fast one. |

## Breaking changes

- No. Adding a verifier is opt-in. Only affects runs that explicitly invoke `--verify-timeouts`.
- Follow-up PRs (Wave 2) will add `timeout-minutes:` to fleet workflows that are currently missing them.

## Rollout

- [x] Verifier shipped.
- [x] Dogfood on shepherd (ok fleet-wide).
- [x] Acceptance test lands.
- [x] CAP registered.
- [ ] Fleet smoke documented: healthy, beaconry, HRC, forge, homelab, kernel-test — exact gaps surfaced for Wave 2 PRs. (This PR's post-merge notes capture per-repo gaps.)

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Binary exists + executable | `test_SH_039:§0` | ✅ |
| Shepherd dogfood passes | `test_SH_039:§1` | ✅ |
| Clean fixture passes | `test_SH_039:§2` | ✅ |
| Over-budget → exit 4 | `test_SH_039:§3` | ✅ |
| Missing timeout-minutes → exit 4 | `test_SH_039:§4` | ✅ |
| Missing tier workflow → exit 3 | `test_SH_039:§5` | ✅ |
| Inline comment tolerated | `test_SH_039:§6` | ✅ |
| Multi-job picks max | `test_SH_039:§7` | ✅ |
| Bad root → exit 1 | `test_SH_039:§8` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Exit paths tested? | Status |
|---|---|---|---|
| `dev-cycle.budget.verify-timeouts` | ✅ | ✅ (0 / 1 / 3 / 4) | new, active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| No third-party deps added (§12) | ✅ (first-party Zig) |
| Shepherd dogfoods (all 4 tiers ok) | ✅ |
| Permissive scan documented (flow-style not supported) | ✅ |
| `make check` green | ✅ |

## Post-merge notes

**Fleet smoke (2026-11-22)** — pre-Wave-2 gaps:

| Repo | ci-branch | ci-patch | ci-release | ci-nightly |
|---|---|---|---|---|
| shepherd | ✅ 5 | ✅ 5 | ✅ 15 | ✅ 120 |
| healthy | ❌ missing file | ❌ missing file | ✅ 15 | ❌ missing file |
| beaconry | ❌ missing file | ❌ missing file | ✅ 15 | ❌ missing file |
| HRC | ❌ missing file | ❌ missing file | ❌ missing file | ❌ missing file |
| forge | ❌ missing file | ❌ missing file | ✅ 15 | ❌ missing file |
| homelab | ⚠️ no timeout-minutes key | ✅ 5 | ✅ 15 | ❌ missing file |
| kernel-test | ❌ missing file | ❌ missing file | ✅ 15 | ✅ 120 |

(Many "missing file" rows reflect worktree state on `main` where SH-035 hasn't yet promoted. On `dev`, more files are present. Wave 2 PRs land the explicit `timeout-minutes:` on the tier job of each repo's ci-branch.yml — plus fills the gaps still missing on dev.)
