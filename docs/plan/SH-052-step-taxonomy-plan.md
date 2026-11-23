---
id: SH-052
slug: step-taxonomy
story: docs/stories/SH-052-step-taxonomy.md
branch: feat/SH-052-step-taxonomy
status: shipped
---

# SH-052 plan — Step taxonomy doc

**Story:** [SH-052](../stories/SH-052-step-taxonomy.md)

## Design delta

Pure docs. No code change. No workflow change.

**New files:**
- `docs/specs/test-taxonomy.md` — 12 categories + per-repo mapping table + deviations section + non-goals.
- `test/acceptance/test_SH_052_step_taxonomy.sh` — 18 assertions covering existence + category row count + per-repo mention + CAPABILITIES link.

**Modified:**
- `docs/specs/CAPABILITIES.md` — new row `dev-cycle.taxonomy.recommendation` under the dev-cycle section.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Rename every repo's targets to canonical names | Explicitly rejected in v3 contract. Survey shows forcing identical names across kernel-test (bash framework) + beaconry (Python+docker+pytest) loses information. |
| Enforce taxonomy as hard gate in audit | Recommendation only. Audit column goes ⚠️/✅, never ❌. |
| Require every repo to have targets in every category | Gaps are honest. kernel-test legitimately has no `scan`; shepherd has no `e2e`. Papering over costs clarity. |

## Breaking changes

- None. Zero code change. Existing targets keep their existing names.

## Rollout

- [x] Taxonomy doc lands.
- [x] CAP registered.
- [x] Acceptance test lands.
- [ ] Audit gains a 12th "taxonomy alignment" column on next re-run (separate story, no code change).

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Doc exists | `test_SH_052:§1` | ✅ |
| 12 category rows present | `test_SH_052:§2` (×12) | ✅ |
| All 7 repos mentioned in mapping | `test_SH_052:§3` (×7) | ✅ |
| CAPABILITIES has the row | `test_SH_052:§4` | ✅ |
| CAPABILITIES links the doc | `test_SH_052:§5` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Status |
|---|---|---|
| `dev-cycle.taxonomy.recommendation` | ✅ | new, active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| No step rename in any repo | ✅ |
| Deviations called out honestly | ✅ |
| Non-goals section explicit | ✅ |
| `make check` green | ✅ |
