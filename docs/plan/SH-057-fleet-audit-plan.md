---
id: SH-057
slug: fleet-audit
story: docs/stories/SH-057-fleet-audit.md
branch: feat/SH-057-fleet-audit
status: shipped    # in-progress → shipped
---

# SH-057 plan — `make fleet-audit`: one repeatable fleet arming + health audit

**Story:** [SH-057](../stories/SH-057-fleet-audit.md)

## Design delta

New files:

- `scripts/fleet-audit.sh` — POSIX sh. The audit *procedure*. Structure:
  1. **Parse** the `docs/FLEET.md` Active table → list of `owner/repo` (the
     registry is the single source of truth; nothing hardcoded).
  2. **Probe** each repo through small single-purpose functions. Each function
     prints one of `OK` / `MISS` / `SKIP` / `WARN` plus a note. Live probes
     (topic, secret, pin, pipeline conclusions, branch, file contents via
     `gh api`) are guarded by `have_gh`; in `--offline` mode they short-circuit
     to `SKIP`.
  3. **Render** three Markdown matrices + a pipeline-health section + a verdict,
     to `--out <path>` (default `docs/specs/fleet-audit-<date>.md`).
  4. **Verdict** is derived mechanically: `FULLY ARMED` iff zero `MISS`/`WARN`
     across arming + best-practice cells *and* zero red pipeline; else
     `DRIFT DETECTED (<armed>/<total> fully armed)` with a ranked findings list.
- `test/acceptance/test_SH_057_fleet_audit.sh` — runs the script `--offline`
  against the real `docs/FLEET.md` and against a synthetic empty-FLEET fixture;
  asserts structure, row count, SKIP-not-FAIL for live cells, Makefile wiring.

Edited files:

- `Makefile` — add `.PHONY: fleet-audit` + a `fleet-audit:` target calling the
  script. **Not** wired into `check` / `ci-*` (it needs the network and is an
  operator tool, not a gate). New acceptance test auto-picked by the
  `test/acceptance/test_SH_*.sh` wildcard.
- `docs/specs/CAPABILITIES.md` — new `## Fleet audit` section with
  `fleet.audit.repeatable`, bidirectionally linked to the test.
- `docs/stories/INDEX.md` — SH-057 row.
- `VERSION` → `0.11.0-rc1` (minor: new operator-facing capability).
- `CHANGELOG.md` — `[v0.11.0-rc1]` entry.

The check catalogue folds the two prior manual audits into one definition:

| Section | Columns | Source audit |
|---|---|---|
| Arming matrix | topic · `.shepherd.yml` · dependabot · Makefile · shepherd caller · gates caller · `ANTHROPIC_API_KEY` · `dry_run` · pin freshness | 2026-11-28 workflow |
| Best-practice matrix | default=dev · dev+main · 9 Makefile targets · schema v1 · dependabot · ci-tiered · shepherd caller · gates caller · SHA-pin · pre-push · test-affected | 2026-11-22 workflow |
| Pipeline health | last `shepherd` cron + `ci-{branch,patch,release,nightly}` conclusions; recent red runs | new (the "all pipelines green" requirement) |

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Zig subcommand `shepherd-bump --audit` | The audit is orchestration over `gh` + text, not bump logic; a shell script matches the other fleet verifiers (`measure-baseline.sh`, `digest-timing.sh`) and needs no rebuild to run. |
| Wire into `make check` / CI as a gate | Needs network + `gh` auth; would make CI flaky and couples a release gate to live GitHub state. The audit is a human-pulled snapshot; keep it out of the blocking path (story §7). |
| Hardcode the six repos | FLEET.md is the registry (`memory/project.md`); hardcoding would drift the moment a 7th repo lands. Parse the Active table. |
| Exit non-zero on drift (`--strict`) | Would let the audit wedge a release on transient GitHub state. Verdict lives in the report; `--strict` parked as a follow-up (story §7). |
| A new top-level audits directory under docs | `verify-docs-layout` enforces specs/plan/stories only; both prior audits live under specs. Keep the convention. |

## Breaking changes

- [x] No — strictly additive. New script, new target, new CAP, new test. No
      existing gate, default, protected-files entry, or schema changes.

The audit is **read-only** against managed repos — it never writes to them,
preserving the §12 posture (topic adds / `dry_run` flips stay human actions).

## Rollout

- [ ] README updated — not required; `fleet-audit` is an internal operator tool,
      not part of the public onboarding contract. (Noted for R2 if the fleet
      layer surfaces it publicly.)
- [ ] `memory/project.md` invariants — unchanged.
- [ ] `docs/specs/DESIGN.md` — unchanged (no §12 decision moved).
- [ ] Downstream notice — n/a (no gate defaults moved).

## Shipping evidence (filled at step 6a)

Three lenses. Any ⚠️/❌ row blocks shipping.

### Lens 1 — Gherkin coverage

| Scenario (from story §8) | Test pointer | Status |
|---|---|---|
| Script exists + executable | `test_SH_057_fleet_audit.sh` S1 | ✅ |
| Offline run → full structure, exit 0 | `test_SH_057_fleet_audit.sh` S2 | ✅ |
| Repo list parsed from FLEET.md | `test_SH_057_fleet_audit.sh` S3 | ✅ |
| Live cells SKIPPED not failed | `test_SH_057_fleet_audit.sh` S4 | ✅ |
| Makefile exposes + resolves `fleet-audit` | `test_SH_057_fleet_audit.sh` S5 | ✅ |
| Empty FLEET.md Active does not crash | `test_SH_057_fleet_audit.sh` S6 | ✅ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `fleet.audit.repeatable` | yes | offline + empty-fixture + SKIP-not-FAIL | ✅ |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (no auto-remediation, no cron, no --strict) | ✅ |
| New CAP listed in §9 appears in `docs/specs/CAPABILITIES.md` | ✅ |
| Protected-files invariant intact (DESIGN §12) — audit is read-only | ✅ |
| Budget caps unchanged | n/a |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

## Post-merge notes

Seeded by two hand-written precursors (`fleet-consistency-audit-2026-11-22.md`,
`…-2026-11-28.md`). The 2026-11-28 pass found three pilots missing the
`shepherd-managed` topic a week after onboarding — exactly the drift a one-command
repeatable audit exists to surface the same day. First live `make fleet-audit`
output recorded alongside this plan.
