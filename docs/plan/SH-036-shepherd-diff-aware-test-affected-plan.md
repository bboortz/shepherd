---
id: SH-036
slug: shepherd-diff-aware-test-affected
story: docs/stories/SH-036-shepherd-diff-aware-test-affected.md
branch: feat/SH-036-test-affected
status: shipped
---

# SH-036 plan — shepherd diff-aware `test-affected`

**Story:** [SH-036](../stories/SH-036-shepherd-diff-aware-test-affected.md)

## Design delta

Replace the identity alias `test-affected: test-acceptance` with a diff-aware wrapper script that selects the relevant tests from the current working-tree diff against the integration branch (default: `origin/dev`).

### Selection rules

| Changed file pattern | Action |
|---|---|
| `test/acceptance/test_SH_<N>_*.sh` | run that test |
| `docs/stories/SH-<N>-*.md` | run `test_SH_<N>_*.sh` |
| `docs/plan/SH-<N>-*.md` | run `test_SH_<N>_*.sh` |
| `scripts/shepherd-poc/<name>.sh` | run tests that grep-mention `<name>` |
| anything else | always-on safety net: `test_SH_012` (docs-layout) + `test_SH_013` (traceability) |

### Full-run bailouts

| Trigger | Reason |
|---|---|
| `Makefile` | changes recipes for every target; could affect anything |
| `bump.zig` / `build.zig` | changes the shepherd-bump binary; potentially affects every verify-* test |
| `.github/workflows/**` | changes workflow shape; test_SH_011/017/030/033 all reference workflows |
| `docs/specs/CAPABILITIES.md` | CAP changes propagate through traceability links |
| `scripts/test-affected.sh` | self-change: safest to run everything |
| no diff detectable | nothing to select against; fall back to full |

### Changed files

- `scripts/test-affected.sh` (new, 95 lines pure sh).
- `Makefile` — `test-affected:` now `build + sh scripts/test-affected.sh` instead of `test-acceptance`.
- `test/acceptance/test_SH_036_test_affected.sh` — 15 assertions covering script existence/shellcheck, Makefile wiring, full-run regex coverage, env-override, selection-rule source refs, behavioural `--list` sanity.
- `docs/specs/CAPABILITIES.md` — new CAP `dev-cycle.shepherd.test-affected-diff-aware`.
- Story + plan docs (this).

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Keep identity alias, mark audit column 11 ✅ with "contract-permitted" rationale | User explicitly asked to "fix all consistency issues". Honest "fix" means wiring real diff-awareness, not reframing the audit. |
| Full module-graph parse (parse `Covers:` headers in test files → trace CAP → trace stories) | Overkill. Simple filename pattern matching captures 95% of correlations with ~100 lines of sh. |
| Use `make -q` style target-dependency tracing | Make doesn't know about docs→test pointers. Would need meta-dependencies in Makefile — too invasive. |
| External tool (`git-nx-affected` etc.) | Adds a third-party dep; shepherd's §12 bans third-party in critical path. |

## Breaking changes

- No. `make test-affected` previously ran the full acceptance suite; now it runs a subset when the diff permits. Full suite still fires via `make test` / `make test-acceptance`.
- CI impact: `make ci-branch` on shepherd drops from ~N tests → ~1-3 on docs-only PRs. On code PRs touching `bump.zig` / Makefile / workflows, falls back to full-run (no change in coverage).

## Rollout

- [x] Script + Makefile wired.
- [x] Acceptance test lands.
- [x] CAP registered.
- [x] Dogfood: `make test-affected` works on dev HEAD (full-run bailout on Makefile edit confirmed).

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Script exists + executable | `test_SH_036:§1` | ✅ |
| Shellcheck-clean | `test_SH_036:§1` | ✅ |
| Makefile wires to script | `test_SH_036:§2` | ✅ |
| No longer identity alias | `test_SH_036:§2` | ✅ |
| `--list` mode exits 0 | `test_SH_036:§3` | ✅ |
| Full-run regex covers Makefile / bump.zig / CAPABILITIES / workflows | `test_SH_036:§4` | ✅ |
| `TEST_AFFECTED_BASE` env knob documented | `test_SH_036:§5` | ✅ |
| Selection rules source-asserted | `test_SH_036:§6` | ✅ |
| `--list` emits a recognised status line | `test_SH_036:§7` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Edge cases tested? | Status |
|---|---|---|---|
| `dev-cycle.shepherd.test-affected-diff-aware` | ✅ | ✅ (full-run + diff-aware + no-changes) | new, active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Fleet audit column 11 for shepherd: ⚠️ → ✅ | ✅ |
| Shellcheck zero-warnings | ✅ |
| Safety-first: unknown-path diff always includes traceability test | ✅ |
| `make check` green (16 acceptance tests, 368 assertions) | ✅ |

## Post-merge notes

- Future: build equivalent `scripts/test-affected.sh` on healthy + kernel-test to close the remaining 2 column-11 ⚠️ cells (SH-037 + SH-038, one per repo).
