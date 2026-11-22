---
id: SH-013
slug: caps-traceability
story: docs/stories/SH-013-caps-traceability.md
branch: feat/SH-013-caps-traceability
status: in-progress
---

# SH-013 plan — Capabilities-matrix traceability

**Story:** [SH-013](../stories/SH-013-caps-traceability.md)

## Design delta

- New `scripts/verify-traceability.sh` (~120 lines bash). Three rules:
  1. Every active CAP row in `docs/specs/CAPABILITIES.md` has a non-empty
     Test column.
  2. Every `test/acceptance/test_SH_*.sh` has a `# CAPs:` header; every CAP
     id named by `# CAPs:` exists in `docs/specs/CAPABILITIES.md`.
  3. Every story with `status: ready|in-progress|shipped` has at least one
     `` - `cap.id` `` bullet in §9.
- Rename `# Covers:` → `# CAPs:` across the 6 existing acceptance tests
  (SH-001, SH-007, SH-009, SH-010, SH-011, SH-012). Zero behaviour change —
  only the header label matches the healthy + forge convention exactly.
- Extend the Makefile `verify-traceability` target to run both the SH-012
  layout check and the new script:

  ```make
  verify-traceability: verify-docs-layout verify-caps-traceability
  verify-docs-layout:
          @test/acceptance/test_SH_012_docs_layout.sh
  verify-caps-traceability:
          @scripts/verify-traceability.sh
  ```

- New `test/acceptance/test_SH_013_traceability.sh` — happy path + three
  negative fixtures (CAP without test, test with unknown CAP, orphan story)
  built in a scratch tmpdir so the fixtures never pollute the real repo.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Port beaconry's ~500-line Python traceability check | Adds a Python dep to shepherd (currently pure bash + zig). Bidirectional enforcement is valuable but can land as a follow-up if drift justifies it. |
| Reshape `docs/specs/CAPABILITIES.md` to healthy's `### <cap.id>` + `- **Covered by**:` section format | 40+ CAPs to migrate, every story + test touched. Shepherd's table format is terser and already readable. Parser adapts. |
| Rename all CAP ids to `CAP-NNN` (beaconry flat format) | Breaks every existing story, plan, and test. `cap.id.name` already matches healthy + forge. |
| Accept both `# Covers:` and `# CAPs:` headers | Encourages drift. One canonical header is clearer. |

## Breaking changes

- [ ] No — strictly additive. Scripts added, Makefile target extended,
  test headers renamed (local to this repo, affects 6 files).

## Rollout

- [x] README untouched — no public contract change.
- [x] `memory/workflow.md` capability-matrix line unchanged (`make
  verify-traceability` was already the stated enforcement verb).
- [x] `docs/specs/DESIGN.md` untouched — no §12 trust-boundary shift.
- [ ] Downstream notice — n/a.

## Shipping evidence (fill at step 6a)

### Lens 1 — Gherkin coverage

| Scenario (from story §8) | Test pointer | Status |
|---|---|---|
| script exists + executable | `test/acceptance/test_SH_013_traceability.sh:§1` | ✅ |
| happy path on actual repo | `test/acceptance/test_SH_013_traceability.sh:§2` | ✅ |
| CAP without test pointer fails | `test/acceptance/test_SH_013_traceability.sh:§3` | ✅ |
| test with unknown CAP fails | `test/acceptance/test_SH_013_traceability.sh:§4` | ✅ |
| ready+ story without §9 CAPs fails | `test/acceptance/test_SH_013_traceability.sh:§5` | ✅ |
| # CAPs header convention | `test/acceptance/test_SH_013_traceability.sh:§6` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `traceability.caps-have-test-pointer` | ✅ | ✅ (positive + CAP-without-test fixture) | ✅ |
| `traceability.tests-name-known-caps` | ✅ | ✅ (positive + unknown-CAP fixture) | ✅ |
| `traceability.stories-name-caps` | ✅ | ✅ (positive + orphan-story fixture) | ✅ |
| `traceability.unified-make-target` | ✅ | ✅ (make verify-traceability runs both) | ✅ |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 — no bidirectional enforcement, no CAP-id rename | ✅ |
| New CAPs listed in §9 all appear in `docs/specs/CAPABILITIES.md` | ✅ |
| Protected-files invariant intact (DESIGN §12) | ✅ (no workflow/.shepherd.yml changes) |
| Budget caps unchanged | ✅ n/a |
| `make verify-traceability` green | ✅ |
| `make check` green | ✅ |

## Post-merge notes

_(filled after merge)_
