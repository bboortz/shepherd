---
id: SH-027
slug: risk-paths
story: docs/stories/SH-027-risk-paths.md
branch: feat/SH-027-risk-paths
status: shipped
---

# SH-027 plan — risk-paths: human-approval gate (distinct from §12 blocklist)

**Story:** [SH-027](../stories/SH-027-risk-paths.md)

## Design delta

New gate `gate.risk-paths-requires-approval` in
`reusable-shepherd-gates.yml`. Reads `.shepherd.yml → risk_paths:
[glob, ...]` (block-list); for each PR-changed file, runs sh `case`
glob match against each configured path. Any match → `escalate()`
with the touched paths list.

Distinct from `blocklist.protected-files` (§12): blocklist bars the
agent from WRITING a path at all; risk-paths let the agent write but
force a human to approve before auto-merge.

### New files

- `scripts/shepherd-poc/gate-risk-paths.sh` (~60 lines sh) — standalone
  matcher, shipped so the acceptance test can exercise the parse + match
  logic offline. Reused inline by the workflow.
- `test/acceptance/test_SH_027_risk_paths.sh` (12 assertions, 8 scenarios).

### Changed files

- `.github/workflows/reusable-shepherd-gates.yml` — insert the new gate
  right after `gate.diff-size` (same `/tmp/sh-009/ctx` + `escalate()`
  pattern). Reads risk_paths block via inline awk; matches via sh `case`.
- `docs/specs/CAPABILITIES.md` — CAP `risk-paths.human-approval-required`
  design → active with test pointer.
- `docs/stories/SH-027-risk-paths.md` → shipped.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Use a real YAML parser (python3-yaml) | Workflow gate must stay pure-sh — zero dep install step. awk + grep handles block-list. |
| Match via `find ... -path` | Doesn't give us the `glob` identity for the needs-human message. sh `case` returns the matched glob implicitly. |
| Reuse `.shepherd.yml → blocklist` for risk-paths | Breaks §12 semantics (bar-write vs require-review). Different fields, different intents. |
| Inline-only (no standalone script) | Can't test parse+match logic offline. Shipping the extractable script costs 60 lines + full fixture coverage. |

## Breaking changes

- [ ] No. Opt-in via `.shepherd.yml → risk_paths: [...]`. Absent config = gate is a no-op.
- Managed repos with existing `.shepherd.yml` but no `risk_paths` key: nothing changes.

## Rollout

- [x] README untouched.
- [x] `docs/specs/DESIGN.md` §12 reference line updated in the SH-014 umbrella; no further §12 change needed.
- [x] `templates/shepherd.yml` already includes the commented `risk_paths: []` default (added by SH-014 umbrella).
- [ ] Downstream notice — n/a. Opt-in by repo.

**R2 slot:** ships in-band with SH-028 auto-revert (both are governance pieces on the same workflow).

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Script executable | `test_SH_027_risk_paths.sh:§0` | ✅ |
| No risk_paths configured → exit 0 | `test_SH_027_risk_paths.sh:§1` | ✅ |
| risk_paths present + no match → exit 0 | `test_SH_027_risk_paths.sh:§2` | ✅ |
| One glob matches → exit 2 + emits matched file:glob | `test_SH_027_risk_paths.sh:§3` | ✅ |
| Multi-glob matches → exit 2 | `test_SH_027_risk_paths.sh:§4` | ✅ |
| Comments in config don't confuse parser | `test_SH_027_risk_paths.sh:§5` | ✅ |
| Malformed config (no risk_paths) → exit 0 | `test_SH_027_risk_paths.sh:§6` | ✅ |
| Empty block list → exit 0 | `test_SH_027_risk_paths.sh:§7` | ✅ |
| Usage error → exit 3 | `test_SH_027_risk_paths.sh:§8` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Exit paths tested? | Status |
|---|---|---|---|
| `risk-paths.human-approval-required` | ✅ | ✅ (0 / 2 / 3) | design → active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story §7 obeyed (no CODEOWNERS auto-assignment, no non-agent-PR blocking) | ✅ |
| New CAP in CAPABILITIES.md | ✅ |
| Protected-files invariant intact | ✅ |
| Budget caps unchanged | ✅ n/a |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

## Post-merge notes

_(filled after merge)_
