---
id: SH-NNN
slug: short-kebab
story: docs/stories/SH-NNN-<slug>.md
branch: feat/SH-NNN-<slug>
status: in-progress    # in-progress → shipped
---

# SH-NNN plan — <one-line title>

**Story:** [SH-NNN](../stories/SH-NNN-<slug>.md)

## Design delta

<What changes. Which file(s), which function(s) (once code exists), which workflow,
which policy default, which CAP. Keep this concrete — a reader should be able to
predict the diff shape from reading this section.>

## Alternatives rejected

| Alternative | Why not |
|---|---|
| <option A> | <reason — scope, safety, onboarding budget, supply chain, agent budget> |
| <option B> | <reason> |

## Breaking changes

- [ ] Yes — <describe>: public gate renamed, default auto-merge policy flipped,
      protected-files list narrowed, scope level promoted, CAP removed, …
- [ ] No — strictly additive or internal.

If yes, README must be updated in the same PR and the PR body must call out the
break. Any change to the protected-files list needs a human-reviewed approval
(the bot cannot flip it).

## Rollout

- [ ] README updated (if public contract moved)
- [ ] `memory/project.md` invariants updated (if an invariant shifted)
- [ ] `docs/DESIGN.md` reconciled (if a §12 trust-boundary decision changed)
- [ ] Downstream notice sent to users of the Action (only if gate defaults moved)

## Shipping evidence (fill at step 6a)

Three lenses. Any ⚠️/❌ row blocks shipping — cycle back to step 4.

### Lens 1 — Gherkin coverage

| Scenario (from story §8) | Test pointer | Status |
|---|---|---|
| <Scenario name> | `<path to test>:LN` | ✅ / ⚠️ / ❌ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `cap.id.name` | | | ✅ / ⚠️ / ❌ |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (out-of-scope) — no scope creep | ✅ / ⚠️ / ❌ |
| New CAPs listed in §9 all appear in `docs/CAPABILITIES.md` | ✅ / ⚠️ / ❌ |
| Protected-files invariant intact (DESIGN §12) | ✅ / ⚠️ / ❌ |
| Budget caps unchanged, or escalated to a human-reviewed change | ✅ / ⚠️ / ❌ / n/a |
| `make verify-traceability` green | ✅ / ⚠️ / ❌ |
| `make check` green | ✅ / ⚠️ / ❌ |

## Post-merge notes

<Filled after the PR merges. One paragraph: what we learned, what bit us, what to
carry into the next story.>
