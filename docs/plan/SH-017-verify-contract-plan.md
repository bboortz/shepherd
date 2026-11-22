---
id: SH-017
slug: verify-contract
story: docs/stories/SH-017-verify-contract.md
branch: feat/SH-017-verify-contract
status: shipped
---

# SH-017 plan — `shepherd-bump --verify-contract`

**Story:** [SH-017](../stories/SH-017-verify-contract.md)

## Design delta

Extends `bump.zig` with a new `verify_contract` Mode. Symmetric with
`--verify-dependabot` (SH-011): opt-out via `.shepherd.yml`, specific
exit codes, dogfoods on shepherd itself.

**Scope**: check that the Makefile at `--root` declares the 9 SH-014
contract targets. Any missing target → exit 4 with per-target
`missing target \`<name>\`` lines (easy to grep + paste into a
needs-human issue). Opt-out via `.shepherd.yml → contract:
{ enforce_enabled: false }` (section-aware).

**New in `bump.zig`** (~140 lines):

- `Mode.verify_contract` + `--verify-contract` arg parsing
- `CONTRACT_TARGETS[9]` constant
- `leadingWsLen` helper (YAML indent tracking)
- `isContractOptOut` — section-aware scanner: tracks `contract:` section
  entry via top-level key + checks for `enforce_enabled: false` inside
- `makefileHasTarget` — scans for recipe-line `<target>:` OR
  `.PHONY:`-listed token
- `cmdVerifyContract` — opens root, honors opt-out, reads Makefile,
  checks each target, emits summary

**New test**: `test/acceptance/test_SH_017_verify_contract.sh` (15
assertions, 6 fixture scenarios in tmpdir).

**CAP flipped**: `dev-cycle.fleet.verify-contract` design → active.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Bash script (`scripts/verify-contract.sh`) instead of Zig | shepherd's bump engine is Zig; symmetric with `--verify-dependabot`. One dispatch point, one `make build` pipeline. |
| Full GNU Make AST parser | Overkill. `<target>:` at line start + `.PHONY:`-listed is strict enough for the contract check. |
| Not section-aware (global `enforce_enabled: false` match) | Would false-positive opt out when dependabot opts out and contract is active. Section tracking is ~12 lines. |
| Post-check: open a needs-human issue | SH-017's scope is the verifier itself. Issue-opening belongs in the reusable workflow that calls `--verify-contract`. The exit codes + stderr are enough to drive that from the caller. |

## Breaking changes

- [ ] No. Additive: new subcommand. No existing flows change behaviour.

## Rollout

- [x] README untouched — internal verifier, no public-contract shift.
- [x] `docs/specs/DESIGN.md` unchanged.
- [x] `memory/workflow.md` unchanged.
- [ ] Downstream: reusable-shepherd.yml could grow a `--verify-contract` step
  (symmetric with the existing `--verify-dependabot` step) — follow-up PR,
  not in this story's scope.

**R2 slot**: Fri 2026-12-11. Shipping now in-band with the SH-014 umbrella rollout.

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Binary exists + help lists --verify-contract | `test_SH_017_verify_contract.sh:§1` | ✅ |
| Shepherd itself passes verify-contract | `test_SH_017_verify_contract.sh:§2` | ✅ |
| Missing Makefile → exit 3 | `test_SH_017_verify_contract.sh:§3` | ✅ |
| Partial Makefile → exit 4 + per-target "missing" | `test_SH_017_verify_contract.sh:§4` | ✅ |
| Complete Makefile → exit 0 | `test_SH_017_verify_contract.sh:§5` | ✅ |
| Opt-out via .shepherd.yml → exit 0 (even w/o Makefile) | `test_SH_017_verify_contract.sh:§6` | ✅ |
| Section-aware: dependabot off ≠ contract off | `test_SH_017_verify_contract.sh:§7` | ✅ |
| .PHONY-only declaration counts as present | `test_SH_017_verify_contract.sh:§8` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `dev-cycle.fleet.verify-contract` | ✅ | ✅ (exits 0 / 3 / 4) | design → active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys §7 (no automated-PR, no workflow wiring) | ✅ |
| New CAP in §9 appears in CAPABILITIES.md | ✅ |
| Protected-files invariant intact | ✅ |
| Budget caps unchanged | ✅ n/a |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

## Post-merge notes

_(filled after merge)_
