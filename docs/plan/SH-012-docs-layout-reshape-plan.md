---
id: SH-012
slug: docs-layout-reshape
story: docs/stories/SH-012-docs-layout-reshape.md
branch: feat/SH-012-docs-layout-reshape
status: in-progress
---

# SH-012 plan — Reshape `docs/` into specs / plan / stories

**Story:** [SH-012](../stories/SH-012-docs-layout-reshape.md)

## Design delta

- Create `docs/specs/` as the home for authoritative contracts.
- `git mv docs/DESIGN.md docs/specs/DESIGN.md`.
- `git mv docs/CAPABILITIES.md docs/specs/CAPABILITIES.md`.
- `docs/plan/` and `docs/stories/` stay as-is.
- `docs/FLEET.md` and `docs/needs-human.md` stay at the `docs/` root
  (ops reference + escalation template — neither is a spec).
- New meta-spec `docs/specs/docs-layout.md` documents the convention so
  the layout is itself a tracked contract, not folklore.
- New acceptance test `test/acceptance/test_SH_012_docs_layout.sh` enforces
  layout + reference integrity across all tracked files except
  `CHANGELOG.md` (historical).
- `Makefile.verify-traceability` stops being a stub — it now invokes the
  new test.
- Rewrite every *live* reference to `docs/DESIGN.md` →
  `docs/specs/DESIGN.md` and `docs/CAPABILITIES.md` →
  `docs/specs/CAPABILITIES.md` in `CLAUDE.md`, `memory/*.md`, `README.md`,
  moved files' self-references, and other stories/plans.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Carve DESIGN.md into topical specs now (trust-boundary.md, bump-engine.md, …) | Doubles the diff size and commingles two concerns (relocation + decomposition). Deferred to a follow-up story. |
| Move FLEET.md + needs-human.md into docs/specs/ too | Neither is a spec — FLEET.md is the opt-in registry (an ops reference), needs-human.md is an issue template. Keeping them at `docs/` root matches their role. |
| Rewrite CHANGELOG.md references | CHANGELOG is historical. Rewriting past entries lies about what the paths were when the change shipped. |
| Keep DESIGN.md at `docs/` and only create empty `docs/specs/` | Defeats the point. `docs/specs/` must be the home for DESIGN.md + CAPABILITIES.md on day one or the convention is folklore from day one. |

## Breaking changes

- [x] Yes — `docs/DESIGN.md` and `docs/CAPABILITIES.md` paths change. Any
  external reader (bookmarks, blog posts) will 404. Mitigation: this is
  pre-launch; no public link has been advertised yet.
- [ ] No

README is updated in the same PR. Memory files (`CLAUDE.md`, `memory/*.md`)
are updated. No downstream notice is needed — the fleet is internal.

## Rollout

- [x] README updated (points to `docs/specs/DESIGN.md`).
- [x] `memory/project.md` invariants updated (points to
  `docs/specs/DESIGN.md`).
- [x] `memory/workflow.md` capability-matrix section points to
  `docs/specs/CAPABILITIES.md`.
- [x] `docs/specs/DESIGN.md` self-references reconciled.
- [x] `CLAUDE.md` `@`-include and all §-references updated.
- [x] `Makefile.verify-traceability` wired up.
- [ ] Downstream notice — n/a.

## Shipping evidence (fill at step 6a)

### Lens 1 — Gherkin coverage

| Scenario (from story §8) | Test pointer | Status |
|---|---|---|
| the three directories exist | `test/acceptance/test_SH_012_docs_layout.sh:§1` | ✅ |
| authoritative contracts live under docs/specs/ | `test/acceptance/test_SH_012_docs_layout.sh:§2` | ✅ |
| ops references stay at docs/ root | `test/acceptance/test_SH_012_docs_layout.sh:§3` | ✅ |
| every live reference to docs/ resolves | `test/acceptance/test_SH_012_docs_layout.sh:§4` | ✅ |
| every acceptance test's Story + Plan headers resolve | `test/acceptance/test_SH_012_docs_layout.sh:§5` | ✅ |
| the layout spec exists | `test/acceptance/test_SH_012_docs_layout.sh:§6` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `docs.layout.three-dirs` | ✅ | ✅ | ✅ |
| `docs.specs.authoritative-contracts` | ✅ | ✅ (both old-path and new-path checked) | ✅ |
| `docs.references.stable` | ✅ | ✅ (resolves AND excludes CHANGELOG) | ✅ |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (out-of-scope) — DESIGN.md not carved | ✅ |
| New CAPs listed in §9 all appear in `docs/specs/CAPABILITIES.md` | ✅ |
| Protected-files invariant intact (DESIGN §12) | ✅ (no workflow/.shepherd.yml changes) |
| Budget caps unchanged | ✅ n/a |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

## Post-merge notes

_(filled after merge)_
