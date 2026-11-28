---
id: SH-058
slug: verify-shipped-status
story: docs/stories/SH-058-verify-shipped-status.md
branch: feat/SH-058-verify-shipped-status
status: shipped    # in-progress → shipped
---

# SH-058 plan — `verify-shipped-status`

**Story:** [SH-058](../stories/SH-058-verify-shipped-status.md)

## Design delta

New files:

- `scripts/verify-shipped-status.sh` — POSIX sh, ~50 lines, sibling to
  `scripts/verify-index-status.sh`. Resolves repo root from its own dir. For
  each `CHANGELOG.md` line matching `^## \[v` (released headings; `[Unreleased]`
  excluded by the `[v` prefix), extracts `SH-[0-9]+` tokens, dedupes, and for
  each token with a matching `docs/stories/SH-NNN-*.md` asserts frontmatter
  `status: shipped`. Exit 1 on any violation (naming story + version), else 0.
  No-op exit 0 when `CHANGELOG.md` is absent.
- `test/acceptance/test_SH_058_verify_shipped_status.sh` — dogfood pass + drift
  catch (flip SH-057 to in-progress) + `[Unreleased]`-exempt fixture + missing-
  story-file fixture + Makefile wiring + no-CHANGELOG no-op.

Edited files:

- `Makefile` — `.PHONY` += `verify-shipped-status`; new target; add it to
  `check-docs` (so `make check`, pre-push, and `ci-branch` all run it, exactly
  like `verify-index-status`).
- `docs/specs/CAPABILITIES.md` — new row `dev-cycle.verify-shipped-status`
  under the dev-cycle section.
- `docs/stories/INDEX.md` — SH-058 row.
- `VERSION` → `0.12.0-rc1` (minor: new enforced gate).
- `CHANGELOG.md` — `[v0.12.0-rc1]` entry.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Extend `verify-index-status.sh` instead of a new script | Different source of truth (CHANGELOG vs INDEX↔frontmatter) and a different failure story. Keeping them separate keeps each check single-purpose and its message precise. |
| Scan the whole released CHANGELOG section body | Bodies name follow-ups and related stories that may be legitimately unshipped → false positives. The heading is the "this version delivered X" signal. |
| Cross-check against git tags | Tags and CHANGELOG headings are 1:1 here already; the CHANGELOG is the human-authored intent and is enough. Tag cross-check parked as a follow-up (story §7). |
| Fail on heading-named stories with no file | Would couple shepherd's gate to story IDs from other repos / pre-stories-dir history. Skip-if-absent keeps it portable (story §6). |

## Breaking changes

- [x] No — strictly additive. New script + target + CAP + test; a new gate that
      is green on the current tree (verified: all heading-referenced stories are
      already shipped). No existing gate/default/schema touched.

## Rollout

- [ ] README updated — not required (internal docs gate, no public contract).
- [ ] `memory/*` invariants — unchanged.
- [ ] `docs/specs/DESIGN.md` — unchanged.
- [ ] Downstream notice — n/a.

## Shipping evidence (filled at step 6a)

### Lens 1 — Gherkin coverage

| Scenario (from story §8) | Test pointer | Status |
|---|---|---|
| Script exists + executable | `test_SH_058…` S1 | ✅ |
| Shepherd passes (dogfood) | `test_SH_058…` S2 | ✅ |
| Released-but-unshipped fails | `test_SH_058…` S3 | ✅ |
| `[Unreleased]` exempt | `test_SH_058…` S4 | ✅ |
| Heading-named story with no file skipped | `test_SH_058…` S5 | ✅ |
| Makefile exposes + check-docs runs it | `test_SH_058…` S6 | ✅ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `dev-cycle.verify-shipped-status` | yes | pass + fail + 2 exempt/skip + no-CHANGELOG | ✅ |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (heading-only, no auto-fix, no tag cross-check) | ✅ |
| New CAP in §9 appears in `docs/specs/CAPABILITIES.md` | ✅ |
| Protected-files invariant intact (DESIGN §12) | ✅ |
| Budget caps unchanged | n/a |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

## Post-merge notes

Born directly from the SH-056 drift found this session: SH-056 shipped in
`v0.10.1-rc1` but sat at `in-progress` (fixed in PR #62). This gate makes that
class of drift impossible to merge going forward.
