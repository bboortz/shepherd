---
id: SH-012
slug: docs-layout-reshape
status: in-progress
created: 2026-11-22
owner: @benni
---

# SH-012 — Reshape `docs/` into specs / plan / stories

## 1. Who is the consumer?

Contributor extending Shepherd itself (humans and Claude alike). The layout of
`docs/` is the first thing anyone reads — it has to tell you where to add a
spec vs. where to add a plan vs. where to look for the authoritative contract.

## 2. When does the story fire?

Whenever someone opens the repo and asks "where does X live?" — concretely:
starting a new SH-NNN story, reading the trust boundary before touching
`validate.sh`, or wiring a new acceptance test's `# Spec:` / `# Story:` /
`# Plan:` headers.

## 3. What does success look like?

- `docs/specs/`, `docs/plan/`, `docs/stories/` exist as the three top-level
  categories under `docs/`.
- The two authoritative contract documents (`DESIGN.md`, `CAPABILITIES.md`)
  live under `docs/specs/`.
- Every live reference in the repo (markdown, shell, YAML, Makefile) that
  points into `docs/` resolves to a real file — no dangling links.
- A single acceptance test, `test_SH_012_docs_layout.sh`, enforces all of
  the above and is wired into `make verify-traceability`.

## 4. How urgent?

- [x] Quality-of-life (layout drift costs time on every new story)
- [ ] Security-critical
- [ ] Correctness
- [ ] Onboarding

## 5. Happy path

```
$ ls docs/
CAPABILITIES.md-less              (moved)
DESIGN.md-less                    (moved)
FLEET.md                          (stays — ops reference)
needs-human.md                    (stays — template)
plan/                             (stays)
specs/                            (new home for DESIGN + CAPABILITIES + future specs)
stories/                          (stays)

$ make verify-traceability
test_SH_012_docs_layout: pass=42 fail=0
```

## 6. Edge cases / failure modes that matter

- A future contributor adds `docs/foo.md` at the root — the test must either
  reject it or the rules must document that the four "non-spec" root files
  (`README.md` and `needs-human.md`, plus future ops references) are the
  only allowed root-level docs files.
- A test file carries a `# Story:` / `# Plan:` header pointing to a path that
  was renamed — the test must catch the broken pointer.
- `CHANGELOG.md` references the *old* paths (`docs/DESIGN.md §12`) by design:
  it is a historical record. The test must exclude CHANGELOG.md from reference
  rewriting so history stays truthful.
- DESIGN.md itself has a self-reference (`## 8. Escalation template
  (\`docs/needs-human.md\`)`) — that reference stays correct because
  needs-human.md stays at the docs/ root.

## 7. Out of scope

- Carving DESIGN.md into topical specs (trust-boundary.md, bump-engine.md, …).
  That is deferred to a follow-up story per the SH-012 design decision.
- Rewriting `CHANGELOG.md` — historical entries use the paths that existed
  when they were written.
- Component specs for the enforcement scripts (`validate.sh`,
  `regen-lockfile.sh`, …). The shape is defined by `docs/specs/docs-layout.md`
  in this story; actual component specs land as follow-up stories.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: the three directories exist
  Given the repo at HEAD
  Then  docs/specs/, docs/plan/, docs/stories/ are directories

Scenario: authoritative contracts live under docs/specs/
  Given the repo at HEAD
  Then  docs/specs/DESIGN.md exists
  And   docs/specs/CAPABILITIES.md exists
  And   docs/DESIGN.md does NOT exist at the old path
  And   docs/CAPABILITIES.md does NOT exist at the old path

Scenario: ops references stay at docs/ root
  Given the repo at HEAD
  Then  docs/FLEET.md exists at the docs/ root
  And   docs/needs-human.md exists at the docs/ root

Scenario: every live reference to docs/ resolves
  Given every tracked file except CHANGELOG.md
  When  we extract substrings matching docs/<path>.md or docs/<dir>/
  Then  every extracted path resolves to a real file or directory

Scenario: every acceptance test's Story + Plan headers resolve
  Given test/acceptance/test_SH_*.sh
  Then  each file's `# Story:` and `# Plan:` header points to a real file

Scenario: the layout spec exists
  Given the repo at HEAD
  Then  docs/specs/docs-layout.md exists and documents the convention
```

## 9. Capabilities delivered or extended

- `docs.layout.three-dirs` — `docs/` has exactly `specs/`, `plan/`, `stories/`
  as the SH-NNN-shaped subdirectories; `README.md`, `FLEET.md`,
  `needs-human.md` may live at the root (ops references + templates).
- `docs.specs.authoritative-contracts` — the authoritative product and
  capability contracts (`DESIGN.md`, `CAPABILITIES.md`) live under
  `docs/specs/` and nowhere else.
- `docs.references.stable` — every live reference from a tracked non-CHANGELOG
  file to a `docs/` path must resolve. Enforced by
  `test_SH_012_docs_layout.sh` and `make verify-traceability`.

---

## Plan doc

[`docs/plan/SH-012-docs-layout-reshape-plan.md`](../plan/SH-012-docs-layout-reshape-plan.md).
