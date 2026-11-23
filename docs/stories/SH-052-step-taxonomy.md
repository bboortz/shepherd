---
id: SH-052
slug: step-taxonomy
status: shipped
created: 2026-11-23
owner: @benni
---

# SH-052 — Step taxonomy doc

> **Follow-up from the [2026-11-23 dev-workflow contract v3](../plan/IDEAS-dev-workflow-contract-v3.md).** Formalizes the 12 step categories from the brief as a shared vocabulary. Repos are encouraged to name a target `unit` if it runs unit tests, `scan` if it runs a security scanner, etc. — but no verifier fails on a deviation.

## 1. Who is the consumer?

- Repo maintainer who wants to know what to call a new target.
- Agent (Claude Code, shepherd-poc) that needs to predict what `make <name>` does in a repo it hasn't seen.
- Reviewer scanning a Makefile diff and asking "is this the right tier for this check?"

## 2. When does the story fire?

- One-time: ship `docs/specs/test-taxonomy.md`.
- Thereafter: audit matrix gains a "taxonomy alignment" column (soft).

## 3. What does success look like?

Mechanically checkable:

- `docs/specs/test-taxonomy.md` exists with 12 categories + per-repo mapping.
- Each category row carries: canonical name, one-line meaning, which stages it fires in, what it needs (toolchain / containers / lab / nothing), concrete examples per fleet repo.
- CAPABILITIES.md gains a `dev-cycle.taxonomy.recommendation` row (status `active`, no test pointer required — pure docs).
- Fleet audit matrix (next re-run) adds the soft column.

## 4. How urgent?

- [ ] Security-critical
- [ ] Correctness
- [x] Quality-of-life (shared vocabulary)
- [x] Onboarding (predictability)

## 5. Happy path

A new repo joins the fleet. Maintainer reads `docs/specs/test-taxonomy.md`, sees "need a target that runs unit tests, no I/O? call it `unit`." They name their target accordingly; agent reads it later and knows what tier it belongs to.

## 6. Edge cases / failure modes that matter

- **Repo has no target in a given category** (e.g. kernel-test has no `typecheck`). Fine — document the gap in the mapping table, don't invent a target.
- **Repo has a target with a canonical name but different content** (e.g. forge's `smoke` is `test-fast`, not a service startup). The mapping table calls it out ("deviation — forge `smoke` is ergonomic alias for fast test run").
- **New category emerges** (e.g. `fuzz` becomes a thing). Taxonomy doc is additive; new category can land without breaking existing repos.

## 7. Out of scope

- Renaming any existing target. Taxonomy is advisory.
- Making the audit's taxonomy-alignment column a hard gate. Soft forever.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: taxonomy doc exists
  Given docs/specs/test-taxonomy.md
  Then  the file has 12 category rows
  And   each row names at least one fleet repo as an example

Scenario: CAPABILITIES has the taxonomy row
  Given docs/specs/CAPABILITIES.md
  Then  it has an active row for dev-cycle.taxonomy.recommendation
  And   the test pointer links to docs/specs/test-taxonomy.md
```

Test: `test/acceptance/test_SH_052_step_taxonomy.sh` (existence + row count + CAPABILITIES link).

## 9. Capabilities delivered or extended

- `dev-cycle.taxonomy.recommendation` — new CAP.

---

## Plan doc

See `docs/plan/SH-052-step-taxonomy-plan.md`.
