---
id: SH-057
slug: fleet-audit
status: shipped        # draft → ready → in-progress → shipped
created: 2026-11-28
owner: @benni
---

# SH-057 — `make fleet-audit`: one repeatable fleet arming + health audit

## 1. Who is the consumer?

The **operator** of the fleet (today: @benni) who needs to answer, on demand and
always the same way, "is every armed repo actually, fully armed, and are all
its pipelines green?" Until SH-057 the answer came from ad-hoc audits written by
hand (`docs/specs/fleet-consistency-audit-2026-11-22.md`, `…-2026-11-28.md`) —
each a different shape, each only as complete as the person remembered to be.

## 2. When does the story fire?

On demand — `make fleet-audit` — before a release, after onboarding a pilot, or
whenever the operator wants fleet health in one glance. Not scheduled (a cron
digest is SH-020's job); this is the human-pulled, full-depth snapshot.

## 3. What does success look like?

One command produces one Markdown file at a deterministic path with a fixed
structure, every time:

- **Arming matrix** — per repo: `shepherd-managed` topic, `.shepherd.yml`,
  dependabot baseline, Makefile, shepherd + gates caller workflows,
  `ANTHROPIC_API_KEY` secret, `dry_run` state, caller pin freshness.
- **Best-practice conformance matrix** — the 11 columns from the 2026-11-22
  audit (default branch, dev+main, 9 Makefile targets, `.shepherd.yml` schema,
  dependabot, ci-tiered workflows, both callers, SHA-pin, pre-push, test-affected).
- **Pipeline health** — last conclusion of each repo's `shepherd` cron and its
  `ci-*` tiers; any red run in the recent window is called out.
- **Verdict** — a single machine-derived line: `FULLY ARMED` when every cell is
  green and every pipeline is green, else `DRIFT DETECTED` with the count and a
  ranked findings list.

Mechanically checkable: the repo list is parsed from `docs/FLEET.md` (not
hardcoded); the script exits 0 and the output file contains every section header
and the verdict line. Live GitHub cells need `gh`; an `--offline` mode renders
the same structure with live cells marked `SKIPPED` so CI can prove the
procedure is well-formed without the network.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (two prior audits disagreed on shape; drift like the three
      missing `shepherd-managed` topics found on 2026-11-28 went unnoticed for a
      week — a repeatable procedure catches it the day it happens)
- [x] Quality-of-life (replaces hand-written audits with one command)
- [ ] Onboarding

## 5. Happy path

```
$ make fleet-audit
fleet-audit: 6 repos from docs/FLEET.md
fleet-audit: gh available — live checks on
fleet-audit:   bboortz/healthy            armed ✓  pipelines ✓
fleet-audit:   bboortz/beaconry           armed ✓  pipelines ✓
fleet-audit:   bboortz/ham-radio-compass  armed ✓  pipelines ✓
fleet-audit:   bb-claw/homelab            DRIFT: no topic; dry_run
fleet-audit:   bb-claw/kernel-test        DRIFT: no topic; dry_run
fleet-audit:   bboortz/forge              DRIFT: no topic; dry_run
fleet-audit: VERDICT — DRIFT DETECTED (3 of 6 fully armed)
fleet-audit: wrote docs/specs/fleet-audit-2026-11-28.md
$ echo $?
0
```

Exit code is 0 whether or not drift is found — the audit always succeeds at
*auditing*; the verdict lives in the report, not the exit code. (A `--strict`
flag that exits non-zero on drift is out of scope, noted in §7.)

## 6. Edge cases / failure modes that matter

- **`gh` absent or unauthenticated** → fall back to `--offline` behaviour for
  live cells (mark `SKIPPED (no gh)`), still emit every offline-derivable cell
  and the full structure. Never hard-fail.
- **A repo in `docs/FLEET.md` was deleted / is unreachable** → that repo's row
  is all `?` with a `(unreachable)` note; the audit continues.
- **`docs/FLEET.md` Active table empty or malformed** → exit 0 with a report
  stating "no repos parsed"; do not crash.
- **A private repo the token can't see** (`bb-claw` repos under a `bboortz`
  token) → live cells `SKIPPED (no access)`, not a false ❌.
- **A managed repo missing a file entirely** (no Makefile) → ❌ cell, not a
  script error.
- **Someone adds a 7th repo to FLEET.md** → it appears automatically; nothing in
  the script is hardcoded to six.

## 7. Out of scope

- No scheduling / cron — SH-020's digest owns the automated cadence; this is the
  human-pulled snapshot.
- No `--strict` non-zero-exit gate (could be a follow-up; this story keeps the
  audit non-blocking so it never wedges a release).
- No auto-remediation — the audit reports drift and recommends fixes; it never
  edits a managed repo, adds a topic, or flips `dry_run` (that stays a
  human-reviewed action, symmetric with the §12 protected-files posture).
- No new forge, OS, or model provider.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: the audit script exists and is executable
  Given a clean shepherd checkout
  Then  scripts/fleet-audit.sh is present and +x

Scenario: offline run produces the full report structure
  Given gh is not consulted (--offline)
  When  scripts/fleet-audit.sh --offline --out <tmp> runs
  Then  it exits 0
  And   <tmp> contains the Arming matrix, Best-practice matrix, Pipeline health,
        and Verdict sections
  And   every repo in docs/FLEET.md Active appears as a matrix row

Scenario: the repo list is parsed from FLEET.md, not hardcoded
  Given docs/FLEET.md lists N repos in its Active table
  When  the audit runs --offline
  Then  the report renders exactly those N repo rows

Scenario: offline run marks live-only cells SKIPPED, not failed
  When  scripts/fleet-audit.sh --offline runs
  Then  live-only cells render as SKIPPED, never as ❌

Scenario: Makefile exposes fleet-audit and resolves cleanly
  Then  `make -n fleet-audit` invokes scripts/fleet-audit.sh
  And   .PHONY includes fleet-audit

Scenario: empty FLEET.md Active table does not crash
  Given a fixture repo whose FLEET.md has no Active rows
  When  the audit runs --offline against it
  Then  it exits 0 and the report states no repos were parsed
```

The acceptance test is `test/acceptance/test_SH_057_fleet_audit.sh`. It runs the
script `--offline` only — the live `gh` path is exercised by the operator at
invocation time, not in CI.

## 9. Capabilities delivered or extended

- `fleet.audit.repeatable` — one command (`make fleet-audit` →
  `scripts/fleet-audit.sh`) produces a fixed-structure Markdown audit of the
  whole fleet: arming matrix + 11-column best-practice matrix + pipeline health +
  a machine-derived verdict. Repo list parsed from `docs/FLEET.md`. `--offline`
  mode renders the structure without the network for CI.

New CAP id goes into `docs/specs/CAPABILITIES.md` in this PR with a bidirectional
link to the acceptance test.

---

## Plan doc

[`docs/plan/SH-057-fleet-audit-plan.md`](../plan/SH-057-fleet-audit-plan.md).
