# Spec — `docs/` layout

Status: active · Delivered by [SH-012](../stories/SH-012-docs-layout-reshape.md) ·
Enforced by [`test/acceptance/test_SH_012_docs_layout.sh`](../../test/acceptance/test_SH_012_docs_layout.sh)
wired into `make verify-traceability`.

## Why this document exists

Three kinds of long-lived documents live under `docs/`: **specs** (what
Shepherd promises to do and how), **plans** (how a specific story is being
executed), and **stories** (who asked for what and why). Each goes in its own
subdirectory so a reader can find the right thing without grep and so the
acceptance test can enforce the convention without heuristics.

## Directory map

```
docs/
  specs/                   — authoritative contracts (product + capability)
    DESIGN.md              — the design source of truth (§1–13)
    CAPABILITIES.md        — capability matrix with bidirectional test links
    docs-layout.md         — this file (meta-spec)
    <future topical specs> — e.g. trust-boundary.md, bump-engine.md, sandbox.md
    <future component specs> — e.g. validate.sh.md, regen-lockfile.sh.md
  plan/                    — one plan per in-progress / shipped story
    _template.md           — canonical plan template
    IDEAS.md               — backlog not yet promoted to stories
    SH-NNN-<slug>-plan.md  — one file per story
  stories/                 — one story per observable change
    _template.md           — canonical story template
    _9-questions.md        — the canonical clarification set
    INDEX.md               — grep-friendly status board
    SH-NNN-<slug>.md       — one file per story
  FLEET.md                 — opt-in registry of repos running Shepherd (ops ref)
  needs-human.md           — escalation issue template (consumed by shepherd-poc)
```

### Why `FLEET.md` and `needs-human.md` live at the `docs/` root

Neither is a spec. `FLEET.md` is a continuously-updated ops reference (the
opt-in registry of repos on Shepherd). `needs-human.md` is a consumed template
— the escalation shell script reads it as the body for new issues. Both would
be mis-filed as specs. Both would be mis-filed under `plan/` or `stories/`.
`docs/` root is the honest home.

## Spec taxonomy inside `docs/specs/`

Two kinds of specs are expected over time:

- **Topical specs** — self-contained slices of the product contract.
  `DESIGN.md` is the anchor today; future carved specs (e.g. `trust-boundary.md`,
  `bump-engine.md`, `sandbox.md`) will each own one topic.
- **Component specs** — interface contracts for a concrete script or
  workflow. One file per enforcement artefact
  (`scripts/shepherd-poc/validate.sh`, `scripts/shepherd-poc/regen-lockfile.sh`,
  `.github/workflows/reusable-shepherd.yml`, …). Each component spec states
  inputs, outputs, exit codes, protected invariants, and points at the
  artefact it specs.

Both kinds coexist. The acceptance test does not distinguish them — only the
*location* (`docs/specs/`) is enforced.

## Reference stability

Every live file in the repo except `CHANGELOG.md` must have working links
into `docs/`. `CHANGELOG.md` is historical and intentionally keeps the paths
that existed when each entry shipped — rewriting it would lie about history.

The acceptance test extracts every substring that looks like
`docs/<...>.md` or `docs/<dir>/` from every tracked non-CHANGELOG file and
asserts each resolves to a real path.

## Test-header convention

Acceptance tests under `test/acceptance/test_SH_*.sh` carry three pointer
headers at the top of the file:

```sh
# Story:  docs/stories/SH-NNN-<slug>.md
# Plan:   docs/plan/SH-NNN-<slug>-plan.md
# Covers: cap.id.name, ...
```

A `# Spec:` header becomes recommended once component specs land; it is
**not yet required** — component specs are deferred. The acceptance test
only enforces `# Story:` and `# Plan:` today.

## What this spec deliberately does NOT do

- Carve `DESIGN.md` into topical specs. Deferred to a follow-up story.
- Define a `# Spec:` acceptance-test header. Deferred until the first
  component spec lands and names a CAP tied to that spec.
- Rewrite `CHANGELOG.md`. Historical by design.
